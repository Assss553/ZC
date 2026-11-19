package com.rox.gameai

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.media.projection.MediaProjectionManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.ContextCompat
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import com.rox.gameai.core.DisplayMode
import com.rox.gameai.core.RoxLog
import com.rox.gameai.core.VideoSourceKind
import com.rox.gameai.pipeline.CaptureService
import com.rox.gameai.ui.RoxActions
import com.rox.gameai.ui.RoxRoot

class MainActivity : ComponentActivity() {
    private val app get() = application as RoxApp
    private var pendingAfterPermissions: (() -> Unit)? = null

    private val permissions = registerForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) { res ->
        res.filterValues { !it }.keys.forEach { RoxLog.w("Permissions", "Denied: $it") }
        pendingAfterPermissions?.invoke(); pendingAfterPermissions = null
    }

    private val projectionLauncher = registerForActivityResult(ActivityResultContracts.StartActivityForResult()) { r ->
        if (r.resultCode == Activity.RESULT_OK && r.data != null) {
            val i = Intent(this, CaptureService::class.java).putExtra(CaptureService.EXTRA_CODE, r.resultCode).putExtra(CaptureService.EXTRA_DATA, r.data)
            ContextCompat.startForegroundService(this, i)
            // Over PS Remote Play, subtitles and masks are drawn in a floating window: always needs this permission
            if (app.settings.value.displayMode != DisplayMode.LOG_ONLY && !app.overlay.canShow()) {
                RoxLog.w("AutoStart", "Overlay permission missing — asking for it (needed to show translation/blur over the game)")
                requestOverlay()
            }
            if (app.engine.connection.isRemotePlayInstalled()) app.engine.connection.launchRemotePlay()
            else RoxLog.w("AutoStart", "PS Remote Play is not installed — capturing whatever is on screen")
        } else RoxLog.w("AutoStart", "Screen capture permission was not granted")
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        installSplashScreen()
        super.onCreate(savedInstanceState)
        val dm = resources.displayMetrics
        val w = maxOf(dm.widthPixels, dm.heightPixels); val h = minOf(dm.widthPixels, dm.heightPixels) // landscape game stream
        app.engine.setScreenSize(w, h, resources.displayMetrics.densityDpi)
        val actions = object : RoxActions {
            override fun autoStart() = this@MainActivity.autoStart()
            override fun startTest() { app.engine.autoStartTest() }
            override fun stop() { app.engine.stop(); stopService(Intent(this@MainActivity, CaptureService::class.java)) }
            override fun requestOverlay() = this@MainActivity.requestOverlay()
            override fun share(text: String) {
                startActivity(Intent.createChooser(Intent(Intent.ACTION_SEND).setType("text/plain").putExtra(Intent.EXTRA_TEXT, text), "ROX"))
            }
            override fun requestMic() = ensurePermissions(listOf(Manifest.permission.RECORD_AUDIO)) { app.engine.restartVoice() }
        }
        setContent { RoxRoot(app, actions) }
        ensurePermissions(buildList { if (Build.VERSION.SDK_INT >= 33) add(Manifest.permission.POST_NOTIFICATIONS) }) {}
    }

    private fun ensurePermissions(list: List<String>, then: () -> Unit) {
        val missing = list.filter { ContextCompat.checkSelfPermission(this, it) != PackageManager.PERMISSION_GRANTED }
        if (missing.isEmpty()) { then(); return }
        pendingAfterPermissions = then
        permissions.launch(missing.toTypedArray())
    }

    private fun requestOverlay() {
        runCatching { startActivity(Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:$packageName"))) }
    }

    private fun autoStart() {
        val s = app.settings.value
        val audio = if (s.voiceEnabled) listOf(Manifest.permission.RECORD_AUDIO) else emptyList()
        when (app.engine.resolveSource()) {
            VideoSourceKind.TEST_PATTERN -> app.engine.autoStartTest()
            VideoSourceKind.CAPTURE_CARD -> ensurePermissions(listOf(Manifest.permission.CAMERA) + audio) {
                if (app.engine.hasCaptureCard()) app.engine.autoStartCaptureCard()
                else RoxLog.e("AutoStart", "No HDMI capture card detected (external USB camera)")
            }
            else -> ensurePermissions(audio) {
                val mpm = getSystemService(MediaProjectionManager::class.java)
                projectionLauncher.launch(mpm.createScreenCaptureIntent())
            }
        }
    }
}
