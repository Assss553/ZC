package com.rox.gameai.vision

import com.rox.gameai.core.IRect

/**
 * Pixel operations on ARGB_8888 int arrays. Pure Kotlin so they run in JVM unit tests and on the
 * frame thread without allocating Bitmaps. All functions modify [px] in place inside [rect].
 */
object ImageOps {

    fun fill(px: IntArray, w: Int, h: Int, rect: IRect, color: Int) {
        val r = rect.clamp(w, h)
        for (y in r.top until r.bottom) {
            val row = y * w
            for (x in r.left until r.right) px[row + x] = color
        }
    }

    fun pixelate(px: IntArray, w: Int, h: Int, rect: IRect, block: Int) {
        val r = rect.clamp(w, h)
        val b = block.coerceAtLeast(2)
        var by = r.top
        while (by < r.bottom) {
            val ey = minOf(by + b, r.bottom)
            var bx = r.left
            while (bx < r.right) {
                val ex = minOf(bx + b, r.right)
                var sr = 0L; var sg = 0L; var sb = 0L; var n = 0
                for (y in by until ey) for (x in bx until ex) {
                    val c = px[y * w + x]
                    sr += (c shr 16) and 0xFF; sg += (c shr 8) and 0xFF; sb += c and 0xFF; n++
                }
                if (n > 0) {
                    val avg = (0xFF shl 24) or ((sr / n).toInt() shl 16) or ((sg / n).toInt() shl 8) or (sb / n).toInt()
                    for (y in by until ey) for (x in bx until ex) px[y * w + x] = avg
                }
                bx = ex
            }
            by = ey
        }
    }

    /** Three separable box-blur passes ≈ Gaussian blur of the given radius. */
    fun gaussianBlur(px: IntArray, w: Int, h: Int, rect: IRect, radius: Int) {
        val r = rect.clamp(w, h)
        if (r.area == 0 || radius < 1) return
        val rw = r.width; val rh = r.height
        val buf = IntArray(rw * rh)
        for (y in 0 until rh) System.arraycopy(px, (r.top + y) * w + r.left, buf, y * rw, rw)
        val tmp = IntArray(rw * rh)
        repeat(3) {
            boxH(buf, tmp, rw, rh, radius)
            boxV(tmp, buf, rw, rh, radius)
        }
        for (y in 0 until rh) System.arraycopy(buf, y * rw, px, (r.top + y) * w + r.left, rw)
    }

    private fun boxH(src: IntArray, dst: IntArray, w: Int, h: Int, rad: Int) {
        for (y in 0 until h) {
            val row = y * w
            var sr = 0; var sg = 0; var sb = 0
            for (i in -rad..rad) {
                val c = src[row + i.coerceIn(0, w - 1)]
                sr += (c shr 16) and 0xFF; sg += (c shr 8) and 0xFF; sb += c and 0xFF
            }
            val div = 2 * rad + 1
            for (x in 0 until w) {
                dst[row + x] = (0xFF shl 24) or ((sr / div) shl 16) or ((sg / div) shl 8) or (sb / div)
                val out = src[row + (x - rad).coerceIn(0, w - 1)]
                val inn = src[row + (x + rad + 1).coerceIn(0, w - 1)]
                sr += ((inn shr 16) and 0xFF) - ((out shr 16) and 0xFF)
                sg += ((inn shr 8) and 0xFF) - ((out shr 8) and 0xFF)
                sb += (inn and 0xFF) - (out and 0xFF)
            }
        }
    }

    private fun boxV(src: IntArray, dst: IntArray, w: Int, h: Int, rad: Int) {
        for (x in 0 until w) {
            var sr = 0; var sg = 0; var sb = 0
            for (i in -rad..rad) {
                val c = src[i.coerceIn(0, h - 1) * w + x]
                sr += (c shr 16) and 0xFF; sg += (c shr 8) and 0xFF; sb += c and 0xFF
            }
            val div = 2 * rad + 1
            for (y in 0 until h) {
                dst[y * w + x] = (0xFF shl 24) or ((sr / div) shl 16) or ((sg / div) shl 8) or (sb / div)
                val out = src[(y - rad).coerceIn(0, h - 1) * w + x]
                val inn = src[(y + rad + 1).coerceIn(0, h - 1) * w + x]
                sr += ((inn shr 16) and 0xFF) - ((out shr 16) and 0xFF)
                sg += ((inn shr 8) and 0xFF) - ((out shr 8) and 0xFF)
                sb += (inn and 0xFF) - (out and 0xFF)
            }
        }
    }

    /** Nearest-neighbour downsample used for fast analysis. Returns (pixels, width, height). */
    fun downsample(px: IntArray, w: Int, h: Int, maxW: Int): Triple<IntArray, Int, Int> {
        if (w <= maxW) return Triple(px, w, h)
        val nw = maxW
        val nh = (h.toLong() * maxW / w).toInt().coerceAtLeast(1)
        val out = IntArray(nw * nh)
        for (y in 0 until nh) {
            val sy = (y.toLong() * h / nh).toInt()
            for (x in 0 until nw) out[y * nw + x] = px[sy * w + (x.toLong() * w / nw).toInt()]
        }
        return Triple(out, nw, nh)
    }
}
