package com.rox.gameai.vision

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.ImageFormat
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.PixelFormat
import android.graphics.RectF
import android.graphics.Shader
import android.hardware.camera2.CameraCaptureSession
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraDevice
import android.hardware.camera2.CameraManager
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.Image
import android.media.ImageReader
import android.media.projection.MediaProjection
import android.os.Handler
import android.os.HandlerThread
import android.util.Size
import com.rox.gameai.core.RoxLog

/** A source of game video frames. The bitmap passed to the sink is only valid during the callback. */
interface FrameSource {
    val id: String
    val label: String
    val isTest: Boolean get() = false
    /** true when frames are shown inside ROX after processing (pre-display blocking is guaranteed). */
    val supportsInAppDisplay: Boolean
    fun start(sink: (Bitmap) -> Unit)
    fun stop()
}

/**
 * TEST VIDEO SOURCE — synthetic game-like video generated on the phone: subtitles/dialogue, a mission
 * banner, a menu, a notification and a moving skin-tone shape. Used to test OCR, translation, Safe Vision
 * and tracking without a PlayStation. It is always labelled as TEST in the UI.
 */
class TestPatternSource(private val width: Int = 1280, private val height: Int = 720, private val fps: Int = 15) : FrameSource {
    override val id = "test"
    override val label = "TEST VIDEO"
    override val isTest = true
    override val supportsInAppDisplay = true
    private var thread: HandlerThread? = null
    @Volatile private var running = false
    private val bmp = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
    private var frame = 0L

    val dialogLines = listOf(
        "Elena: We must find the ancient key before nightfall.",
        "Marcus: The bridge to the north is guarded by soldiers.",
        "Elena: Follow me and stay quiet.",
    )

    fun render(n: Long): Bitmap {
        val c = Canvas(bmp)
        val bg = Paint().apply { shader = LinearGradient(0f, 0f, 0f, height.toFloat(), Color.rgb(20, 28, 24), Color.rgb(48, 60, 52), Shader.TileMode.CLAMP) }
        c.drawRect(0f, 0f, width.toFloat(), height.toFloat(), bg)
        val p = Paint(Paint.ANTI_ALIAS_FLAG)
        // Moving "exposed skin" shape (tests Safe Vision + tracking)
        val t = (n % 150) / 150f
        val cx = 200f + t * (width - 400f)
        p.color = Color.rgb(224, 172, 140)
        c.drawOval(RectF(cx - 90f, 150f, cx + 90f, 420f), p)
        // Mission banner (top-left)
        p.color = Color.WHITE; p.textSize = 34f
        c.drawText("Mission: Reach the old lighthouse", 40f, 70f, p)
        // Menu (left column)
        p.textSize = 30f
        listOf("Continue", "Inventory", "Map").forEachIndexed { i, s -> c.drawText(s, 40f, 470f + i * 44f, p) }
        // Notification (top-right)
        p.textSize = 26f
        c.drawText("Trophy unlocked", width - 300f, 60f, p)
        // Dialogue box (bottom)
        p.color = Color.argb(200, 0, 0, 0)
        c.drawRect(120f, height - 150f, width - 120f, height - 40f, p)
        p.color = Color.WHITE; p.textSize = 36f
        c.drawText(dialogLines[((n / (fps * 4L)) % dialogLines.size).toInt()], 150f, height - 80f, p)
        return bmp
    }

    override fun start(sink: (Bitmap) -> Unit) {
        val th = HandlerThread("rox-test-source").also { it.start() }
        thread = th; running = true
        val h = Handler(th.looper)
        val period = 1000L / fps
        h.post(object : Runnable {
            override fun run() {
                if (!running) return
                val t0 = System.currentTimeMillis()
                sink(render(frame++))
                h.postDelayed(this, (period - (System.currentTimeMillis() - t0)).coerceAtLeast(1))
            }
        })
    }

    override fun stop() { running = false; thread?.quitSafely(); thread = null }
}

/**
 * Captures the phone screen (e.g. the official PS Remote Play app) through MediaProjection, after the
 * user explicitly accepts Android's screen-capture prompt. Content protected with FLAG_SECURE/DRM is
 * delivered black by Android and is NOT bypassed.
 */
class ScreenCaptureSource(private val projection: MediaProjection, private val w: Int, private val h: Int, private val dpi: Int) : FrameSource {
    override val id = "screen"
    override val label = "PS Remote Play (screen capture)"
    override val supportsInAppDisplay = false
    private var thread: HandlerThread? = null
    private var reader: ImageReader? = null
    private var display: VirtualDisplay? = null
    private var rowBmp: Bitmap? = null
    private var out: Bitmap? = null

    override fun start(sink: (Bitmap) -> Unit) {
        val th = HandlerThread("rox-screen").also { it.start() }
        thread = th
        val handler = Handler(th.looper)
        projection.registerCallback(object : MediaProjection.Callback() {
            override fun onStop() { RoxLog.w("Capture", "Screen capture stopped by the system/user") }
        }, handler)
        val r = ImageReader.newInstance(w, h, PixelFormat.RGBA_8888, 2)
        reader = r
        r.setOnImageAvailableListener({ ir ->
            val img = runCatching { ir.acquireLatestImage() }.getOrNull() ?: return@setOnImageAvailableListener
            try { sink(toBitmap(img)) } catch (t: Throwable) { RoxLog.e("Capture", "frame failed", t) } finally { img.close() }
        }, handler)
        display = projection.createVirtualDisplay("rox-capture", w, h, dpi, DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR, r.surface, null, handler)
        RoxLog.i("Capture", "Screen capture started ${w}x$h")
    }

    private fun toBitmap(img: Image): Bitmap {
        val plane = img.planes[0]
        val pixelStride = plane.pixelStride
        val rowW = plane.rowStride / pixelStride
        val rb = rowBmp?.takeIf { it.width == rowW && it.height == img.height } ?: Bitmap.createBitmap(rowW, img.height, Bitmap.Config.ARGB_8888).also { rowBmp = it }
        plane.buffer.rewind()
        rb.copyPixelsFromBuffer(plane.buffer)
        if (rowW == img.width) return rb
        val o = out?.takeIf { it.width == img.width && it.height == img.height } ?: Bitmap.createBitmap(img.width, img.height, Bitmap.Config.ARGB_8888).also { out = it }
        Canvas(o).drawBitmap(rb, 0f, 0f, null)
        return o
    }

    override fun stop() {
        runCatching { display?.release() }; display = null
        runCatching { reader?.close() }; reader = null
        thread?.quitSafely(); thread = null
    }

    fun release() { stop(); runCatching { projection.stop() } }
}

/**
 * HDMI capture card connected over USB-C. On phones with Android's external (UVC) camera support the
 * card appears as an EXTERNAL camera. Frames are processed BEFORE they are shown inside ROX.
 * HDCP-protected output is not bypassed: on PS4/PS5 HDCP must be disabled by the user in the console's
 * own settings (allowed for games; video apps stay protected).
 */
class ExternalCameraSource(private val context: Context) : FrameSource {
    override val id = "capture_card"
    override val label = "HDMI capture card (USB)"
    override val supportsInAppDisplay = true
    private var thread: HandlerThread? = null
    private var device: CameraDevice? = null
    private var session: CameraCaptureSession? = null
    private var reader: ImageReader? = null
    private var argb: IntArray = IntArray(0)
    private var bmp: Bitmap? = null

    companion object {
        fun findExternalCamera(context: Context): String? = runCatching {
            val cm = context.getSystemService(CameraManager::class.java)
            cm.cameraIdList.firstOrNull { cm.getCameraCharacteristics(it).get(CameraCharacteristics.LENS_FACING) == CameraCharacteristics.LENS_FACING_EXTERNAL }
        }.getOrNull()

        /** Converts a YUV_420_888 image to ARGB pixels (handles any row/pixel stride). */
        fun yuvToArgb(img: Image, out: IntArray) {
            val w = img.width; val h = img.height
            val yP = img.planes[0]; val uP = img.planes[1]; val vP = img.planes[2]
            val yB = yP.buffer; val uB = uP.buffer; val vB = vP.buffer
            val yRow = yP.rowStride; val uvRow = uP.rowStride; val uvPix = uP.pixelStride
            for (y in 0 until h) {
                for (x in 0 until w) {
                    val yy = (yB.get(y * yRow + x).toInt() and 0xFF) - 16
                    val uvIndex = (y / 2) * uvRow + (x / 2) * uvPix
                    val u = (uB.get(uvIndex).toInt() and 0xFF) - 128
                    val v = (vB.get(uvIndex).toInt() and 0xFF) - 128
                    val c = 1.164f * yy.coerceAtLeast(0)
                    val r = (c + 1.596f * v).toInt().coerceIn(0, 255)
                    val g = (c - 0.392f * u - 0.813f * v).toInt().coerceIn(0, 255)
                    val b = (c + 2.017f * u).toInt().coerceIn(0, 255)
                    out[y * w + x] = (0xFF shl 24) or (r shl 16) or (g shl 8) or b
                }
            }
        }
    }

    @SuppressLint("MissingPermission")
    override fun start(sink: (Bitmap) -> Unit) {
        val id = findExternalCamera(context) ?: run { RoxLog.w("CaptureCard", "No external (UVC) camera found"); return }
        val cm = context.getSystemService(CameraManager::class.java)
        val th = HandlerThread("rox-capture-card").also { it.start() }
        thread = th
        val handler = Handler(th.looper)
        val map = cm.getCameraCharacteristics(id).get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP)
        val sizes: Array<Size> = map?.getOutputSizes(ImageFormat.YUV_420_888) ?: arrayOf(Size(1280, 720))
        val size = sizes.minByOrNull { kotlin.math.abs(it.width * it.height - 1280 * 720) } ?: Size(1280, 720)
        val r = ImageReader.newInstance(size.width, size.height, ImageFormat.YUV_420_888, 3)
        reader = r
        r.setOnImageAvailableListener({ ir ->
            val img = runCatching { ir.acquireLatestImage() }.getOrNull() ?: return@setOnImageAvailableListener
            try {
                if (argb.size != img.width * img.height) argb = IntArray(img.width * img.height)
                yuvToArgb(img, argb)
                val b = bmp?.takeIf { it.width == img.width && it.height == img.height } ?: Bitmap.createBitmap(img.width, img.height, Bitmap.Config.ARGB_8888).also { bmp = it }
                b.setPixels(argb, 0, img.width, 0, 0, img.width, img.height)
                sink(b)
            } catch (t: Throwable) { RoxLog.e("CaptureCard", "frame failed", t) } finally { img.close() }
        }, handler)
        cm.openCamera(id, object : CameraDevice.StateCallback() {
            override fun onOpened(camera: CameraDevice) {
                device = camera
                @Suppress("DEPRECATION")
                camera.createCaptureSession(listOf(r.surface), object : CameraCaptureSession.StateCallback() {
                    override fun onConfigured(s: CameraCaptureSession) {
                        session = s
                        val req = camera.createCaptureRequest(CameraDevice.TEMPLATE_PREVIEW).apply { addTarget(r.surface) }.build()
                        s.setRepeatingRequest(req, null, handler)
                        RoxLog.i("CaptureCard", "Capture card streaming ${size.width}x${size.height}")
                    }
                    override fun onConfigureFailed(s: CameraCaptureSession) { RoxLog.e("CaptureCard", "Session configuration failed") }
                }, handler)
            }
            override fun onDisconnected(camera: CameraDevice) { RoxLog.w("CaptureCard", "Capture card disconnected"); camera.close() }
            override fun onError(camera: CameraDevice, error: Int) { RoxLog.e("CaptureCard", "Camera error $error"); camera.close() }
        }, handler)
    }

    override fun stop() {
        runCatching { session?.close() }; session = null
        runCatching { device?.close() }; device = null
        runCatching { reader?.close() }; reader = null
        thread?.quitSafely(); thread = null
    }
}
