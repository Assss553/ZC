package com.rox.gameai.pipeline

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.projection.MediaProjectionManager
import android.os.IBinder
import com.rox.gameai.MainActivity
import com.rox.gameai.R
import com.rox.gameai.RoxApp
import com.rox.gameai.core.RoxLog

/** Foreground service required by Android for MediaProjection (screen capture of PS Remote Play). */
class CaptureService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) { (application as RoxApp).engine.stop(); stopSelf(); return START_NOT_STICKY }
        val nm = getSystemService(NotificationManager::class.java)
        nm.createNotificationChannel(NotificationChannel(CHANNEL, getString(R.string.capture_channel), NotificationManager.IMPORTANCE_LOW))
        val open = PendingIntent.getActivity(this, 0, Intent(this, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE)
        val stop = PendingIntent.getService(this, 1, Intent(this, CaptureService::class.java).setAction(ACTION_STOP), PendingIntent.FLAG_IMMUTABLE)
        val n = Notification.Builder(this, CHANNEL)
            .setContentTitle(getString(R.string.app_name)).setContentText(getString(R.string.capture_running))
            .setSmallIcon(R.drawable.ic_launcher_foreground).setContentIntent(open).setOngoing(true)
            .addAction(Notification.Action.Builder(null, "STOP", stop).build())
            .build()
        startForeground(1, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION)
        val code = intent?.getIntExtra(EXTRA_CODE, 0) ?: 0
        @Suppress("DEPRECATION")
        val data: Intent? = intent?.getParcelableExtra(EXTRA_DATA)
        if (data != null) {
            try {
                val mpm = getSystemService(MediaProjectionManager::class.java)
                val projection = mpm.getMediaProjection(code, data)
                if (projection != null) (application as RoxApp).engine.onProjectionReady(projection)
                else RoxLog.e("Capture", "MediaProjection refused")
            } catch (t: Throwable) { RoxLog.e("Capture", "Cannot start screen capture", t) }
        }
        return START_NOT_STICKY
    }

    override fun onDestroy() { super.onDestroy(); RoxLog.i("Capture", "Capture service stopped") }

    companion object {
        const val CHANNEL = "rox_capture"
        const val EXTRA_CODE = "code"
        const val EXTRA_DATA = "data"
        const val ACTION_STOP = "com.rox.gameai.STOP"
    }
}
