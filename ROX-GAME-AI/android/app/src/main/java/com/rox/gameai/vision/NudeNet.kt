package com.rox.gameai.vision

import com.rox.gameai.core.Categories
import com.rox.gameai.core.Detection
import com.rox.gameai.core.IRect

/**
 * Pre/post-processing for the NudeNet 320n detector (YOLOv8 layout: output [1, 4+18, N]).
 * Ported 1:1 from the reference Python implementation (nudenet 3.4.2, AGPL-3.0). Pure Kotlin → JVM-tested.
 */
object NudeNet {
    const val SIZE = 320
    val LABELS = listOf(
        "FEMALE_GENITALIA_COVERED", "FACE_FEMALE", "BUTTOCKS_EXPOSED", "FEMALE_BREAST_EXPOSED", "FEMALE_GENITALIA_EXPOSED",
        "MALE_BREAST_EXPOSED", "ANUS_EXPOSED", "FEET_EXPOSED", "BELLY_COVERED", "FEET_COVERED", "ARMPITS_COVERED",
        "ARMPITS_EXPOSED", "FACE_MALE", "BELLY_EXPOSED", "MALE_GENITALIA_EXPOSED", "ANUS_COVERED", "FEMALE_BREAST_COVERED", "BUTTOCKS_COVERED",
    )
    private val NUDITY = setOf("FEMALE_BREAST_EXPOSED", "FEMALE_GENITALIA_EXPOSED", "MALE_GENITALIA_EXPOSED", "BUTTOCKS_EXPOSED", "ANUS_EXPOSED")

    /** Pads to a square (bottom/right, black), bilinear-resizes to 320, RGB, /255, NCHW. Returns (tensor, paddedSide). */
    fun preprocess(px: IntArray, w: Int, h: Int): Pair<FloatArray, Int> {
        val side = maxOf(w, h)
        val out = FloatArray(3 * SIZE * SIZE)
        val scale = side.toFloat() / SIZE
        val plane = SIZE * SIZE
        for (y in 0 until SIZE) {
            val sy = ((y + 0.5f) * scale - 0.5f).coerceAtLeast(0f)
            val y0 = sy.toInt(); val y1 = minOf(y0 + 1, side - 1); val fy = sy - y0
            for (x in 0 until SIZE) {
                val sx = ((x + 0.5f) * scale - 0.5f).coerceAtLeast(0f)
                val x0 = sx.toInt(); val x1 = minOf(x0 + 1, side - 1); val fx = sx - x0
                fun at(xx: Int, yy: Int) = if (xx < w && yy < h) px[yy * w + xx] else 0xFF000000.toInt()
                val c00 = at(x0, y0); val c10 = at(x1, y0); val c01 = at(x0, y1); val c11 = at(x1, y1)
                for (ch in 0 until 3) {
                    val sh = 16 - 8 * ch // R, G, B
                    val v = (((c00 shr sh) and 0xFF) * (1 - fx) + ((c10 shr sh) and 0xFF) * fx) * (1 - fy) +
                        (((c01 shr sh) and 0xFF) * (1 - fx) + ((c11 shr sh) and 0xFF) * fx) * fy
                    out[ch * plane + y * SIZE + x] = v / 255f
                }
            }
        }
        return out to side
    }

    data class Raw(val box: FloatArray, val score: Float, val cls: Int)

    /** @param out flattened [22][n] output; returns detections in original pixel coordinates. */
    fun postprocess(out: FloatArray, n: Int, w: Int, h: Int, side: Int, minScore: Float = 0.2f): List<Raw> {
        val k = SIZE.toFloat()
        val cand = ArrayList<Raw>()
        for (i in 0 until n) {
            var best = -1; var bs = 0f
            for (c in 0 until LABELS.size) { val s = out[(4 + c) * n + i]; if (s > bs) { bs = s; best = c } }
            if (bs < minScore) continue
            val cx = out[i]; val cy = out[n + i]; val bw = out[2 * n + i]; val bh = out[3 * n + i]
            var x = (cx - bw / 2) * side / k; var y = (cy - bh / 2) * side / k
            var ww = bw * side / k; var hh = bh * side / k
            x = x.coerceIn(0f, w.toFloat()); y = y.coerceIn(0f, h.toFloat())
            ww = minOf(ww, w - x); hh = minOf(hh, h - y)
            cand += Raw(floatArrayOf(x, y, ww, hh), bs, best)
        }
        return nms(cand, 0.25f, 0.45f)
    }

    private fun iou(a: FloatArray, b: FloatArray): Float {
        val l = maxOf(a[0], b[0]); val t = maxOf(a[1], b[1]); val r = minOf(a[0] + a[2], b[0] + b[2]); val bt = minOf(a[1] + a[3], b[1] + b[3])
        val inter = maxOf(0f, r - l) * maxOf(0f, bt - t)
        val u = a[2] * a[3] + b[2] * b[3] - inter
        return if (u <= 0f) 0f else inter / u
    }

    fun nms(c: List<Raw>, scoreThr: Float, iouThr: Float): List<Raw> {
        val sorted = c.filter { it.score >= scoreThr }.sortedByDescending { it.score }
        val keep = ArrayList<Raw>()
        for (d in sorted) if (keep.none { iou(it.box, d.box) > iouThr }) keep += d
        return keep
    }

    /** Keeps only exposed-nudity classes above the sensitivity threshold, as ROX detections. */
    fun toDetections(raw: List<Raw>, sensitivity: Float): List<Detection> {
        val thr = 0.65f - 0.4f * sensitivity.coerceIn(0f, 1f)
        return raw.filter { LABELS[it.cls] in NUDITY && it.score >= thr }.map {
            Detection(IRect(it.box[0].toInt(), it.box[1].toInt(), (it.box[0] + it.box[2]).toInt(), (it.box[1] + it.box[3]).toInt()), it.score, Categories.NUDITY)
        }
    }
}
