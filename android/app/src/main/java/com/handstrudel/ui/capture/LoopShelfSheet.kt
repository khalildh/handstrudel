package com.handstrudel.ui.capture

import androidx.compose.foundation.layout.height
import androidx.compose.material.icons.filled.UnfoldMore
import com.handstrudel.ui.theme.StudioIcons

import androidx.compose.foundation.layout.statusBarsPadding
import com.handstrudel.ui.studio.common.SheetGrabber
import androidx.compose.foundation.layout.fillMaxHeight
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
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.VolumeOff
import androidx.compose.material.icons.automirrored.filled.VolumeUp
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Repeat
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.handstrudel.app.LocalAppServices
import com.handstrudel.capture.WavFile
import com.handstrudel.capture.drafts.DraftExport
import com.handstrudel.engine.SavedLoop
import com.handstrudel.ui.theme.LocalStudioPalette
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File
import java.util.Locale
import java.util.UUID
import kotlin.math.roundToInt

/** iOS `LoopRecorder.barOptions`. */
internal val LOOP_BAR_OPTIONS = listOf(1, 2, 4, 8, 16, 32)

/** iOS `LoopShelfView`. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun LoopShelfSheetView(onDismiss: () -> Unit) {
    val engine = LocalAppServices.current.engine
    val palette = LocalStudioPalette.current
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val share = rememberShareCopyLauncher()
    val running by engine.isRunning.collectAsState()
    val loops by engine.savedLoops.collectAsState()
    val bars by engine.loopRecordingBars.collectAsState()
    var renameTarget by remember { mutableStateOf<SavedLoop?>(null) }
    var nextName by remember { mutableStateOf("") }
    var deleteTarget by remember { mutableStateOf<SavedLoop?>(null) }
    var message by remember { mutableStateOf<String?>(null) }
    var exporting by remember { mutableStateOf(false) }

    DisposableEffect(Unit) {
        onDispose { if (!engine.isRunning.value) engine.stopAllLoops() }
    }

    ModalBottomSheet(
        modifier = Modifier.statusBarsPadding(),
        onDismissRequest = onDismiss,
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        containerColor = palette.background,
        dragHandle = { SheetGrabber() },
    ) {
        // iOS: inline navigation bar with only a trailing Done, then the scrolling content.
        Box(Modifier.fillMaxWidth().height(44.dp).padding(horizontal = 8.dp)) {
            com.handstrudel.ui.studio.common.SheetTextButton("Done", Modifier.align(Alignment.CenterEnd), bold = true, onClick = onDismiss)
        }
        Column(
            Modifier.fillMaxHeight().verticalScroll(rememberScrollState()).padding(20.dp).padding(bottom = 12.dp).testTag("loop-shelf"),
            verticalArrangement = Arrangement.spacedBy(15.dp),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                Icon(StudioIcons.Waveform, null, tint = palette.accent, modifier = Modifier.size(14.dp))
                Text("PRIVATE AUDIO LIBRARY", fontFamily = StudioFonts.Mono, fontWeight = FontWeight.SemiBold, fontSize = 12.sp, color = palette.accent)
            }
            Text("Loop shelf", fontFamily = StudioFonts.Serif, fontSize = 34.sp, color = palette.ink)
            Text(
                if (running) "Layer loops with the live instrument." else "Preview captured audio without opening the wheel.",
                fontSize = 15.sp, color = palette.muted,
            )
            // iOS `Picker("New recording length")` in a VStack renders as a menu button: the
            // current value in the tint with an up/down chevron; the label is only spoken.
            Box {
                var barsMenu by remember { mutableStateOf(false) }
                Row(
                    Modifier.testTag("loop-recording-length").clip(RoundedCornerShape(8.dp))
                        .clickable { barsMenu = true }
                        .semantics { contentDescription = "New recording length" }
                        .padding(horizontal = 11.dp, vertical = 7.dp),
                    verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(5.dp),
                ) {
                    Text(if (bars == 1) "1 bar" else "$bars bars", fontSize = 17.sp, color = palette.accent)
                    Icon(Icons.Filled.UnfoldMore, null, tint = palette.accent, modifier = Modifier.size(15.dp))
                }
                DropdownMenu(expanded = barsMenu, onDismissRequest = { barsMenu = false }) {
                    LOOP_BAR_OPTIONS.forEach { option ->
                        DropdownMenuItem(
                            text = { Text(if (option == 1) "1 bar" else "$option bars") },
                            trailingIcon = if (bars == option) ({ Icon(StudioIcons.Checkmark, null, modifier = Modifier.size(16.dp)) }) else null,
                            onClick = { barsMenu = false; engine.setLoopRecordingBars(option) },
                        )
                    }
                }
            }
            if (loops.isEmpty()) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Icon(StudioIcons.Repeat, null, tint = palette.ink, modifier = Modifier.size(22.dp))
                    Text("No loops yet", fontWeight = FontWeight.SemiBold, fontSize = 17.sp, color = palette.ink)
                }
                Text("Tap the repeat button on the wheel to capture app audio.", fontSize = 15.sp, color = palette.muted)
            }
            loops.forEach { loop ->
                LoopRow(
                    loop,
                    onRename = { nextName = loop.name; renameTarget = loop },
                    onExport = {
                        if (!exporting) {
                            exporting = true
                            scope.launch {
                                try {
                                    val copy = withContext(Dispatchers.IO) { exportLoop(context, loop) }
                                    share.share(copy, "audio/wav")
                                } catch (_: Exception) {
                                    message = "Couldn't export this loop. The original is still saved."
                                } finally {
                                    exporting = false
                                }
                            }
                        }
                    },
                    onDelete = { deleteTarget = loop },
                    onMessage = { message = it },
                )
            }
            if (exporting) {
                Text("Preparing audio", color = palette.muted)
                LinearProgressIndicator(Modifier.fillMaxWidth(), color = palette.accent)
            }
        }
    }

    renameTarget?.let { loop ->
        AlertDialog(
            onDismissRequest = { renameTarget = null },
            title = { Text("Rename loop") },
            text = { OutlinedTextField(nextName, { nextName = it }, label = { Text("Loop name") }, singleLine = true) },
            confirmButton = {
                TextButton(enabled = nextName.trim().isNotEmpty(), onClick = {
                    engine.renameLoop(loop.id, nextName)
                    renameTarget = null
                }) { Text("Save") }
            },
            dismissButton = { TextButton(onClick = { renameTarget = null }) { Text("Cancel") } },
        )
    }
    deleteTarget?.let { loop ->
        AlertDialog(
            onDismissRequest = { deleteTarget = null },
            title = { Text("Delete this loop?") },
            text = { Text("Any WAV copies you've shared will stay where you saved them.") },
            confirmButton = {
                TextButton(onClick = { engine.deleteLoop(loop.id); deleteTarget = null }) { Text("Delete loop", color = palette.recording) }
            },
            dismissButton = { TextButton(onClick = { deleteTarget = null }) { Text("Cancel") } },
        )
    }
    message?.let {
        AlertDialog(
            onDismissRequest = { message = null },
            title = { Text("Loops") },
            text = { Text(it) },
            confirmButton = { TextButton(onClick = { message = null }) { Text("OK") } },
        )
    }
}

/** iOS `AudioExporter.shareCaptured`: a checked temporary copy of the original WAV. */
internal fun exportLoop(context: android.content.Context, loop: SavedLoop): File {
    val source = loop.file ?: throw IllegalStateException("missing file")
    if (!WavFile.isComplete(source, loop.durationSeconds)) throw IllegalStateException("The captured audio file is incomplete.")
    val output = File(DraftExport.exportsDir(context), "HandStrudel-${UUID.randomUUID()}.wav")
    source.copyTo(output)
    return output
}

@Composable
private fun LoopRow(
    loop: SavedLoop,
    onRename: () -> Unit,
    onExport: () -> Unit,
    onDelete: () -> Unit,
    onMessage: (String) -> Unit,
) {
    val engine = LocalAppServices.current.engine
    val palette = LocalStudioPalette.current
    val playingIds by engine.playingLoopIds.collectAsState()
    val playing = loop.id in playingIds
    var menu by remember { mutableStateOf(false) }
    var gain by remember(loop.id, loop.gain) { mutableStateOf(loop.gain.toFloat()) }
    Column(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(palette.surface)
            .border(1.dp, palette.border, RoundedCornerShape(16.dp)).padding(12.dp),
        verticalArrangement = Arrangement.spacedBy(7.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Box(
                Modifier.size(44.dp).clip(CircleShape).background(palette.accent)
                    .semantics { contentDescription = "${if (playing) "Stop" else "Play"} ${loop.name}" }
                    .clickable {
                        if (!engine.toggleLoopPlayback(loop.id)) onMessage("This loop couldn't play. Its audio file may be unavailable.")
                    },
                contentAlignment = Alignment.Center,
            ) { Icon(if (playing) Icons.Filled.Stop else Icons.Filled.PlayArrow, null, tint = palette.onAccent) }
            Column(Modifier.weight(1f)) {
                Text(loop.name, fontWeight = FontWeight.SemiBold, fontSize = 17.sp, color = palette.ink)
                Text("WAV · ${String.format(Locale.US, "%.1f", loop.durationSeconds)} s", fontSize = 12.sp, color = palette.muted)
            }
            Box {
                Box(
                    Modifier.size(44.dp).semantics { contentDescription = "Actions for ${loop.name}" }.clickable { menu = true },
                    contentAlignment = Alignment.Center,
                ) { Icon(Icons.Filled.MoreVert, null, tint = palette.accent) }
                DropdownMenu(expanded = menu, onDismissRequest = { menu = false }) {
                    DropdownMenuItem(text = { Text("Rename") }, onClick = { menu = false; onRename() })
                    DropdownMenuItem(text = { Text("Export original WAV") }, onClick = { menu = false; onExport() })
                    DropdownMenuItem(text = { Text("Delete", color = palette.recording) }, onClick = { menu = false; onDelete() })
                }
            }
        }
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Box(
                Modifier.size(44.dp).semantics { contentDescription = if (loop.muted) "Unmute ${loop.name}" else "Mute ${loop.name}" }
                    .clickable { engine.toggleLoopMute(loop.id) },
                contentAlignment = Alignment.Center,
            ) {
                Icon(if (loop.muted) Icons.AutoMirrored.Filled.VolumeOff else Icons.AutoMirrored.Filled.VolumeUp, null, tint = palette.accent)
            }
            Slider(
                value = gain,
                onValueChange = { gain = ((it / 0.05f).roundToInt() * 0.05f).coerceIn(0f, 1f); engine.setLoopGain(loop.id, gain.toDouble()) },
                valueRange = 0f..1f, steps = 19,
                colors = SliderDefaults.colors(thumbColor = palette.accent, activeTrackColor = palette.accent),
                modifier = Modifier.weight(1f).semantics { contentDescription = "Volume for ${loop.name}" },
            )
            Text("${(gain * 100).roundToInt()}%", fontSize = 12.sp, color = palette.muted, modifier = Modifier.width(40.dp))
        }
    }
}
