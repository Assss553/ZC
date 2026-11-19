package com.rox.gameai.connection

import android.content.Context
import android.content.Intent
import android.net.Uri
import com.rox.gameai.core.ConsoleType
import com.rox.gameai.core.RoxLog
import com.rox.gameai.core.SavedConsole
import com.rox.gameai.core.SettingsRepo
import com.rox.gameai.core.Store
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

enum class LinkStatus { IDLE, SEARCHING, CONNECTED, STANDBY, LOST, RECONNECTING }

data class ConnState(
    val status: LinkStatus = LinkStatus.IDLE,
    val console: SavedConsole? = null,
    val runningApp: String? = null,
    val runningTitleId: String? = null,
    val lastSeen: Long = 0,
    val message: String = "",
)

/**
 * Wireless link to a PS4/PS5 on the LAN: discovery, saved (paired) consoles, live status polling,
 * loss detection and automatic re-discovery (also when the console's IP changed).
 *
 * NOTE: this link reports the console state + running game. The VIDEO itself reaches the phone through
 * the official PS Remote Play app (screen capture) or an HDMI capture card — see the pipeline.
 */
class ConnectionManager(private val context: Context, private val store: Store, private val settings: SettingsRepo, private val scope: CoroutineScope) {
    private val discovery = ConsoleDiscovery(context)
    private val _state = MutableStateFlow(ConnState())
    val state: StateFlow<ConnState> = _state
    private val _found = MutableStateFlow<List<DdpProtocol.Response>>(emptyList())
    val found: StateFlow<List<DdpProtocol.Response>> = _found
    private var monitor: Job? = null

    init {
        store.consoles.value.firstOrNull { it.autoConnect }?.let { connect(it) }
    }

    fun scan(manualIp: String? = null) = scope.launch {
        _state.value = _state.value.copy(status = if (_state.value.console == null) LinkStatus.SEARCHING else _state.value.status, message = "")
        val r = discovery.discover(targetIp = manualIp?.takeIf { it.isNotBlank() })
        _found.value = r
        RoxLog.i("Connect", "Scan finished: ${r.size} console(s) ${r.joinToString { "${it.type}/${it.hostName}@${it.ip}" }}")
        if (_state.value.console == null) _state.value = _state.value.copy(status = LinkStatus.IDLE, message = if (r.isEmpty()) "no_console" else "")
    }

    /** "Pairing" = saving this console as trusted ROX device and monitoring it. */
    fun pair(r: DdpProtocol.Response) {
        val c = SavedConsole(r.hostId, r.hostName, r.type, r.ip, System.currentTimeMillis(), true)
        store.upsertConsole(c)
        RoxLog.i("Connect", "Paired ${c.type} ${c.name} (${c.ip})")
        connect(c)
    }

    fun addManual(ip: String, type: ConsoleType, name: String) {
        val c = SavedConsole("manual-$ip", name.ifBlank { "PlayStation" }, type, ip, 0, true)
        store.upsertConsole(c); connect(c)
    }

    fun forget(hostId: String) {
        store.removeConsole(hostId)
        if (_state.value.console?.hostId == hostId) disconnect()
    }

    fun disconnect() {
        monitor?.cancel(); monitor = null
        _state.value = ConnState()
    }

    fun connect(c: SavedConsole) {
        monitor?.cancel()
        _state.value = ConnState(LinkStatus.SEARCHING, c)
        monitor = scope.launch {
            var misses = 0
            while (isActive) {
                var cur = _state.value.console ?: break
                var r = discovery.discover(timeoutMs = 1500, targetIp = cur.ip).firstOrNull { it.hostId == cur.hostId || cur.hostId.startsWith("manual-") }
                if (r == null && settings.value.autoReconnect && misses >= 1) {
                    // IP may have changed (DHCP): broadcast and match by host id
                    _state.value = _state.value.copy(status = LinkStatus.RECONNECTING)
                    r = discovery.discover(timeoutMs = 2000).firstOrNull { it.hostId == cur.hostId }
                }
                if (r != null) {
                    if (misses > 0 || _state.value.status != LinkStatus.CONNECTED) RoxLog.i("Connect", "Console reachable: ${r.hostName} state=${r.state} app=${r.runningAppName}")
                    misses = 0
                    if (cur.hostId.startsWith("manual-") || r.ip != cur.ip || cur.type != r.type) {
                        store.removeConsole(cur.hostId)
                        cur = SavedConsole(r.hostId, r.hostName, r.type, r.ip, System.currentTimeMillis(), cur.autoConnect)
                    } else cur = cur.copy(lastSeen = System.currentTimeMillis())
                    store.upsertConsole(cur)
                    _state.value = ConnState(
                        status = if (r.state == DdpProtocol.PowerState.STANDBY) LinkStatus.STANDBY else LinkStatus.CONNECTED,
                        console = cur, runningApp = r.runningAppName, runningTitleId = r.runningAppTitleId, lastSeen = System.currentTimeMillis(),
                    )
                } else {
                    misses++
                    if (misses == 2) RoxLog.w("Connect", "Console ${cur.name} not responding (lost)")
                    _state.value = _state.value.copy(status = if (misses >= 2) LinkStatus.LOST else _state.value.status)
                }
                delay(settings.value.discoveryIntervalSec.coerceAtLeast(3) * 1000L)
            }
        }
    }

    fun isRemotePlayInstalled(): Boolean = context.packageManager.getLaunchIntentForPackage(REMOTE_PLAY_PKG) != null

    /** Opens the official PS Remote Play app (which performs Sony's own sign-in, pairing and streaming). */
    fun launchRemotePlay() {
        val i = context.packageManager.getLaunchIntentForPackage(REMOTE_PLAY_PKG)
            ?: Intent(Intent.ACTION_VIEW, Uri.parse("https://play.google.com/store/apps/details?id=$REMOTE_PLAY_PKG"))
        i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        runCatching { context.startActivity(i) }.onFailure { RoxLog.e("Connect", "Cannot open PS Remote Play", it) }
    }

    companion object { const val REMOTE_PLAY_PKG = "com.playstation.remoteplay" }
}
