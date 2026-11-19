package com.rox.gameai.vision

import ai.onnxruntime.OnnxTensor
import ai.onnxruntime.OrtEnvironment
import ai.onnxruntime.OrtSession
import android.content.Context
import com.rox.gameai.core.Detection
import com.rox.gameai.core.RoxLog
import java.nio.FloatBuffer

/** Trained exposed-body-part detector running on-device with ONNX Runtime (NNAPI when available). */
class NudeNetDetector private constructor(private val env: OrtEnvironment, private val session: OrtSession) {
    private val inputName = session.inputNames.first()

    @Synchronized
    fun detect(px: IntArray, w: Int, h: Int, sensitivity: Float): List<Detection> {
        val (tensor, side) = NudeNet.preprocess(px, w, h)
        OnnxTensor.createTensor(env, FloatBuffer.wrap(tensor), longArrayOf(1, 3, NudeNet.SIZE.toLong(), NudeNet.SIZE.toLong())).use { input ->
            session.run(mapOf(inputName to input)).use { res ->
                @Suppress("UNCHECKED_CAST")
                val out = (res[0].value as Array<Array<FloatArray>>)[0]
                val n = out[0].size
                val flat = FloatArray(out.size * n)
                for (r in out.indices) System.arraycopy(out[r], 0, flat, r * n, n)
                return NudeNet.toDetections(NudeNet.postprocess(flat, n, w, h, side), sensitivity)
            }
        }
    }

    companion object {
        fun load(context: Context): NudeNetDetector? = try {
            val bytes = context.assets.open("safevision/nudenet_320n.onnx").use { it.readBytes() }
            val env = OrtEnvironment.getEnvironment()
            val opts = OrtSession.SessionOptions().apply {
                setIntraOpNumThreads(2)
                runCatching { addNnapi() }.onFailure { RoxLog.w("SafeVision", "NNAPI not available, using CPU") }
            }
            NudeNetDetector(env, env.createSession(bytes, opts)).also { RoxLog.i("SafeVision", "Trained nudity detector loaded (on-device)") }
        } catch (t: Throwable) {
            RoxLog.e("SafeVision", "Trained detector failed to load — falling back to colour heuristic", t); null
        }
    }
}
