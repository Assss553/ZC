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
        val sv = SafeVision(classifier = { _, _, _ -> score to 0f })
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

class NudeNetPortTest {
    private fun output(n: Int, rows: List<Triple<FloatArray, Int, Float>>): FloatArray {
        val o = FloatArray(22 * n)
        rows.forEachIndexed { i, (box, cls, score) ->
            for (k in 0 until 4) o[k * n + i] = box[k]
            o[(4 + cls) * n + i] = score
        }
        return o
    }

    @org.junit.Test fun postprocessScalesBoxesAndAppliesNms() {
        val breast = com.rox.gameai.vision.NudeNet.LABELS.indexOf("FEMALE_BREAST_EXPOSED")
        val face = com.rox.gameai.vision.NudeNet.LABELS.indexOf("FACE_FEMALE")
        // 640x360 frame -> padded side 640, model space 320 => scale 2
        val out = output(4, listOf(
            Triple(floatArrayOf(100f, 50f, 40f, 20f), breast, 0.9f),
            Triple(floatArrayOf(101f, 50f, 40f, 20f), breast, 0.8f), // duplicate -> removed by NMS
            Triple(floatArrayOf(200f, 100f, 20f, 20f), face, 0.95f),
            Triple(floatArrayOf(10f, 10f, 4f, 4f), breast, 0.1f),   // below score
        ))
        val raw = com.rox.gameai.vision.NudeNet.postprocess(out, 4, 640, 360, 640)
        org.junit.Assert.assertEquals(2, raw.size)
        val dets = com.rox.gameai.vision.NudeNet.toDetections(raw, 0.5f)
        org.junit.Assert.assertEquals(1, dets.size) // face is not nudity
        val r = dets[0].rect
        org.junit.Assert.assertEquals(com.rox.gameai.core.IRect(160, 80, 240, 120), r)
        org.junit.Assert.assertEquals(com.rox.gameai.core.Categories.NUDITY, dets[0].category)
    }

    @org.junit.Test fun preprocessIsNchwRgbNormalisedAndPadded() {
        val w = 64; val h = 32
        val px = IntArray(w * h) { 0xFFFF0000.toInt() } // pure red
        val (t, side) = com.rox.gameai.vision.NudeNet.preprocess(px, w, h)
        org.junit.Assert.assertEquals(64, side)
        org.junit.Assert.assertEquals(3 * 320 * 320, t.size)
        org.junit.Assert.assertEquals(1f, t[10 * 320 + 10], 1e-3f)              // R plane, top area = image
        org.junit.Assert.assertEquals(0f, t[320 * 320 + 10 * 320 + 10], 1e-3f)  // G plane
        org.junit.Assert.assertEquals(0f, t[300 * 320 + 10], 1e-3f)             // bottom = black padding
    }

    @org.junit.Test fun trainedDetectorBoxesAreMaskedAndHeuristicDisabled() {
        val w = 320; val h = 180
        val px = IntArray(w * h) { 0xFFE0AC8C.toInt() } // whole frame skin-coloured: heuristic would fire
        val sv = com.rox.gameai.vision.SafeVision(regionDetector = { _, _, _, _ ->
            listOf(com.rox.gameai.core.Detection(com.rox.gameai.core.IRect(10, 10, 50, 50), 0.9f, com.rox.gameai.core.Categories.NUDITY))
        })
        val res = sv.process(px, w, h, com.rox.gameai.core.AiSettings(blurMode = com.rox.gameai.core.BlurMode.BLACK), now = 0)
        org.junit.Assert.assertEquals(1, res.regions.size)
        org.junit.Assert.assertEquals(com.rox.gameai.core.Categories.NUDITY, res.regions[0].category)
        org.junit.Assert.assertEquals(0xFF000000.toInt(), px[30 * w + 30])
        org.junit.Assert.assertEquals(0xFFE0AC8C.toInt(), px[150 * w + 300])
    }
}
