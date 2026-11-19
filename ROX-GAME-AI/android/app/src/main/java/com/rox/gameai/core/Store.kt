package com.rox.gameai.core

import android.content.Context
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.util.concurrent.Executors

/** JSON-file persistence for paired consoles, game profiles, translation history and Safe Vision log. */
class Store(context: Context) {
    private val dir = File(context.filesDir, "store").apply { mkdirs() }
    private val io = Executors.newSingleThreadExecutor()

    private val _consoles = MutableStateFlow(read("consoles") { o ->
        SavedConsole(o.getString("hostId"), o.getString("name"), runCatching { ConsoleType.valueOf(o.getString("type")) }.getOrDefault(ConsoleType.UNKNOWN),
            o.getString("ip"), o.optLong("lastSeen"), o.optBoolean("autoConnect", true))
    })
    val consoles: StateFlow<List<SavedConsole>> = _consoles

    private val _games = MutableStateFlow(read("games") { o ->
        GameProfile(o.getString("id"), o.getString("name"), o.optString("titleId"), o.optString("language"), o.optBoolean("safeVision", true),
            o.optString("blurMode").takeIf { it.isNotEmpty() }?.let { runCatching { BlurMode.valueOf(it) }.getOrNull() },
            if (o.has("ocrIntervalMs")) o.getInt("ocrIntervalMs") else null, o.optLong("lastPlayed"), o.optInt("timesPlayed"))
    })
    val games: StateFlow<List<GameProfile>> = _games

    private val _history = MutableStateFlow(read("history") { o ->
        TranslationEntry(o.getLong("time"), o.optString("game"), runCatching { TextKind.valueOf(o.getString("kind")) }.getOrDefault(TextKind.OTHER),
            o.getString("source"), o.optString("sourceLang"), o.getString("translated"), o.optString("speaker"), o.optBoolean("fromVoice"))
    })
    val history: StateFlow<List<TranslationEntry>> = _history

    private val _blocked = MutableStateFlow(read("blocked") { o ->
        BlockedEvent(o.getLong("time"), o.optString("game"), o.getString("category"), o.optDouble("score").toFloat(),
            runCatching { BlurMode.valueOf(o.getString("mode")) }.getOrDefault(BlurMode.GAUSSIAN))
    })
    val blocked: StateFlow<List<BlockedEvent>> = _blocked

    fun upsertConsole(c: SavedConsole) = synchronized(this) {
        _consoles.value = _consoles.value.filter { it.hostId != c.hostId } + c
        write("consoles", _consoles.value) { JSONObject().put("hostId", it.hostId).put("name", it.name).put("type", it.type.name).put("ip", it.ip).put("lastSeen", it.lastSeen).put("autoConnect", it.autoConnect) }
    }
    fun removeConsole(hostId: String) = synchronized(this) {
        _consoles.value = _consoles.value.filter { it.hostId != hostId }
        write("consoles", _consoles.value) { JSONObject().put("hostId", it.hostId).put("name", it.name).put("type", it.type.name).put("ip", it.ip).put("lastSeen", it.lastSeen).put("autoConnect", it.autoConnect) }
    }

    fun upsertGame(g: GameProfile) = synchronized(this) {
        _games.value = (_games.value.filter { it.id != g.id } + g).sortedByDescending { it.lastPlayed }
        saveGames()
    }
    fun removeGame(id: String) = synchronized(this) { _games.value = _games.value.filter { it.id != id }; saveGames() }
    private fun saveGames() = write("games", _games.value) {
        JSONObject().put("id", it.id).put("name", it.name).put("titleId", it.titleId).put("language", it.language).put("safeVision", it.safeVision)
            .put("blurMode", it.blurMode?.name ?: "").put("lastPlayed", it.lastPlayed).put("timesPlayed", it.timesPlayed)
            .also { o -> it.ocrIntervalMs?.let { v -> o.put("ocrIntervalMs", v) } }
    }

    fun addTranslation(e: TranslationEntry) = synchronized(this) {
        _history.value = (_history.value + e).takeLast(3000)
        saveHistory()
    }
    fun clearHistory() = synchronized(this) { _history.value = emptyList(); saveHistory() }
    private fun saveHistory() = write("history", _history.value) {
        JSONObject().put("time", it.time).put("game", it.game).put("kind", it.kind.name).put("source", it.source).put("sourceLang", it.sourceLang)
            .put("translated", it.translated).put("speaker", it.speaker).put("fromVoice", it.fromVoice)
    }

    fun addBlocked(e: BlockedEvent) = synchronized(this) {
        _blocked.value = (_blocked.value + e).takeLast(1000)
        saveBlocked()
    }
    fun clearBlocked() = synchronized(this) { _blocked.value = emptyList(); saveBlocked() }
    private fun saveBlocked() = write("blocked", _blocked.value) {
        JSONObject().put("time", it.time).put("game", it.game).put("category", it.category).put("score", it.score.toDouble()).put("mode", it.mode.name)
    }

    private fun <T> read(name: String, parse: (JSONObject) -> T): List<T> {
        val f = File(dir, "$name.json")
        if (!f.exists()) return emptyList()
        return try {
            val arr = JSONArray(f.readText())
            (0 until arr.length()).mapNotNull { i -> runCatching { parse(arr.getJSONObject(i)) }.getOrNull() }
        } catch (t: Throwable) {
            RoxLog.e("Store", "Corrupt $name.json, backing it up", t)
            f.renameTo(File(dir, "$name.corrupt.${System.currentTimeMillis()}.json"))
            emptyList()
        }
    }

    private fun <T> write(name: String, items: List<T>, enc: (T) -> JSONObject) {
        val snapshot = items.toList()
        io.execute {
            try {
                val arr = JSONArray(); snapshot.forEach { arr.put(enc(it)) }
                val tmp = File(dir, "$name.json.tmp")
                tmp.writeText(arr.toString())
                val target = File(dir, "$name.json")
                if (target.exists()) target.copyTo(File(dir, "$name.bak.json"), overwrite = true) // backup copy
                tmp.renameTo(target)
            } catch (t: Throwable) { RoxLog.e("Store", "Failed to write $name", t) }
        }
    }
}
