package com.rox.gameai.ai

import android.graphics.Bitmap
import com.google.mlkit.nl.languageid.LanguageIdentification
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.TextRecognizer
import com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions
import com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions
import com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import com.rox.gameai.core.IRect
import kotlinx.coroutines.tasks.await

enum class Script { LATIN, JAPANESE, CHINESE, KOREAN }

data class OcrBlock(val text: String, val rect: IRect, val confidence: Float = 1f)

/** On-device OCR (ML Kit bundled models — offline, GPU/NPU acceleration handled by ML Kit). */
class OcrEngine {
    private val clients = HashMap<Script, TextRecognizer>()
    private val langId = LanguageIdentification.getClient()

    private fun client(s: Script): TextRecognizer = clients.getOrPut(s) {
        when (s) {
            Script.LATIN -> TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
            Script.JAPANESE -> TextRecognition.getClient(JapaneseTextRecognizerOptions.Builder().build())
            Script.CHINESE -> TextRecognition.getClient(ChineseTextRecognizerOptions.Builder().build())
            Script.KOREAN -> TextRecognition.getClient(KoreanTextRecognizerOptions.Builder().build())
        }
    }

    /** @param scaleBack factor to map OCR coordinates back to full-frame coordinates */
    suspend fun recognize(bitmap: Bitmap, script: Script, scaleBack: Float = 1f): List<OcrBlock> {
        val result = client(script).process(InputImage.fromBitmap(bitmap, 0)).await()
        return result.textBlocks.mapNotNull { b ->
            val r = b.boundingBox ?: return@mapNotNull null
            val text = b.lines.joinToString(" ") { it.text }.trim()
            if (text.length < 2) null else OcrBlock(text, IRect(r.left, r.top, r.right, r.bottom).scale(scaleBack, scaleBack))
        }
    }

    /** Returns a BCP-47 code ("en", "ja", …) or "und". */
    suspend fun identifyLanguage(text: String): String =
        if (text.isBlank()) "und" else runCatching { langId.identifyLanguage(text).await() }.getOrDefault("und")

    fun close() { clients.values.forEach { it.close() }; clients.clear(); langId.close() }

    companion object {
        fun scriptFor(lang: String): Script = when (lang.substringBefore('-').lowercase()) {
            "ja" -> Script.JAPANESE
            "zh" -> Script.CHINESE
            "ko" -> Script.KOREAN
            else -> Script.LATIN
        }
    }
}
