package com.rox.tv

import org.json.JSONObject

/**
 * Phone → TV protocol (JSON over WebSocket, local Wi-Fi only).
 *  {"type":"hello","code":"123456","device":"Phone"}      pairing (code shown on the TV)
 *  {"type":"subtitle","text":"…","speaker":"Elena","kind":"DIALOG","ttlMs":4000,"id":17}
 *  {"type":"clear"}
 *  {"type":"ping"}
 * TV → phone: {"type":"welcome","name":"ROX TV","mode":"A|B"} or {"type":"error","reason":"bad_code"}
 */
object TvProtocol {
    const val PORT = 9770
    const val SERVICE_TYPE = "_roxtv._tcp."

    sealed class Msg {
        data class Hello(val code: String, val device: String) : Msg()
        data class Subtitle(val text: String, val speaker: String, val kind: String, val ttlMs: Long, val id: Long) : Msg()
        data class Item(val text: String, val l: Float, val t: Float, val r: Float, val b: Float, val kind: String)
        data class Items(val items: List<Item>, val ttlMs: Long) : Msg()
        object Clear : Msg()
        object Ping : Msg()
        data class Unknown(val raw: String) : Msg()
    }

    fun parse(raw: String): Msg = try {
        val j = JSONObject(raw)
        when (j.optString("type")) {
            "hello" -> Msg.Hello(j.optString("code"), j.optString("device", "Phone"))
            "subtitle" -> Msg.Subtitle(j.optString("text"), j.optString("speaker"), j.optString("kind", "DIALOG"),
                j.optLong("ttlMs", 4000L).coerceIn(500L, 30_000L), j.optLong("id"))
            "items" -> {
                val a = j.optJSONArray("items")
                Msg.Items((0 until (a?.length() ?: 0)).mapNotNull { i ->
                    val o = a!!.optJSONObject(i) ?: return@mapNotNull null
                    Msg.Item(o.optString("t"), o.optDouble("l").toFloat(), o.optDouble("tp").toFloat(), o.optDouble("r").toFloat(), o.optDouble("b").toFloat(), o.optString("k"))
                }.filter { it.text.isNotBlank() && it.r > it.l && it.b > it.t }, j.optLong("ttlMs", 3000L).coerceIn(500L, 30_000L))
            }
            "clear" -> Msg.Clear
            "ping" -> Msg.Ping
            else -> Msg.Unknown(raw)
        }
    } catch (_: Throwable) { Msg.Unknown(raw) }

    fun welcome(name: String, mode: String) = JSONObject().put("type", "welcome").put("name", name).put("mode", mode).toString()
    fun error(reason: String) = JSONObject().put("type", "error").put("reason", reason).toString()

    /** 6-digit pairing code. */
    fun newCode(rnd: java.util.Random = java.security.SecureRandom()): String = String.format(java.util.Locale.US, "%06d", rnd.nextInt(1_000_000))

    /** Converts Arabic-Indic / Eastern Arabic digits to ASCII so "٥٣١٧٥٧" == "531757". */
    fun asciiDigits(s: String): String = buildString { s.trim().forEach { c -> append(if (Character.isDigit(c)) ('0' + Character.getNumericValue(c)) else c) } }

    /** What the TV should show: speaker label + text, trimmed to a readable length. */
    fun display(s: Msg.Subtitle): String {
        val body = s.text.trim().let { if (it.length > 220) it.take(217) + "…" else it }
        return if (s.speaker.isNotBlank()) "${s.speaker}: $body" else body
    }
}

/** Pairing + subtitle timing state (pure, JVM-tested). */
class SubtitleState(private val code: String) {
    private val paired = HashSet<Any>()
    var text: String = ""; private set
    var expiresAt: Long = 0; private set
    var lastId: Long = -1; private set

    fun onHello(client: Any, msg: TvProtocol.Msg.Hello): Boolean {
        val ok = TvProtocol.asciiDigits(msg.code) == TvProtocol.asciiDigits(code)
        if (ok) paired.add(client)
        return ok
    }

    fun isPaired(client: Any) = client in paired
    fun remove(client: Any) { paired.remove(client) }

    /** Returns true if the visible text changed. */
    fun onSubtitle(client: Any, s: TvProtocol.Msg.Subtitle, now: Long): Boolean {
        if (!isPaired(client)) return false
        val t = TvProtocol.display(s)
        expiresAt = now + s.ttlMs
        lastId = s.id
        if (t == text) return false
        text = t
        return true
    }

    fun onClear(client: Any): Boolean {
        if (!isPaired(client) || text.isEmpty()) return false
        text = ""; return true
    }

    /** Auto-hide when the dialogue disappeared and the phone sent nothing new. */
    fun tick(now: Long): Boolean {
        if (text.isNotEmpty() && now > expiresAt) { text = ""; return true }
        return false
    }
}
