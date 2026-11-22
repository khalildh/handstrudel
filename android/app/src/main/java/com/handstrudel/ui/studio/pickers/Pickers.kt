package com.handstrudel.ui.studio.pickers

import androidx.compose.foundation.background
import com.handstrudel.models.ProgressionCategory
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AddCircleOutline
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Edit
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
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.handstrudel.app.LocalAppServices
import com.handstrudel.models.CHORD_PROGRESSIONS
import com.handstrudel.models.ChordProgression
import com.handstrudel.models.CustomScale
import com.handstrudel.models.SOUNDFONT_INSTRUMENTS
import com.handstrudel.models.Scale
import com.handstrudel.models.ScaleSelection
import com.handstrudel.models.SoundFontInstrument
import com.handstrudel.ui.studio.common.LockBadge
import com.handstrudel.ui.studio.common.PickerCategoryChip
import com.handstrudel.ui.studio.common.PickerRow
import com.handstrudel.ui.studio.common.StudioSheet
import com.handstrudel.ui.studio.common.rememberPaywallHost
import com.handstrudel.ui.theme.LocalStudioPalette

// Picker sheets shared by the Music home sound sheet and the control sheet.
// Ported from iOS `StartOverlayView.swift` (`InstrumentPickerSheet`,
// `ProgressionPickerSheet`, `ScalePickerSheet`). All gate on the single "pro"
// pack, like iOS (`proPaywall`).

private const val PRO = "pro"

/** iOS `GMCategory`, in GM family order (program / 8). */
enum class GMCategory(val displayName: String, val emoji: String) {
    PIANO("Piano", "🎹"), CHROMATIC_PERCUSSION("Mallets", "🔔"), ORGAN("Organ", "🎚️"), GUITAR("Guitar", "🎸"),
    BASS("Bass", "🎻"), STRINGS("Strings", "🎻"), ENSEMBLE("Ensemble", "👥"), BRASS("Brass", "🎺"),
    REED("Reed", "🎷"), PIPE("Pipe", "🪈"), SYNTH_LEAD("Synth Lead", "🌊"), SYNTH_PAD("Synth Pad", "🌫️"),
    SYNTH_FX("Synth FX", "✨"), ETHNIC("Ethnic", "🪕"), PERCUSSIVE("Percussive", "🪘"), SOUND_FX("Sound FX", "💥");

    companion object {
        fun of(program: Int): GMCategory = entries[(program / 8).coerceIn(0, entries.size - 1)]
    }
}

val SoundFontInstrument.gmCategory: GMCategory get() = GMCategory.of(program)

/** iOS picker tabs: every `ProgressionCategory` except custom. */
internal val PICKER_PROGRESSION_CATEGORIES: List<ProgressionCategory> =
    ProgressionCategory.entries.filter { it != ProgressionCategory.CUSTOM }

/** The progression's picker category (iOS `ChordProgression.category`; premium = not essentials). */
val ChordProgression.pickerCategory: ProgressionCategory get() = category

/** iOS `InstrumentPickerSheet`: GM category tabs, PRO-badged locked rows. */
@Composable
fun InstrumentPickerSheet(
    selected: SoundFontInstrument,
    onSelect: (SoundFontInstrument) -> Unit,
    onDismiss: () -> Unit,
) {
    val paywall = rememberPaywallHost()
    val palette = LocalStudioPalette.current
    var category by remember { mutableStateOf(selected.gmCategory) }
    StudioSheet(
        title = "Instrument",
        onDismiss = onDismiss,
        header = {
            Row(
                Modifier.fillMaxWidth().background(palette.surface).horizontalScroll(rememberScrollState())
                    .padding(horizontal = 16.dp, vertical = 10.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                GMCategory.entries.forEach { cat ->
                    PickerCategoryChip(cat.displayName, category == cat) { category = cat }
                }
            }
        },
    ) {
        val rows = SOUNDFONT_INSTRUMENTS.filter { it.gmCategory == category }
        LazyColumn(Modifier.fillMaxWidth()) {
            items(rows, key = { it.id }) { inst ->
                val locked = paywall.isLocked(inst.packId)
                PickerRow(
                    title = inst.name,
                    selected = inst.id == selected.id,
                    locked = locked,
                    modifier = Modifier.testTag("instrument-${inst.id}"),
                ) {
                    if (locked) paywall.open(inst.packId ?: PRO) else { onSelect(inst); onDismiss() }
                }
            }
            if (rows.isEmpty()) {
                item {
                    Text("No instruments in this category yet.", color = palette.muted, modifier = Modifier.padding(20.dp))
                }
            }
        }
    }
}

/** iOS `ProgressionPickerSheet`: category tabs, "N chords" subtitles. */
@Composable
fun ProgressionPickerSheet(
    selected: ChordProgression,
    onSelect: (ChordProgression) -> Unit,
    onDismiss: () -> Unit,
) {
    val paywall = rememberPaywallHost()
    val palette = LocalStudioPalette.current
    var category by remember { mutableStateOf(if (selected.isCustom) ProgressionCategory.ESSENTIALS else selected.pickerCategory) }
    StudioSheet(
        title = "Chord Progression",
        onDismiss = onDismiss,
        header = {
            Row(
                Modifier.fillMaxWidth().background(palette.surface).horizontalScroll(rememberScrollState())
                    .padding(horizontal = 16.dp, vertical = 10.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                PICKER_PROGRESSION_CATEGORIES.forEach { cat ->
                    PickerCategoryChip(cat.displayName, category == cat) { category = cat }
                }
            }
        },
    ) {
        val rows = CHORD_PROGRESSIONS.filter { !it.isCustom && it.pickerCategory == category }
        LazyColumn(Modifier.fillMaxWidth()) {
            items(rows, key = { it.id }) { prog ->
                val locked = paywall.isLocked(prog.packId)
                PickerRow(
                    title = prog.name,
                    subtitle = "${prog.degrees.size} chords",
                    selected = prog.id == selected.id,
                    locked = locked,
                    modifier = Modifier.testTag("progression-${prog.id}"),
                ) {
                    if (locked) paywall.open(prog.packId ?: PRO) else { onSelect(prog); onDismiss() }
                }
            }
            if (rows.isEmpty()) {
                item {
                    Text("No progressions in this category yet.", color = palette.muted, modifier = Modifier.padding(20.dp))
                }
            }
        }
    }
}

/**
 * iOS `ScalePickerSheet`: "Your scales" (create / edit / delete custom
 * scales, Pro only) then "Built-in scales". Selecting applies through
 * [onSelect] and dismisses.
 */
@Composable
fun ScalePickerSheet(onDismiss: () -> Unit) {
    val services = LocalAppServices.current
    val engine = services.engine
    val paywall = rememberPaywallHost()
    val palette = LocalStudioPalette.current
    val selected by engine.selectedScale.collectAsState()
    val key by engine.selectedKey.collectAsState()
    val saved by engine.customScales.collectAsState()
    val hasPro = !paywall.isLocked(PRO)
    var editor by remember { mutableStateOf<EditorRequest?>(null) }

    fun choose(scale: ScaleSelection) { engine.setScale(scale); onDismiss() }

    StudioSheet(title = "Scale", onDismiss = onDismiss, leadingAction = "Done" to onDismiss, trailingAction = null, mediumDetent = true) {
        LazyColumn(Modifier.fillMaxWidth()) {
            item { SectionLabel("Your scales") }
            item {
                Row(
                    Modifier.fillMaxWidth().heightIn(min = 48.dp).testTag("create-custom-scale")
                        .clickable { if (hasPro) editor = EditorRequest(null) else paywall.open(PRO) }
                        .padding(horizontal = 20.dp, vertical = 8.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(10.dp),
                ) {
                    Icon(Icons.Filled.AddCircleOutline, null, tint = palette.accent, modifier = Modifier.size(20.dp))
                    Text("Create Custom Scale", fontSize = 15.sp, color = palette.accent)
                    Spacer(Modifier.weight(1f))
                    if (!hasPro) LockBadge()
                }
            }
            items(saved, key = { it.id }) { scale ->
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Box(Modifier.weight(1f)) {
                        PickerRow(
                            title = scale.name,
                            selected = (selected as? ScaleSelection.Custom)?.scale?.id == scale.id,
                            locked = !hasPro,
                        ) { if (hasPro) choose(ScaleSelection.Custom(scale)) else paywall.open(PRO) }
                    }
                    RowIcon(Icons.Filled.Edit, "Edit", palette.accent, Modifier.testTag("custom-scale-edit-${scale.name}")) {
                        if (hasPro) editor = EditorRequest(scale) else paywall.open(PRO)
                    }
                    RowIcon(Icons.Filled.Delete, "Delete", palette.recording, Modifier.testTag("custom-scale-delete-${scale.name}")) {
                        engine.deleteCustomScale(scale.id)
                        if ((selected as? ScaleSelection.Custom)?.scale?.id == scale.id) engine.setScale(ScaleSelection.PENTATONIC)
                    }
                }
            }
            item { SectionLabel("Built-in scales") }
            items(Scale.entries.toList(), key = { it.rawValue }) { scale ->
                val locked = scale.isPremium && !hasPro
                PickerRow(
                    title = scale.displayName,
                    selected = (selected as? ScaleSelection.BuiltIn)?.scale == scale,
                    locked = locked,
                    modifier = Modifier.testTag("scale-${scale.rawValue}"),
                ) { if (locked) paywall.open(PRO) else choose(ScaleSelection.BuiltIn(scale)) }
            }
        }
    }

    editor?.let { req ->
        CustomScaleEditor(
            key = key,
            existing = req.scale,
            seed = selected.intervals,
            onSave = { scale ->
                if (!hasPro || !engine.saveCustomScale(scale)) false
                else { engine.setScale(ScaleSelection.Custom(scale)); true }
            },
            onDismiss = { editor = null },
        )
    }
}

private data class EditorRequest(val scale: CustomScale?)

@Composable
private fun SectionLabel(text: String) {
    val palette = LocalStudioPalette.current
    Text(
        text, fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = palette.muted,
        modifier = Modifier.padding(start = 20.dp, top = 16.dp, bottom = 4.dp),
    )
}

@Composable
private fun RowIcon(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    label: String,
    tint: androidx.compose.ui.graphics.Color,
    modifier: Modifier = Modifier,
    onClick: () -> Unit,
) {
    Box(
        modifier.size(44.dp).clip(CircleShape).clickable(onClickLabel = label, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) { Icon(icon, label, tint = tint, modifier = Modifier.size(20.dp)) }
}
