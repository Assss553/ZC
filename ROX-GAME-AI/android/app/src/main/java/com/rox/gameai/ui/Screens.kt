@file:OptIn(ExperimentalMaterial3Api::class)

package com.rox.gameai.ui

import android.os.PowerManager
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.rox.gameai.RoxApp
import com.rox.gameai.connection.LinkStatus
import com.rox.gameai.core.AudioSourceKind
import com.rox.gameai.core.BlurMode
import com.rox.gameai.core.Categories
import com.rox.gameai.core.ConsoleType
import com.rox.gameai.core.DisplayMode
import com.rox.gameai.core.GameProfile
import com.rox.gameai.core.NRect
import com.rox.gameai.core.RoxLog
import com.rox.gameai.core.VideoSourceKind
import com.rox.gameai.pipeline.AutoStep
import kotlinx.coroutines.delay
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

private val timeFmt = SimpleDateFormat("HH:mm:ss", Locale.US)
private val dateFmt = SimpleDateFormat("yyyy-MM-dd HH:mm", Locale.US)

@Composable
private fun ScrollPage(content: @Composable () -> Unit) {
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 14.dp, vertical = 6.dp)) { content(); Spacer(Modifier.height(40.dp)) }
}

@Composable
private fun RoxField(value: String, label: String, onChange: (String) -> Unit, modifier: Modifier = Modifier) {
    OutlinedTextField(value, onChange, modifier = modifier, label = { Text(label) }, singleLine = true,
        colors = OutlinedTextFieldDefaults.colors(focusedBorderColor = RoxOrange, unfocusedBorderColor = RoxLine, focusedLabelColor = RoxOrange, cursorColor = RoxOrange))
}

@Composable
private fun PrimaryButton(text: String, modifier: Modifier = Modifier, onClick: () -> Unit) =
    Button(onClick, modifier, shape = RoundedCornerShape(12.dp), colors = ButtonDefaults.buttonColors(containerColor = RoxOrange, contentColor = RoxBlack)) { Text(text, fontWeight = FontWeight.Black) }

@Composable
private fun SecondaryButton(text: String, modifier: Modifier = Modifier, onClick: () -> Unit) =
    OutlinedButton(onClick, modifier, shape = RoundedCornerShape(12.dp)) { Text(text, color = RoxWhite) }

@Composable
fun linkText(s: LinkStatus) = when (s) {
    LinkStatus.IDLE -> t("Not connected", "غير متصل")
    LinkStatus.SEARCHING -> t("Searching…", "جارٍ البحث…")
    LinkStatus.CONNECTED -> t("Connected (LAN)", "متصل (الشبكة المحلية)")
    LinkStatus.STANDBY -> t("Console in rest mode", "الجهاز في وضع الراحة")
    LinkStatus.LOST -> t("Connection lost", "انقطع الاتصال")
    LinkStatus.RECONNECTING -> t("Reconnecting…", "جارٍ إعادة الاتصال…")
}

@Composable
private fun stepText(s: AutoStep) = when (s) {
    AutoStep.IDLE -> t("Stopped", "متوقف")
    AutoStep.DETECT_SOURCE -> t("1. Detecting stream source", "1. اكتشاف مصدر البث")
    AutoStep.RECEIVE -> t("2. Receiving video & audio", "2. استقبال الصورة والصوت")
    AutoStep.RECOGNIZE -> t("3. Recognising game", "3. التعرف على اللعبة")
    AutoStep.LANGUAGE -> t("4. Detecting language", "4. تحديد لغة اللعبة")
    AutoStep.TRANSLATION -> t("5. Starting translation", "5. تشغيل الترجمة")
    AutoStep.VOICE -> t("6. Starting voice translation", "6. تشغيل ترجمة الصوت")
    AutoStep.SAFE_VISION -> t("7. Starting Safe Vision", "7. تشغيل Safe Vision")
    AutoStep.PROFILE -> t("8. Applying game profile", "8. تطبيق إعدادات اللعبة")
    AutoStep.DISPLAY -> t("9. Showing processed video", "9. عرض الصورة المعالجة")
    AutoStep.RUNNING -> t("Running", "يعمل")
    AutoStep.ERROR -> t("Error — see Logs", "خطأ — راجع السجلات")
}

// ───────────────────────────── HOME ─────────────────────────────
@Composable
fun HomeScreen(app: RoxApp, actions: RoxActions, go: (Section) -> Unit) {
    val conn by app.engine.connection.state.collectAsState()
    val st by app.engine.status.collectAsState()
    val perf by app.engine.perf.stats.collectAsState()
    val game by app.engine.recognizer.state.collectAsState()
    val pc by app.server.state.collectAsState()
    ScrollPage {
        if (pc.connected) RoxServerCard(app)
        ProcessedVideo(app)
        Row(Modifier.fillMaxWidth().padding(vertical = 10.dp), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            PrimaryButton("AUTO START", Modifier.weight(1f).height(54.dp)) { actions.autoStart() }
            Button({ actions.stop() }, Modifier.weight(1f).height(54.dp), shape = RoundedCornerShape(12.dp), colors = ButtonDefaults.buttonColors(containerColor = RoxPanel2, contentColor = RoxWhite)) { Text("STOP", fontWeight = FontWeight.Black) }
        }
        Text(stepText(st.step) + if (st.message.isNotBlank()) " · ${st.message}" else "", color = RoxOrange, fontWeight = FontWeight.Bold)
        if (game.needsManualPick) {
            RoxCard(t("Game not recognised", "لم يتم التعرف على اللعبة")) {
                Note(t("Choose it in the Game Library.", "اخترها يدويًا من مكتبة الألعاب."))
                PrimaryButton(t("Choose game", "اختيار اللعبة")) { go(Section.LIBRARY) }
            }
        }
        RoxCard(t("Status", "الحالة")) {
            Row { StatusTile(t("Connection", "الاتصال"), linkText(conn.status), conn.status == LinkStatus.CONNECTED, Modifier.weight(1f)); StatusTile(t("Console", "الجهاز"), conn.console?.let { "${it.type} · ${it.name}" } ?: "—", conn.console != null, Modifier.weight(1f)) }
            Row { StatusTile(t("Game", "اللعبة"), game.profile?.name ?: conn.runningApp ?: "—", game.profile != null, Modifier.weight(1f)); StatusTile(t("Video", "الفيديو"), if (!st.running) t("Off", "متوقف") else if (st.videoActive) "${st.sourceLabel}${if (st.isTestSource) " (TEST)" else ""}" else t("No signal", "لا إشارة"), if (st.running) st.videoActive else null, Modifier.weight(1f)) }
            Row { StatusTile(t("Translation", "الترجمة"), if (st.translationActive) t("On", "تعمل") + (if (st.gameLanguage.isNotEmpty()) " · ${st.gameLanguage}→ar" else "") else t("Off", "متوقفة"), st.translationActive, Modifier.weight(1f)); StatusTile(t("Voice", "الصوت"), if (st.voiceActive) st.voiceMode else t("Off", "متوقف"), st.voiceActive, Modifier.weight(1f)) }
            Row { StatusTile(t("Protection", "الحماية"), if (st.safeActive) "Safe Vision ON" else t("Off", "متوقفة"), st.safeActive, Modifier.weight(1f)); StatusTile(t("Memory / CPU", "الذاكرة / المعالج"), "${perf.javaHeapMb + perf.nativeHeapMb} MB · ${perf.cpuPercent}%", perf.cpuPercent < 70, Modifier.weight(1f)) }
            Row { StatusTile(t("Processing delay", "تأخير المعالجة"), "${perf.processingMs} ms · OCR ${perf.ocrMs} ms · ${"%.1f".format(perf.fps)} fps", perf.processingMs < 60, Modifier.weight(1f)); StatusTile(t("Temperature", "الحرارة"), thermalText(perf.thermalStatus) + if (perf.throttled) t(" (throttling)", " (تخفيف الحمل)") else "", !perf.throttled, Modifier.weight(1f)) }
        }
        RoxCard(t("Test without a PlayStation", "اختبار بدون PlayStation")) {
            Note(t("Runs the full pipeline on a built-in TEST VIDEO (synthetic). This is not a real console stream.", "يشغّل النظام الكامل على فيديو تجريبي مدمج. هذا ليس بثًا حقيقيًا من الجهاز."))
            SecondaryButton(t("Start test video", "تشغيل الفيديو التجريبي")) { actions.startTest() }
        }
    }
}

@Composable
private fun thermalText(s: Int) = when {
    s >= PowerManager.THERMAL_STATUS_SEVERE -> t("Hot", "ساخن")
    s >= PowerManager.THERMAL_STATUS_MODERATE -> t("Warm", "دافئ")
    else -> t("Normal", "طبيعية")
}

// ───────────────────────────── CONNECT ─────────────────────────────
@Composable
fun ConnectScreen(app: RoxApp) {
    val cm = app.engine.connection
    val conn by cm.state.collectAsState()
    val found by cm.found.collectAsState()
    val saved by app.store.consoles.collectAsState()
    var ip by remember { mutableStateOf("") }
    var manualType by remember { mutableStateOf(ConsoleType.PS5) }
    ScrollPage {
        RoxServerCard(app)
        RoxCard(t("Status", "الحالة")) {
            StatusTile(linkText(conn.status), conn.console?.let { "${it.type} · ${it.name} · ${it.ip}" + (conn.runningApp?.let { a -> "\n▶ $a" } ?: "") } ?: "—", conn.status == LinkStatus.CONNECTED)
            Note(t("How it works: ROX finds the console on your Wi-Fi and monitors its state and running game. The video itself comes from Sony's official PS Remote Play app (sign-in and pairing with your PSN account are done there) or from an HDMI capture card.",
                "طريقة العمل: يكتشف ROX الجهاز على شبكة Wi-Fi ويراقب حالته واللعبة المشغلة. أما الفيديو نفسه فيأتي من تطبيق Sony الرسمي PS Remote Play (تسجيل الدخول والاقتران بحساب PSN يتمان فيه) أو من بطاقة التقاط HDMI."))
        }
        RoxCard(t("1. Search the network", "1. البحث في الشبكة")) {
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                PrimaryButton(t("Search PS4 / PS5", "البحث عن PS4 / PS5")) { cm.scan() }
            }
            if (conn.message == "no_console") Note(t("No console answered. Make sure the phone and the console are on the same Wi-Fi and the console is on or in rest mode with network enabled.", "لم يستجب أي جهاز. تأكد من أن الهاتف والجهاز على نفس شبكة Wi-Fi وأن الجهاز يعمل أو في وضع الراحة مع تفعيل الشبكة."), RoxRed)
            found.forEach { r ->
                Row(Modifier.fillMaxWidth().padding(vertical = 4.dp).background(RoxPanel2, RoundedCornerShape(10.dp)).padding(10.dp), verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.weight(1f)) {
                        Text("${r.type} · ${r.hostName}", color = RoxWhite, fontWeight = FontWeight.Bold)
                        Text("${r.ip} · ${r.state}${r.runningAppName?.let { " · $it" } ?: ""}", color = RoxGrey, fontSize = 12.sp)
                    }
                    PrimaryButton(t("Pair", "اقتران")) { cm.pair(r) }
                }
            }
        }
        RoxCard(t("2. Add by IP", "2. إضافة عبر IP")) {
            RoxField(ip, t("Console IP (e.g. 192.168.1.20)", "عنوان IP للجهاز"), { ip = it }, Modifier.fillMaxWidth())
            ChipRow(listOf(ConsoleType.PS5, ConsoleType.PS4), manualType, { it.name }) { manualType = it }
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                SecondaryButton(t("Query IP", "فحص العنوان")) { cm.scan(ip) }
                PrimaryButton(t("Add device", "إضافة جهاز")) { if (ip.isNotBlank()) cm.addManual(ip.trim(), manualType, manualType.name) }
            }
        }
        RoxCard(t("Paired devices", "الأجهزة المقترنة")) {
            if (saved.isEmpty()) Note(t("No paired devices yet.", "لا توجد أجهزة مقترنة بعد."))
            saved.forEach { c ->
                Row(Modifier.fillMaxWidth().padding(vertical = 4.dp), verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.weight(1f)) {
                        Text("${c.type} · ${c.name}", color = RoxWhite, fontWeight = FontWeight.Bold)
                        Text("${c.ip} · ${if (c.lastSeen > 0) dateFmt.format(Date(c.lastSeen)) else "—"}", color = RoxGrey, fontSize = 12.sp)
                    }
                    TextButton({ cm.connect(c) }) { Text(t("Connect", "اتصال"), color = RoxOrange) }
                    TextButton({ cm.forget(c.hostId) }) { Text(t("Forget", "حذف"), color = RoxRed) }
                }
            }
        }
        RoxCard("PS Remote Play") {
            Note(if (cm.isRemotePlayInstalled()) t("Installed. AUTO START opens it after the screen-capture consent.", "مثبت. يفتحه AUTO START بعد الموافقة على التقاط الشاشة.") else t("Not installed. Install Sony's official app to stream the console to this phone.", "غير مثبت. ثبّت تطبيق Sony الرسمي لبث الجهاز إلى هذا الهاتف."))
            PrimaryButton(t("Open PS Remote Play", "فتح PS Remote Play")) { cm.launchRemotePlay() }
        }
    }
}

// ───────────────────────────── LIBRARY ─────────────────────────────
private val langOptions = listOf("", "en", "ja", "zh", "ko", "fr", "de", "es", "it", "pt", "ru")

@Composable
fun LibraryScreen(app: RoxApp) {
    val games by app.store.games.collectAsState()
    val cur by app.engine.recognizer.state.collectAsState()
    var name by remember { mutableStateOf("") }
    ScrollPage {
        RoxCard(t("Current game", "اللعبة الحالية")) {
            Text(cur.profile?.let { "${it.name} (${cur.source})" } ?: t("Not recognised", "غير معروفة"), color = RoxWhite, fontWeight = FontWeight.Bold)
            Row(verticalAlignment = Alignment.CenterVertically) {
                RoxField(name, t("Game name", "اسم اللعبة"), { name = it }, Modifier.weight(1f))
                Spacer(Modifier.width(8.dp))
                PrimaryButton(t("Set", "تحديد")) { if (name.isNotBlank()) { app.engine.recognizer.manual(name.trim()); name = "" } }
            }
        }
        if (games.isEmpty()) Note(t("Games you play are saved here automatically with their own settings.", "تُحفظ الألعاب التي تلعبها هنا تلقائيًا مع إعداداتها الخاصة."))
        games.forEach { g -> GameCard(app, g, g.id == cur.profile?.id) }
    }
}

@Composable
private fun GameCard(app: RoxApp, g: GameProfile, current: Boolean) {
    RoxCard(g.name + if (current) " ●" else "") {
        Note("${t("Played", "مرات اللعب")}: ${g.timesPlayed} · ${if (g.lastPlayed > 0) dateFmt.format(Date(g.lastPlayed)) else "—"}${if (g.titleId.isNotEmpty()) " · ${g.titleId}" else ""}")
        Text(t("Game language", "لغة اللعبة"), color = RoxGrey, fontSize = 12.sp)
        ChipRow(langOptions, g.language, { if (it.isEmpty()) t("Auto", "تلقائي") else it.uppercase() }) { app.engine.recognizer.updateProfile(g.copy(language = it)) }
        SettingSwitch("Safe Vision", g.safeVision) { app.engine.recognizer.updateProfile(g.copy(safeVision = it)) }
        ChipRow(listOf<BlurMode?>(null) + BlurMode.entries, g.blurMode, { it?.name ?: t("Global", "الإعداد العام") }) { app.engine.recognizer.updateProfile(g.copy(blurMode = it)) }
        Row {
            if (!current) TextButton({ app.engine.recognizer.select(g, "manual") }) { Text(t("Select", "اختيار"), color = RoxOrange) }
            TextButton({ app.store.removeGame(g.id) }) { Text(t("Delete", "حذف"), color = RoxRed) }
        }
    }
}

// ───────────────────────────── LIVE TRANSLATION ─────────────────────────────
@Composable
fun LiveTranslationScreen(app: RoxApp, actions: RoxActions) {
    val s by app.settings.state.collectAsState()
    val overlays by app.engine.overlays.collectAsState()
    val models by app.engine.translator.modelStatus.collectAsState()
    val ctx = app.engine.dialog
    var tick by remember { mutableIntStateOf(0) }
    LaunchedEffect(Unit) { while (true) { delay(1000); tick++ } }
    ScrollPage {
        RoxCard("ROX LIVE TRANSLATOR") {
            SettingSwitch(t("Live translation", "الترجمة المباشرة"), s.translationEnabled) { v -> app.settings.update { it.copy(translationEnabled = v) } }
            Text(t("Display mode", "نمط العرض"), color = RoxGrey, fontSize = 12.sp)
            ChipRow(DisplayMode.entries, s.displayMode, {
                when (it) { DisplayMode.ON_VIDEO -> t("Over video", "فوق الفيديو"); DisplayMode.FLOATING_WINDOW -> t("Separate window", "نافذة منفصلة"); DisplayMode.LOG_ONLY -> t("Dialogue log", "سجل الحوارات") }
            }) { m -> app.settings.update { it.copy(displayMode = m) }; if (m == DisplayMode.FLOATING_WINDOW && !app.overlay.canShow()) actions.requestOverlay() }
            if (s.displayMode == DisplayMode.FLOATING_WINDOW && !app.overlay.canShow()) {
                Note(t("Overlay permission needed for the floating window.", "تحتاج النافذة العائمة إلى صلاحية العرض فوق التطبيقات."), RoxRed)
                SecondaryButton(t("Grant permission", "منح الصلاحية")) { actions.requestOverlay() }
            }
            Note(t("Target language: Arabic. Translation models download once (~30 MB each) then work offline.", "اللغة الهدف: العربية. تُحمَّل نماذج الترجمة مرة واحدة (~30MB لكل لغة) ثم تعمل دون إنترنت."))
            models.forEach { (k, v) -> Note("$k: $v") }
        }
        ProcessedVideo(app)
        RoxCard(t("On screen now", "الظاهر الآن على الشاشة")) {
            if (overlays.isEmpty()) Note(t("No text detected yet.", "لم يُكتشف نص بعد."))
            overlays.forEach { o ->
                Column(Modifier.padding(vertical = 4.dp)) {
                    Text("${o.kind}${if (o.speaker.isNotBlank()) " · ${o.speaker}" else ""}", color = RoxOrange, fontSize = 11.sp, fontWeight = FontWeight.Bold)
                    Text(o.translated, color = RoxWhite, fontSize = 16.sp)
                    Text(o.original, color = RoxGrey, fontSize = 12.sp)
                }
            }
        }
        RoxCard(t("Dialogue context", "سياق الحوار")) {
            val lines = remember(tick) { ctx.recent() }
            if (lines.isEmpty()) Note("—")
            lines.takeLast(12).forEach { l -> Text((if (l.speaker.isNotBlank()) "${l.speaker}: " else "") + l.translated, color = RoxWhite, modifier = Modifier.padding(vertical = 2.dp)) }
        }
    }
}

// ───────────────────────────── VOICE ─────────────────────────────
@Composable
fun VoiceScreen(app: RoxApp, actions: RoxActions) {
    val s by app.settings.state.collectAsState()
    val lines by app.engine.voice.collectAsState()
    val st by app.engine.status.collectAsState()
    var level by remember { mutableIntStateOf(0) }
    LaunchedEffect(Unit) { while (true) { delay(300); level = app.engine.audioLevel() } }
    ScrollPage {
        RoxCard("ROX VOICE TRANSLATOR") {
            SettingSwitch(t("Voice translation", "الترجمة الصوتية"), s.voiceEnabled) { v -> app.settings.update { it.copy(voiceEnabled = v) }; actions.requestMic() }
            StatusTile(t("Mode", "الوضع"), "${st.voiceMode} · ${t("audio level", "مستوى الصوت")} $level", st.voiceActive)
            if (!app.engine.voiceAvailable()) Note(t("This phone has no speech-recognition service (install/enable Google speech services).", "لا توجد خدمة تعرف على الكلام في هذا الهاتف (فعّل خدمات Google للكلام)."), RoxRed)
            Text(t("Audio source", "مصدر الصوت"), color = RoxGrey, fontSize = 12.sp)
            ChipRow(AudioSourceKind.entries, s.audioSource, {
                when (it) { AudioSourceKind.STREAM_PLAYBACK -> t("Stream app audio", "صوت تطبيق البث"); AudioSourceKind.USB_CAPTURE -> t("Capture card", "بطاقة الالتقاط"); AudioSourceKind.MICROPHONE -> t("Microphone", "الميكروفون") }
            }) { v -> app.settings.update { it.copy(audioSource = v) }; app.engine.restartVoice() }
            Text(t("Spoken language", "لغة الكلام"), color = RoxGrey, fontSize = 12.sp)
            ChipRow(listOf("en-US", "ja-JP", "zh-CN", "ko-KR", "fr-FR", "de-DE", "es-ES"), s.voiceLanguage, { it }) { v -> app.settings.update { it.copy(voiceLanguage = v) }; app.engine.restartVoice() }
            SettingSwitch(t("Arabic voice reading (experimental dubbing)", "قراءة الترجمة بصوت عربي (دبلجة تجريبية)"), s.ttsDubbing, t("Uses the phone's Arabic text-to-speech voice", "يستخدم صوت تحويل النص إلى كلام العربي في الهاتف")) { v -> app.settings.update { it.copy(ttsDubbing = v) }; app.engine.restartVoice() }
            Note(t("Game-audio capture needs Android 13+ and a streaming app that allows audio capture. Otherwise ROX listens through the microphone. Speaker names come from on-screen subtitles.",
                "التقاط صوت اللعبة يحتاج Android 13 أو أحدث وتطبيق بث يسمح بالتقاط الصوت. وإلا يستمع ROX عبر الميكروفون. أسماء المتحدثين تؤخذ من الترجمة الظاهرة على الشاشة."))
        }
        RoxCard(t("Live speech", "الكلام المباشر")) {
            if (lines.isEmpty()) Note("—")
            lines.reversed().forEach { l ->
                Column(Modifier.padding(vertical = 4.dp)) {
                    if (l.partial) Text("… ${l.text}", color = RoxGrey) else {
                        Text((if (l.speaker.isNotBlank()) "${l.speaker}: " else "") + l.translated, color = RoxWhite, fontSize = 16.sp)
                        Text("${timeFmt.format(Date(l.time))} · ${l.text}", color = RoxGrey, fontSize = 12.sp)
                    }
                }
            }
        }
    }
}

// ───────────────────────────── SAFE VISION ─────────────────────────────
@Composable
fun SafeVisionScreen(app: RoxApp) {
    val s by app.settings.state.collectAsState()
    val blocked by app.store.blocked.collectAsState()
    ScrollPage {
        RoxCard("ROX SAFE VISION") {
            SettingSwitch(t("Protection", "الحماية"), s.safeVisionEnabled) { v -> app.settings.update { it.copy(safeVisionEnabled = v) } }
            Text(t("Blocking mode", "نمط الحجب"), color = RoxGrey, fontSize = 12.sp)
            ChipRow(BlurMode.entries, s.blurMode, {
                when (it) { BlurMode.GAUSSIAN -> "Gaussian Blur"; BlurMode.PIXELATE -> "Pixelation"; BlurMode.BLACK -> "Black Mask"; BlurMode.FULL_SCENE -> "Full Scene Blur" }
            }) { m -> app.settings.update { it.copy(blurMode = m) } }
            SettingSlider(t("Sensitivity", "مستوى الحساسية"), s.sensitivity, 0f..1f, "${(s.sensitivity * 100).toInt()}%") { v -> app.settings.update { it.copy(sensitivity = v) } }
            SettingSlider(t("Blur strength", "قوة التغبيش"), s.blurStrength.toFloat(), 4f..60f, "${s.blurStrength}") { v -> app.settings.update { it.copy(blurStrength = v.toInt()) } }
            SettingSlider(t("Mask size (padding)", "حجم منطقة الحجب"), s.maskPadding, 0f..0.6f, "+${(s.maskPadding * 100).toInt()}%") { v -> app.settings.update { it.copy(maskPadding = v) } }
            Note(t("Frames are masked before they are shown inside ROX (capture card / test video). Over PS Remote Play the mask is drawn on the floating window and can appear ~1 frame late.",
                "تُحجب الإطارات قبل عرضها داخل ROX (بطاقة الالتقاط / الفيديو التجريبي). فوق PS Remote Play يُرسم الحجب على النافذة العائمة وقد يتأخر إطارًا واحدًا تقريبًا."))
        }
        RoxCard(t("Categories", "الفئات المحجوبة")) {
            fun toggle(c: String, on: Boolean) = app.settings.update { it.copy(categories = if (on) it.categories + c else it.categories - c) }
            SettingSwitch(t("Exposed skin areas", "المناطق المكشوفة"), Categories.EXPOSED in s.categories, t("Heuristic skin-region detector (on-device)", "كاشف مناطق الجلد (خوارزمية محلية)")) { toggle(Categories.EXPOSED, it) }
            val model = app.engine.modelInstalled
            SettingSwitch(t("Nudity", "العري"), Categories.NUDITY in s.categories, if (model) t("Trained model active", "النموذج المدرب يعمل") else t("Requires a classification model (not installed)", "يتطلب نموذج تصنيف (غير مثبت)")) { toggle(Categories.NUDITY, it) }
            SettingSwitch(t("Sexual content", "المحتوى الجنسي"), Categories.SEXUAL in s.categories, if (model) t("Trained model active", "النموذج المدرب يعمل") else t("Requires a classification model (not installed)", "يتطلب نموذج تصنيف (غير مثبت)")) { toggle(Categories.SEXUAL, it) }
            SettingSwitch(t("My custom regions", "المناطق التي أحددها"), Categories.CUSTOM in s.categories) { toggle(Categories.CUSTOM, it) }
        }
        RoxCard(t("Custom regions", "مناطق حجب مخصصة")) {
            val presets = listOf(
                t("Center", "الوسط") to NRect(0.3f, 0.25f, 0.7f, 0.75f), t("Left half", "النصف الأيسر") to NRect(0f, 0f, 0.5f, 1f),
                t("Right half", "النصف الأيمن") to NRect(0.5f, 0f, 1f, 1f), t("Top", "الأعلى") to NRect(0f, 0f, 1f, 0.33f), t("Bottom", "الأسفل") to NRect(0f, 0.66f, 1f, 1f),
            )
            ChipRow(presets.map { it.first }, null, { "+ $it" }) { label -> presets.firstOrNull { it.first == label }?.let { p -> app.settings.update { it.copy(customRegions = it.customRegions + p.second) } } }
            s.customRegions.forEachIndexed { i, r ->
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text("#${i + 1}  ${(r.l * 100).toInt()}%,${(r.t * 100).toInt()}% → ${(r.r * 100).toInt()}%,${(r.b * 100).toInt()}%", color = RoxWhite, modifier = Modifier.weight(1f))
                    TextButton({ app.settings.update { it.copy(customRegions = it.customRegions.filterIndexed { j, _ -> j != i }) } }) { Text(t("Remove", "إزالة"), color = RoxRed) }
                }
            }
        }
        RoxCard(t("Blocked scenes log", "سجل المشاهد المحجوبة")) {
            Row { Text("${blocked.size}", color = RoxOrange, fontWeight = FontWeight.Bold, modifier = Modifier.weight(1f)); TextButton({ app.store.clearBlocked() }) { Text(t("Clear", "مسح"), color = RoxRed) } }
            blocked.takeLast(30).reversed().forEach { b -> Note("${dateFmt.format(Date(b.time))} · ${b.category} · ${(b.score * 100).toInt()}% · ${b.mode}${if (b.game.isNotBlank()) " · ${b.game}" else ""}", RoxWhite) }
        }
    }
}

// ───────────────────────────── AI SETTINGS ─────────────────────────────
@Composable
fun AiSettingsScreen(app: RoxApp) {
    val s by app.settings.state.collectAsState()
    ScrollPage {
        RoxCard(t("Performance & quality", "الأداء والجودة")) {
            SettingSlider(t("Translation speed (OCR every)", "سرعة الترجمة (OCR كل)"), s.ocrIntervalMs.toFloat(), 300f..3000f, "${s.ocrIntervalMs} ms") { v -> app.settings.update { it.copy(ocrIntervalMs = v.toInt()) } }
            SettingSlider(t("OCR accuracy (resolution)", "دقة OCR (الدقة)"), s.ocrScale, 0.3f..1f, "${(s.ocrScale * 100).toInt()}%") { v -> app.settings.update { it.copy(ocrScale = v) } }
            SettingSlider(t("Video analysis quality", "جودة تحليل الفيديو"), s.analysisWidth.toFloat(), 160f..960f, "${s.analysisWidth}px") { v -> app.settings.update { it.copy(analysisWidth = v.toInt()) } }
            SettingSlider(t("Content detection sensitivity", "حساسية اكتشاف المحتوى"), s.sensitivity, 0f..1f, "${(s.sensitivity * 100).toInt()}%") { v -> app.settings.update { it.copy(sensitivity = v) } }
            SettingSlider(t("Blur strength", "قوة التغبيش"), s.blurStrength.toFloat(), 4f..60f, "${s.blurStrength}") { v -> app.settings.update { it.copy(blurStrength = v.toInt()) } }
            Text(t("Audio quality", "جودة الصوت"), color = RoxGrey, fontSize = 12.sp)
            ChipRow(listOf(16000, 22050, 44100), s.audioSampleRate, { "${it / 1000.0} kHz" }) { v -> app.settings.update { it.copy(audioSampleRate = v) } }
        }
        RoxCard(t("Processing", "المعالجة")) {
            SettingSwitch(t("Local (on-device) processing", "المعالجة المحلية على الهاتف"), s.localProcessing, t("Default. OCR, translation, detection and speech run on the phone.", "الوضع الافتراضي. تعمل القراءة والترجمة والكشف والكلام على الهاتف.")) { v -> app.settings.update { it.copy(localProcessing = v) } }
            SettingSwitch(t("Optional cloud translation", "الترجمة السحابية الاختيارية"), s.cloudEnabled) { v -> app.settings.update { it.copy(cloudEnabled = v) } }
            if (s.cloudEnabled) {
                RoxField(s.cloudEndpoint, t("Your backend URL (POST {text,source,target})", "رابط الخادم الخاص بك"), { v -> app.settings.update { it.copy(cloudEndpoint = v.trim()) } }, Modifier.fillMaxWidth())
                Note(t("No API key is stored in the app: point this to your own server, which keeps the key.", "لا يُخزَّن أي مفتاح API في التطبيق: استخدم خادمك الخاص الذي يحتفظ بالمفتاح."))
            }
        }
    }
}

// ───────────────────────────── HISTORY ─────────────────────────────
@Composable
fun HistoryScreen(app: RoxApp, actions: RoxActions) {
    val h by app.store.history.collectAsState()
    var q by remember { mutableStateOf("") }
    val list = remember(h, q) { h.asReversed().filter { q.isBlank() || it.source.contains(q, true) || it.translated.contains(q) || it.game.contains(q, true) } }
    Column(Modifier.fillMaxSize().padding(horizontal = 14.dp)) {
        RoxField(q, t("Search", "بحث"), { q = it }, Modifier.fillMaxWidth())
        Row {
            Text("${list.size}", color = RoxOrange, fontWeight = FontWeight.Bold, modifier = Modifier.weight(1f).padding(top = 12.dp))
            TextButton({ actions.share(list.joinToString("\n\n") { "[${dateFmt.format(Date(it.time))}] ${it.game} ${it.kind}\n${it.speaker.let { s -> if (s.isNotBlank()) "$s: " else "" }}${it.source}\n→ ${it.translated}" }) }) { Text(t("Export", "تصدير"), color = RoxOrange) }
            TextButton({ app.store.clearHistory() }) { Text(t("Clear", "مسح"), color = RoxRed) }
        }
        LazyColumn {
            items(list.take(500)) { e ->
                Column(Modifier.fillMaxWidth().padding(vertical = 4.dp).background(RoxPanel, RoundedCornerShape(10.dp)).padding(10.dp)) {
                    Text("${dateFmt.format(Date(e.time))} · ${e.kind}${if (e.fromVoice) " · 🎙" else ""}${if (e.game.isNotBlank()) " · ${e.game}" else ""}", color = RoxOrange, fontSize = 11.sp)
                    Text((if (e.speaker.isNotBlank()) "${e.speaker}: " else "") + e.translated, color = RoxWhite, fontSize = 16.sp)
                    Text("${e.sourceLang}: ${e.source}", color = RoxGrey, fontSize = 12.sp)
                }
            }
        }
    }
}

// ───────────────────────────── CONNECTION SETTINGS ─────────────────────────────
@Composable
fun ConnectionSettingsScreen(app: RoxApp) {
    val s by app.settings.state.collectAsState()
    ScrollPage {
        RoxCard(t("Video source", "مصدر الفيديو")) {
            ChipRow(VideoSourceKind.entries, s.videoSource, {
                when (it) { VideoSourceKind.AUTO -> t("Automatic", "تلقائي"); VideoSourceKind.CAPTURE_CARD -> t("HDMI capture card", "بطاقة التقاط HDMI"); VideoSourceKind.SCREEN_CAPTURE -> "PS Remote Play"; VideoSourceKind.TEST_PATTERN -> t("Test video", "فيديو تجريبي") }
            }) { v -> app.settings.update { it.copy(videoSource = v) } }
            StatusTile(t("Capture card", "بطاقة الالتقاط"), if (app.engine.hasCaptureCard()) t("Detected", "مكتشفة") else t("Not detected", "غير مكتشفة"), app.engine.hasCaptureCard())
            Note(t("Automatic: uses a USB HDMI capture card if one is connected, otherwise captures PS Remote Play.", "تلقائي: يستخدم بطاقة التقاط HDMI عبر USB إذا كانت موصولة، وإلا يلتقط PS Remote Play."))
        }
        RoxCard(t("Connection", "الاتصال")) {
            SettingSwitch(t("Auto reconnect", "إعادة الاتصال تلقائيًا"), s.autoReconnect) { v -> app.settings.update { it.copy(autoReconnect = v) } }
            SettingSlider(t("Status check interval", "فترة فحص الحالة"), s.discoveryIntervalSec.toFloat(), 3f..30f, "${s.discoveryIntervalSec} s") { v -> app.settings.update { it.copy(discoveryIntervalSec = v.toInt()) } }
            SettingSlider(t("Stream loss timeout", "مهلة انقطاع البث"), s.streamTimeoutSec.toFloat(), 2f..20f, "${s.streamTimeoutSec} s") { v -> app.settings.update { it.copy(streamTimeoutSec = v.toInt()) } }
        }
    }
}

// ───────────────────────────── LOGS ─────────────────────────────
@Composable
fun LogsScreen(actions: RoxActions) {
    val logs by RoxLog.entries.collectAsState()
    Column(Modifier.fillMaxSize().padding(horizontal = 14.dp)) {
        Row {
            Text("${logs.size}", color = RoxOrange, modifier = Modifier.weight(1f).padding(top = 12.dp))
            TextButton({ actions.share(RoxLog.exportText()) }) { Text(t("Share", "مشاركة"), color = RoxOrange) }
            TextButton({ RoxLog.clear() }) { Text(t("Clear", "مسح"), color = RoxRed) }
        }
        LazyColumn {
            items(logs.asReversed()) { e ->
                Text("${timeFmt.format(Date(e.time))} ${e.level}/${e.tag}: ${e.message}", fontSize = 12.sp,
                    color = when (e.level) { 'E' -> RoxRed; 'W' -> RoxOrange; else -> RoxGrey }, modifier = Modifier.padding(vertical = 2.dp))
            }
        }
    }
}


// ───────────────────────────── ROX SERVER (PC) ─────────────────────────────
@Composable
fun RoxServerCard(app: RoxApp) {
    val st by app.server.state.collectAsState()
    val found by app.server.found.collectAsState()
    val subs by app.server.subtitles.collectAsState()
    var host by remember { mutableStateOf("") }
    var searching by remember { mutableStateOf(false) }
    LaunchedEffect(searching) { if (searching) { app.server.discover(); searching = false } }
    RoxCard("ROX Server (PC)") {
        StatusTile(
            if (st.connected) t("Connected to PC", "متصل بالكمبيوتر") else t("Not connected", "غير متصل"),
            st.server?.let { "${it.name} · ${it.host}:${it.port}" + if (st.connected) " · ${st.fps} fps · OCR ${st.ocrMs} ms · ${st.lang}" else "" } ?: "—",
            st.connected,
        )
        Note(t("Run ROX Server on your PC (same Wi-Fi). The PC receives the PlayStation through the official chiaki-ng client (Sony sign-in + PIN there) and does the AI; the phone shows the translation.",
            "شغّل ROX Server على الكمبيوتر (نفس الشبكة). الكمبيوتر يستقبل البلايستيشن عبر عميل chiaki-ng الرسمي (تسجيل الدخول برمز Sony هناك) ويشغّل الذكاء الاصطناعي، والجوال يعرض الترجمة."))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            PrimaryButton(if (searching) t("Searching…", "جارٍ البحث…") else t("Find ROX Server", "البحث عن ROX Server")) { searching = true }
            if (st.server != null) SecondaryButton(t("Disconnect", "قطع الاتصال")) { app.server.disconnect() }
        }
        found.forEach { s ->
            Row(Modifier.fillMaxWidth().padding(vertical = 4.dp), verticalAlignment = Alignment.CenterVertically) {
                Text("${s.name}\n${s.host}:${s.port}", color = RoxWhite, modifier = Modifier.weight(1f))
                PrimaryButton(t("Connect", "اتصال")) { app.server.connect(s) }
            }
        }
        Row(verticalAlignment = Alignment.CenterVertically) {
            RoxField(host, t("PC IP (optional)", "عنوان الكمبيوتر (اختياري)"), { host = it }, Modifier.weight(1f))
            Spacer(Modifier.width(8.dp))
            SecondaryButton(t("Connect", "اتصال")) { if (host.isNotBlank()) app.server.connectManual(host) }
        }
        if (st.connected) {
            subs.take(4).forEach { o ->
                Column(Modifier.padding(vertical = 4.dp)) {
                    Text("${o.kind}${if (o.speaker.isNotBlank()) " · ${o.speaker}" else ""}", color = RoxOrange, fontSize = 11.sp)
                    Text(o.translated, color = RoxWhite, fontSize = 16.sp)
                    Text(o.original, color = RoxGrey, fontSize = 12.sp)
                }
            }
        }
    }
}
