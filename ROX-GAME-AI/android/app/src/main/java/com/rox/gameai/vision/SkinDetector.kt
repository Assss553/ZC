package com.rox.gameai.vision

import com.rox.gameai.core.Categories
import com.rox.gameai.core.Detection
import com.rox.gameai.core.IRect

/**
 * HEURISTIC exposed-skin region detector (YCbCr skin model + grid connected components).
 * This is NOT a trained nudity classifier: it finds large skin-coloured areas so they can be masked.
 * A trained model can be plugged in through [TfliteContentClassifier].
 */
class SkinDetector(private val cell: Int = 8) {

    fun isSkin(c: Int): Boolean {
        val r = (c shr 16) and 0xFF; val g = (c shr 8) and 0xFF; val b = c and 0xFF
        val y = 0.299 * r + 0.587 * g + 0.114 * b
        val cb = 128 - 0.168736 * r - 0.331264 * g + 0.5 * b
        val cr = 128 + 0.5 * r - 0.418688 * g - 0.081312 * b
        return y > 45 && cb in 77.0..127.0 && cr in 135.0..173.0 && r > g && r > b
    }

    /** @param sensitivity 0..1 (higher = blocks smaller / less certain areas) */
    fun detect(px: IntArray, w: Int, h: Int, sensitivity: Float): List<Detection> {
        val gw = w / cell; val gh = h / cell
        if (gw == 0 || gh == 0) return emptyList()
        val s = sensitivity.coerceIn(0f, 1f)
        val cellThreshold = 0.75f - 0.4f * s           // fraction of skin pixels in a cell
        val minCells = (24 - 18 * s).toInt().coerceAtLeast(4)  // min component size
        val ratio = FloatArray(gw * gh)
        for (gy in 0 until gh) for (gx in 0 until gw) {
            var n = 0
            var y = gy * cell
            while (y < (gy + 1) * cell) {
                var x = gx * cell
                while (x < (gx + 1) * cell) { if (isSkin(px[y * w + x])) n++; x += 2 }
                y += 2
            }
            ratio[gy * gw + gx] = n / ((cell / 2f) * (cell / 2f))
        }
        val on = BooleanArray(gw * gh) { ratio[it] >= cellThreshold }
        val seen = BooleanArray(gw * gh)
        val out = ArrayList<Detection>()
        val stack = IntArray(gw * gh)
        for (start in on.indices) {
            if (!on[start] || seen[start]) continue
            var sp = 0; stack[sp++] = start; seen[start] = true
            var minX = gw; var minY = gh; var maxX = 0; var maxY = 0; var count = 0; var sum = 0f
            while (sp > 0) {
                val i = stack[--sp]
                val x = i % gw; val y = i / gw
                count++; sum += ratio[i]
                if (x < minX) minX = x; if (y < minY) minY = y; if (x > maxX) maxX = x; if (y > maxY) maxY = y
                val nb = intArrayOf(i - 1, i + 1, i - gw, i + gw)
                for ((k, j) in nb.withIndex()) {
                    if (j < 0 || j >= on.size) continue
                    if (k == 0 && x == 0) continue
                    if (k == 1 && x == gw - 1) continue
                    if (on[j] && !seen[j]) { seen[j] = true; stack[sp++] = j }
                }
            }
            if (count < minCells) continue
            val rect = IRect(minX * cell, minY * cell, (maxX + 1) * cell, (maxY + 1) * cell)
            // Ignore components that cover nearly the whole frame (usually orange/beige scenery, sky, sand)
            if (rect.area > 0.85f * w * h) continue
            val density = count.toFloat() / ((maxX - minX + 1) * (maxY - minY + 1))
            val score = (sum / count) * 0.6f + density * 0.4f
            out += Detection(rect, score.coerceIn(0f, 1f), Categories.EXPOSED)
        }
        return out
    }
}
