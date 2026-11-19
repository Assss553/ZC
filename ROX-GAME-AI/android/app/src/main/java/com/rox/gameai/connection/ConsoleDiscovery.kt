package com.rox.gameai.connection

import android.content.Context
import android.net.ConnectivityManager
import android.net.LinkProperties
import com.rox.gameai.core.RoxLog
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.Inet4Address
import java.net.InetAddress
import java.net.SocketTimeoutException

/** Finds PS4/PS5 consoles on the local Wi-Fi network using UDP discovery (broadcast or a specific IP). */
class ConsoleDiscovery(private val context: Context) {

    private fun broadcastAddresses(): List<InetAddress> {
        val out = mutableListOf<InetAddress>(InetAddress.getByName("255.255.255.255"))
        runCatching {
            val cm = context.getSystemService(ConnectivityManager::class.java)
            val lp: LinkProperties? = cm.getLinkProperties(cm.activeNetwork)
            lp?.linkAddresses?.forEach { la ->
                val a = la.address
                if (a is Inet4Address) {
                    val ip = a.address
                    val prefix = la.prefixLength
                    val mask = if (prefix == 0) 0 else (-1 shl (32 - prefix))
                    val ipInt = ((ip[0].toInt() and 0xFF) shl 24) or ((ip[1].toInt() and 0xFF) shl 16) or ((ip[2].toInt() and 0xFF) shl 8) or (ip[3].toInt() and 0xFF)
                    val b = ipInt or mask.inv()
                    out += InetAddress.getByAddress(byteArrayOf((b shr 24).toByte(), (b shr 16).toByte(), (b shr 8).toByte(), b.toByte()))
                }
            }
        }
        return out.distinct()
    }

    suspend fun discover(timeoutMs: Long = 2500, targetIp: String? = null): List<DdpProtocol.Response> = withContext(Dispatchers.IO) {
        val results = LinkedHashMap<String, DdpProtocol.Response>()
        try {
            DatagramSocket().use { socket ->
                socket.broadcast = true
                socket.soTimeout = 250
                val targets = if (targetIp != null) listOf(InetAddress.getByName(targetIp)) else broadcastAddresses()
                for (addr in targets) {
                    for ((port, ps5) in listOf(DdpProtocol.PS4_PORT to false, DdpProtocol.PS5_PORT to true)) {
                        val data = DdpProtocol.searchRequest(ps5)
                        runCatching { socket.send(DatagramPacket(data, data.size, addr, port)) }
                            .onFailure { RoxLog.w("Discovery", "send to ${addr.hostAddress}:$port failed: ${it.message}") }
                    }
                }
                val buf = ByteArray(2048)
                val deadline = System.currentTimeMillis() + timeoutMs
                while (System.currentTimeMillis() < deadline) {
                    val pkt = DatagramPacket(buf, buf.size)
                    try {
                        socket.receive(pkt)
                        val text = String(pkt.data, 0, pkt.length, Charsets.UTF_8)
                        val ip = pkt.address.hostAddress ?: continue
                        DdpProtocol.parse(text, ip)?.let { results[it.hostId] = it }
                    } catch (_: SocketTimeoutException) { }
                }
            }
        } catch (t: Throwable) {
            RoxLog.e("Discovery", "Discovery failed", t)
        }
        results.values.toList()
    }
}
