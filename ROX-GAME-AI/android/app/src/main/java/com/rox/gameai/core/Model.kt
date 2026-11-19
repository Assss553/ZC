package com.rox.gameai.core

/** Integer rectangle in frame pixel coordinates (pure Kotlin, JVM-testable). */
data class IRect(val left: Int, val top: Int, val right: Int, val bottom: Int) {
    val width: Int get() = right - left
    val height: Int get() = bottom - top
    val area: Int get() = if (width <= 0 || height <= 0) 0 else width * height
    val centerX: Int get() = (left + right) / 2
    val centerY: Int get() = (top + bottom) / 2

    fun clamp(w: Int, h: Int) = IRect(left.coerceIn(0, w), top.coerceIn(0, h), right.coerceIn(0, w), bottom.coerceIn(0, h))

    fun inflate(fraction: Float): IRect {
        val dx = (width * fraction).toInt()
        val dy = (height * fraction).toInt()
        return IRect(left - dx, top - dy, right + dx, bottom + dy)
    }

    fun scale(sx: Float, sy: Float) = IRect((left * sx).toInt(), (top * sy).toInt(), (right * sx).toInt(), (bottom * sy).toInt())

    fun intersect(o: IRect): IRect = IRect(maxOf(left, o.left), maxOf(top, o.top), minOf(right, o.right), minOf(bottom, o.bottom))

    fun iou(o: IRect): Float {
        val inter = intersect(o).area
        if (inter == 0) return 0f
        return inter.toFloat() / (area + o.area - inter).toFloat()
    }
}

/** Normalized rectangle (0..1) used for user-defined blocking regions. */
data class NRect(val l: Float, val t: Float, val r: Float, val b: Float) {
    fun toPixels(w: Int, h: Int) = IRect((l * w).toInt(), (t * h).toInt(), (r * w).toInt(), (b * h).toInt())
    fun encode() = "$l,$t,$r,$b"
    companion object {
        fun decode(s: String): NRect? {
            val p = s.split(",").mapNotNull { it.trim().toFloatOrNull() }
            return if (p.size == 4) NRect(p[0], p[1], p[2], p[3]) else null
        }
    }
}

enum class BlurMode { GAUSSIAN, PIXELATE, BLACK, FULL_SCENE }
enum class DisplayMode { ON_VIDEO, FLOATING_WINDOW, LOG_ONLY }
enum class VideoSourceKind { AUTO, CAPTURE_CARD, SCREEN_CAPTURE, TEST_PATTERN }
enum class AudioSourceKind { STREAM_PLAYBACK, USB_CAPTURE, MICROPHONE }
enum class ConsoleType { PS4, PS5, UNKNOWN }
enum class TextKind { DIALOG, MENU, MISSION, NOTIFICATION, ITEM, SIGN, OTHER }

object Categories {
    const val EXPOSED = "exposed_skin"
    const val NUDITY = "nudity"
    const val SEXUAL = "sexual"
    const val CUSTOM = "custom_region"
    val all = listOf(EXPOSED, NUDITY, SEXUAL, CUSTOM)
}

data class Detection(val rect: IRect, val score: Float, val category: String)

data class SavedConsole(
    val hostId: String,
    val name: String,
    val type: ConsoleType,
    val ip: String,
    val lastSeen: Long,
    val autoConnect: Boolean = true,
)

data class GameProfile(
    val id: String,
    val name: String,
    val titleId: String = "",
    val language: String = "",          // BCP-47 code detected or chosen ("" = auto)
    val safeVision: Boolean = true,
    val blurMode: BlurMode? = null,      // null = use global setting
    val ocrIntervalMs: Int? = null,
    val lastPlayed: Long = 0,
    val timesPlayed: Int = 0,
)

data class TranslationEntry(
    val time: Long,
    val game: String,
    val kind: TextKind,
    val source: String,
    val sourceLang: String,
    val translated: String,
    val speaker: String = "",
    val fromVoice: Boolean = false,
)

data class BlockedEvent(val time: Long, val game: String, val category: String, val score: Float, val mode: BlurMode)

data class TextOverlay(val rect: IRect, val original: String, val translated: String, val kind: TextKind, val speaker: String = "")
