package com.rox.gameai.ui

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.rox.gameai.RoxApp
import com.rox.gameai.core.DisplayMode

/** Shows the PROCESSED frame (Safe Vision already applied) + translations drawn over the video. */
@Composable
fun ProcessedVideo(app: RoxApp, modifier: Modifier = Modifier) {
    val frame by app.engine.frame.collectAsState()
    val overlays by app.engine.overlays.collectAsState()
    val status by app.engine.status.collectAsState()
    val settings by app.settings.state.collectAsState()
    Box(modifier.fillMaxWidth().aspectRatio(16f / 9f).clip(RoundedCornerShape(14.dp)).background(Color.Black), contentAlignment = Alignment.Center) {
        val f = frame
        if (!status.running) {
            Text(t("No stream — press AUTO START", "لا يوجد بث — اضغط AUTO START"), color = RoxGrey)
        } else if (!status.inAppDisplay) {
            Text(t("Processing PS Remote Play in the background.\nTranslations appear in the floating window.", "تتم معالجة PS Remote Play في الخلفية.\nتظهر الترجمة في النافذة العائمة."), color = RoxGrey, modifier = Modifier.padding(16.dp))
        } else if (f == null) {
            Text(t("Waiting for video…", "بانتظار الفيديو…"), color = RoxGrey)
        } else {
            val img = remember(f.seq) { f.bitmap.asImageBitmap() }
            Image(img, null, Modifier.fillMaxSize(), contentScale = ContentScale.Fit)
            if (settings.displayMode == DisplayMode.ON_VIDEO && status.frameW > 0) {
                BoxWithConstraints(Modifier.fillMaxSize()) {
                    val density = LocalDensity.current
                    val sx = constraints.maxWidth.toFloat() / status.frameW
                    val sy = constraints.maxHeight.toFloat() / status.frameH
                    overlays.forEach { o ->
                        val x: Dp = with(density) { (o.rect.left * sx).toDp() }
                        val y: Dp = with(density) { (o.rect.top * sy).toDp() }
                        Text(
                            (if (o.speaker.isNotBlank()) "${o.speaker}: " else "") + o.translated,
                            color = RoxWhite, fontSize = 11.sp, fontWeight = FontWeight.Bold,
                            modifier = Modifier.offset(x, y).widthIn(max = 260.dp)
                                .background(Color(0xD90A0A0A), RoundedCornerShape(6.dp)).padding(horizontal = 6.dp, vertical = 2.dp),
                        )
                    }
                }
            }
            if (status.isTestSource) {
                Text("TEST VIDEO", color = RoxBlack, fontSize = 10.sp, fontWeight = FontWeight.Black,
                    modifier = Modifier.align(Alignment.TopEnd).padding(8.dp).background(RoxOrange, RoundedCornerShape(4.dp)).padding(horizontal = 6.dp, vertical = 2.dp))
            }
        }
    }
}
