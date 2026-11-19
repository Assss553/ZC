package com.rox.gameai.vision

import com.rox.gameai.core.AiSettings
import com.rox.gameai.core.BlurMode
import com.rox.gameai.core.Categories
import com.rox.gameai.core.Detection
import com.rox.gameai.core.IRect

/**
 * ROX SAFE VISION. Runs on every frame BEFORE the frame is published for display:
 * detect → track → apply the mask on the pixels → only then the frame is shown.
 * Pure pixel logic (no Android types) so the full chain is unit-tested on the JVM.
 */
class SafeVision(
    private val classifier: ((IntArray, Int, Int) -> Pair<Float, Float>)? = null,
    /** Trained region detector (NudeNet): returns boxes of exposed body parts in frame coordinates. */
    private val regionDetector: ((IntArray, Int, Int, Float) -> List<Detection>)? = null,
) {
    private var lastRegionDets: List<Detection> = emptyList()
    private val skin = SkinDetector()
    val tracker = RegionTracker()
    private var frameNo = 0L
    @Volatile private var lastScene = 0f to 0f
    @Volatile var fullSceneUntil = 0L; private set
    private var inModelScene = false

    val modelAvailable: Boolean get() = classifier != null || regionDetector != null

    data class Result(val regions: List<RegionTracker.Track>, val fullScene: Boolean, val newEvents: List<Detection>, val analysisMs: Long)

    fun process(px: IntArray, w: Int, h: Int, s: AiSettings, now: Long, profileEnabled: Boolean = true, modeOverride: BlurMode? = null): Result {
        val t0 = System.nanoTime()
        if (!s.safeVisionEnabled || !profileEnabled) { tracker.reset(); return Result(emptyList(), false, emptyList(), 0) }
        val mode = modeOverride ?: s.blurMode
        val (small, sw, sh) = ImageOps.downsample(px, w, h, s.analysisWidth.coerceIn(160, 960))
        val sx = w.toFloat() / sw; val sy = h.toFloat() / sh
        val dets = ArrayList<Detection>()
        // Colour heuristic only when no trained detector is available (it misfires on game skin tones)
        if (Categories.EXPOSED in s.categories && regionDetector == null) {
            skin.detect(small, sw, sh, s.sensitivity).forEach { dets += it.copy(rect = it.rect.scale(sx, sy)) }
        }
        if (regionDetector != null && Categories.NUDITY in s.categories) {
            // Trained detector every 2nd frame; the tracker keeps masks in place between runs
            if (frameNo % 2 == 0L) lastRegionDets = regionDetector.invoke(px, w, h, s.sensitivity)
            dets += lastRegionDets
        }
        val events = ArrayList<Detection>()
        // Whole-scene model (if installed): every 3rd frame
        if (classifier != null && (Categories.NUDITY in s.categories || Categories.SEXUAL in s.categories)) {
            if (frameNo % 3 == 0L) lastScene = classifier.invoke(small, sw, sh)
            val threshold = 0.85f - 0.45f * s.sensitivity
            val (nud, sex) = lastScene
            val hit = (Categories.NUDITY in s.categories && nud > threshold) || (Categories.SEXUAL in s.categories && sex > threshold)
            if (inModelScene && now >= fullSceneUntil) inModelScene = false
            if (hit) {
                if (!inModelScene) events += Detection(IRect(0, 0, w, h), maxOf(nud, sex), if (nud >= sex) Categories.NUDITY else Categories.SEXUAL)
                inModelScene = true
                fullSceneUntil = now + 1200 // un-blur automatically ~1.2 s after the scene ends
            }
        }
        frameNo++
        val tracks = tracker.update(dets, now)
        tracker.lastNewTracks.forEach { events += Detection(it.rect, it.score, it.category) }
        val fullScene = mode == BlurMode.FULL_SCENE && tracks.isNotEmpty() || now < fullSceneUntil
        val radius = s.blurStrength.coerceIn(4, 60)
        if (fullScene) {
            ImageOps.gaussianBlur(px, w, h, IRect(0, 0, w, h), radius * 2)
        } else {
            for (t in tracks) apply(px, w, h, t.rect.inflate(s.maskPadding), mode, radius)
        }
        if (Categories.CUSTOM in s.categories) for (r in s.customRegions) apply(px, w, h, r.toPixels(w, h), if (mode == BlurMode.FULL_SCENE) BlurMode.GAUSSIAN else mode, radius)
        return Result(tracks, fullScene, events, (System.nanoTime() - t0) / 1_000_000)
    }

    private fun apply(px: IntArray, w: Int, h: Int, r: IRect, mode: BlurMode, radius: Int) {
        when (mode) {
            BlurMode.GAUSSIAN, BlurMode.FULL_SCENE -> ImageOps.gaussianBlur(px, w, h, r, radius)
            BlurMode.PIXELATE -> ImageOps.pixelate(px, w, h, r, radius)
            BlurMode.BLACK -> ImageOps.fill(px, w, h, r, 0xFF000000.toInt())
        }
    }
}
