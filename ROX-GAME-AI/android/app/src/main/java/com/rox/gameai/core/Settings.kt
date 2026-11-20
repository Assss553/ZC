package com.rox.gameai.core

import android.content.Context
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

class SettingsRepo(context: Context) {
    private val p = context.getSharedPreferences("rox_settings", Context.MODE_PRIVATE)
    init {
        // v2 migration: voice translation must be opt-in (older builds had it on, which kept the mic chime looping)
        if (p.getInt("settingsVersion", 1) < 2) { p.edit().putBoolean("voiceEnabled", false).putInt("settingsVersion", 2).apply() }
    }
    private val _state = MutableStateFlow(load())
    val state: StateFlow<AiSettings> = _state
    val value: AiSettings get() = _state.value

    fun update(block: (AiSettings) -> AiSettings) {
        val n = block(_state.value)
        _state.value = n
        save(n)
    }

    private inline fun <reified T : Enum<T>> enumOf(name: String?, def: T): T =
        runCatching { enumValueOf<T>(name ?: def.name) }.getOrDefault(def)

    private fun load(): AiSettings {
        val d = AiSettings()
        return AiSettings(
            uiLanguage = p.getString("uiLanguage", d.uiLanguage)!!,
            targetLanguage = p.getString("targetLanguage", d.targetLanguage)!!,
            ocrIntervalMs = p.getInt("ocrIntervalMs", d.ocrIntervalMs),
            ocrScale = p.getFloat("ocrScale", d.ocrScale),
            analysisWidth = p.getInt("analysisWidth", d.analysisWidth),
            sensitivity = p.getFloat("sensitivity", d.sensitivity),
            blurStrength = p.getInt("blurStrength", d.blurStrength),
            maskPadding = p.getFloat("maskPadding", d.maskPadding),
            blurMode = enumOf(p.getString("blurMode", null), d.blurMode),
            categories = p.getStringSet("categories", d.categories)!!.toSet(),
            customRegions = (p.getString("customRegions", "") ?: "").split(";").mapNotNull { NRect.decode(it) },
            safeVisionEnabled = p.getBoolean("safeVisionEnabled", d.safeVisionEnabled),
            translationEnabled = p.getBoolean("translationEnabled", d.translationEnabled),
            voiceEnabled = p.getBoolean("voiceEnabled", d.voiceEnabled),
            voiceLanguage = p.getString("voiceLanguage", d.voiceLanguage)!!,
            audioSampleRate = p.getInt("audioSampleRate", d.audioSampleRate),
            ttsDubbing = p.getBoolean("ttsDubbing", d.ttsDubbing),
            localProcessing = p.getBoolean("localProcessing", d.localProcessing),
            cloudEnabled = p.getBoolean("cloudEnabled", d.cloudEnabled),
            cloudEndpoint = p.getString("cloudEndpoint", d.cloudEndpoint)!!,
            displayMode = enumOf(p.getString("displayMode", null), d.displayMode),
            videoSource = enumOf(p.getString("videoSource", null), d.videoSource),
            audioSource = enumOf(p.getString("audioSource", null), d.audioSource),
            autoReconnect = p.getBoolean("autoReconnect", d.autoReconnect),
            discoveryIntervalSec = p.getInt("discoveryIntervalSec", d.discoveryIntervalSec),
            streamTimeoutSec = p.getInt("streamTimeoutSec", d.streamTimeoutSec),
        )
    }

    private fun save(s: AiSettings) {
        p.edit()
            .putString("uiLanguage", s.uiLanguage).putString("targetLanguage", s.targetLanguage)
            .putInt("ocrIntervalMs", s.ocrIntervalMs).putFloat("ocrScale", s.ocrScale)
            .putInt("analysisWidth", s.analysisWidth).putFloat("sensitivity", s.sensitivity)
            .putInt("blurStrength", s.blurStrength).putFloat("maskPadding", s.maskPadding)
            .putString("blurMode", s.blurMode.name).putStringSet("categories", s.categories)
            .putString("customRegions", s.customRegions.joinToString(";") { it.encode() })
            .putBoolean("safeVisionEnabled", s.safeVisionEnabled).putBoolean("translationEnabled", s.translationEnabled)
            .putBoolean("voiceEnabled", s.voiceEnabled).putString("voiceLanguage", s.voiceLanguage)
            .putInt("audioSampleRate", s.audioSampleRate).putBoolean("ttsDubbing", s.ttsDubbing)
            .putBoolean("localProcessing", s.localProcessing).putBoolean("cloudEnabled", s.cloudEnabled)
            .putString("cloudEndpoint", s.cloudEndpoint).putString("displayMode", s.displayMode.name)
            .putString("videoSource", s.videoSource.name).putString("audioSource", s.audioSource.name)
            .putBoolean("autoReconnect", s.autoReconnect).putInt("discoveryIntervalSec", s.discoveryIntervalSec)
            .putInt("streamTimeoutSec", s.streamTimeoutSec)
            .apply()
    }
}
