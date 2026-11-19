package com.rox.gameai.pipeline

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.PixelFormat
import android.provider.Settings
import android.text.Layout
import android.text.StaticLayout
import android.text.TextPaint
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import com.rox.gameai.core.RoxLog
import com.rox.gameai.core.TextOverlay
import com.rox.gameai.vision.RegionTracker

/**
 * Floating translation window shown ON TOP of PS Remote Play (Display mode "separate window").
 * It is touch-transparent so the game controls keep working. Masks drawn here appear after capture
 * analysis (~1 frame later), so guaranteed pre-display blocking is only possible in the in-app view
 * (capture card / test video).
 */
class OverlayWindow(private val context: Context) {
    private var view: OverlayView? = null
    private val wm = context.getSystemService(WindowManager::class.java)

    fun canShow() = Settings.canDrawOverlays(context)

    fun show() {
        if (view != null || !canShow()) return
        val v = OverlayView(context)
        val lp = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT, WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                // SECURE: the overlay is excluded (black) from screen capture, so ROX never OCRs its own Arabic text
                WindowManager.LayoutParams.FLAG_SECURE,
            PixelFormat.TRANSLUCENT,
        ).apply { gravity = Gravity.TOP or Gravity.START }
        runCatching { wm.addView(v, lp); view = v; RoxLog.i("Overlay", "Floating window shown") }.onFailure { RoxLog.e("Overlay", "Cannot show overlay", it) }
    }

    fun hide() { view?.let { runCatching { wm.removeView(it) } }; view = null }

    fun update(texts: List<TextOverlay>, regions: List<RegionTracker.Track>, frameW: Int, frameH: Int) {
        view?.let { it.texts = texts; it.regions = regions; it.frameW = frameW; it.frameH = frameH; it.postInvalidate() }
    }

    private class OverlayView(ctx: Context) : View(ctx) {
        var texts: List<TextOverlay> = emptyList()
        var regions: List<RegionTracker.Track> = emptyList()
        var frameW = 1; var frameH = 1
        private val bg = Paint().apply { color = Color.argb(215, 10, 10, 10) }
        private val border = Paint().apply { color = Color.rgb(255, 122, 0); style = Paint.Style.STROKE; strokeWidth = 3f }
        private val mask = Paint().apply { color = Color.BLACK }
        private val tp = TextPaint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.WHITE; textSize = 34f }

        override fun onDraw(canvas: Canvas) {
            if (frameW <= 1) return
            val sx = width.toFloat() / frameW; val sy = height.toFloat() / frameH
            for (r in regions) canvas.drawRect(r.rect.left * sx, r.rect.top * sy, r.rect.right * sx, r.rect.bottom * sy, mask)
            // Subtitle panel at the bottom with dialogue + mission lines
            val lines = texts.filter { it.translated.isNotBlank() }.take(4)
            if (lines.isEmpty()) return
            val body = lines.joinToString("\n") { (if (it.speaker.isNotBlank()) "${it.speaker}: " else "") + it.translated }
            val wText = (width * 0.9f).toInt()
            val layout = StaticLayout.Builder.obtain(body, 0, body.length, tp, wText).setAlignment(Layout.Alignment.ALIGN_CENTER).build()
            val top = height - layout.height - 60f
            canvas.drawRoundRect(width * 0.04f, top - 16f, width * 0.96f, top + layout.height + 16f, 18f, 18f, bg)
            canvas.drawRoundRect(width * 0.04f, top - 16f, width * 0.96f, top + layout.height + 16f, 18f, 18f, border)
            canvas.save(); canvas.translate(width * 0.05f, top); layout.draw(canvas); canvas.restore()
        }
    }
}
