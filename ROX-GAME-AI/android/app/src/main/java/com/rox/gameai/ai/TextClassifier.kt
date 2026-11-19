package com.rox.gameai.ai

import com.rox.gameai.core.IRect
import com.rox.gameai.core.TextKind

/** Classifies an on-screen text block (dialogue, menu, mission, notification…) from layout + keywords. */
object TextClassifier {
    private val mission = listOf("mission", "quest", "objective", "task", "goal", "mission:", "任务", "クエスト", "目標", "퀘스트", "임무", "objectif", "auftrag", "misión", "objetivo", "مهمة")
    private val notify = listOf("trophy", "unlocked", "saved", "saving", "achievement", "level up", "new item", "obtained", "acquired", "トロフィー", "奖杯", "트로피")
    private val item = listOf("ammo", "weapon", "sword", "rifle", "pistol", "shield", "armor", "potion", "damage", "atk", "def", "hp", "mp", "弹药", "武器", "武器", "무기")

    data class Result(val kind: TextKind, val speaker: String, val body: String)

    private val speakerRegex = Regex("^([\\p{L}][\\p{L} .'\\-]{0,24})\\s*[:：]\\s*(.+)$")

    fun classify(text: String, rect: IRect, frameW: Int, frameH: Int): Result {
        val t = text.trim()
        val lower = t.lowercase()
        val m = speakerRegex.find(t)
        val name = m?.groupValues?.get(1)?.trim()?.lowercase()
        val nameIsKeyword = name != null && (mission + notify + item).any { name == it.trimEnd(':') || name.startsWith(it.trimEnd(':')) }
        if (m != null && !nameIsKeyword && m.groupValues[2].length > 3) {
            return Result(TextKind.DIALOG, m.groupValues[1].trim(), m.groupValues[2].trim())
        }
        if (mission.any { lower.contains(it) }) return Result(TextKind.MISSION, "", t)
        if (notify.any { lower.contains(it) }) return Result(TextKind.NOTIFICATION, "", t)
        if (item.any { lower.contains(it) }) return Result(TextKind.ITEM, "", t)
        val words = t.split(Regex("\\s+")).size
        val cy = rect.centerY.toFloat() / frameH
        val wide = rect.width.toFloat() / frameW
        if (cy > 0.65f && wide > 0.35f && words >= 3) return Result(TextKind.DIALOG, "", t)
        if (cy < 0.2f && (rect.centerX.toFloat() / frameW) > 0.6f) return Result(TextKind.NOTIFICATION, "", t)
        if (words <= 3 && t.length <= 24) return Result(TextKind.MENU, "", t)
        if (words >= 6) return Result(TextKind.SIGN, "", t)
        return Result(TextKind.OTHER, "", t)
    }
}

/** Fuzzy title matching for game recognition (normalised token overlap). */
object GameMatcher {
    fun normalize(s: String) = s.lowercase().replace(Regex("[™®©:’'\\-_.,!?]"), " ").replace(Regex("\\s+"), " ").trim()

    fun similarity(a: String, b: String): Float {
        val na = normalize(a); val nb = normalize(b)
        if (na.isEmpty() || nb.isEmpty()) return 0f
        if (na == nb) return 1f
        if (na.contains(nb) || nb.contains(na)) return 0.9f
        val ta = na.split(" ").filter { it.length > 1 }.toSet()
        val tb = nb.split(" ").filter { it.length > 1 }.toSet()
        if (ta.isEmpty() || tb.isEmpty()) return 0f
        return ta.intersect(tb).size.toFloat() / ta.union(tb).size
    }

    /** Best library title whose name appears in the OCR'd screen text. */
    fun bestMatch(screenText: String, titles: List<String>, threshold: Float = 0.6f): String? {
        val screen = normalize(screenText)
        return titles.map { it to (if (screen.contains(normalize(it)) && normalize(it).length >= 4) 1f else similarity(screenText, it)) }
            .filter { it.second >= threshold }
            .maxByOrNull { it.second }?.first
    }
}
