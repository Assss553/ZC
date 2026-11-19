package com.rox.gameai.vision

import com.rox.gameai.core.Detection
import com.rox.gameai.core.IRect

/**
 * Tracks detected regions across frames (greedy IoU matching + smoothing) so masks follow moving
 * objects, do not flicker, and are removed automatically [holdMs] after the content disappears.
 */
class RegionTracker(private val holdMs: Long = 900, private val iouThreshold: Float = 0.15f, private val smoothing: Float = 0.5f) {

    data class Track(val id: Int, val rect: IRect, val category: String, val score: Float, val firstSeen: Long, val lastSeen: Long, val hits: Int)

    private var nextId = 1
    private val tracks = ArrayList<Track>()
    var lastNewTracks: List<Track> = emptyList(); private set

    @Synchronized
    fun update(dets: List<Detection>, now: Long): List<Track> {
        val used = BooleanArray(dets.size)
        val updated = ArrayList<Track>()
        for (t in tracks) {
            var best = -1; var bestIou = iouThreshold
            for ((i, d) in dets.withIndex()) {
                if (used[i] || d.category != t.category) continue
                val v = t.rect.iou(d.rect)
                if (v > bestIou) { bestIou = v; best = i }
            }
            if (best >= 0) {
                used[best] = true
                val d = dets[best]
                updated += t.copy(rect = lerp(t.rect, d.rect), score = d.score, lastSeen = now, hits = t.hits + 1)
            } else if (now - t.lastSeen <= holdMs) {
                updated += t
            }
        }
        val fresh = ArrayList<Track>()
        for ((i, d) in dets.withIndex()) if (!used[i]) {
            val t = Track(nextId++, d.rect, d.category, d.score, now, now, 1)
            updated += t; fresh += t
        }
        tracks.clear(); tracks.addAll(updated)
        lastNewTracks = fresh
        return tracks.toList()
    }

    @Synchronized fun active(): List<Track> = tracks.toList()
    @Synchronized fun reset() { tracks.clear() }

    private fun lerp(a: IRect, b: IRect): IRect {
        val s = smoothing
        fun m(x: Int, y: Int) = (x + (y - x) * s).toInt()
        // Always keep the union-ish expansion so fast motion is still covered
        return IRect(minOf(m(a.left, b.left), b.left), minOf(m(a.top, b.top), b.top), maxOf(m(a.right, b.right), b.right), maxOf(m(a.bottom, b.bottom), b.bottom))
    }
}
