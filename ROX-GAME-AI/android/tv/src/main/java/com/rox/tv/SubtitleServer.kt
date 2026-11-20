package com.rox.tv

import android.content.Context
import android.net.nsd.NsdManager
import android.net.nsd.NsdServiceInfo
import android.os.Handler
import android.os.Looper
import android.util.Log
import org.java_websocket.WebSocket
import org.java_websocket.handshake.ClientHandshake
import org.java_websocket.server.WebSocketServer
import java.net.InetSocketAddress

/** Local WebSocket server on the TV + mDNS/NSD advertisement so the phone finds it automatically. */
class SubtitleServer private constructor(private val context: Context, val code: String) {
    var mode: () -> String = { "A" }
    var onChange: (text: String) -> Unit = {}
    var onStatus: (String) -> Unit = {}
    var isShown: () -> Boolean = { false }
    var onItems: (List<TvProtocol.Msg.Item>, Long) -> Unit = { _, _ -> }
    @Volatile var lastStatus = "starting…"; private set

    companion object {
        @Volatile private var instance: SubtitleServer? = null
        /** One server per process: re-opening ROX TV re-attaches instead of binding port 9770 twice. */
        @Synchronized fun get(context: Context, code: String): SubtitleServer =
            instance ?: SubtitleServer(context.applicationContext, code).also { instance = it; it.start() }
    }

    private val main = Handler(Looper.getMainLooper())
    val state = SubtitleState(code)
    private var server: WebSocketServer? = null
    private var nsd: NsdManager? = null
    private var reg: NsdManager.RegistrationListener? = null
    @Volatile var clients = 0; private set

    private fun start() {
        val s = object : WebSocketServer(InetSocketAddress(TvProtocol.PORT)) {
            override fun onOpen(conn: WebSocket, handshake: ClientHandshake) { status("phone connecting…") }
            override fun onClose(conn: WebSocket, code: Int, reason: String?, remote: Boolean) {
                main.post { state.remove(conn); clients = connections.count { state.isPaired(it) }; status(if (clients > 0) "phone connected" else "waiting for phone") }
            }
            override fun onMessage(conn: WebSocket, message: String) {
                val m = TvProtocol.parse(message)
                main.post {
                    when (m) {
                        is TvProtocol.Msg.Hello -> if (state.onHello(conn, m)) {
                            conn.send(TvProtocol.welcome("ROX TV", mode())); clients = connections.count { state.isPaired(it) }
                            status("phone connected: ${m.device}")
                        } else { conn.send(TvProtocol.error("bad_code")); status("wrong pairing code from phone") }
                        is TvProtocol.Msg.Subtitle -> {
                            if (state.onSubtitle(conn, m, System.currentTimeMillis())) onChange(state.text)
                            // Ack after layout so the phone learns whether the text is really visible
                            main.postDelayed({ runCatching { conn.send("{\"type\":\"ack\",\"id\":${m.id},\"shown\":${isShown()}}") } }, 300)
                        }
                        is TvProtocol.Msg.Items -> if (state.isPaired(conn)) onItems(m.items, m.ttlMs)
                        TvProtocol.Msg.Clear -> if (state.onClear(conn)) onChange("")
                        TvProtocol.Msg.Ping -> conn.send("{\"type\":\"pong\"}")
                        is TvProtocol.Msg.Unknown -> Log.w("ROXTV", "unknown msg")
                    }
                }
            }
            override fun onError(conn: WebSocket?, ex: Exception) { Log.e("ROXTV", "server error", ex); status("server error: ${ex.message}") }
            override fun onStart() { status("waiting for phone") }
        }
        s.isReuseAddr = true
        s.connectionLostTimeout = 10
        try { s.start() } catch (t: Throwable) { status("server error: ${t.message}") }
        server = s
        // Auto-hide expired subtitles
        main.post(object : Runnable { override fun run() { if (state.tick(System.currentTimeMillis())) onChange(""); main.postDelayed(this, 250) } })
        register()
    }

    private fun register() {
        val info = NsdServiceInfo().apply { serviceName = "ROX TV"; serviceType = TvProtocol.SERVICE_TYPE; port = TvProtocol.PORT }
        val l = object : NsdManager.RegistrationListener {
            override fun onServiceRegistered(i: NsdServiceInfo) { Log.i("ROXTV", "NSD registered ${i.serviceName}") }
            override fun onRegistrationFailed(i: NsdServiceInfo, e: Int) { status("network discovery failed ($e) — enter the TV IP on the phone") }
            override fun onServiceUnregistered(i: NsdServiceInfo) {}
            override fun onUnregistrationFailed(i: NsdServiceInfo, e: Int) {}
        }
        nsd = context.getSystemService(NsdManager::class.java)
        runCatching { nsd?.registerService(info, NsdManager.PROTOCOL_DNS_SD, l); reg = l }
    }

    private fun status(s: String) = main.post { lastStatus = s; onStatus(s) }

    fun stop() {
        runCatching { reg?.let { nsd?.unregisterService(it) } }
        runCatching { server?.stop(500) }
    }
}
