package com.rox.gameai.connection

import com.rox.gameai.core.IRect
import com.rox.gameai.core.RoxLog
import com.rox.gameai.core.Store
import com.rox.gameai.core.TextKind
import com.rox.gameai.core.TextOverlay
import com.rox.gameai.core.TranslationEntry
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import org.json.JSONObject
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetAddress
import java.net.SocketTimeoutException
import java.util.concurrent.TimeUnit

/**
 * Link to ROX Server running on the user's PC (same Wi-Fi). The PC receives the PlayStation stream
 * through the official chiaki-ng client and runs OCR/translation/Safe Vision on its GPU; this client
 * shows the results on the phone.
 */
class RoxServerClient(private val store: Store, private val scope: CoroutineScope) {
    data class Server(val name: String, val host: String, val port: Int)
    data class State(
        val connected: Boolean = false, val server: Server? = null, val message: String = "",
        val fps: Double = 0.0, val ocrMs: Int = 0, val lang: String = "", val running: Boolean = false,
    )

    private val _state = MutableStateFlow(State())
    val state: StateFlow<State> = _state
    private val _found = MutableStateFlow<List<Server>>(emptyList())
    val found: StateFlow<List<Server>> = _found
    private val _subtitles = MutableStateFlow<List<TextOverlay>>(emptyList())
    val subtitles: StateFlow<List<TextOverlay>> = _subtitles
    private val seen = HashMap<String, Long>()
    private val http = OkHttpClient.Builder().pingInterval(10, TimeUnit.SECONDS).readTimeout(0, TimeUnit.MILLISECONDS).build()
    private var ws: WebSocket? = null
    private var reconnect: Job? = null
    @Volatile private var wanted: Server? = null

    suspend fun discover(timeoutMs: Long = 2000): List<Server> = withContext(Dispatchers.IO) {
        val out = LinkedHashMap<String, Server>()
        runCatching {
            DatagramSocket().use { s ->
                s.broadcast = true; s.soTimeout = 300
                val msg = "ROX_DISCOVER".toByteArray()
                s.send(DatagramPacket(msg, msg.size, InetAddress.getByName("255.255.255.255"), DISCOVERY_PORT))
                val buf = ByteArray(1024)
                val end = System.currentTimeMillis() + timeoutMs
                while (System.currentTimeMillis() < end) {
                    val p = DatagramPacket(buf, buf.size)
                    try {
                        s.receive(p)
                        val j = JSONObject(String(p.data, 0, p.length))
                        val host = p.address.hostAddress ?: continue
                        out[host] = Server(j.optString("name", "ROX Server"), host, j.optInt("port", 9750))
                    } catch (_: SocketTimeoutException) {
                    }
                }
            }
        }.onFailure { RoxLog.e("RoxServer", "Discovery failed", it) }
        out.values.toList().also { _found.value = it; RoxLog.i("RoxServer", "Found ${it.size} ROX Server(s)") }
    }

    fun connect(server: Server) {
        wanted = server
        open(server)
        reconnect?.cancel()
        reconnect = scope.launch {
            while (isActive && wanted != null) {
                delay(4000)
                if (!_state.value.connected && wanted != null) { RoxLog.w("RoxServer", "Reconnecting to ${server.host}"); open(server) }
            }
        }
    }

    fun connectManual(host: String, port: Int = 9750) = connect(Server("ROX Server", host.trim(), port))

    fun disconnect() {
        wanted = null; reconnect?.cancel(); ws?.close(1000, "bye"); ws = null
        _state.value = State(); _subtitles.value = emptyList()
    }

    private fun open(server: Server) {
        ws?.cancel()
        val req = Request.Builder().url("ws://${server.host}:${server.port}/ws").build()
        ws = http.newWebSocket(req, object : WebSocketListener() {
            override fun onOpen(webSocket: WebSocket, response: Response) {
                _state.value = _state.value.copy(connected = true, server = server, message = "")
                RoxLog.i("RoxServer", "Connected to ${server.host}:${server.port}")
            }
            override fun onMessage(webSocket: WebSocket, text: String) = handle(text)
            override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
                if (_state.value.connected) RoxLog.w("RoxServer", "Connection lost: ${t.message}")
                _state.value = _state.value.copy(connected = false, server = server, message = t.message ?: "error")
            }
            override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
                _state.value = _state.value.copy(connected = false)
            }
        })
    }

    fun send(cmd: JSONObject) { ws?.send(cmd.toString()) }

    private fun handle(text: String) {
        try {
            val j = JSONObject(text)
            when (j.optString("type")) {
                "status", "hello" -> {
                    val s = if (j.has("status")) j.optJSONObject("status") ?: j else j
                    _state.value = _state.value.copy(fps = s.optDouble("fps", 0.0), ocrMs = s.optInt("ocr_ms"), lang = s.optString("lang"), running = s.optBoolean("running"))
                }
                "frame" -> {
                    val arr = j.optJSONArray("subtitles") ?: return
                    val now = System.currentTimeMillis()
                    val list = (0 until arr.length()).map { i ->
                        val o = arr.getJSONObject(i)
                        val b = o.optJSONArray("box")
                        val rect = if (b != null && b.length() == 4) IRect(b.getInt(0), b.getInt(1), b.getInt(2), b.getInt(3)) else IRect(0, 0, 0, 0)
                        val kind = runCatching { TextKind.valueOf(o.optString("kind")) }.getOrDefault(TextKind.OTHER)
                        TextOverlay(rect, o.optString("original"), o.optString("translated"), kind, o.optString("speaker"))
                    }
                    _subtitles.value = list
                    for (s in list) {
                        val k = s.original.lowercase()
                        if (now - (seen[k] ?: 0) > 20_000) {
                            store.addTranslation(TranslationEntry(now, "PC", s.kind, s.original, _state.value.lang, s.translated, s.speaker))
                        }
                        seen[k] = now
                    }
                    if (seen.size > 2000) seen.entries.removeIf { now - it.value > 60_000 }
                }
            }
        } catch (t: Throwable) { RoxLog.e("RoxServer", "Bad message", t) }
    }

    companion object { const val DISCOVERY_PORT = 9751 }
}
