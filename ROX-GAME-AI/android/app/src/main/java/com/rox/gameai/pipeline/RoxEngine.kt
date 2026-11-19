package com.rox.gameai.pipeline

import android.content.Context
import android.graphics.Bitmap
import android.media.projection.MediaProjection
import android.os.SystemClock
import com.rox.gameai.ai.GameRecognizer
import com.rox.gameai.ai.OcrEngine
import com.rox.gameai.ai.Script
import com.rox.gameai.ai.TextClassifier
import com.rox.gameai.connection.ConnectionManager
import com.rox.gameai.core.BlockedEvent
import com.rox.gameai.core.DisplayMode
import com.rox.gameai.core.PerfMonitor
import com.rox.gameai.core.RoxLog
import com.rox.gameai.core.SettingsRepo
import com.rox.gameai.core.Store
import com.rox.gameai.core.TextKind
import com.rox.gameai.core.TextOverlay
import com.rox.gameai.core.TranslationEntry
import com.rox.gameai.core.VideoSourceKind
import com.rox.gameai.translation.DialogContext
import com.rox.gameai.translation.TranslationEngine
import com.rox.gameai.vision.ExternalCameraSource
import com.rox.gameai.vision.FrameSource
import com.rox.gameai.vision.RegionTracker
import com.rox.gameai.vision.SafeVision
import com.rox.gameai.vision.TestPatternSource
import com.rox.gameai.vision.TfliteContentClassifier
import com.rox.gameai.voice.VoiceLine
import com.rox.gameai.voice.VoiceTranslator
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.util.concurrent.atomic.AtomicBoolean

enum class AutoStep { IDLE, DETECT_SOURCE, RECEIVE, RECOGNIZE, LANGUAGE, TRANSLATION, VOICE, SAFE_VISION, PROFILE, DISPLAY, RUNNING, ERROR }

data class PipelineStatus(
    val running: Boolean = false,
    val step: AutoStep = AutoStep.IDLE,
    val sourceLabel: String = "",
    val isTestSource: Boolean = false,
    val inAppDisplay: Boolean = true,
    val videoActive: Boolean = false,
    val frameW: Int = 0,
    val frameH: Int = 0,
    val translationActive: Boolean = false,
    val voiceActive: Boolean = false,
    val voiceMode: String = "off",
    val safeActive: Boolean = false,
    val gameLanguage: String = "",
    val ocrScript: Script = Script.LATIN,
    val message: String = "",
)

class FrameHolder(val bitmap: Bitmap, val seq: Long)

/** ROX AUTO START — orchestrates source → Safe Vision → display, OCR → translation, audio → voice translation. */
class RoxEngine(
    private val context: Context,
    val settings: SettingsRepo,
    val store: Store,
    val connection: ConnectionManager,
    val perf: PerfMonitor,
    private val scope: CoroutineScope,
) {
    val ocr = OcrEngine()
    val translator = TranslationEngine(settings)
    val recognizer = GameRecognizer(store)
    val dialog = DialogContext()
    val safeVision: SafeVision
    val modelInstalled: Boolean

    private val _status = MutableStateFlow(PipelineStatus())
    val status: StateFlow<PipelineStatus> = _status
    private val _frame = MutableStateFlow<FrameHolder?>(null)
    val frame: StateFlow<FrameHolder?> = _frame
    private val _overlays = MutableStateFlow<List<TextOverlay>>(emptyList())
    val overlays: StateFlow<List<TextOverlay>> = _overlays
    private val _regions = MutableStateFlow<List<RegionTracker.Track>>(emptyList())
    val regions: StateFlow<List<RegionTracker.Track>> = _regions
    private val _voice = MutableStateFlow<List<VoiceLine>>(emptyList())
    val voice: StateFlow<List<VoiceLine>> = _voice

    private var nudeDetector: com.rox.gameai.vision.NudeNetDetector? = null
    @Volatile private var diagFrames = 0
    @Volatile private var diagOcrBlocks = 0
    @Volatile private var diagOcrSample = ""
    @Volatile private var diagMasks = 0
    @Volatile private var diagBright = 0
    private var source: FrameSource? = null
    var projection: MediaProjection? = null
        private set
    private var screenSize = Triple(1280, 720, 320)
    private val voiceTranslator: VoiceTranslator
    private var watchdog: Job? = null
    @Volatile private var lastFrameAt = 0L
    @Volatile private var lastOcrAt = 0L
    private val ocrBusy = AtomicBoolean(false)
    private var buffers = arrayOfNulls<Bitmap>(3)
    private var bufIndex = 0
    private var pixels = IntArray(0)
    private var seq = 0L
    private var autoScriptIndex = 0
    private var restarts = 0
    // Language voting: a language becomes "the game language" after 3 consistent detections and only
    // changes after 8 consistent different ones (stops en/zh flip-flopping on noisy OCR).
    @Volatile private var stickyLang = ""
    private var candLang = ""; private var candVotes = 0
    private val voteLangs = setOf("en", "ja", "zh", "ko", "fr", "de", "es", "it", "pt", "ru", "tr")

    private fun vote(id: String): String {
        if (id !in voteLangs) return stickyLang
        if (id == stickyLang) { candVotes = 0; return stickyLang }
        if (id == candLang) candVotes++ else { candLang = id; candVotes = 1 }
        val need = if (stickyLang.isEmpty()) 3 else 8
        if (candVotes >= need) { stickyLang = id; candVotes = 0; RoxLog.i("Language", "Game language set to: $id") }
        return stickyLang
    }
    @Volatile private var blackSince = 0L
    @Volatile private var blackWarned = false

    /** true if the frame is (almost) completely black — what Android delivers for protected (FLAG_SECURE/DRM) apps. */
    private fun isBlack(px: IntArray): Boolean {
        var bright = 0; var n = 0
        var i = 0
        while (i < px.size) { val c = px[i]; if (((c shr 16) and 0xFF) + ((c shr 8) and 0xFF) + (c and 0xFF) > 45) bright++; n++; i += 97 }
        return bright * 100 < n * 2
    }

    init {
        val model = TfliteContentClassifier.load(context)
        val nude = com.rox.gameai.vision.NudeNetDetector.load(context)
        nudeDetector = nude
        safeVision = SafeVision(
            model?.let { m -> { px: IntArray, w: Int, h: Int -> m.classify(px, w, h).let { it.nudity to it.sexual } } },
            nude?.let { d -> { px: IntArray, w: Int, h: Int, sens: Float -> d.detect(px, w, h, sens) } },
        )
        modelInstalled = safeVision.modelAvailable
        voiceTranslator = VoiceTranslator(context, settings,
            onFinal = { text, lang -> scope.launch { onVoiceFinal(text, lang) } },
            onSilent = {
                if (settings.value.audioSource == com.rox.gameai.core.AudioSourceKind.STREAM_PLAYBACK) {
                    RoxLog.w("Voice", "Game audio is blocked by the streaming app — switching to the microphone automatically")
                    settings.update { it.copy(audioSource = com.rox.gameai.core.AudioSourceKind.MICROPHONE) }
                    scope.launch(Dispatchers.Main) { restartVoice() }
                }
            },
            onPartial = { text -> _voice.value = (_voice.value.filter { !it.partial } + VoiceLine(System.currentTimeMillis(), "", text, "", true)).takeLast(60) })
        // Recognise game automatically from the console's own report
        scope.launch { connection.state.collect { recognizer.fromConsole(it.runningApp, it.runningTitleId) } }
    }

    fun setScreenSize(w: Int, h: Int, dpi: Int) { screenSize = Triple(w, h, dpi) }

    fun hasCaptureCard() = ExternalCameraSource.findExternalCamera(context) != null

    /** Decide which source AUTO START needs. Returns SCREEN_CAPTURE when the UI must ask for capture consent. */
    fun resolveSource(): VideoSourceKind = when (settings.value.videoSource) {
        VideoSourceKind.AUTO -> if (hasCaptureCard()) VideoSourceKind.CAPTURE_CARD else VideoSourceKind.SCREEN_CAPTURE
        else -> settings.value.videoSource
    }

    fun onProjectionReady(p: MediaProjection) {
        projection = p
        val (w, h, dpi) = screenSize
        // Capture at half resolution (enough for OCR/detection, saves battery and heat)
        autoStart(com.rox.gameai.vision.ScreenCaptureSource(p, w / 2, h / 2, dpi))
    }

    fun autoStartTest() = autoStart(TestPatternSource())
    fun autoStartCaptureCard() = autoStart(ExternalCameraSource(context))

    private fun step(s: AutoStep, msg: String = "") { _status.value = _status.value.copy(step = s, message = msg); RoxLog.i("AutoStart", "$s $msg") }

    fun autoStart(src: FrameSource) {
        stop(keepProjection = src is com.rox.gameai.vision.ScreenCaptureSource)
        source = src
        restarts = 0
        _status.value = PipelineStatus(running = true, step = AutoStep.DETECT_SOURCE, sourceLabel = src.label, isTestSource = src.isTest, inAppDisplay = src.supportsInAppDisplay)
        RoxLog.i("AutoStart", "1/9 source detected: ${src.label}${if (src.isTest) " (TEST — not a real PlayStation stream)" else ""}")
        step(AutoStep.RECEIVE)
        lastFrameAt = SystemClock.elapsedRealtime()
        src.start(::onFrame)
        scope.launch {
            // Wait for first frame
            val t0 = SystemClock.elapsedRealtime()
            while (_frame.value == null && SystemClock.elapsedRealtime() - t0 < 8000 && _status.value.running) delay(100)
            if (!_status.value.running) return@launch
            if (_frame.value == null) { step(AutoStep.ERROR, "no_video"); RoxLog.e("AutoStart", "No video frames received from ${src.label}") }
            step(AutoStep.RECOGNIZE)
            val conn = connection.state.value
            recognizer.fromConsole(conn.runningApp, conn.runningTitleId)
            step(AutoStep.LANGUAGE)
            val lang = recognizer.state.value.profile?.language.orEmpty()
            _status.value = _status.value.copy(gameLanguage = lang, ocrScript = OcrEngine.scriptFor(lang))
            step(AutoStep.TRANSLATION)
            _status.value = _status.value.copy(translationActive = settings.value.translationEnabled)
            if (lang.isNotEmpty()) launch { translator.prepare(lang) }
            step(AutoStep.VOICE)
            if (settings.value.voiceEnabled && !src.isTest) {
                withContext(Dispatchers.Main) { voiceTranslator.start(projection) }
                _status.value = _status.value.copy(voiceActive = voiceTranslator.mode != "unavailable", voiceMode = voiceTranslator.mode)
            }
            step(AutoStep.SAFE_VISION)
            _status.value = _status.value.copy(safeActive = settings.value.safeVisionEnabled)
            step(AutoStep.PROFILE, recognizer.state.value.profile?.name ?: "")
            step(AutoStep.DISPLAY)
            step(AutoStep.RUNNING)
        }
        startWatchdog()
    }

    private fun startWatchdog() {
        watchdog?.cancel()
        watchdog = scope.launch {
            var tick = 0
            while (isActive && _status.value.running) {
                delay(1000)
                if (++tick % 10 == 0) {
                    val nd = nudeDetector
                    RoxLog.i("Diag", "10s: frames=$diagFrames ${_status.value.frameW}x${_status.value.frameH} ocrBlocks=$diagOcrBlocks lang=${_status.value.gameLanguage.ifEmpty { "?" }} text=\"$diagOcrSample\" maskedFrames=$diagMasks nudenet=${nd?.lastBest ?: "off"} (${nd?.lastMs ?: 0}ms) overlay=${if (_status.value.inAppDisplay) "in-app" else "floating"}")
                    diagFrames = 0; diagOcrBlocks = 0; diagMasks = 0; diagOcrSample = ""
                }
                val gap = SystemClock.elapsedRealtime() - lastFrameAt
                val active = gap < settings.value.streamTimeoutSec * 1000L
                if (_status.value.videoActive != active) {
                    _status.value = _status.value.copy(videoActive = active)
                    if (!active) RoxLog.w("Stream", "Video stream interrupted (${gap} ms without frames)")
                    else RoxLog.i("Stream", "Video stream restored")
                }
                // Screen capture delivers no frames when the screen is static, so only restart real device sources
                if (!active && gap > settings.value.streamTimeoutSec * 2000L && restarts < 5 && source is ExternalCameraSource) {
                    restarts++
                    RoxLog.w("Stream", "Restarting capture source (attempt $restarts)")
                    source?.let { s -> s.stop(); delay(500); s.start(::onFrame) }
                    lastFrameAt = SystemClock.elapsedRealtime()
                }
            }
        }
    }

    /** Frame thread: Safe Vision runs on the pixels BEFORE the frame is published for display. */
    private fun onFrame(src: Bitmap) {
        val t0 = SystemClock.elapsedRealtime()
        lastFrameAt = t0
        val s = settings.value
        val w = src.width; val h = src.height
        // OCR on the ORIGINAL (unmasked) frame, throttled, never blocking the frame thread
        val profile = recognizer.state.value.profile
        val interval = (profile?.ocrIntervalMs ?: s.ocrIntervalMs).toLong().let { if (perf.stats.value.throttled) it * 2 else it }
        if (s.translationEnabled && t0 - lastOcrAt >= interval && ocrBusy.compareAndSet(false, true)) {
            lastOcrAt = t0
            val scale = s.ocrScale.coerceIn(0.3f, 1f)
            val small = Bitmap.createScaledBitmap(src, (w * scale).toInt().coerceAtLeast(64), (h * scale).toInt().coerceAtLeast(36), true)
            scope.launch(Dispatchers.Default) { try { runOcr(small, 1f / scale, w, h) } finally { ocrBusy.set(false) } }
        }
        if (pixels.size != w * h) pixels = IntArray(w * h)
        src.getPixels(pixels, 0, w, 0, 0, w, h)
        if (isBlack(pixels)) {
            if (blackSince == 0L) blackSince = t0
            if (!blackWarned && t0 - blackSince > 4000) {
                blackWarned = true
                RoxLog.e("Stream", "The captured video is completely black: the streaming app (e.g. PS Remote Play) blocks screen capture. ROX cannot see the game this way — use the PC (ROX Server / ROX Play) or an HDMI capture card.")
                _status.value = _status.value.copy(message = "protected")
            }
        } else if (blackSince != 0L) {
            blackSince = 0L
            if (blackWarned) { blackWarned = false; _status.value = _status.value.copy(message = ""); RoxLog.i("Stream", "Video visible again") }
        }
        val res = safeVision.process(pixels, w, h, s, System.currentTimeMillis(), profile?.safeVision ?: true, profile?.blurMode)
        diagFrames++; if (res.regions.isNotEmpty()) diagMasks++
        for (e in res.newEvents) RoxLog.i("SafeVision", "Blocked ${e.category} (${(e.score * 100).toInt()}%) at ${e.rect}")
        val idx = bufIndex; bufIndex = (bufIndex + 1) % buffers.size
        val out = buffers[idx]?.takeIf { it.width == w && it.height == h } ?: Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888).also { buffers[idx] = it }
        out.setPixels(pixels, 0, w, 0, 0, w, h)
        _frame.value = FrameHolder(out, ++seq)
        _regions.value = res.regions
        if (_status.value.frameW != w || _status.value.frameH != h) _status.value = _status.value.copy(frameW = w, frameH = h)
        val game = profile?.name ?: ""
        for (e in res.newEvents) store.addBlocked(BlockedEvent(System.currentTimeMillis(), game, e.category, e.score, s.blurMode))
        perf.onFrame(SystemClock.elapsedRealtime() - t0)
    }

    private suspend fun runOcr(bmp: Bitmap, scaleBack: Float, frameW: Int, frameH: Int) {
        val t0 = SystemClock.elapsedRealtime()
        try {
            val st = _status.value
            var lang = recognizer.state.value.profile?.language.orEmpty().ifEmpty { stickyLang }
            val script = if (lang.isNotEmpty()) OcrEngine.scriptFor(lang) else Script.LATIN
            var blocks = ocr.recognize(bmp, script, scaleBack)
            if (blocks.isEmpty() && lang.isEmpty() && autoScriptIndex < 30) {
                // Unknown language: probe CJK recognisers in turn
                val probe = listOf(Script.JAPANESE, Script.CHINESE, Script.KOREAN)[autoScriptIndex++ % 3]
                blocks = ocr.recognize(bmp, probe, scaleBack)
            }
            perf.lastOcrMs = SystemClock.elapsedRealtime() - t0
            diagOcrBlocks += blocks.size
            if (blocks.isNotEmpty()) diagOcrSample = blocks.joinToString(" | ") { it.text }.take(80)
            if (blocks.isEmpty()) { _overlays.value = emptyList(); return }
            val all = blocks.joinToString(" ") { it.text }
            recognizer.fromScreenText(all)
            if (recognizer.state.value.profile?.language.isNullOrEmpty() && all.length >= 12) {
                val voted = vote(ocr.identifyLanguage(all))
                if (voted.isNotEmpty() && voted != _status.value.gameLanguage) {
                    recognizer.setLanguage(voted)
                    _status.value = _status.value.copy(gameLanguage = voted, ocrScript = OcrEngine.scriptFor(voted))
                }
                lang = voted
            }
            if (lang.isEmpty() || lang == "und") return
            val now = System.currentTimeMillis()
            val game = recognizer.state.value.profile?.name ?: ""
            val out = ArrayList<TextOverlay>()
            for (b in blocks) {
                val c = TextClassifier.classify(b.text, b.rect, frameW, frameH)
                val translated = translator.translate(c.body, lang) ?: continue
                out += TextOverlay(b.rect, c.body, translated, c.kind, c.speaker)
                if (!translator.cache.seenRecently(c.body, now)) {
                    store.addTranslation(TranslationEntry(now, game, c.kind, c.body, lang, translated, c.speaker))
                    if (c.kind == TextKind.DIALOG) dialog.add(DialogContext.Line(now, c.speaker, c.body, translated))
                }
            }
            _overlays.value = if (settings.value.displayMode == DisplayMode.LOG_ONLY) emptyList() else out
        } catch (t: Throwable) {
            RoxLog.e("OCR", "OCR/translation failed", t)
        } finally { bmp.recycle() }
    }

    private suspend fun onVoiceFinal(text: String, lang: String) {
        val now = System.currentTimeMillis()
        val speaker = dialog.lastSpeaker(now)
        val tr = translator.translate(text, lang.substringBefore('-')) ?: ""
        _voice.value = (_voice.value.filter { !it.partial } + VoiceLine(now, speaker, text, tr, false)).takeLast(60)
        if (tr.isNotEmpty()) {
            store.addTranslation(TranslationEntry(now, recognizer.state.value.profile?.name ?: "", TextKind.DIALOG, text, lang, tr, speaker, fromVoice = true))
            withContext(Dispatchers.Main) { voiceTranslator.speak(tr) }
        }
    }

    fun voiceAvailable() = voiceTranslator.isRecognitionAvailable()
    fun audioLevel() = voiceTranslator.audioLevel

    fun restartVoice() {
        voiceTranslator.stop()
        if (_status.value.running && settings.value.voiceEnabled) {
            voiceTranslator.start(projection)
            _status.value = _status.value.copy(voiceActive = voiceTranslator.mode != "unavailable", voiceMode = voiceTranslator.mode)
        } else _status.value = _status.value.copy(voiceActive = false, voiceMode = "off")
    }

    fun stop(keepProjection: Boolean = false) {
        watchdog?.cancel(); watchdog = null
        source?.stop(); source = null
        voiceTranslator.stop()
        safeVision.tracker.reset()
        if (!keepProjection) { runCatching { projection?.stop() }; projection = null }
        if (_status.value.running) RoxLog.i("AutoStart", "STOP")
        _status.value = PipelineStatus()
        _frame.value = null; _overlays.value = emptyList(); _regions.value = emptyList()
        recognizer.reset()
        stickyLang = ""; candLang = ""; candVotes = 0; autoScriptIndex = 0
    }
}
