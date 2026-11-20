package com.rox.gameai.core

/** All user-tunable AI settings (pure data, JVM-testable). */
data class AiSettings(
    val uiLanguage: String = "ar",
    val targetLanguage: String = "ar",
    // Translation speed: how often OCR runs on the stream
    val ocrIntervalMs: Int = 800,
    // OCR accuracy: resolution used for OCR (fraction of source width, max 1.0)
    val ocrScale: Float = 0.75f,
    // Video analysis quality: max width used for content detection
    val analysisWidth: Int = 320,
    val sensitivity: Float = 0.5f,
    val blurStrength: Int = 18,
    val maskPadding: Float = 0.15f,
    val blurMode: BlurMode = BlurMode.GAUSSIAN,
    val categories: Set<String> = Categories.all.toSet(),
    val customRegions: List<NRect> = emptyList(),
    val safeVisionEnabled: Boolean = true,
    val translationEnabled: Boolean = true,
    val voiceEnabled: Boolean = false,
    val voiceLanguage: String = "en-US",
    val audioSampleRate: Int = 16000,
    val ttsDubbing: Boolean = false,
    val localProcessing: Boolean = true,
    val cloudEnabled: Boolean = false,
    val cloudEndpoint: String = "",
    val displayMode: DisplayMode = DisplayMode.ON_VIDEO,
    val videoSource: VideoSourceKind = VideoSourceKind.AUTO,
    val audioSource: AudioSourceKind = AudioSourceKind.STREAM_PLAYBACK,
    val autoReconnect: Boolean = true,
    val discoveryIntervalSec: Int = 8,
    val streamTimeoutSec: Int = 5,
)
