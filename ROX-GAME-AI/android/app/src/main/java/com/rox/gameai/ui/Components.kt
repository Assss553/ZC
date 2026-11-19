@file:OptIn(ExperimentalMaterial3Api::class)

package com.rox.gameai.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

@Composable
fun RoxCard(title: String? = null, modifier: Modifier = Modifier, content: @Composable ColumnScope.() -> Unit) {
    Column(
        modifier.fillMaxWidth().padding(vertical = 6.dp)
            .background(RoxPanel, RoundedCornerShape(16.dp)).border(1.dp, RoxLine, RoundedCornerShape(16.dp)).padding(14.dp),
    ) {
        if (title != null) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(Modifier.size(width = 4.dp, height = 16.dp).background(RoxOrange, RoundedCornerShape(2.dp)))
                Spacer(Modifier.width(8.dp))
                Text(title, style = MaterialTheme.typography.titleMedium, color = RoxWhite)
            }
            Spacer(Modifier.padding(4.dp))
        }
        content()
    }
}

/** ok: true = green, false = red, null = neutral */
@Composable
fun StatusTile(label: String, value: String, ok: Boolean?, modifier: Modifier = Modifier) {
    Column(modifier.padding(4.dp).background(RoxPanel2, RoundedCornerShape(12.dp)).padding(10.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.size(8.dp).background(when (ok) { true -> RoxGreen; false -> RoxRed; null -> RoxOrange }, CircleShape))
            Spacer(Modifier.width(6.dp))
            Text(label, style = MaterialTheme.typography.labelSmall, color = RoxGrey)
        }
        Text(value, color = RoxWhite, fontWeight = FontWeight.Bold, fontSize = 14.sp, maxLines = 2)
    }
}

@Composable
fun SettingSwitch(label: String, checked: Boolean, sub: String? = null, onChange: (Boolean) -> Unit) {
    Row(Modifier.fillMaxWidth().padding(vertical = 4.dp), verticalAlignment = Alignment.CenterVertically) {
        Column(Modifier.weight(1f)) {
            Text(label, color = RoxWhite)
            if (sub != null) Text(sub, color = RoxGrey, fontSize = 12.sp)
        }
        Switch(checked, onChange, colors = SwitchDefaults.colors(checkedThumbColor = RoxBlack, checkedTrackColor = RoxOrange, uncheckedThumbColor = RoxGrey, uncheckedTrackColor = RoxPanel2, uncheckedBorderColor = RoxLine))
    }
}

@Composable
fun SettingSlider(label: String, value: Float, range: ClosedFloatingPointRange<Float>, valueText: String, steps: Int = 0, onChange: (Float) -> Unit) {
    Column(Modifier.fillMaxWidth().padding(vertical = 4.dp)) {
        Row { Text(label, color = RoxWhite, modifier = Modifier.weight(1f)); Text(valueText, color = RoxOrange, fontWeight = FontWeight.Bold) }
        Slider(value, onChange, valueRange = range, steps = steps, colors = SliderDefaults.colors(thumbColor = RoxOrange, activeTrackColor = RoxOrange, inactiveTrackColor = RoxPanel2))
    }
}

@Composable
fun <T> ChipRow(options: List<T>, selected: T?, label: @Composable (T) -> String, onSelect: (T) -> Unit) {
    Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        options.forEach { o ->
            FilterChip(
                selected = o == selected, onClick = { onSelect(o) }, label = { Text(label(o)) },
                colors = FilterChipDefaults.filterChipColors(selectedContainerColor = RoxOrange, selectedLabelColor = RoxBlack, containerColor = RoxPanel2, labelColor = RoxWhite),
            )
        }
    }
}

@Composable
fun Note(text: String, color: Color = RoxGrey) { Text(text, color = color, fontSize = 12.sp, modifier = Modifier.padding(vertical = 4.dp)) }
