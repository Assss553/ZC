package com.rox.gameai.connection

import android.content.Context
import android.net.nsd.NsdManager
import android.net.nsd.NsdServiceInfo
import android.os.Build
import com.rox.gameai.core.RoxLog
import com.rox.gameai.core.TextKind
import com.rox.gameai.core.TextOverlay
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import org.json.JSONObject
import java.util.concurrent.TimeUnit

/** Phone → ROX TV link: finds the TV with NSD (mDNS), pairs with the 6-digit code shown on the TV, sends subtitles. */
class TvLink(private val context: Context, private val scope: CoroutineScope) {
    data class Tv(val name: String, val host: String, val port: Int)
    data class State(val connected: Boolean = false, val paired: Boolean = false, val tv: Tv? = null, val message: String = "", val mode: String = "", val sent: Int = 0, val lastSent: String = "", val acked: Int = 0, val shownOnTv: Boolean? = null)

    private val _state = MutableStateFlow(State())
    val state: StateFlow<State> = _state
    private val _found = MutableStateFlow<List<Tv>>(emptyList())
    val found: StateFlow<List<Tv>> = _found
    private val http = OkHttpClient.Builder().pingInterval(5, TimeUnit.SECONDS).readTimeout(0, TimeUnit.MILLISECONDS).build()
    private var ws: WebSocket? = null
    private var code = ""
    private var wanted: Tv? = null
    private var keepAlive: Job? = null
    private var lastText = ""; private var lastSentAt = 0L; private var emptySince = 0L; private var seq = 0L
    private var discovery: NsdManager.DiscoveryListener? = null

    fun discover() {
        val nsd = context.getSystemService(NsdManager::class.java)
        discovery?.let { runCatching { nsd.stopServiceDiscovery(it) } }
        _found.value = emptyList()
        val l = object : NsdManager.DiscoveryListener {
            override fun onDiscoveryStarted(t: String) { RoxLog.i("TV", "Searching for ROX TV…") }
            override fun onDiscoveryStopped(t: String) {}
            override fun onStartDiscoveryFailed(t: String, e: Int) { RoxLog.w("TV", "Discovery failed ($e) — enter the TV IP manually") }
            override fun onStopDiscoveryFailed(t: String, e: Int) {}
            override fun onServiceLost(s: NsdServiceInfo) {}
            override fun onServiceFound(s: NsdServiceInfo) {
                @Suppress("DEPRECATION")
                nsd.resolveService(s, object : NsdManager.ResolveListener {
                    override fun onResolveFailed(s: NsdServiceInfo, e: Int) {}
                    override fun onServiceResolved(s: NsdServiceInfo) {
                        val host = (if (Build.VERSION.SDK_INT >= 34) s.hostAddresses.firstOrNull() else @Suppress("DEPRECATION") s.host)?.hostAddress ?: return
                        val tv = Tv(s.serviceName, host, s.port)
                        if (_found.value.none { it.host == host }) { _found.value = _found.value + tv; RoxLog.i("TV", "Found ${tv.name} at $host") }
                    }
                })
            }
        }
        discovery = l
        runCatching { nsd.discoverServices("_roxtv._tcp.", NsdManager.PROTOCOL_DNS_SD, l) }.onFailure { RoxLog.e("TV", "NSD unavailable", it) }
    }

    fun connect(tv: Tv, pairingCode: String) {
        code = pairingCode.trim().map { if (Character.isDigit(it)) ('0' + Character.getNumericValue(it)) else it }.joinToString(""); wanted = tv
        open(tv)
        keepAlive?.cancel()
        keepAlive = scope.launch {
            while (isActive && wanted != null) {
                delay(3000)
                if (!_state.value.connected && wanted != null) { RoxLog.w("TV", "Reconnecting to ${tv.host}"); open(tv) }
            }
        }
    }

    fun disconnect() { wanted = null; keepAlive?.cancel(); ws?.close(1000, "bye"); ws = null; _state.value = State() }

    private fun open(tv: Tv) {
        ws?.cancel()
        ws = http.newWebSocket(Request.Builder().url("ws://${tv.host}:${tv.port}").build(), object : WebSocketListener() {
            override fun onOpen(webSocket: WebSocket, response: Response) {
                _state.value = _state.value.copy(connected = true, tv = tv, message = "")
                webSocket.send(JSONObject().put("type", "hello").put("code", code).put("device", Build.MODEL).toString())
            }
            override fun onMessage(webSocket: WebSocket, text: String) {
                val j = runCatching { JSONObject(text) }.getOrNull() ?: return
                when (j.optString("type")) {
                    "welcome" -> { _state.value = _state.value.copy(paired = true, mode = j.optString("mode")); RoxLog.i("TV", "Paired with ${tv.name} (${tv.host})"); lastText = "" }
                    "ack" -> {
                        val shown = j.optBoolean("shown")
                        _state.value = _state.value.copy(acked = _state.value.acked + 1, shownOnTv = shown)
                        if (!shown) RoxLog.w("TV", "TV received the subtitle but it is NOT visible on screen (subtitles off, or hidden under the HDMI picture)")
                    }
                    "error" -> { _state.value = _state.value.copy(paired = false, message = j.optString("reason")); RoxLog.w("TV", "TV refused: ${j.optString("reason")}") }
                }
            }
            override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
                _state.value = _state.value.copy(connected = false, paired = false, message = t.message ?: "error")
            }
            override fun onClosed(webSocket: WebSocket, code: Int, reason: String) { _state.value = _state.value.copy(connected = false, paired = false) }
        })
    }

    /** Called with every OCR/translation result; sends only changes, refreshes TTL, clears when the dialogue is gone. */
    private var lastItemsKey = ""; private var lastItemsAt = 0L

    /**
     * Positioned translations (menus, labels) drawn on the TV where the original text is.
     * Coordinates are normalised to the 16:9 game picture inside the captured phone screen
     * (Remote Play letterboxes the game; we remove the side bars).
     */
    fun onPositioned(list: List<TextOverlay>, frameW: Int, frameH: Int, now: Long = System.currentTimeMillis()) {
        if (!_state.value.paired || frameW <= 0 || frameH <= 0) return
        val gw: Float; val gh: Float; val ox: Float; val oy: Float
        if (frameW.toFloat() / frameH > 16f / 9f) { gh = frameH.toFloat(); gw = gh * 16f / 9f; ox = (frameW - gw) / 2f; oy = 0f }
        else { gw = frameW.toFloat(); gh = gw * 9f / 16f; ox = 0f; oy = (frameH - gh) / 2f }
        val items = org.json.JSONArray()
        list.filter { it.translated.isNotBlank() && it.kind != TextKind.DIALOG }.take(24).forEach { o ->
            val l = (o.rect.left - ox) / gw; val t = (o.rect.top - oy) / gh; val r = (o.rect.right - ox) / gw; val b = (o.rect.bottom - oy) / gh
            if (r <= 0f || b <= 0f || l >= 1f || t >= 1f) return@forEach
            items.put(JSONObject().put("t", o.translated).put("l", l.toDouble()).put("tp", t.toDouble()).put("r", r.toDouble()).put("b", b.toDouble()).put("k", o.kind.name))
        }
        val key = items.toString()
        if (key == lastItemsKey && now - lastItemsAt < 2000) return
        lastItemsKey = key; lastItemsAt = now
        send(JSONObject().put("type", "items").put("items", items).put("ttlMs", 3000))
    }

    fun onOverlays(list: List<TextOverlay>, now: Long = System.currentTimeMillis()) {
        if (!_state.value.paired) return
        val best = list.filter { it.translated.isNotBlank() && it.kind in setOf(TextKind.DIALOG, TextKind.MISSION, TextKind.NOTIFICATION, TextKind.SIGN) }
            .sortedBy { when (it.kind) { TextKind.DIALOG -> 0; TextKind.MISSION -> 1; TextKind.NOTIFICATION -> 2; TextKind.SIGN -> 3; else -> 4 } }
            .take(2)
        val text = best.joinToString("\n") { it.translated }
        val speaker = best.firstOrNull()?.speaker.orEmpty()
        if (text.isEmpty()) {
            if (lastText.isNotEmpty()) { if (emptySince == 0L) emptySince = now; if (now - emptySince > 1200) { send(JSONObject().put("type", "clear")); lastText = "" } }
            return
        }
        emptySince = 0L
        if (text != lastText || now - lastSentAt > 2000) {
            sendSubtitle(text, speaker, best.first().kind.name)
            lastText = text; lastSentAt = now
        }
    }

    fun sendSubtitle(text: String, speaker: String = "", kind: String = "DIALOG", ttlMs: Long = 4500) {
        send(JSONObject().put("type", "subtitle").put("text", text).put("speaker", speaker).put("kind", kind).put("ttlMs", ttlMs).put("id", ++seq))
        _state.value = _state.value.copy(sent = _state.value.sent + 1, lastSent = text)
    }

    private fun send(j: JSONObject) { ws?.send(j.toString()) }
}
