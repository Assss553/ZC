package com.rox.gameai

import com.rox.gameai.core.AiSettings
import com.rox.gameai.core.BlurMode
import com.rox.gameai.core.Categories
import com.rox.gameai.core.Detection
import com.rox.gameai.core.IRect
import com.rox.gameai.core.NRect
import com.rox.gameai.vision.RegionTracker
import com.rox.gameai.vision.SafeVision
import com.rox.gameai.vision.SkinDetector
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** Synthetic "test video": dark scene with a skin-coloured ellipse moving left → right. */
class SafeVisionTest {
    private val skin = (0xFF shl 24) or (224 shl 16) or (172 shl 8) or 140
    private val bg = 0xFF1E2A24.toInt()
    private val w = 640; private val h = 360

    private fun frame(cx: Int): IntArray {
        val px = IntArray(w * h) { bg }
        for (y in 0 until h) for (x in 0 until w) {
            val dx = (x - cx) / 60.0; val dy = (y - 150) / 90.0
            if (dx * dx + dy * dy <= 1.0) px[y * w + x] = skin
        }
        return px
    }

    @Test fun skinColourClassifier() {
        val d = SkinDetector()
        assertTrue(d.isSkin(skin))
        assertFalse(d.isSkin(bg))
        assertFalse(d.isSkin(0xFF2050FF.toInt()))
        assertFalse(d.isSkin(0xFF00C000.toInt()))
    }

    @Test fun detectsSkinRegionAtRightPlace() {
        val dets = SkinDetector().detect(frame(320), w, h, 0.5f)
        assertEquals(1, dets.size)
        val r = dets[0].rect
        assertTrue("rect $r should contain the ellipse centre", r.left < 320 && r.right > 320 && r.top < 150 && r.bottom > 150)
    }

    @Test fun noDetectionOnCleanScene() {
        assertTrue(SkinDetector().detect(IntArray(w * h) { bg }, w, h, 1f).isEmpty())
    }

    @Test fun masksPixelsBeforeDisplayForEveryMode() {
        for (mode in listOf(BlurMode.BLACK, BlurMode.PIXELATE, BlurMode.GAUSSIAN, BlurMode.FULL_SCENE)) {
            val sv = SafeVision()
            val px = frame(320)
            val s = AiSettings(blurMode = mode, categories = setOf(Categories.EXPOSED), analysisWidth = 320)
            val res = sv.process(px, w, h, s, now = 1000)
            assertEquals(mode.name, 1, res.regions.size)
            val centre = px[150 * w + 320]
            when (mode) {
                BlurMode.BLACK -> assertEquals(0xFF000000.toInt(), centre)
                else -> assertTrue("$mode must alter edge pixels", px[150 * w + 262] != skin || px[150 * w + 258] != bg)
            }
            if (mode == BlurMode.FULL_SCENE) assertTrue(res.fullScene)
        }
    }

    @Test fun tracksMovingObjectAndReleasesAfterSceneEnds() {
        val sv = SafeVision()
        val s = AiSettings(blurMode = BlurMode.BLACK, categories = setOf(Categories.EXPOSED))
        var id = -1
        for (i in 0 until 10) {
            val cx = 150 + i * 30
            val px = frame(cx)
            val res = sv.process(px, w, h, s, now = i * 66L)
            assertEquals(1, res.regions.size)
            if (id < 0) id = res.regions[0].id else assertEquals("same object keeps same track id", id, res.regions[0].id)
            assertEquals("object at $cx must be masked", 0xFF000000.toInt(), px[150 * w + cx])
        }
        // Scene ends: mask is held briefly, then removed automatically
        val clean = IntArray(w * h) { bg }
        assertEquals(1, sv.process(clean.copyOf(), w, h, s, now = 700).regions.size)
        val after = clean.copyOf()
        assertEquals(0, sv.process(after, w, h, s, now = 3000).regions.size)
        assertEquals(bg, after[150 * w + 300])
    }

    @Test fun disabledLeavesFrameUntouched() {
        val px = frame(320); val orig = px.copyOf()
        SafeVision().process(px, w, h, AiSettings(safeVisionEnabled = false), now = 0)
        assertTrue(px.contentEquals(orig))
    }

    @Test fun customRegionAlwaysMasked() {
        val px = IntArray(w * h) { bg }
        SafeVision().process(px, w, h, AiSettings(blurMode = BlurMode.BLACK, categories = setOf(Categories.CUSTOM), customRegions = listOf(NRect(0f, 0f, 0.5f, 0.5f))), now = 0)
        assertEquals(0xFF000000.toInt(), px[10 * w + 10])
        assertEquals(bg, px[300 * w + 600])
    }

    @Test fun modelCategoryTriggersFullSceneAndAutoUnblur() {
        var score = 0.99f
        val sv = SafeVision { _, _, _ -> score to 0f }
        val s = AiSettings(categories = setOf(Categories.NUDITY), blurMode = BlurMode.GAUSSIAN)
        val res = sv.process(IntArray(w * h) { bg }, w, h, s, now = 0)
        assertTrue(res.fullScene); assertEquals(Categories.NUDITY, res.newEvents.first().category)
        score = 0.01f
        repeat(3) { sv.process(IntArray(w * h) { bg }, w, h, s, now = 100L * it) }
        assertFalse(sv.process(IntArray(w * h) { bg }, w, h, s, now = 5000).fullScene)
    }

    @Test fun trackerIgnoresOtherCategories() {
        val t = RegionTracker()
        t.update(listOf(Detection(IRect(0, 0, 10, 10), 1f, "a")), 0)
        val r = t.update(listOf(Detection(IRect(0, 0, 10, 10), 1f, "b")), 10)
        assertEquals(2, r.size)
    }
}
