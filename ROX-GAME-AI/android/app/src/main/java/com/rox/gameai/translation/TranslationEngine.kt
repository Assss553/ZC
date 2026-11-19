package com.rox.gameai.translation

import com.google.mlkit.common.model.DownloadConditions
import com.google.mlkit.nl.translate.TranslateLanguage
import com.google.mlkit.nl.translate.Translation
import com.google.mlkit.nl.translate.Translator
import com.google.mlkit.nl.translate.TranslatorOptions
import com.rox.gameai.core.RoxLog
import com.rox.gameai.core.SettingsRepo
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

/**
 * Replaceable translation engine. Default: ML Kit on-device translation (models ~30 MB per language,
 * downloaded once, then offline). Optional cloud engine: the user's OWN backend endpoint (no API key
 * is stored in the app — the backend holds the key).
 */
class TranslationEngine(private val settings: SettingsRepo) {
    val cache = TranslationCache()
    private val translators = HashMap<String, Translator>()
    private val mutex = Mutex()
    private val _modelStatus = MutableStateFlow<Map<String, String>>(emptyMap())
    val modelStatus: StateFlow<Map<String, String>> = _modelStatus

    companion object {
        val supportedSources = listOf("en", "ja", "zh", "ko", "fr", "de", "es", "it", "pt", "ru", "tr")
    }

    fun isSupported(lang: String) = TranslateLanguage.fromLanguageTag(lang.substringBefore('-')) != null

    private suspend fun translator(src: String, dst: String): Translator? = mutex.withLock {
        val s = TranslateLanguage.fromLanguageTag(src.substringBefore('-')) ?: return@withLock null
        val d = TranslateLanguage.fromLanguageTag(dst.substringBefore('-')) ?: return@withLock null
        val key = "$s>$d"
        translators[key]?.let { return@withLock it }
        val t = Translation.getClient(TranslatorOptions.Builder().setSourceLanguage(s).setTargetLanguage(d).build())
        _modelStatus.value = _modelStatus.value + (key to "downloading")
        try {
            t.downloadModelIfNeeded(DownloadConditions.Builder().build()).await()
            _modelStatus.value = _modelStatus.value + (key to "ready")
            RoxLog.i("Translate", "Model ready $key")
            translators[key] = t
            t
        } catch (e: Throwable) {
            _modelStatus.value = _modelStatus.value + (key to "error")
            RoxLog.e("Translate", "Model download failed $key", e)
            t.close(); null
        }
    }

    /** Translates [text] from [src] into the configured target language. Returns null if impossible. */
    suspend fun translate(text: String, src: String): String? {
        val dst = settings.value.targetLanguage
        if (src.substringBefore('-') == dst) return text
        cache.get(text)?.let { return it }
        val s = settings.value
        val result = if (s.cloudEnabled && s.cloudEndpoint.isNotBlank() && !s.localProcessing) {
            cloud(text, src, dst) ?: translator(src, dst)?.let { runCatching { it.translate(text).await() }.getOrNull() }
        } else {
            translator(src, dst)?.let { runCatching { it.translate(text).await() }.onFailure { e -> RoxLog.e("Translate", "translate failed", e) }.getOrNull() }
                ?: if (s.cloudEnabled && s.cloudEndpoint.isNotBlank()) cloud(text, src, dst) else null
        }
        if (result != null) cache.put(text, result)
        return result
    }

    suspend fun prepare(src: String) { translator(src, settings.value.targetLanguage) }

    private suspend fun cloud(text: String, src: String, dst: String): String? = withContext(Dispatchers.IO) {
        try {
            val c = URL(settings.value.cloudEndpoint).openConnection() as HttpURLConnection
            c.requestMethod = "POST"; c.connectTimeout = 4000; c.readTimeout = 6000; c.doOutput = true
            c.setRequestProperty("Content-Type", "application/json")
            c.outputStream.use { it.write(JSONObject().put("text", text).put("source", src).put("target", dst).toString().toByteArray()) }
            if (c.responseCode !in 200..299) { RoxLog.w("Translate", "Cloud HTTP ${c.responseCode}"); return@withContext null }
            JSONObject(c.inputStream.bufferedReader().readText()).optString("translation").takeIf { it.isNotBlank() }
        } catch (t: Throwable) { RoxLog.e("Translate", "Cloud translation failed", t); null }
    }

    fun close() { translators.values.forEach { it.close() }; translators.clear() }
}
