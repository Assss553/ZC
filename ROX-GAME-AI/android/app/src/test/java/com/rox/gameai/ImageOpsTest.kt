package com.rox.gameai

import com.rox.gameai.core.IRect
import com.rox.gameai.vision.ImageOps
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class ImageOpsTest {
    private fun checker(w: Int, h: Int) = IntArray(w * h) { i -> if (((i % w) / 4 + (i / w) / 4) % 2 == 0) 0xFFFFFFFF.toInt() else 0xFF000000.toInt() }

    @Test fun blackMaskOnlyInsideRect() {
        val w = 40; val h = 30; val px = IntArray(w * h) { 0xFF336699.toInt() }
        ImageOps.fill(px, w, h, IRect(10, 10, 20, 20), 0xFF000000.toInt())
        assertEquals(0xFF000000.toInt(), px[15 * w + 15])
        assertEquals(0xFF336699.toInt(), px[5 * w + 5])
        assertEquals(0xFF336699.toInt(), px[25 * w + 25])
    }

    @Test fun pixelateMakesUniformBlocks() {
        val w = 32; val h = 32; val px = checker(w, h)
        ImageOps.pixelate(px, w, h, IRect(0, 0, 32, 32), 8)
        val first = px[0]
        for (y in 0 until 8) for (x in 0 until 8) assertEquals(first, px[y * w + x])
    }

    @Test fun gaussianBlurReducesContrastInsideRectOnly() {
        val w = 64; val h = 64; val px = checker(w, h); val orig = px.copyOf()
        ImageOps.gaussianBlur(px, w, h, IRect(16, 16, 48, 48), 6)
        val c = px[32 * w + 32] and 0xFF
        assertTrue("blurred centre should be mid-grey, was $c", c in 60..200)
        assertEquals(orig[2 * w + 2], px[2 * w + 2])
        assertNotEquals(orig[32 * w + 32], px[32 * w + 32])
    }

    @Test fun rectsAreClampedSafely() {
        val w = 10; val h = 10; val px = IntArray(100)
        ImageOps.gaussianBlur(px, w, h, IRect(-50, -50, 500, 500), 3)
        ImageOps.pixelate(px, w, h, IRect(-5, 3, 50, 4), 4)
        ImageOps.fill(px, w, h, IRect(20, 20, 30, 30), -1)
    }

    @Test fun downsampleKeepsAspect() {
        val (o, nw, nh) = ImageOps.downsample(IntArray(1280 * 720), 1280, 720, 320)
        assertEquals(320, nw); assertEquals(180, nh); assertEquals(320 * 180, o.size)
    }

    @Test fun iou() {
        assertEquals(1f, IRect(0, 0, 10, 10).iou(IRect(0, 0, 10, 10)), 1e-6f)
        assertEquals(0f, IRect(0, 0, 10, 10).iou(IRect(20, 20, 30, 30)), 1e-6f)
        assertEquals(25f / 175f, IRect(0, 0, 10, 10).iou(IRect(5, 5, 15, 15)), 1e-4f)
    }
}
