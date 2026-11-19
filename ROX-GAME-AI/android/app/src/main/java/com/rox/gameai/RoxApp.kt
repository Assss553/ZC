package com.rox.gameai

import android.app.Application
import com.rox.gameai.connection.ConnectionManager
import com.rox.gameai.core.DisplayMode
import com.rox.gameai.core.PerfMonitor
import com.rox.gameai.core.RoxLog
import com.rox.gameai.core.SettingsRepo
import com.rox.gameai.core.Store
import com.rox.gameai.pipeline.OverlayWindow
import com.rox.gameai.pipeline.RoxEngine
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.launch

class RoxApp : Application() {
    val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    lateinit var settings: SettingsRepo; private set
    lateinit var store: Store; private set
    lateinit var engine: RoxEngine; private set
    lateinit var overlay: OverlayWindow; private set
    lateinit var server: com.rox.gameai.connection.RoxServerClient; private set
    lateinit var tv: com.rox.gameai.connection.TvLink; private set

    override fun onCreate() {
        super.onCreate()
        RoxLog.init(this)
        Thread.setDefaultUncaughtExceptionHandler(Thread.getDefaultUncaughtExceptionHandler().let { prev ->
            Thread.UncaughtExceptionHandler { t, e -> RoxLog.e("Crash", "Uncaught on ${t.name}", e); prev?.uncaughtException(t, e) }
        })
        settings = SettingsRepo(this)
        store = Store(this)
        val perf = PerfMonitor(this, scope)
        val conn = ConnectionManager(this, store, settings, scope)
        engine = RoxEngine(this, settings, store, conn, perf, scope)
        overlay = OverlayWindow(this)
        server = com.rox.gameai.connection.RoxServerClient(store, scope)
        tv = com.rox.gameai.connection.TvLink(this, scope)
        scope.launch { engine.overlays.collect { tv.onOverlays(it) } }
        scope.launch { server.subtitles.collect { tv.onOverlays(it) } }
        RoxLog.i("App", "ROX GAME AI ${BuildConfig.VERSION_NAME} started (Android ${android.os.Build.VERSION.RELEASE}, ${android.os.Build.MODEL})")
        // Floating translation window above PS Remote Play
        scope.launch(Dispatchers.Main) {
            combine(engine.status, engine.overlays, engine.regions, settings.state) { st, o, r, s -> listOf(st, o, r, s) }.collect { l ->
                val st = l[0] as com.rox.gameai.pipeline.PipelineStatus
                val s = l[3] as com.rox.gameai.core.AiSettings
                @Suppress("UNCHECKED_CAST")
                val o = l[1] as List<com.rox.gameai.core.TextOverlay>
                @Suppress("UNCHECKED_CAST")
                val r = l[2] as List<com.rox.gameai.vision.RegionTracker.Track>
                val want = st.running && !st.inAppDisplay && s.displayMode != DisplayMode.LOG_ONLY
                if (want) { overlay.show(); overlay.update(o, r, st.frameW, st.frameH) } else overlay.hide()
            }
        }
    }
}
