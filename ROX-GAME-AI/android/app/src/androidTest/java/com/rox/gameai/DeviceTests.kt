package com.rox.gameai

import android.graphics.Bitmap
import android.speech.SpeechRecognizer
import android.util.Log
import androidx.test.core.app.ActivityScenario
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.rox.gameai.ai.OcrEngine
import com.rox.gameai.ai.Script
import com.rox.gameai.core.BlurMode
import com.rox.gameai.core.Categories
import com.rox.gameai.core.VideoSourceKind
import com.rox.gameai.pipeline.AutoStep
import com.rox.gameai.vision.TestPatternSource
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeout
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Runs on a real Android runtime (emulator in GitHub Actions). Uses the built-in TEST VIDEO source —
 * these results are NOT a test of a real PS4/PS5 stream.
 */
@RunWith(AndroidJUnit4::class)
class DeviceTests {
    private val app get() = InstrumentationRegistry.getInstrumentation().targetContext.applicationContext as RoxApp
    private fun report(msg: String) = Log.i("ROX_TEST_REPORT", msg)

    @Test fun appLaunches() {
        ActivityScenario.launch(MainActivity::class.java).use { s ->
            Thread.sleep(2500)
            s.onActivity { assertTrue(!it.isFinishing) }
        }
        report("appLaunches OK")
    }

    @Test fun ocrReadsTestVideoFrame() = runBlocking {
        val frame = TestPatternSource().render(0).copy(Bitmap.Config.ARGB_8888, false)
        val t0 = System.currentTimeMillis()
        val blocks = OcrEngine().recognize(frame, Script.LATIN)
        val text = blocks.joinToString(" | ") { it.text }
        report("OCR ${System.currentTimeMillis() - t0} ms: $text")
        assertTrue("mission text not found: $text", text.contains("lighthouse", true))
        assertTrue("dialogue text not found: $text", text.contains("ancient key", true))
        assertTrue(blocks.all { it.rect.width > 0 && it.rect.height > 0 })
    }

    @Test fun languageIdentification() = runBlocking {
        val lang = OcrEngine().identifyLanguage("We must find the ancient key before nightfall")
        report("language id = $lang")
        assertEquals("en", lang)
    }

    @Test fun translatesEnglishToArabic() = runBlocking {
        val e = app.engine
        val out = withTimeout(240_000) { e.translator.translate("Follow me and stay quiet.", "en") }
        report("translation: $out")
        assertNotNull("translation model could not be downloaded/used", out)
        assertTrue("output is not Arabic: $out", out!!.any { it in '؀'..'ۿ' })
        // second call must come from cache (no duplicate translation)
        assertEquals(out, e.translator.cache.get("follow me and stay quiet."))
    }

    @Test fun autoStartPipelineOnTestVideo() = runBlocking {
        val e = app.engine
        app.settings.update { it.copy(videoSource = VideoSourceKind.TEST_PATTERN, blurMode = BlurMode.BLACK, categories = Categories.all.toSet(), voiceEnabled = false, ocrIntervalMs = 500) }
        e.autoStartTest()
        val deadline = System.currentTimeMillis() + 240_000
        while (System.currentTimeMillis() < deadline && e.overlays.value.none { it.translated.any { c -> c in '؀'..'ۿ' } }) Thread.sleep(500)
        val st = e.status.value
        val frame = e.frame.value
        val regions = e.regions.value
        val perf = e.perf.stats.value
        report("pipeline step=${st.step} lang=${st.gameLanguage} video=${st.videoActive} frames=${frame?.seq} regions=${regions.size} overlays=${e.overlays.value.map { it.kind.name + ':' + it.translated }} perf=$perf")
        assertEquals(AutoStep.RUNNING, st.step)
        assertTrue(st.isTestSource)
        assertNotNull(frame)
        assertEquals("en", st.gameLanguage)
        if (e.modelInstalled) {
            // Trained detector: the test video contains no nudity, so nothing may be blurred (no false positive)
            assertTrue("false positive on a clean test scene: $regions", regions.isEmpty())
        } else {
            assertTrue("Safe Vision did not track the moving test object", regions.isNotEmpty())
            val r = regions.first().rect
            val px = frame!!.bitmap.getPixel(r.centerX.coerceIn(0, frame.bitmap.width - 1), r.centerY.coerceIn(0, frame.bitmap.height - 1))
            assertEquals("displayed frame not masked", 0xFF000000.toInt(), px)
        }
        assertTrue("no Arabic translation overlay produced", e.overlays.value.any { it.translated.any { c -> c in '؀'..'ۿ' } })
        assertTrue(app.store.history.value.isNotEmpty())
        e.stop()
        assertEquals(AutoStep.IDLE, e.status.value.step)
    }

    @Test fun trainedNudityDetectorRunsOnDevice() {
        val ctx = InstrumentationRegistry.getInstrumentation().targetContext
        val d = com.rox.gameai.vision.NudeNetDetector.load(ctx)
        assertNotNull("trained detector failed to load on device", d)
        val bmp = TestPatternSource().render(0)
        val px = IntArray(bmp.width * bmp.height)
        bmp.getPixels(px, 0, bmp.width, 0, 0, bmp.width, bmp.height)
        d!!.detect(px, bmp.width, bmp.height, 0.5f) // warm-up
        val t0 = System.currentTimeMillis()
        val dets = d.detect(px, bmp.width, bmp.height, 0.5f)
        report("NudeNet on device: ${System.currentTimeMillis() - t0} ms, detections on clean frame = ${dets.size}")
        assertTrue("false positive on clean frame: $dets", dets.isEmpty())
    }

    @Test fun speechRecognitionAvailability() {
        val ctx = InstrumentationRegistry.getInstrumentation().targetContext
        // Emulators usually have no recognition service: we REPORT it instead of claiming success.
        report("speech recognition available = ${SpeechRecognizer.isRecognitionAvailable(ctx)}")
    }
}
