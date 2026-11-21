package com.handstrudel.ui.studio.sheet

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.GraphicEq
import androidx.compose.material.icons.filled.Layers
import androidx.compose.material.icons.filled.LibraryMusic
import androidx.compose.material.icons.filled.MusicNote
import androidx.compose.material.icons.filled.Piano
import androidx.compose.material.icons.filled.UnfoldMore
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import com.handstrudel.app.LocalAppServices
import com.handstrudel.models.MusicKey
import com.handstrudel.models.WAVEFORMS
import com.handstrudel.ui.studio.common.PaywallHost
import com.handstrudel.ui.studio.common.SectionHeader
import com.handstrudel.ui.studio.common.StudioPaddedPanel
import com.handstrudel.ui.studio.common.StudioSettingRow
import com.handstrudel.ui.studio.common.StudioSettingsDivider
import com.handstrudel.ui.studio.common.StudioSettingsPanel
import com.handstrudel.ui.studio.home.StudioSettingsHero
import com.handstrudel.ui.studio.pickers.InstrumentPickerSheet
import com.handstrudel.ui.studio.pickers.ProgressionPickerSheet
import com.handstrudel.ui.studio.pickers.ScalePickerSheet
import com.handstrudel.ui.theme.LocalStudioPalette

/** iOS ControlSheet `.sound`: hero, harmony, waveform grid (non-SoundFont path), Presets row. */
@Composable
internal fun SoundTab(paywall: PaywallHost, onOpenPresets: () -> Unit) {
    val services = LocalAppServices.current
    val engine = services.engine
    services.store.state.collectAsState().value
    val mode by engine.mode.collectAsState()
    val radialSF by engine.radialUseSoundFont.collectAsState()
    val splitSF by engine.splitUseSoundFont.collectAsState()
    val scaleSF by engine.scaleUseSoundFont.collectAsState()
    val instrument by engine.selectedSoundFontInstrument.collectAsState()
    val waveform by engine.selectedWaveform.collectAsState()
    val key by engine.selectedKey.collectAsState()
    val scale by engine.selectedScale.collectAsState()
    val progression by engine.chordMelodyProgression.collectAsState()
    val recordingLocked by services.capture.isRecordingLocked.collectAsState()

    val usesSF = ControlSheetLogic.activePathUsesSoundFont(mode, radialSF, splitSF, scaleSF)
    val chordFamily = mode.isChordMelodyFamily

    var showScalePicker by remember { mutableStateOf(false) }
    var showInstrumentPicker by remember { mutableStateOf(false) }
    var showProgressionPicker by remember { mutableStateOf(false) }

    StudioSettingsHero(
        title = if (usesSF) instrument.name else WAVEFORMS.firstOrNull { it.id == waveform }?.name ?: "Synth",
        key = key,
        scale = scale,
        progression = if (chordFamily) progression else null,
        instrument = if (usesSF) instrument else null,
    )

    // ---- Harmony ----
    Column(verticalArrangement = Arrangement.spacedBy(9.dp)) {
        SectionHeader("HARMONY", Icons.Filled.MusicNote, Modifier.padding(start = 3.dp))
        StudioSettingsPanel {
            if (usesSF) {
                StudioSettingRow(
                    "Instrument", Icons.Filled.GraphicEq, value = instrument.name,
                    modifier = Modifier.testTag("settings-instrument-picker"),
                ) { showInstrumentPicker = true }
                StudioSettingsDivider()
            }
            StudioKeyMenu(selection = key, onSelect = { engine.setKey(it) })
            StudioSettingsDivider()
            StudioSettingRow(
                "Scale", Icons.Filled.Piano, value = scale.displayName, modifier = Modifier.testTag("scale-picker"),
            ) { showScalePicker = true }
            if (chordFamily) {
                StudioSettingsDivider()
                StudioSettingRow("Chords", Icons.Filled.LibraryMusic, value = progression.name) { showProgressionPicker = true }
            }
        }
        // TODO(engine): chordMode / setChordMode and circleOfFifthsEnabled / setCircleOfFifths —
        // iOS shows "Chords" and "Circle of 5ths" pill toggles here; the seam has neither.
    }

    // ---- Sound (waveforms) ----
    if (!usesSF) {
        StudioPaddedPanel {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                SectionHeader("SOUND", Icons.Filled.GraphicEq)
                TileGrid(WAVEFORMS, columns = 4) { wf ->
                    val locked = wf.isPremium && paywall.isLocked(wf.packId)
                    EmojiTile(
                        emoji = wf.emoji, label = wf.name, selected = waveform == wf.id, locked = locked,
                        modifier = Modifier.testTag("waveform-${wf.id}"),
                    ) {
                        if (locked) wf.packId?.let(paywall::open) else engine.setWaveform(wf.id)
                    }
                }
            }
        }
    }

    // ---- Presets ----
    StudioSettingsPanel(Modifier.alpha(if (recordingLocked) 0.5f else 1f)) {
        StudioSettingRow(
            "Presets", Icons.Filled.Layers, modifier = Modifier.testTag("settings-presets"),
            onClick = if (recordingLocked) null else onOpenPresets,
        )
    }

    if (showScalePicker) ScalePickerSheet(onDismiss = { showScalePicker = false })
    if (showInstrumentPicker) {
        InstrumentPickerSheet(
            selected = instrument,
            onSelect = { engine.setSoundFontInstrument(it) },
            onDismiss = { showInstrumentPicker = false },
        )
    }
    if (showProgressionPicker) {
        ProgressionPickerSheet(
            selected = progression,
            onSelect = { engine.setProgression(it) },
            onDismiss = { showProgressionPicker = false },
        )
    }
}

/** iOS `StudioKeyMenu`: "Key" row opening a menu of the 12 keys with a checkmark on the current one. */
@Composable
internal fun StudioKeyMenu(selection: MusicKey, onSelect: (MusicKey) -> Unit) {
    val palette = LocalStudioPalette.current
    var expanded by remember { mutableStateOf(false) }
    Box {
        StudioSettingRow(
            "Key", Icons.Filled.MusicNote, value = selection.displayName,
            modifier = Modifier.testTag("studio-key-picker"),
            trailing = Icons.Filled.UnfoldMore,
        ) { expanded = true }
        DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }, modifier = Modifier.align(Alignment.TopEnd)) {
            MusicKey.entries.forEach { key ->
                DropdownMenuItem(
                    text = {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            if (key == selection) Icon(Icons.Filled.Check, null, tint = palette.accent, modifier = Modifier.size(16.dp))
                            else Spacer(Modifier.width(16.dp))
                            Spacer(Modifier.width(10.dp))
                            Text(key.displayName)
                        }
                    },
                    onClick = { onSelect(key); expanded = false },
                    modifier = Modifier.testTag("studio-key-${key.displayName}"),
                )
            }
        }
    }
}
