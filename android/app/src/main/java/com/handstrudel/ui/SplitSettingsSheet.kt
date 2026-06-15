package com.handstrudel.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.handstrudel.engine.EngineController
import com.handstrudel.models.CHORD_PROGRESSIONS
import com.handstrudel.models.ChordProgression
import com.handstrudel.models.MusicKey
import com.handstrudel.models.SOUNDFONT_INSTRUMENTS
import com.handstrudel.models.Scale
import com.handstrudel.models.SoundFontInstrument

private val ACCENT = Color(0xFF00FF9E)
private val SURFACE = Color(0xFF181818)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SplitSettingsSheet(
    engine: EngineController,
    onDismiss: () -> Unit,
) {
    val sheetState = rememberModalBottomSheetState()
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = SURFACE,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 20.dp, vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(24.dp),
        ) {
            SectionLabel("INSTRUMENT")
            InstrumentRow(engine)

            SectionLabel("KEY")
            KeyRow(engine)

            SectionLabel("SCALE")
            ScaleRow(engine)

            SectionLabel("CHORD PROGRESSION")
            ProgressionRow(engine)

            SectionLabel("HANDS")
            SwapHandsRow(engine)
        }
    }
}

@Composable
private fun SectionLabel(text: String) {
    Text(
        text,
        fontSize = 11.sp,
        fontWeight = FontWeight.Bold,
        color = Color.White.copy(alpha = 0.4f),
        letterSpacing = 3.sp,
    )
}

@Composable
private fun KeyRow(engine: EngineController) {
    val selected by engine.selectedKeyFlow.collectAsState()
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .horizontalScroll(rememberScrollState()),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        for (key in MusicKey.values()) {
            Chip(
                label = key.displayName,
                isSelected = key == selected,
                onClick = { engine.selectedKey = key },
            )
        }
    }
}

@Composable
private fun ScaleRow(engine: EngineController) {
    val selected by engine.selectedScaleFlow.collectAsState()
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .horizontalScroll(rememberScrollState()),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        for (scale in Scale.values()) {
            Chip(
                label = scale.displayName,
                isSelected = scale == selected,
                onClick = { engine.selectedScale = scale },
            )
        }
    }
}

@Composable
private fun InstrumentRow(engine: EngineController) {
    val selected by engine.selectedInstrumentFlow.collectAsState()
    LazyRow(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        items(SOUNDFONT_INSTRUMENTS) { instrument ->
            InstrumentChip(
                instrument = instrument,
                isSelected = instrument.id == selected.id,
                onClick = { engine.selectedInstrument = instrument },
            )
        }
    }
}

@Composable
private fun InstrumentChip(instrument: SoundFontInstrument, isSelected: Boolean, onClick: () -> Unit) {
    val bg = if (isSelected) ACCENT.copy(alpha = 0.18f) else Color.White.copy(alpha = 0.06f)
    val fg = if (isSelected) ACCENT else Color.White.copy(alpha = 0.85f)
    Row(
        modifier = Modifier
            .clip(RoundedCornerShape(10.dp))
            .background(bg)
            .clickable { onClick() }
            .padding(horizontal = 12.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Text(instrument.emoji, fontSize = 14.sp)
        Text(instrument.name, color = fg, fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
    }
}

@Composable
private fun ProgressionRow(engine: EngineController) {
    val selected by engine.selectedProgressionFlow.collectAsState()
    LazyRow(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        items(CHORD_PROGRESSIONS) { prog ->
            ProgressionChip(
                progression = prog,
                isSelected = prog.id == selected.id,
                onClick = { engine.selectedProgression = prog },
            )
        }
    }
}

@Composable
private fun SwapHandsRow(engine: EngineController) {
    val swap by engine.swapHandsFlow.collectAsState()
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(
                "Swap hands",
                fontSize = 14.sp,
                fontWeight = FontWeight.SemiBold,
                color = Color.White,
            )
            Text(
                if (swap) "Right hand → chord, left → melody" else "Left hand → chord, right → melody",
                fontSize = 11.sp,
                color = Color.White.copy(alpha = 0.55f),
            )
        }
        Switch(
            checked = swap,
            onCheckedChange = { engine.swapHands = it },
            colors = SwitchDefaults.colors(
                checkedThumbColor = Color.Black,
                checkedTrackColor = ACCENT,
                uncheckedThumbColor = Color.White.copy(alpha = 0.6f),
                uncheckedTrackColor = Color.White.copy(alpha = 0.15f),
            ),
        )
    }
}

@Composable
private fun Chip(label: String, isSelected: Boolean, onClick: () -> Unit) {
    val bg = if (isSelected) ACCENT.copy(alpha = 0.18f) else Color.White.copy(alpha = 0.06f)
    val fg = if (isSelected) ACCENT else Color.White.copy(alpha = 0.85f)
    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(10.dp))
            .background(bg)
            .clickable { onClick() }
            .padding(horizontal = 12.dp, vertical = 8.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(label, color = fg, fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
    }
}

@Composable
private fun ProgressionChip(progression: ChordProgression, isSelected: Boolean, onClick: () -> Unit) {
    val bg = if (isSelected) ACCENT.copy(alpha = 0.18f) else Color.White.copy(alpha = 0.06f)
    val fg = if (isSelected) ACCENT else Color.White.copy(alpha = 0.85f)
    Row(
        modifier = Modifier
            .clip(RoundedCornerShape(10.dp))
            .background(bg)
            .clickable { onClick() }
            .padding(horizontal = 12.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Text(progression.emoji, fontSize = 14.sp)
        Text(progression.name, color = fg, fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
    }
}
