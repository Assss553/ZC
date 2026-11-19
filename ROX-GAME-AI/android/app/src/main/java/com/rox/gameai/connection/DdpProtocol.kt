package com.rox.gameai.connection

import com.rox.gameai.core.ConsoleType

/**
 * PlayStation LAN "device discovery protocol" (the same status query PS Remote Play uses to list
 * consoles on the local network). It only reports state/name/running title — no video, no keys,
 * no authentication. Ports: PS4 = 987, PS5 = 9302 (UDP).
 */
object DdpProtocol {
    const val PS4_PORT = 987
    const val PS5_PORT = 9302
    private const val VERSION_PS4 = "00020020"
    private const val VERSION_PS5 = "00030010"

    enum class PowerState { ON, STANDBY, UNKNOWN }

    data class Response(
        val ip: String,
        val statusCode: Int,
        val state: PowerState,
        val hostId: String,
        val hostName: String,
        val type: ConsoleType,
        val requestPort: Int?,
        val runningAppName: String?,
        val runningAppTitleId: String?,
        val systemVersion: String?,
    )

    fun searchRequest(ps5: Boolean): ByteArray =
        "SRCH * HTTP/1.1\ndevice-discovery-protocol-version:${if (ps5) VERSION_PS5 else VERSION_PS4}\n".toByteArray(Charsets.UTF_8)

    fun parse(text: String, ip: String): Response? {
        val lines = text.replace("\r", "").split("\n").map { it.trim() }.filter { it.isNotEmpty() }
        if (lines.isEmpty()) return null
        val status = Regex("^HTTP/1\\.1\\s+(\\d{3})").find(lines[0]) ?: return null
        val code = status.groupValues[1].toInt()
        val map = HashMap<String, String>()
        for (l in lines.drop(1)) {
            val i = l.indexOf(':')
            if (i > 0) map[l.substring(0, i).trim().lowercase()] = l.substring(i + 1).trim()
        }
        val hostId = map["host-id"] ?: return null
        val type = when (map["host-type"]?.uppercase()) {
            "PS5" -> ConsoleType.PS5
            "PS4" -> ConsoleType.PS4
            else -> ConsoleType.UNKNOWN
        }
        val state = when (code) { 200 -> PowerState.ON; 620 -> PowerState.STANDBY; else -> PowerState.UNKNOWN }
        return Response(
            ip = ip, statusCode = code, state = state, hostId = hostId,
            hostName = map["host-name"] ?: "PlayStation", type = type,
            requestPort = map["host-request-port"]?.toIntOrNull(),
            runningAppName = map["running-app-name"]?.takeIf { it.isNotBlank() },
            runningAppTitleId = map["running-app-titleid"]?.takeIf { it.isNotBlank() },
            systemVersion = map["system-version"],
        )
    }
}
