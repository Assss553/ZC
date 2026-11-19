package com.rox.tv

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.view.Gravity
import android.view.WindowManager
import android.widget.TextView

/** Mode B: subtitle window drawn above whatever the TV shows (e.g. its own HDMI input app). */
class OverlayService : Service() {
    private var view: TextView? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val nm = getSystemService(NotificationManager::class.java)
        nm.createNotificationChannel(NotificationChannel("rox_tv", "ROX TV", NotificationManager.IMPORTANCE_LOW))
        val n = Notification.Builder(this, "rox_tv").setContentTitle("ROX TV").setContentText("Subtitles over HDMI").setSmallIcon(android.R.drawable.ic_menu_view).build()
        if (Build.VERSION.SDK_INT >= 34) startForeground(1, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE) else startForeground(1, n)
        if (view == null) {
            val wm = getSystemService(WindowManager::class.java)
            val tv = Ui.subtitleView(this)
            val lp = WindowManager.LayoutParams(
                WindowManager.LayoutParams.WRAP_CONTENT, WindowManager.LayoutParams.WRAP_CONTENT,
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE,
                PixelFormat.TRANSLUCENT,
            ).apply { gravity = Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL; y = 60 }
            try { wm.addView(tv, lp); view = tv; Bus.overlayOk = true } catch (t: Throwable) { Bus.overlayOk = false; Bus.overlayError = t.message ?: t.javaClass.simpleName }
            Bus.listeners += { text -> view?.post { Ui.applyText(view!!, text) } }
        }
        return START_STICKY
    }

    override fun onDestroy() {
        view?.let { runCatching { getSystemService(WindowManager::class.java).removeView(it) } }
        view = null
        super.onDestroy()
    }
}

/** Tiny in-process bus between the server (activity) and the overlay service. */
object Bus {
    val listeners = mutableListOf<(String) -> Unit>()
    @Volatile var overlayOk: Boolean? = null
    @Volatile var overlayError: String = ""
    fun publish(text: String) = listeners.forEach { it(text) }
}
