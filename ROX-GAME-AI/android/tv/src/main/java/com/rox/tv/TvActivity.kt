package com.rox.tv

import android.app.Activity
import android.content.Intent
import android.graphics.Color
import android.media.tv.TvContract
import android.media.tv.TvInputInfo
import android.media.tv.TvInputManager
import android.media.tv.TvView
import android.net.Uri
import android.net.wifi.WifiManager
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Log
import android.view.Gravity
import android.view.KeyEvent
import android.view.View
import android.widget.FrameLayout
import android.widget.TextView
import java.net.Inet4Address
import java.net.NetworkInterface

/**
 * ROX TV — proof of concept for showing Arabic subtitles over the PlayStation picture on Android TV.
 *  Mode A: ROX TV shows the HDMI input itself (TvView passthrough) and draws subtitles on top.
 *  Mode B: a floating subtitle window above the TV's own HDMI app (needs "display over other apps").
 * Every result is measured on the real TV and shown on screen — nothing is assumed.
 */
class TvActivity : Activity() {
    private lateinit var tvView: TvView
    private lateinit var subtitle: TextView
    private lateinit var diag: TextView
    private lateinit var server: SubtitleServer
    private val main = Handler(Looper.getMainLooper())
    private var multicast: WifiManager.MulticastLock? = null

    private var hdmiInputs: List<TvInputInfo> = emptyList()
    private var inputIndex = 0
    private var modeA = "not tested"
    private var modeB = "not tested"
    private var phoneStatus = "starting…"
    private var enabled = true
    private var showDiag = true
    private var mode = "A"
    private var received = 0
    private lateinit var rootView: FrameLayout
    private var lastReceived = "—"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val root = FrameLayout(this).apply { setBackgroundColor(Color.BLACK) }
        tvView = TvView(this).apply { isFocusable = false; isFocusableInTouchMode = false; descendantFocusability = android.view.ViewGroup.FOCUS_BLOCK_DESCENDANTS }
        root.addView(tvView, FrameLayout.LayoutParams(-1, -1))
        subtitle = Ui.subtitleView(this)
        root.addView(subtitle, FrameLayout.LayoutParams(-2, -2, Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL).apply { bottomMargin = 60 })
        diag = TextView(this).apply {
            setTextColor(Color.WHITE); textSize = 15f; setPadding(28, 22, 28, 22)
            setBackgroundColor(Color.argb(205, 10, 10, 10))
        }
        root.addView(diag, FrameLayout.LayoutParams(-2, -2, Gravity.TOP or Gravity.START).apply { setMargins(30, 30, 30, 30) })
        subtitle.elevation = 50f; diag.elevation = 40f
        setContentView(root)
        rootView = root

        multicast = getSystemService(WifiManager::class.java)?.createMulticastLock("roxtv")?.apply { setReferenceCounted(false); acquire() }
        val code = getPreferences(MODE_PRIVATE).getString("code", null)?.let { TvProtocol.asciiDigits(it) } ?: TvProtocol.newCode().also { getPreferences(MODE_PRIVATE).edit().putString("code", it).apply() }
        server = SubtitleServer.get(this, code)
        server.mode = { mode }
        server.onChange = { text -> if (text.isNotBlank()) { received++; lastReceived = text.take(60); render() }; show(text) }
        server.isShown = { if (enabled) subtitleShown() else false }
        server.onStatus = { phoneStatus = it; render() }
        phoneStatus = server.lastStatus
        if (checkSelfPermission("android.permission.READ_TV_LISTINGS") != android.content.pm.PackageManager.PERMISSION_GRANTED)
            runCatching { requestPermissions(arrayOf("android.permission.READ_TV_LISTINGS"), 1) }
        findInputs()
        startModeA()
        render()
    }

    private fun findInputs() {
        hdmiInputs = try {
            val tim = getSystemService(TvInputManager::class.java)
            tim?.tvInputList.orEmpty().filter { it.isPassthroughInput }.sortedBy { if (it.type == TvInputInfo.TYPE_HDMI) 0 else 1 }
        } catch (t: Throwable) {
            Log.e("ROXTV", "tv input list failed", t); emptyList()
        }
        if (hdmiInputs.isEmpty()) modeA = "NOT AVAILABLE — this device exposes no HDMI/passthrough input to apps"
    }

    private fun startModeA() {
        val input = hdmiInputs.getOrNull(inputIndex) ?: return
        mode = "A"
        modeA = "tuning ${label(input)}…"
        tvView.setCallback(object : TvView.TvInputCallback() {
            override fun onVideoAvailable(inputId: String) { modeA = "WORKS ✓ — HDMI picture shown inside ROX TV (${label(input)})"; render() }
            override fun onVideoUnavailable(inputId: String, reason: Int) {
                modeA = "no picture yet (reason $reason: ${reasonText(reason)}) — is the PlayStation on and on ${label(input)}?"; render()
            }
            override fun onConnectionFailed(inputId: String) { modeA = "FAILED — the TV refused to give this input to apps"; render() }
            override fun onDisconnected(inputId: String) { modeA = "disconnected from ${label(input)}"; render() }
        })
        try {
            tvView.tune(input.id, TvContract.buildChannelUriForPassthroughInput(input.id))
        } catch (t: Throwable) {
            modeA = "FAILED — ${t.javaClass.simpleName}: ${t.message}"
        }
        main.postDelayed({ if (modeA.startsWith("tuning")) { modeA = "no response after 8 s — Mode A probably unsupported on this TV"; render() } }, 8000)
        render()
    }

    /** Mode B: floating subtitles + open the TV's own HDMI app. */
    private fun startModeB() {
        if (!Settings.canDrawOverlays(this)) {
            modeB = "needs permission 'Display over other apps'. If the TV has no such setting run once from a PC:\n   adb shell appops set com.rox.tv SYSTEM_ALERT_WINDOW allow"
            runCatching { startActivity(Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:$packageName"))) }
                .onFailure { modeB += "\n   (this TV has no overlay settings screen)" }
            render(); return
        }
        mode = "B"
        startForegroundService(Intent(this, OverlayService::class.java))
        main.postDelayed({
            modeB = when (Bus.overlayOk) {
                true -> "window created ✓ — now check: are subtitles visible on top of the HDMI picture?"
                false -> "FAILED to create window: ${Bus.overlayError}"
                null -> "starting…"
            }
            render()
            hdmiInputs.getOrNull(inputIndex)?.let { input ->
                runCatching { startActivity(Intent(Intent.ACTION_VIEW, TvContract.buildChannelUriForPassthroughInput(input.id))) }
                    .onFailure { modeB += "\n   could not open ${label(input)} automatically — switch input with the remote" }
            }
            Bus.publish("هذه ترجمة تجريبية من ROX — هل تظهر فوق صورة اللعبة؟")
        }, 1200)
    }

    private fun show(text: String) {
        val t = if (enabled) text else ""
        Ui.applyText(subtitle, t)
        subtitle.bringToFront(); rootView.requestLayout(); rootView.invalidate()
        Bus.publish(t)
    }

    /** Reported back to the phone so it can show whether the subtitle is really on screen. */
    fun subtitleShown(): Boolean = subtitle.isShown && subtitle.width > 0 && subtitle.height > 0

    private fun label(i: TvInputInfo) = runCatching { i.loadLabel(this).toString() }.getOrDefault(i.id)

    private fun reasonText(r: Int) = when (r) {
        TvInputManager.VIDEO_UNAVAILABLE_REASON_TUNING -> "tuning"
        TvInputManager.VIDEO_UNAVAILABLE_REASON_WEAK_SIGNAL -> "no signal"
        TvInputManager.VIDEO_UNAVAILABLE_REASON_BUFFERING -> "buffering"
        TvInputManager.VIDEO_UNAVAILABLE_REASON_AUDIO_ONLY -> "audio only"
        else -> "unknown"
    }

    private fun ip(): String = runCatching {
        NetworkInterface.getNetworkInterfaces().toList().flatMap { it.inetAddresses.toList() }
            .firstOrNull { !it.isLoopbackAddress && it is Inet4Address }?.hostAddress
    }.getOrNull() ?: "?"

    private fun render() {
        diag.visibility = if (showDiag) View.VISIBLE else View.GONE
        diag.text = buildString {
            append("ROX TV   •   ${ip()}:${TvProtocol.PORT}\n")
            append("PAIRING CODE:  ${server.code}\n")
            append("Phone: $phoneStatus\n")
            append("Subtitles: ${if (enabled) "ON" else "OFF (press OK)"}   received: $received   last: $lastReceived   key: $lastKey\n\n")
            append("HDMI inputs: ${if (hdmiInputs.isEmpty()) "none visible to apps" else hdmiInputs.joinToString { label(it) }}\n")
            append("Mode A (HDMI inside ROX): $modeA\n")
            append("Mode B (window over TV's HDMI app): $modeB\n\n")
            append("Remote:  OK = subtitles on/off   ▲▼ = size   ◀▶ = transparency\n")
            append("1 = Mode A   2 = Mode B   3 = next HDMI   0 = test subtitle   MENU/INFO = hide this panel")
        }
    }

    private val ourKeys = setOf(KeyEvent.KEYCODE_DPAD_CENTER, KeyEvent.KEYCODE_ENTER, KeyEvent.KEYCODE_DPAD_UP, KeyEvent.KEYCODE_DPAD_DOWN,
        KeyEvent.KEYCODE_DPAD_LEFT, KeyEvent.KEYCODE_DPAD_RIGHT, KeyEvent.KEYCODE_0, KeyEvent.KEYCODE_1, KeyEvent.KEYCODE_2, KeyEvent.KEYCODE_3,
        KeyEvent.KEYCODE_MENU, KeyEvent.KEYCODE_INFO, KeyEvent.KEYCODE_GUIDE, KeyEvent.KEYCODE_PROG_RED, KeyEvent.KEYCODE_PROG_GREEN)
    private var lastKey = "—"

    /** TvView forwards remote keys to the HDMI input; take ours first. */
    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (event.keyCode in ourKeys) {
            if (event.action == KeyEvent.ACTION_DOWN) { lastKey = KeyEvent.keyCodeToString(event.keyCode).removePrefix("KEYCODE_"); onKeyDown(event.keyCode, event); render() }
            return true
        }
        return super.dispatchKeyEvent(event)
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        when (keyCode) {
            KeyEvent.KEYCODE_DPAD_CENTER, KeyEvent.KEYCODE_ENTER -> { enabled = !enabled; Ui.applyText(subtitle, if (enabled) server.state.text else ""); render() }
            KeyEvent.KEYCODE_DPAD_UP -> { Ui.sizeSp = (Ui.sizeSp + 2).coerceAtMost(60f); show(subtitle.text.toString()) }
            KeyEvent.KEYCODE_DPAD_DOWN -> { Ui.sizeSp = (Ui.sizeSp - 2).coerceAtLeast(14f); show(subtitle.text.toString()) }
            KeyEvent.KEYCODE_DPAD_LEFT -> { Ui.alpha = (Ui.alpha - 0.1f).coerceAtLeast(0.2f); show(subtitle.text.toString()) }
            KeyEvent.KEYCODE_DPAD_RIGHT -> { Ui.alpha = (Ui.alpha + 0.1f).coerceAtMost(1f); show(subtitle.text.toString()) }
            KeyEvent.KEYCODE_1 -> startModeA()
            KeyEvent.KEYCODE_2, KeyEvent.KEYCODE_PROG_RED -> startModeB()
            KeyEvent.KEYCODE_3 -> { if (hdmiInputs.isNotEmpty()) { inputIndex = (inputIndex + 1) % hdmiInputs.size; startModeA() } }
            KeyEvent.KEYCODE_0, KeyEvent.KEYCODE_PROG_GREEN -> show("إيلينا: يجب أن نجد المفتاح القديم قبل حلول الظلام.")
            KeyEvent.KEYCODE_MENU, KeyEvent.KEYCODE_INFO, KeyEvent.KEYCODE_GUIDE -> { showDiag = !showDiag; render() }
            else -> return super.onKeyDown(keyCode, event)
        }
        return true
    }

    override fun onDestroy() {
        server.onChange = {}; server.onStatus = {}  // keep the server running for the phone
        runCatching { tvView.reset() }
        multicast?.release()
        super.onDestroy()
    }
}
