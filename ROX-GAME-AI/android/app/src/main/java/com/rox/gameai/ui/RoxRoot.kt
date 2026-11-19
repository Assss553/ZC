@file:OptIn(ExperimentalMaterial3Api::class)

package com.rox.gameai.ui

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Menu
import androidx.compose.material3.DrawerValue
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ModalDrawerSheet
import androidx.compose.material3.ModalNavigationDrawer
import androidx.compose.material3.NavigationDrawerItem
import androidx.compose.material3.NavigationDrawerItemDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.material3.rememberDrawerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.scale
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.rox.gameai.RoxApp
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

interface RoxActions {
    fun autoStart()
    fun startTest()
    fun stop()
    fun requestOverlay()
    fun share(text: String)
    fun requestMic()
}

enum class Section(val en: String, val ar: String) {
    HOME("Home Dashboard", "لوحة التحكم"),
    CONNECT("Connect PlayStation", "ربط PlayStation"),
    LIBRARY("Game Library", "مكتبة الألعاب"),
    LIVE("Live Translation", "الترجمة المباشرة"),
    VOICE("Voice Translation", "الترجمة الصوتية"),
    SAFE("Safe Vision", "الحماية Safe Vision"),
    AI("AI Settings", "إعدادات الذكاء الاصطناعي"),
    HISTORY("Translation History", "سجل الترجمة"),
    CONN_SETTINGS("Connection Settings", "إعدادات الاتصال"),
    LOGS("Logs", "السجلات"),
}

@Composable
fun RoxLogo(modifier: Modifier = Modifier) {
    Canvas(modifier) {
        val s = size.minDimension
        drawCircle(RoxOrange, radius = s * 0.46f, style = Stroke(width = s * 0.05f))
        val p = Path().apply {
            moveTo(s * 0.34f, s * 0.28f); lineTo(s * 0.55f, s * 0.28f)
            cubicTo(s * 0.72f, s * 0.28f, s * 0.72f, s * 0.54f, s * 0.55f, s * 0.54f)
            lineTo(s * 0.68f, s * 0.74f); moveTo(s * 0.34f, s * 0.28f); lineTo(s * 0.34f, s * 0.74f)
        }
        drawPath(p, RoxOrange, style = Stroke(width = s * 0.08f))
        drawCircle(RoxWhite, radius = s * 0.03f, center = Offset(s * 0.72f, s * 0.24f))
    }
}

@Composable
private fun Splash(onDone: () -> Unit) {
    val a = remember { Animatable(0f) }
    LaunchedEffect(Unit) { a.animateTo(1f, tween(900)); delay(500); onDone() }
    Box(Modifier.fillMaxSize().background(RoxBlack), contentAlignment = Alignment.Center) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            RoxLogo(Modifier.size(140.dp).scale(0.7f + 0.3f * a.value).alpha(a.value))
            Spacer(Modifier.height(18.dp))
            Text("ROX GAME AI", color = RoxWhite, fontSize = 28.sp, fontWeight = FontWeight.Black, letterSpacing = 4.sp, modifier = Modifier.alpha(a.value))
            Text("TRANSLATE · PROTECT · PLAY", color = RoxOrange, fontSize = 12.sp, letterSpacing = 3.sp, modifier = Modifier.alpha(a.value))
        }
    }
}

@Composable
fun RoxRoot(app: RoxApp, actions: RoxActions) {
    val settings by app.settings.state.collectAsState()
    val arabic = settings.uiLanguage == "ar"
    var splash by rememberSaveable { mutableStateOf(true) }
    var section by rememberSaveable { mutableStateOf(Section.HOME) }
    CompositionLocalProvider(LocalArabic provides arabic, LocalLayoutDirection provides if (arabic) LayoutDirection.Rtl else LayoutDirection.Ltr) {
        RoxTheme {
            if (splash) { Splash { splash = false }; return@RoxTheme }
            val drawer = rememberDrawerState(DrawerValue.Closed)
            val scope = rememberCoroutineScope()
            ModalNavigationDrawer(drawerState = drawer, drawerContent = {
                ModalDrawerSheet(drawerContainerColor = RoxBlack) {
                    Column(Modifier.verticalScroll(rememberScrollState()).padding(12.dp)) {
                        RoxLogo(Modifier.size(64.dp).padding(4.dp))
                        Text("ROX GAME AI", color = RoxWhite, fontWeight = FontWeight.Black, fontSize = 20.sp, modifier = Modifier.padding(8.dp))
                        Section.entries.forEach { s ->
                            NavigationDrawerItem(
                                label = { Text(if (arabic) s.ar else s.en) }, selected = s == section,
                                onClick = { section = s; scope.launch { drawer.close() } },
                                colors = NavigationDrawerItemDefaults.colors(selectedContainerColor = RoxOrange, selectedTextColor = RoxBlack, unselectedContainerColor = RoxBlack, unselectedTextColor = RoxWhite),
                            )
                        }
                    }
                }
            }) {
                Scaffold(
                    containerColor = RoxBlack,
                    topBar = {
                        TopAppBar(
                            title = { Text(if (arabic) section.ar else section.en, fontWeight = FontWeight.Bold) },
                            navigationIcon = { IconButton({ scope.launch { drawer.open() } }) { Icon(Icons.Filled.Menu, "menu", tint = RoxOrange) } },
                            actions = {
                                TextButton({ app.settings.update { it.copy(uiLanguage = if (arabic) "en" else "ar") } }) { Text(if (arabic) "EN" else "ع", color = RoxOrange, fontWeight = FontWeight.Bold) }
                            },
                            colors = TopAppBarDefaults.topAppBarColors(containerColor = RoxBlack, titleContentColor = RoxWhite),
                        )
                    },
                ) { pad ->
                    Box(Modifier.padding(pad).fillMaxSize()) {
                        when (section) {
                            Section.HOME -> HomeScreen(app, actions) { section = it }
                            Section.CONNECT -> ConnectScreen(app)
                            Section.LIBRARY -> LibraryScreen(app)
                            Section.LIVE -> LiveTranslationScreen(app, actions)
                            Section.VOICE -> VoiceScreen(app, actions)
                            Section.SAFE -> SafeVisionScreen(app)
                            Section.AI -> AiSettingsScreen(app)
                            Section.HISTORY -> HistoryScreen(app, actions)
                            Section.CONN_SETTINGS -> ConnectionSettingsScreen(app)
                            Section.LOGS -> LogsScreen(actions)
                        }
                    }
                }
            }
        }
    }
}
