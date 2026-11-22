package com.handstrudel.ui.studio.sheet

import com.handstrudel.ui.theme.StudioIcons

import com.handstrudel.ui.theme.StudioFonts
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Audiotrack
import androidx.compose.material.icons.filled.Contrast
import androidx.compose.material.icons.filled.ExpandLess
import androidx.compose.material.icons.filled.ExpandMore
import androidx.compose.material.icons.filled.GridOn
import androidx.compose.material.icons.filled.Headphones
import androidx.compose.material.icons.filled.LibraryMusic
import androidx.compose.material.icons.filled.MoreHoriz
import androidx.compose.material.icons.filled.MusicNote
import androidx.compose.material.icons.filled.PanTool
import androidx.compose.material.icons.filled.Piano
import androidx.compose.material.icons.filled.Remove
import androidx.compose.material.icons.filled.TouchApp
import androidx.compose.material.icons.filled.TrackChanges
import androidx.compose.material.icons.filled.Waves
import androidx.compose.material.icons.outlined.Piano
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.handstrudel.app.LocalAppServices
import com.handstrudel.engine.StudioMode
import com.handstrudel.ui.nav.LocalAppNavigator
import com.handstrudel.ui.studio.common.SectionHeader
import com.handstrudel.ui.studio.common.StudioPaddedPanel
import com.handstrudel.ui.studio.home.StudioInputPicker
import com.handstrudel.ui.theme.LocalStudioPalette

/** iOS ControlSheet `.play`: play input, other modes, and the per-mode PERFORMANCE section. */
@Composable
internal fun PlayTab(onOpenLearnPicker: () -> Unit) {
    val services = LocalAppServices.current
    val engine = services.engine
    val navigator = LocalAppNavigator.current
    val playInput by engine.playInput.collectAsState()
    val mode by engine.mode.collectAsState()

    StudioPaddedPanel {
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            SectionHeader("PLAY INPUT", Icons.Filled.TouchApp)
            StudioInputPicker(selection = playInput, onChange = navigator::changePlayInput)
        }
    }
    StudioPaddedPanel { OtherModesPicker(mode, onOpenLearnPicker) }
    if (ControlSheetLogic.hasModeContextControls(mode)) {
        StudioPaddedPanel {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                SectionHeader("PERFORMANCE", Icons.Filled.PanTool)
                ModeSection(mode)
            }
        }
    }
}

private data class ModeChoice(val label: String, val icon: ImageVector, val mode: StudioMode)

private val MODE_ROWS: List<List<ModeChoice>> = listOf(
    listOf(
        ModeChoice("Split", Icons.Filled.Contrast, StudioMode.SPLIT),
        ModeChoice("Scale", Icons.Filled.MusicNote, StudioMode.SCALE),
        ModeChoice("Radial", Icons.Filled.TrackChanges, StudioMode.RADIAL),
    ),
    listOf(
        ModeChoice("Chord+Melody", Icons.Filled.PanTool, StudioMode.CHORD_MELODY),
        ModeChoice("SoundFont", Icons.Filled.Piano, StudioMode.SOUNDFONT),
        ModeChoice("Melodic", Icons.Outlined.Piano, StudioMode.MELODIC),
    ),
    listOf(
        ModeChoice("Flow", StudioIcons.Waveform, StudioMode.FLOW),
        ModeChoice("Hybrid", Icons.Filled.Waves, StudioMode.HYBRID),
        ModeChoice("Lead", Icons.Filled.Audiotrack, StudioMode.LEAD),
    ),
    listOf(
        ModeChoice("Grid", Icons.Filled.GridOn, StudioMode.GRID),
        ModeChoice("Drums", Icons.Filled.Headphones, StudioMode.DRUM),
        ModeChoice("Learn", Icons.Filled.LibraryMusic, StudioMode.LEARN),
    ),
)

/** iOS `otherModesPickerSection`: collapsed by default in Split/Scale. */
@Composable
internal fun OtherModesPicker(mode: StudioMode, onOpenLearnPicker: () -> Unit) {
    val engine = LocalAppServices.current.engine
    val palette = LocalStudioPalette.current
    var expanded by rememberSaveable { mutableStateOf(ControlSheetLogic.otherModesInitiallyExpanded(mode)) }
    val modeName = ControlSheetLogic.modeName(mode)

    fun setMode(target: StudioMode) {
        engine.switchMode(target)
        if (target == StudioMode.LEARN && engine.learn.value.currentSongId == null) onOpenLearnPicker()
    }

    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Row(
            Modifier.fillMaxWidth().heightIn(min = 44.dp)
                .clickable(role = Role.Button) { expanded = !expanded }
                .semantics {
                    contentDescription = "Other modes"
                    stateDescription = if (expanded) "Expanded, $modeName" else "Collapsed, $modeName"
                }
                .testTag("music-other-modes"),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Icon(Icons.Filled.MoreHoriz, null, tint = palette.ink, modifier = Modifier.size(20.dp))
            Text("Other modes", fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = palette.ink)
            Spacer(Modifier.weight(1f).widthIn(min = 8.dp))
            Text(modeName, fontSize = 12.sp, color = palette.muted)
            Icon(if (expanded) Icons.Filled.ExpandLess else Icons.Filled.ExpandMore, null, tint = palette.ink, modifier = Modifier.size(18.dp))
        }
        if (expanded) {
            MODE_ROWS.forEach { row ->
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    row.forEach { choice ->
                        ModeButton(choice, active = choice.mode == mode, modifier = Modifier.weight(1f)) { setMode(choice.mode) }
                    }
                }
            }
        }
    }
}

@Composable
private fun ModeButton(choice: ModeChoice, active: Boolean, modifier: Modifier, onClick: () -> Unit) {
    val palette = LocalStudioPalette.current
    val shape = RoundedCornerShape(12.dp)
    Column(
        modifier.height(48.dp).clip(shape)
            .background(
                if (active) Brush.verticalGradient(listOf(palette.accent.copy(alpha = 0.2f), palette.accent.copy(alpha = 0.08f)))
                else Brush.verticalGradient(listOf(palette.ink.copy(alpha = 0.04f), palette.ink.copy(alpha = 0.02f))),
            )
            .border(if (active) 1.5.dp else 0.5.dp, if (active) palette.accent.copy(alpha = 0.5f) else palette.ink.copy(alpha = 0.06f), shape)
            .clickable(role = Role.Button, onClick = onClick)
            .semantics { selected = active }
            .testTag("mode-${choice.mode.raw}"),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(3.dp, Alignment.CenterVertically),
    ) {
        Icon(choice.icon, null, tint = if (active) palette.accent else palette.ink.copy(alpha = 0.5f), modifier = Modifier.size(18.dp))
        Text(
            choice.label, fontSize = 11.sp, fontWeight = FontWeight.SemiBold, fontFamily = StudioFonts.Rounded, maxLines = 1,
            color = if (active) palette.accent else palette.ink.copy(alpha = 0.6f),
        )
    }
}

/** iOS `modeSection`. */
@Composable
internal fun ModeSection(mode: StudioMode) {
    val engine = LocalAppServices.current.engine
    val palette = LocalStudioPalette.current
    val swap by engine.chordMelodySwapHands.collectAsState()
    val autoStrum by engine.chordMelodyAutoStrum.collectAsState()
    val padVolume by engine.chordMelodyPadVolume.collectAsState()
    val radialSF by engine.radialUseSoundFont.collectAsState()
    val splitSF by engine.splitUseSoundFont.collectAsState()
    val scaleSF by engine.scaleUseSoundFont.collectAsState()

    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        when (mode) {
            StudioMode.CHORD_MELODY, StudioMode.RADIAL, StudioMode.SPLIT, StudioMode.SCALE -> {
                QuantizeRow()
                Column(Modifier.padding(top = 2.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    Text(ControlSheetLogic.chordFamilyDescription(mode), fontSize = 13.sp, color = palette.muted)
                    CustomProgressionEditor()
                    SheetToggle("Swap hands (right = chords)", swap) { engine.setSwapHands(it) }
                    SheetToggle("Auto-strum (re-articulate on each beat)", autoStrum) { engine.setAutoStrum(it) }
                    if (mode != StudioMode.CHORD_MELODY) {
                        val useSF = when (mode) {
                            StudioMode.RADIAL -> radialSF
                            StudioMode.SPLIT -> splitSF
                            else -> scaleSF
                        }
                        SheetToggle("Voice through SoundFont", useSF, Modifier.testTag("settings-voice-soundfont")) {
                            engine.setUseSoundFont(mode, it)
                        }
                    }
                    PadVolumeRow(padVolume) { engine.setPadVolume(it) }
                }
            }
            StudioMode.SOUNDFONT -> {
                Column(Modifier.padding(top = 2.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    Text(
                        "The chord hand holds the harmony. The melody hand plays notes from the current chord.",
                        fontSize = 13.sp, color = palette.muted,
                    )
                    SheetToggle("Swap hands (right = chords)", swap) { engine.setSwapHands(it) }
                    SheetToggle("Auto-strum (re-articulate on each beat)", autoStrum) { engine.setAutoStrum(it) }
                    PadVolumeRow(padVolume) { engine.setPadVolume(it) }
                }
            }
            StudioMode.GRID -> GridControls()
            else -> Unit
        }
    }
}

@Composable
private fun PadVolumeRow(volume: Double, onChange: (Double) -> Unit) {
    val palette = LocalStudioPalette.current
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("Pad volume", fontSize = 13.sp, fontWeight = FontWeight.Medium, fontFamily = StudioFonts.Rounded, color = palette.ink.copy(alpha = 0.8f))
            Spacer(Modifier.weight(1f))
            Text(
                ControlSheetLogic.padVolumePercent(volume), fontSize = 11.sp, fontFamily = StudioFonts.Mono,
                color = palette.muted, modifier = Modifier.testTag("settings-pad-volume-value"),
            )
        }
        SheetSlider(volume.toFloat(), 0f..0.6f, Modifier.testTag("settings-pad-volume")) { onChange(it.toDouble()) }
    }
}

/** iOS `quantizeRow`: "Sync to beat" toggle plus the 1/4 · 1/8 · 1/16 grid choice. */
@Composable
private fun QuantizeRow() {
    val engine = LocalAppServices.current.engine
    val palette = LocalStudioPalette.current
    val enabled by engine.quantizeEnabled.collectAsState()
    val div by engine.quantizeDiv.collectAsState()
    Column(Modifier.padding(top = 2.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
        SheetToggle("Sync to beat (snap notes to the grid)", enabled, Modifier.testTag("settings-quantize")) { engine.setQuantizeEnabled(it) }
        if (enabled) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Text("Grid", fontSize = 11.sp, fontWeight = FontWeight.Medium, fontFamily = StudioFonts.Rounded, color = palette.muted)
                listOf(4 to "1/4", 8 to "1/8", 16 to "1/16").forEach { (d, label) ->
                    CapsuleChoice(label, div == d, monospaced = true) { engine.setQuantizeDiv(d) }
                }
            }
        }
    }
}

/** iOS grid branch of `modeSection`: quantize, hint, Range 1/2/3, Oct −/+ (1…6). */
@Composable
private fun GridControls() {
    val engine = LocalAppServices.current.engine
    val palette = LocalStudioPalette.current
    val range by engine.gridOctaveRange.collectAsState()
    val octave by engine.gridBaseOctave.collectAsState()
    QuantizeRow()
    Text(
        "Pinch to play notes. Move hand up/down to change pitch.",
        fontSize = 11.sp, fontFamily = StudioFonts.Rounded, color = palette.muted, modifier = Modifier.padding(top = 2.dp),
    )
    Row(Modifier.fillMaxWidth().padding(top = 4.dp), verticalAlignment = Alignment.CenterVertically) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            Text("Range", fontSize = 11.sp, fontWeight = FontWeight.Medium, fontFamily = StudioFonts.Rounded, color = palette.muted)
            listOf(1, 2, 3).forEach { r ->
                val selected = range == r
                Box(
                    Modifier.size(40.dp).clip(CircleShape).clickable(role = Role.Button) { engine.setGridOctaveRange(r) }
                        .semantics { this.selected = selected }.testTag("grid-range-$r"),
                    contentAlignment = Alignment.Center,
                ) {
                    Box(
                        Modifier.size(28.dp).clip(CircleShape)
                            .background(if (selected) palette.accent.copy(alpha = 0.15f) else palette.ink.copy(alpha = 0.04f)),
                        contentAlignment = Alignment.Center,
                    ) {
                        Text("$r", fontSize = 12.sp, fontWeight = FontWeight.Bold, fontFamily = StudioFonts.Rounded, color = if (selected) palette.accent else palette.muted)
                    }
                }
            }
        }
        Spacer(Modifier.weight(1f))
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
            Text("Oct", fontSize = 11.sp, fontWeight = FontWeight.Medium, fontFamily = StudioFonts.Rounded, color = palette.muted)
            CircleIconButton(Icons.Filled.Remove, "Lower octave", size = 24.dp, iconSize = 10.dp, tint = palette.muted) {
                if (octave > 1) engine.setGridBaseOctave(octave - 1)
            }
            Text(
                "$octave", fontSize = 13.sp, fontWeight = FontWeight.Bold, fontFamily = StudioFonts.Mono,
                color = palette.accent, modifier = Modifier.width(20.dp).testTag("grid-octave"),
            )
            CircleIconButton(Icons.Filled.Add, "Raise octave", size = 24.dp, iconSize = 10.dp, tint = palette.muted) {
                if (octave < 6) engine.setGridBaseOctave(octave + 1)
            }
        }
    }
}

/** iOS `customProgressionEditor`: free-text field + "Set" (disabled until something parses). */
@Composable
internal fun CustomProgressionEditor() {
    val engine = LocalAppServices.current.engine
    val palette = LocalStudioPalette.current
    val focus = LocalFocusManager.current
    var text by rememberSaveable { mutableStateOf("") }
    val preview = ControlSheetLogic.customProgression(text)
    fun apply() {
        val parsed = ControlSheetLogic.customProgression(text) ?: return
        engine.setProgression(parsed)
        focus.clearFocus()
    }
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text("Custom chord progression", fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = palette.ink)
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            BasicTextField(
                value = text,
                onValueChange = { text = it },
                singleLine = true,
                textStyle = TextStyle(fontSize = 15.sp, fontFamily = StudioFonts.Mono, color = palette.ink),
                cursorBrush = SolidColor(palette.accent),
                keyboardOptions = KeyboardOptions(
                    capitalization = KeyboardCapitalization.None, autoCorrectEnabled = false, imeAction = ImeAction.Go,
                ),
                keyboardActions = KeyboardActions(onGo = { apply() }),
                modifier = Modifier.weight(1f).heightIn(min = 44.dp).clip(RoundedCornerShape(10.dp))
                    .background(palette.background).testTag("progression-input"),
                decorationBox = { inner ->
                    Box(Modifier.padding(horizontal = 12.dp).heightIn(min = 44.dp), contentAlignment = Alignment.CenterStart) {
                        if (text.isEmpty()) Text("I V vi IV", fontSize = 15.sp, fontFamily = StudioFonts.Mono, color = palette.muted)
                        inner()
                    }
                },
            )
            Box(
                Modifier.heightIn(min = 44.dp).widthIn(min = 44.dp).clip(RoundedCornerShape(10.dp))
                    .clickable(enabled = preview != null, role = Role.Button) { apply() }
                    .testTag("progression-set"),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    "Set", fontSize = 15.sp, fontWeight = FontWeight.SemiBold,
                    color = if (preview != null) palette.accent else palette.muted.copy(alpha = 0.5f),
                )
            }
        }
    }
}
