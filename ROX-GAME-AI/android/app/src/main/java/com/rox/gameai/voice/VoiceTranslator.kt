package com.rox.gameai.voice

import android.annotation.SuppressLint
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioDeviceInfo
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioPlaybackCaptureConfiguration
import android.media.AudioRecord
import android.media.MediaRecorder
import android.media.projection.MediaProjection
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.ParcelFileDescriptor
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.speech.tts.TextToSpeech
import com.rox.gameai.core.AudioSourceKind
import com.rox.gameai.core.RoxLog
import com.rox.gameai.core.SettingsRepo
import java.io.FileOutputStream
import java.util.Locale
import kotlin.math.abs

data class VoiceLine(val time: Long, val speaker: String, val text: String, val translated: String, val partial: Boolean)

/**
 * ROX VOICE TRANSLATOR.
 *  • Android 13+: game audio is captured (AudioPlaybackCapture from the stream app, or the USB capture
 *    card's audio input) and piped directly into Android's SpeechRecognizer (EXTRA_AUDIO_SOURCE).
 *  • Android 10-12 or when capture is refused: microphone recognition (game sound from speakers).
 *  Speaker attribution: taken from on-screen subtitle names when available (no voice biometrics).
 *  Arabic dubbing: experimental reading of translations with Android TTS.
 */
class VoiceTranslator(
    private val context: Context,
    private val settings: SettingsRepo,
    private val onFinal: (text: String, lang: String) -> Unit,
    private val onPartial: (text: String) -> Unit,
) {
    private val main = Handler(Looper.getMainLooper())
    private var recognizer: SpeechRecognizer? = null
    private var record: AudioRecord? = null
    private var pump: Thread? = null
    @Volatile private var writeFd: ParcelFileDescriptor? = null
    @Volatile private var running = false
    @Volatile var audioLevel = 0; private set
    @Volatile var mode = "off"; private set
    private var projection: MediaProjection? = null
    private var tts: TextToSpeech? = null
    private var ttsReady = false

    fun isRecognitionAvailable() = SpeechRecognizer.isRecognitionAvailable(context)

    @SuppressLint("MissingPermission")
    fun start(projection: MediaProjection?) {
        if (running) return
        if (!isRecognitionAvailable()) { RoxLog.e("Voice", "No speech recognition service on this device"); mode = "unavailable"; return }
        this.projection = projection
        running = true
        val src = settings.value.audioSource
        val canPipe = Build.VERSION.SDK_INT >= 33
        record = if (canPipe) createRecord(src, projection) else null
        mode = when {
            record != null && src == AudioSourceKind.STREAM_PLAYBACK -> "stream-audio"
            record != null -> "usb-audio"
            else -> "microphone"
        }
        RoxLog.i("Voice", "Voice translation started (mode=$mode, lang=${settings.value.voiceLanguage})")
        record?.let { r -> r.startRecording(); startPump(r) }
        main.post { listen() }
        if (settings.value.ttsDubbing && tts == null) {
            tts = TextToSpeech(context) { st -> ttsReady = st == TextToSpeech.SUCCESS; if (ttsReady) tts?.language = Locale("ar") }
        }
    }

    @SuppressLint("MissingPermission")
    private fun createRecord(src: AudioSourceKind, projection: MediaProjection?): AudioRecord? = try {
        val rate = settings.value.audioSampleRate
        val fmt = AudioFormat.Builder().setEncoding(AudioFormat.ENCODING_PCM_16BIT).setSampleRate(rate).setChannelMask(AudioFormat.CHANNEL_IN_MONO).build()
        val minBuf = AudioRecord.getMinBufferSize(rate, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT).coerceAtLeast(4096) * 2
        when {
            src == AudioSourceKind.STREAM_PLAYBACK && projection != null -> {
                val cfg = AudioPlaybackCaptureConfiguration.Builder(projection)
                    .addMatchingUsage(AudioAttributes.USAGE_GAME).addMatchingUsage(AudioAttributes.USAGE_MEDIA).addMatchingUsage(AudioAttributes.USAGE_UNKNOWN).build()
                AudioRecord.Builder().setAudioFormat(fmt).setBufferSizeInBytes(minBuf).setAudioPlaybackCaptureConfig(cfg).build()
            }
            src == AudioSourceKind.USB_CAPTURE -> {
                val am = context.getSystemService(AudioManager::class.java)
                val usb = am.getDevices(AudioManager.GET_DEVICES_INPUTS).firstOrNull { it.type == AudioDeviceInfo.TYPE_USB_DEVICE || it.type == AudioDeviceInfo.TYPE_USB_HEADSET }
                if (usb == null) { RoxLog.w("Voice", "No USB audio input found, using microphone"); null }
                else AudioRecord.Builder().setAudioSource(MediaRecorder.AudioSource.DEFAULT).setAudioFormat(fmt).setBufferSizeInBytes(minBuf).build().also { it.setPreferredDevice(usb) }
            }
            else -> null
        }?.takeIf { it.state == AudioRecord.STATE_INITIALIZED }
    } catch (t: Throwable) { RoxLog.e("Voice", "Audio capture not available", t); null }

    private fun startPump(r: AudioRecord) {
        pump = Thread({
            val buf = ShortArray(1024)
            val bytes = ByteArray(2048)
            var silentSince = System.currentTimeMillis()
            var warned = false
            while (running) {
                val n = r.read(buf, 0, buf.size)
                if (n <= 0) continue
                var peak = 0
                for (i in 0 until n) { val v = abs(buf[i].toInt()); if (v > peak) peak = v; bytes[2 * i] = (buf[i].toInt() and 0xFF).toByte(); bytes[2 * i + 1] = (buf[i].toInt() shr 8).toByte() }
                audioLevel = peak
                if (peak > 300) silentSince = System.currentTimeMillis()
                else if (!warned && System.currentTimeMillis() - silentSince > 15_000) {
                    warned = true
                    RoxLog.w("Voice", "Captured game audio is silent for 15 s — the streaming app may block audio capture; switch Voice source to Microphone")
                }
                val fd = writeFd ?: continue
                try { FileOutputStream(fd.fileDescriptor).write(bytes, 0, n * 2) } catch (_: Throwable) { /* recognizer session ended; next session opens a new pipe */ }
            }
        }, "rox-audio-pump").also { it.start() }
    }

    private fun listen() {
        if (!running) return
        recognizer?.destroy()
        val rec = if (Build.VERSION.SDK_INT >= 31 && SpeechRecognizer.isOnDeviceRecognitionAvailable(context) && settings.value.localProcessing)
            SpeechRecognizer.createOnDeviceSpeechRecognizer(context) else SpeechRecognizer.createSpeechRecognizer(context)
        recognizer = rec
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, settings.value.voiceLanguage)
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, settings.value.localProcessing)
        }
        if (record != null && Build.VERSION.SDK_INT >= 33) {
            val pipe = ParcelFileDescriptor.createPipe()
            writeFd?.let { runCatching { it.close() } }
            writeFd = pipe[1]
            intent.putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE, pipe[0])
            intent.putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE_ENCODING, AudioFormat.ENCODING_PCM_16BIT)
            intent.putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE_SAMPLING_RATE, settings.value.audioSampleRate)
            intent.putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE_CHANNEL_COUNT, 1)
        }
        rec.setRecognitionListener(object : RecognitionListener {
            override fun onReadyForSpeech(params: Bundle?) {}
            override fun onBeginningOfSpeech() {}
            override fun onRmsChanged(rmsdB: Float) {}
            override fun onBufferReceived(buffer: ByteArray?) {}
            override fun onEndOfSpeech() {}
            override fun onEvent(eventType: Int, params: Bundle?) {}
            override fun onPartialResults(partialResults: Bundle?) {
                partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull()?.let { if (it.isNotBlank()) onPartial(it) }
            }
            override fun onResults(results: Bundle?) {
                results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull()?.let { if (it.isNotBlank()) onFinal(it, settings.value.voiceLanguage) }
                main.postDelayed({ listen() }, 100)
            }
            override fun onError(error: Int) {
                if (error != SpeechRecognizer.ERROR_NO_MATCH && error != SpeechRecognizer.ERROR_SPEECH_TIMEOUT) RoxLog.w("Voice", "Recognizer error $error")
                main.postDelayed({ listen() }, if (error == SpeechRecognizer.ERROR_RECOGNIZER_BUSY) 800 else 250)
            }
        })
        runCatching { rec.startListening(intent) }.onFailure { RoxLog.e("Voice", "startListening failed", it) }
    }

    fun speak(text: String) {
        if (settings.value.ttsDubbing && ttsReady) tts?.speak(text, TextToSpeech.QUEUE_ADD, null, "rox-${System.nanoTime()}")
    }

    fun stop() {
        running = false
        mode = "off"
        main.post { recognizer?.destroy(); recognizer = null }
        runCatching { record?.stop() }; runCatching { record?.release() }; record = null
        writeFd?.let { runCatching { it.close() } }; writeFd = null
        pump = null
        tts?.shutdown(); tts = null; ttsReady = false
        RoxLog.i("Voice", "Voice translation stopped")
    }
}
