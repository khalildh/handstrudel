package com.handstrudel.ui.studio.sheet

import com.handstrudel.ui.theme.StudioIcons
import com.handstrudel.ui.theme.StudioFonts
import androidx.compose.foundation.background
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
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.IosShare
import androidx.compose.material.icons.filled.Headphones
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.PlayCircle
import androidx.compose.material.icons.filled.Remove
import androidx.compose.material.icons.filled.StopCircle
import androidx.compose.material.icons.filled.Timer
import androidx.compose.material.icons.filled.Tune
import androidx.compose.material.icons.automirrored.filled.VolumeOff
import androidx.compose.material.icons.automirrored.filled.VolumeUp
import androidx.compose.material.icons.outlined.LockOpen
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.Layout
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.handstrudel.app.LocalAppServices
import kotlinx.coroutines.withContext
import kotlinx.coroutines.launch
import kotlinx.coroutines.Dispatchers
import com.handstrudel.engine.DrumTrackState
import com.handstrudel.engine.SavedLoop
import com.handstrudel.models.DRUM_LOOPS
import com.handstrudel.models.PARAM_DEFS
import com.handstrudel.models.ParamDef
import com.handstrudel.ui.studio.common.PaywallHost
import com.handstrudel.ui.studio.common.SectionHeader
import com.handstrudel.ui.studio.common.StudioPaddedPanel
import com.handstrudel.ui.theme.LocalStudioPalette
import java.util.UUID

private val ORANGE = Color(0xFFFF9500)

/** iOS ControlSheet `.mix`: BPM + params (not chord family), Drums 1 / Drums 2, loops. */
@Composable
internal fun MixTab(paywall: PaywallHost) {
    val services = LocalAppServices.current
    val engine = services.engine
    services.store.state.collectAsState().value
    val mode by engine.mode.collectAsState()
    val drums1 by engine.drumTrack1.collectAsState()
    val drums2 by engine.drumTrack2.collectAsState()
    val loops by engine.savedLoops.collectAsState()

    if (!mode.isChordMelodyFamily) {
        StudioPaddedPanel { BpmSection() }
        StudioPaddedPanel { ParamsSection() }
    }
    StudioPaddedPanel { DrumTrackSection("DRUMS 1", 1, drums1, paywall) }
    StudioPaddedPanel { DrumTrackSection("DRUMS 2", 2, drums2, paywall) }
    if (loops.isNotEmpty()) StudioPaddedPanel { LoopsSection(loops) }
    // Snippets / track sections are unreachable in 1.0.1 (no snippet capture), so they're not ported.
}

/** iOS `bpmSection`. */
@Composable
internal fun BpmSection() {
    val engine = LocalAppServices.current.engine
    val palette = LocalStudioPalette.current
    val manualBPM by engine.manualBPM.collectAsState()
    val bpmIsMapped = engine.bpmIsMapped
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        SectionHeader("BPM", StudioIcons.Metronome)
        Text(
            "${ControlSheetLogic.roundedInt(manualBPM)}",
            fontSize = 32.sp, fontWeight = FontWeight.Bold, fontFamily = StudioFonts.Mono, color = palette.accent,
            textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth().testTag("settings-bpm-value"),
        )
        if (bpmIsMapped) {
            Text("Controlled by hand", fontSize = 11.sp, fontFamily = StudioFonts.Rounded, color = palette.muted)
        } else {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                CircleIconButton(Icons.Filled.Remove, "Decrease BPM") { engine.setManualBPM(maxOf(50.0, manualBPM - 1)) }
                SheetSlider(manualBPM.toFloat(), 50f..205f, Modifier.weight(1f), steps = 154) {
                    engine.setManualBPM(ControlSheetLogic.stepped(it.toDouble()))
                }
                CircleIconButton(Icons.Filled.Add, "Increase BPM") { engine.setManualBPM(minOf(205.0, manualBPM + 1)) }
            }
        }
    }
}

/** iOS `paramsSection` / `paramRow`. */
@Composable
internal fun ParamsSection() {
    val engine = LocalAppServices.current.engine
    val locked by engine.lockedParams.collectAsState()
    val smoothed by engine.smoothedParams.collectAsState()
    val manual by engine.manualValues.collectAsState()
    val mapped = engine.mappedParamIds.toSet().ifEmpty { ControlSheetLogic.DEFAULT_MAPPED_PARAM_IDS }
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        SectionHeader("PARAMETERS", StudioIcons.SliderHorizontal3)
        PARAM_DEFS.filter { it.id in mapped }.forEach { def ->
            val isLocked = def.id in locked
            val current = if (isLocked) manual[def.id] ?: def.defaultValue else smoothed[def.id] ?: def.defaultValue
            ParamRow(
                def = def,
                isLocked = isLocked,
                value = current,
                onToggleLock = { engine.toggleLock(def.id) },
                onValue = { v -> engine.setManualValue(def.id, v) },
            )
        }
    }
}

@Composable
private fun ParamRow(def: ParamDef, isLocked: Boolean, value: Double, onToggleLock: () -> Unit, onValue: (Double) -> Unit) {
    val palette = LocalStudioPalette.current
    Row(
        Modifier.fillMaxWidth().heightIn(min = 32.dp).testTag("param-${def.id}"),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Box(
            Modifier.size(32.dp).clip(CircleShape).clickable(role = Role.Button, onClick = onToggleLock)
                .semantics { contentDescription = if (isLocked) "Unlock ${def.label}" else "Lock ${def.label}" },
            contentAlignment = Alignment.Center,
        ) {
            Box(
                Modifier.size(24.dp).clip(CircleShape).background(if (isLocked) ORANGE.copy(alpha = 0.2f) else Color.Transparent),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    if (isLocked) Icons.Filled.Lock else Icons.Outlined.LockOpen, null,
                    tint = if (isLocked) ORANGE else palette.muted.copy(alpha = 0.4f), modifier = Modifier.size(13.dp),
                )
            }
        }
        Text(
            def.label, fontSize = 13.sp, fontWeight = FontWeight.Medium, fontFamily = StudioFonts.Rounded,
            color = if (isLocked) ORANGE else palette.ink, maxLines = 1, modifier = Modifier.width(58.dp),
        )
        if (isLocked) {
            SheetSlider(value.toFloat(), def.min.toFloat()..def.max.toFloat(), Modifier.weight(1f), tint = ORANGE) { onValue(it.toDouble()) }
        } else {
            val normalized = ((value - def.min) / (def.max - def.min)).coerceIn(0.0, 1.0).toFloat()
            Box(Modifier.weight(1f).height(8.dp).clip(CircleShape).background(palette.ink.copy(alpha = 0.08f))) {
                Box(Modifier.fillMaxWidth(normalized).height(8.dp).clip(CircleShape).background(palette.accent.copy(alpha = 0.5f)))
            }
        }
        Text(
            ControlSheetLogic.formatParam(def, value), fontSize = 12.sp, fontWeight = FontWeight.Medium,
            fontFamily = StudioFonts.Mono, color = palette.muted, textAlign = TextAlign.End, maxLines = 1,
            modifier = Modifier.width(56.dp),
        )
    }
}

/** iOS `drumTrackSection(label:loop:volume:bpm:)`. */
@Composable
internal fun DrumTrackSection(label: String, track: Int, state: DrumTrackState, paywall: PaywallHost) {
    val engine = LocalAppServices.current.engine
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        SectionHeader(label, StudioIcons.BeatsHeadphones, notAvailable = DRUM_LOOPS.any { it.isPremium && paywall.isLocked(it.packId) })
        TileGrid(DRUM_LOOPS, columns = 3) { loop ->
            val locked = loop.isPremium && paywall.isLocked(loop.packId)
            EmojiTile(
                emoji = loop.emoji, label = loop.name, selected = state.loopId == loop.id, locked = locked,
                emojiSize = 22.sp, modifier = Modifier.testTag("drums$track-${loop.id}"),
            ) {
                if (locked) loop.packId?.let(paywall::open) else engine.setDrumLoop(track, loop.id)
            }
        }
        if (state.loopId != "none") {
            LabeledSliderRow("VOL", ControlSheetLogic.percent(state.volume), state.volume.toFloat(), 0.2f..2.0f) {
                engine.setDrumVolume(track, it.toDouble())
            }
            LabeledSliderRow("BPM", "${ControlSheetLogic.roundedInt(state.bpm)}", state.bpm.toFloat(), 40f..240f, steps = 199) {
                engine.setDrumBPM(track, ControlSheetLogic.stepped(it.toDouble()))
            }
        }
    }
}

/** iOS ControlSheet `loopsSection`, plus the shelf's mute / gain / rename for captured loops. */
@Composable
internal fun LoopsSection(loops: List<SavedLoop>) {
    val engine = LocalAppServices.current.engine
    val palette = LocalStudioPalette.current
    val playing by engine.playingLoopIds.collectAsState()
    val bars by engine.loopRecordingBars.collectAsState()
    var renameTarget by remember { mutableStateOf<SavedLoop?>(null) }
    var message by remember { mutableStateOf<String?>(null) }
    val context = androidx.compose.ui.platform.LocalContext.current
    val scope = androidx.compose.runtime.rememberCoroutineScope()
    val share = com.handstrudel.ui.capture.rememberShareCopyLauncher()
    var exporting by remember { mutableStateOf(false) }

    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            SectionHeader("LOOPS", StudioIcons.Waveform)
            Spacer(Modifier.weight(1f))
            if (playing.isNotEmpty()) {
                Box(
                    Modifier.heightIn(min = 36.dp).clip(CircleShape).clickable(role = Role.Button) { engine.stopAllLoops() }
                        .padding(horizontal = 6.dp),
                    contentAlignment = Alignment.Center,
                ) { Text("Stop All", fontSize = 11.sp, fontWeight = FontWeight.SemiBold, fontFamily = StudioFonts.Rounded, color = Color.Red.copy(alpha = 0.8f)) }
            }
        }
        Text(
            "Tap the red circle button to record a loop. Loops auto-play and layer on top of each other.",
            fontSize = 11.sp, fontFamily = StudioFonts.Rounded, color = palette.muted,
        )
        FlowRowCompat {
            Text("Length", fontSize = 11.sp, fontWeight = FontWeight.Medium, fontFamily = StudioFonts.Rounded, color = palette.muted, modifier = Modifier.padding(top = 10.dp))
            ControlSheetLogic.LOOP_BAR_OPTIONS.forEach { option ->
                CapsuleChoice("$option bars", bars == option) { engine.setLoopRecordingBars(option) }
            }
        }
        loops.forEach { loop ->
            LoopRow(
                loop = loop,
                isPlaying = loop.id in playing,
                onToggle = {
                    if (!engine.toggleLoopPlayback(loop.id)) message = "This loop couldn't play. Its audio file may be unavailable."
                },
                onRename = { renameTarget = loop },
                exporting = exporting,
                onExport = {
                    // iOS `AudioExporter.shareCaptured` (event loops are unreachable in 1.0.1).
                    exporting = true
                    scope.launch {
                        try {
                            val copy = withContext(Dispatchers.IO) { com.handstrudel.ui.capture.exportLoop(context, loop) }
                            share.share(copy, "audio/wav")
                        } catch (_: Exception) {
                            message = "Couldn't export this loop. The original is still saved."
                        } finally {
                            exporting = false
                        }
                    }
                },
                onDelete = { engine.deleteLoop(loop.id) },
                onMute = { engine.toggleLoopMute(loop.id) },
                onGain = { engine.setLoopGain(loop.id, it) },
            )
        }
    }

    renameTarget?.let { loop -> RenameLoopDialog(loop, onDismiss = { renameTarget = null }) { id, name -> engine.renameLoop(id, name) } }
    message?.let { text ->
        AlertDialog(
            onDismissRequest = { message = null },
            confirmButton = { TextButton(onClick = { message = null }) { Text("OK") } },
            title = { Text("Loops") },
            text = { Text(text) },
        )
    }
}

@Composable
private fun LoopRow(
    loop: SavedLoop,
    isPlaying: Boolean,
    onToggle: () -> Unit,
    onRename: () -> Unit,
    exporting: Boolean,
    onExport: () -> Unit,
    onDelete: () -> Unit,
    onMute: () -> Unit,
    onGain: (Double) -> Unit,
) {
    val palette = LocalStudioPalette.current
    Column(Modifier.fillMaxWidth().padding(vertical = 4.dp).testTag("loop-${loop.id}")) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Box(
                Modifier.size(44.dp).clip(CircleShape).clickable(role = Role.Button, onClick = onToggle)
                    .semantics { contentDescription = "${if (isPlaying) "Stop" else "Play"} ${loop.name}" },
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    if (isPlaying) Icons.Filled.StopCircle else Icons.Filled.PlayCircle, null,
                    tint = if (isPlaying) ORANGE else palette.accent, modifier = Modifier.size(30.dp),
                )
            }
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text(loop.name, fontSize = 13.sp, fontWeight = FontWeight.SemiBold, fontFamily = StudioFonts.Rounded, color = palette.ink, maxLines = 1)
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text(
                        loop.mode, fontSize = 9.sp, fontWeight = FontWeight.Bold, fontFamily = StudioFonts.Rounded, color = palette.accent,
                        modifier = Modifier.clip(CircleShape).background(palette.accent.copy(alpha = 0.15f)).padding(horizontal = 6.dp, vertical = 2.dp),
                    )
                    Text(
                        if (loop.hasCapturedAudio) "Captured audio" else "Note events",
                        fontSize = 10.sp, fontFamily = StudioFonts.Mono, color = palette.muted, maxLines = 1,
                    )
                    Text(ControlSheetLogic.loopDuration(loop.durationSeconds), fontSize = 10.sp, fontFamily = StudioFonts.Mono, color = palette.muted)
                }
            }
            if (loop.hasCapturedAudio) {
                CircleIconButton(
                    Icons.Filled.IosShare, "Export WAV", size = 28.dp, iconSize = 14.dp,
                    tint = palette.accent.copy(alpha = if (exporting) 0.3f else 0.6f), background = Color.Transparent,
                    onClick = { if (!exporting) onExport() },
                )
            }
            CircleIconButton(
                Icons.Filled.Edit, "Rename ${loop.name}", size = 28.dp, iconSize = 14.dp,
                tint = palette.accent.copy(alpha = 0.6f), background = Color.Transparent, onClick = onRename,
            )
            CircleIconButton(
                Icons.Filled.Delete, "Delete ${loop.name}", size = 28.dp, iconSize = 14.dp,
                tint = palette.muted.copy(alpha = 0.5f), background = Color.Transparent, onClick = onDelete,
            )
        }
        if (loop.hasCapturedAudio) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                CircleIconButton(
                    if (loop.muted) Icons.AutoMirrored.Filled.VolumeOff else Icons.AutoMirrored.Filled.VolumeUp,
                    if (loop.muted) "Unmute ${loop.name}" else "Mute ${loop.name}",
                    size = 28.dp, iconSize = 16.dp, tint = palette.accent, background = Color.Transparent, onClick = onMute,
                )
                SheetSlider(loop.gain.toFloat(), 0f..1f, Modifier.weight(1f), steps = 19) { onGain(it.toDouble()) }
                Text(ControlSheetLogic.percent(loop.gain), fontSize = 11.sp, fontFamily = StudioFonts.Mono, color = palette.muted)
            }
        }
    }
}

/** iOS "Rename loop" alert from `LoopShelfView`. */
@Composable
private fun RenameLoopDialog(loop: SavedLoop, onDismiss: () -> Unit, onSave: (UUID, String) -> Unit) {
    var name by remember(loop.id) { mutableStateOf(loop.name) }
    val clean = ControlSheetLogic.cleanLoopName(name)
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Rename loop") },
        text = {
            OutlinedTextField(name, { name = it }, singleLine = true, placeholder = { Text("Loop name") }, modifier = Modifier.testTag("loop-rename-field"))
        },
        confirmButton = { TextButton(onClick = { onSave(loop.id, name); onDismiss() }, enabled = clean.isNotEmpty()) { Text("Save") } },
        dismissButton = { TextButton(onClick = onDismiss) { Text("Cancel") } },
    )
}

/** Minimal wrapping row (8 dp gaps) so the six length capsules fit on phones. */
@Composable
private fun FlowRowCompat(content: @Composable () -> Unit) {
    Layout(content = content, modifier = Modifier.fillMaxWidth()) { measurables, constraints ->
        val gap = 6.dp.roundToPx()
        val placeables = measurables.map { it.measure(constraints.copy(minWidth = 0, minHeight = 0)) }
        var x = 0
        var y = 0
        var rowHeight = 0
        val positions = placeables.map { p ->
            if (x > 0 && x + p.width > constraints.maxWidth) { x = 0; y += rowHeight + gap; rowHeight = 0 }
            val pos = x to y
            x += p.width + gap
            rowHeight = maxOf(rowHeight, p.height)
            pos
        }
        layout(constraints.maxWidth, y + rowHeight) {
            placeables.forEachIndexed { i, p -> p.place(positions[i].first, positions[i].second) }
        }
    }
}
