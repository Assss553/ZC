package com.rox.gameai.translation

/** LRU cache + "recently shown" window so the same on-screen text is never translated twice. */
class TranslationCache(private val capacity: Int = 600, private val repeatWindowMs: Long = 20_000) {
    private val map = object : LinkedHashMap<String, String>(64, 0.75f, true) {
        override fun removeEldestEntry(eldest: MutableMap.MutableEntry<String, String>?) = size > capacity
    }
    private val lastSeen = HashMap<String, Long>()

    companion object {
        fun normalize(text: String): String =
            text.lowercase().replace(Regex("[\\s\\u00A0]+"), " ").replace(Regex("[\"'`«»“”]"), "").trim()
    }

    @Synchronized fun get(text: String): String? = map[normalize(text)]
    @Synchronized fun put(text: String, translated: String) { map[normalize(text)] = translated }
    @Synchronized fun size() = map.size

    /** Returns true if this text was already shown within the repeat window (do not log it again). */
    @Synchronized fun seenRecently(text: String, now: Long): Boolean {
        val k = normalize(text)
        val prev = lastSeen[k]
        lastSeen[k] = now
        if (lastSeen.size > capacity * 2) lastSeen.entries.removeIf { now - it.value > repeatWindowMs }
        return prev != null && now - prev < repeatWindowMs
    }
}

/** Keeps a rolling dialogue context (speaker + line) for display and speaker attribution. */
class DialogContext(private val max: Int = 30) {
    data class Line(val time: Long, val speaker: String, val text: String, val translated: String)
    private val lines = ArrayDeque<Line>()

    @Synchronized fun add(line: Line) { lines.addLast(line); while (lines.size > max) lines.removeFirst() }
    @Synchronized fun recent(): List<Line> = lines.toList()
    /** Speaker of the most recent subtitle line within [windowMs], used to label voice lines. */
    @Synchronized fun lastSpeaker(now: Long, windowMs: Long = 4000): String =
        lines.lastOrNull { it.speaker.isNotBlank() && now - it.time <= windowMs }?.speaker ?: ""
}
