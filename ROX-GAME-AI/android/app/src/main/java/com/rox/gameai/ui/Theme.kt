package com.rox.gameai.ui

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Typography
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp

val RoxBlack = Color(0xFF0A0A0A)
val RoxPanel = Color(0xFF151515)
val RoxPanel2 = Color(0xFF1E1E1E)
val RoxLine = Color(0xFF2C2C2C)
val RoxOrange = Color(0xFFFF7A00)
val RoxOrangeDark = Color(0xFF8A4200)
val RoxWhite = Color(0xFFFFFFFF)
val RoxGrey = Color(0xFFB5B5B5)
val RoxRed = Color(0xFFE5484D)
val RoxGreen = Color(0xFF3CCB7F)

// Every slot is set explicitly so no default (purple/blue) Material colour can appear.
private val scheme = darkColorScheme(
    primary = RoxOrange, onPrimary = RoxBlack, primaryContainer = RoxOrangeDark, onPrimaryContainer = RoxWhite, inversePrimary = RoxOrange,
    secondary = RoxOrange, onSecondary = RoxBlack, secondaryContainer = RoxPanel2, onSecondaryContainer = RoxWhite,
    tertiary = RoxWhite, onTertiary = RoxBlack, tertiaryContainer = RoxPanel2, onTertiaryContainer = RoxWhite,
    background = RoxBlack, onBackground = RoxWhite, surface = RoxBlack, onSurface = RoxWhite,
    surfaceVariant = RoxPanel, onSurfaceVariant = RoxGrey, surfaceTint = RoxBlack, inverseSurface = RoxWhite, inverseOnSurface = RoxBlack,
    error = RoxRed, onError = RoxWhite, errorContainer = Color(0xFF3A1214), onErrorContainer = RoxWhite,
    outline = RoxLine, outlineVariant = RoxLine, scrim = Color(0xCC000000),
    surfaceBright = RoxPanel2, surfaceContainer = RoxPanel, surfaceContainerHigh = RoxPanel2, surfaceContainerHighest = Color(0xFF262626),
    surfaceContainerLow = RoxPanel, surfaceContainerLowest = RoxBlack, surfaceDim = RoxBlack,
)

private val type = Typography(
    headlineSmall = TextStyle(fontWeight = FontWeight.Black, fontSize = 22.sp, letterSpacing = 1.sp),
    titleMedium = TextStyle(fontWeight = FontWeight.Bold, fontSize = 16.sp),
    bodyMedium = TextStyle(fontSize = 14.sp),
    labelSmall = TextStyle(fontWeight = FontWeight.Medium, fontSize = 11.sp, letterSpacing = 0.5.sp),
)

val LocalArabic = compositionLocalOf { true }

/** Bilingual text: Arabic (default, RTL) or English. */
@Composable
fun t(en: String, ar: String): String = if (LocalArabic.current) ar else en

@Composable
fun RoxTheme(content: @Composable () -> Unit) = MaterialTheme(colorScheme = scheme, typography = type, content = content)
