package com.rox.gameai.vision

import android.content.Context
import com.rox.gameai.core.RoxLog
import org.tensorflow.lite.Interpreter
import java.io.FileInputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.channels.FileChannel

/**
 * Optional trained classifier for NUDITY / SEXUAL categories. ROX does not ship a model (licensing);
 * place a 224x224 RGB float image classifier at assets/safevision/model.tflite with labels in
 * assets/safevision/labels.txt (e.g. drawings, hentai, neutral, porn, sexy). If absent, these two
 * categories report "model not installed" and only the heuristic + custom regions are active.
 */
class TfliteContentClassifier private constructor(private val interpreter: Interpreter, private val labels: List<String>) {
    private val input = ByteBuffer.allocateDirect(224 * 224 * 3 * 4).order(ByteOrder.nativeOrder())
    private val output = Array(1) { FloatArray(labels.size) }

    data class Scores(val nudity: Float, val sexual: Float)

    fun classify(px: IntArray, w: Int, h: Int): Scores {
        input.rewind()
        for (y in 0 until 224) for (x in 0 until 224) {
            val c = px[(y * h / 224) * w + (x * w / 224)]
            input.putFloat(((c shr 16) and 0xFF) / 255f); input.putFloat(((c shr 8) and 0xFF) / 255f); input.putFloat((c and 0xFF) / 255f)
        }
        interpreter.run(input, output)
        fun s(vararg names: String) = labels.withIndex().filter { (_, l) -> names.any { l.contains(it, true) } }.maxOfOrNull { output[0][it.index] } ?: 0f
        return Scores(nudity = s("porn", "hentai", "nude", "nudity"), sexual = s("sexy", "sexual", "suggestive"))
    }

    fun close() = interpreter.close()

    companion object {
        fun load(context: Context): TfliteContentClassifier? = try {
            val fd = context.assets.openFd("safevision/model.tflite")
            val buf = FileInputStream(fd.fileDescriptor).channel.map(FileChannel.MapMode.READ_ONLY, fd.startOffset, fd.declaredLength)
            val labels = context.assets.open("safevision/labels.txt").bufferedReader().readLines().filter { it.isNotBlank() }
            val opts = Interpreter.Options().setNumThreads(2).setUseNNAPI(true)
            TfliteContentClassifier(Interpreter(buf, opts), labels).also { RoxLog.i("SafeVision", "Content model loaded (${labels.size} labels, NNAPI)") }
        } catch (_: java.io.FileNotFoundException) {
            null
        } catch (t: Throwable) {
            RoxLog.e("SafeVision", "Failed to load content model", t); null
        }
    }
}
