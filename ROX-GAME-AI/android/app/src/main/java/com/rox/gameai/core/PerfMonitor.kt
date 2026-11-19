package com.rox.gameai.core

import android.content.Context
import android.os.Debug
import android.os.PowerManager
import android.os.Process
import android.os.SystemClock
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

data class PerfStats(
    val javaHeapMb: Int = 0,
    val nativeHeapMb: Int = 0,
    val cpuPercent: Int = 0,
    val fps: Float = 0f,
    val processingMs: Long = 0,
    val ocrMs: Long = 0,
    val thermalStatus: Int = 0,
    val throttled: Boolean = false,
)

/** Real measurements of this process: heap, CPU time share, frame rate, processing latency, thermal state. */
class PerfMonitor(context: Context, scope: CoroutineScope) {
    private val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
    private val _stats = MutableStateFlow(PerfStats())
    val stats: StateFlow<PerfStats> = _stats

    @Volatile private var frames = 0
    @Volatile var lastProcessingMs = 0L
    @Volatile var lastOcrMs = 0L

    fun onFrame(processingMs: Long) { frames++; lastProcessingMs = processingMs }

    init {
        scope.launch {
            var lastCpu = Process.getElapsedCpuTime()
            var lastWall = SystemClock.elapsedRealtime()
            var lastFrames = 0
            val cores = Runtime.getRuntime().availableProcessors().coerceAtLeast(1)
            while (isActive) {
                delay(1000)
                val cpu = Process.getElapsedCpuTime(); val wall = SystemClock.elapsedRealtime()
                val dWall = (wall - lastWall).coerceAtLeast(1)
                val cpuPct = ((cpu - lastCpu) * 100 / (dWall * cores)).toInt().coerceIn(0, 100)
                val f = frames; val fps = (f - lastFrames) * 1000f / dWall
                lastCpu = cpu; lastWall = wall; lastFrames = f
                val rt = Runtime.getRuntime()
                val thermal = pm.currentThermalStatus
                _stats.value = PerfStats(
                    javaHeapMb = ((rt.totalMemory() - rt.freeMemory()) / 1_048_576).toInt(),
                    nativeHeapMb = (Debug.getNativeHeapAllocatedSize() / 1_048_576).toInt(),
                    cpuPercent = cpuPct, fps = fps, processingMs = lastProcessingMs, ocrMs = lastOcrMs,
                    thermalStatus = thermal, throttled = thermal >= PowerManager.THERMAL_STATUS_SEVERE,
                )
            }
        }
    }
}
