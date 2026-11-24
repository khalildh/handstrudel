package com.handstrudel.ui.capture

import com.handstrudel.ui.theme.StudioIcons
import com.handstrudel.ui.theme.StudioFonts
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.wrapContentSize
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.FiberManualRecord
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Repeat
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material.icons.filled.Tune
import androidx.compose.material3.CircularProgressIndicator
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
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.zIndex
import com.handstrudel.app.LocalAppServices
import com.handstrudel.ui.theme.LocalStudioPalette

/** iOS `bottomControls`: loop button + Loops (left), ½× over record (centre), settings (right). */
@Composable
internal fun StageBottomControlsView(onOpenSettings: () -> Unit, itemModifier: Modifier = Modifier) {
    val services = LocalAppServices.current
    val controller = captureController()
    val palette = LocalStudioPalette.current
    val state by services.capture.state.collectAsState()
    val locked by services.capture.isRecordingLocked.collectAsState()
    var showLoops by remember { mutableStateOf(false) }

    Row(
        Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 24.dp),
        verticalAlignment = Alignment.Bottom,
    ) {
        if (controller != null) {
            Column(itemModifier, horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(2.dp)) {
                LoopRecordButton()
                Text(
                    "Loops",
                    fontSize = 11.sp, fontWeight = FontWeight.SemiBold, color = Color.White,
                    modifier = Modifier.testTag("stage-loop-shelf")
                        .defaultMinSize(minWidth = 44.dp, minHeight = 28.dp)
                        .clip(CircleShape).background(Color.Black.copy(alpha = 0.64f))
                        // iOS disables these during a take or count-in without dimming them.
                        .clickable(enabled = !locked) { showLoops = true }
                        .padding(horizontal = 10.dp, vertical = 6.dp),
                )
            }
        }
        Spacer(Modifier.weight(1f))
        if (controller != null) {
            Column(itemModifier, horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp)) {
                val idle = !state.isRecording && !state.isBusy && state.countdown == null
                if (idle) HalfSpeedToggle()
                RecordButton()
            }
        }
        Spacer(Modifier.weight(1f))
        Box(
            itemModifier
                .testTag("settings-button")
                .semantics { contentDescription = "Music settings" }
                .size(44.dp)
                .clip(CircleShape)
                .background(Color.Black.copy(alpha = 0.55f))
                .clickable(enabled = !locked, onClick = onOpenSettings),
            contentAlignment = Alignment.Center,
        ) { Icon(StudioIcons.SliderHorizontal3, contentDescription = null, tint = Color.White, modifier = Modifier.size(24.dp)) }
    }

    if (showLoops) LoopShelfSheetView(onDismiss = { showLoops = false })
}

@Composable
private fun HalfSpeedToggle() {
    val services = LocalAppServices.current
    val palette = LocalStudioPalette.current
    val halfSpeed by services.prefs.recordAtHalfSpeed.collectAsState()
    Row(
        Modifier.testTag("half-speed-recording")
            .semantics { contentDescription = "Half-speed recording"; stateDescription = if (halfSpeed) "On" else "Off" }
            .heightIn(min = 32.dp)
            .clip(CircleShape)
            .background(if (halfSpeed) palette.mediaAccent else Color.Black.copy(alpha = 0.55f))
            .clickable { services.prefs.setRecordAtHalfSpeed(!halfSpeed) }
            .padding(horizontal = 10.dp, vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        val tint = if (halfSpeed) palette.mediaOnAccent else Color.White
        // iOS Label at `.caption`: the tortoise glyph is ~20 pt wide.
        Icon(StudioIcons.Tortoise, contentDescription = null, tint = tint, modifier = Modifier.size(21.dp))
        Text("½×", fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = tint)
    }
}

/** iOS `recordButton`. */
@Composable
private fun RecordButton() {
    val services = LocalAppServices.current
    val controller = captureController() ?: return
    val palette = LocalStudioPalette.current
    val state by services.capture.state.collectAsState()
    val ui by controller.ui.collectAsState()
    val countdown = state.countdown
    val enabled = !state.isBusy && !state.isLoopCapturing
    val label = when {
        state.isRecording -> "Stop recording"
        countdown != null -> "Cancel countdown"
        else -> "Record video"
    }
    Box(
        Modifier.testTag("record-button")
            .semantics {
                contentDescription = label
                if (countdown != null) stateDescription =
                    if (ui.countingBeats) "$countdown beats remaining" else "$countdown seconds remaining"
            }
            .size(62.dp)
            .clip(CircleShape)
            .background(Color.Black.copy(alpha = 0.55f))
            .border(1.5.dp, Color.White.copy(alpha = 0.8f), CircleShape)
            .clickable(enabled = enabled) { controller.toggleRecord() },
        contentAlignment = Alignment.Center,
    ) {
        when {
            state.isBusy -> CircularProgressIndicator(color = Color.White, strokeWidth = 2.dp, modifier = Modifier.size(24.dp))
            state.isRecording -> Box(Modifier.size(27.dp).clip(RoundedCornerShape(6.dp)).background(palette.recording))
            countdown != null -> Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text("$countdown", fontSize = 20.sp, fontWeight = FontWeight.SemiBold, color = Color.White)
                if (ui.countingBeats) Text(if (countdown == 1) "Beat" else "Beats", fontSize = 10.sp, fontWeight = FontWeight.SemiBold, color = Color.White)
            }
            else -> Box(Modifier.padding(7.dp).size(48.dp).clip(CircleShape).background(palette.recording))
        }
    }
}

/** iOS `loopRecordButton` with its progress ring, count badge and notices. */
@Composable
private fun LoopRecordButton() {
    val services = LocalAppServices.current
    val controller = captureController() ?: return
    val palette = LocalStudioPalette.current
    val engine = services.engine
    val state by services.capture.state.collectAsState()
    val ui by controller.ui.collectAsState()
    val loopRecording by engine.isLoopRecording.collectAsState()
    val loopBusy by engine.loopCaptureBusy.collectAsState()
    val progress by engine.loopRecordingProgress.collectAsState()
    val loops by engine.savedLoops.collectAsState()
    val enabled = !loopBusy && !state.isRecording && !state.isBusy && state.countdown == null
    Box(Modifier.size(44.dp), contentAlignment = Alignment.Center) {
        Box(
            Modifier.testTag("loop-record-button")
                .semantics { contentDescription = if (loopRecording) "Stop loop recording" else "Record audio loop" }
                .size(44.dp)
                .clip(CircleShape)
                .background(Color.Black.copy(alpha = 0.55f))
                .clickable(enabled = enabled) { controller.toggleAudioLoop() },
            contentAlignment = Alignment.Center,
        ) {
            if (loopRecording) {
                Canvas(Modifier.size(44.dp)) {
                    drawArc(Color.Red, -90f, (360 * progress).toFloat(), false,
                        topLeft = Offset(1.5.dp.toPx(), 1.5.dp.toPx()),
                        size = Size(size.width - 3.dp.toPx(), size.height - 3.dp.toPx()),
                        style = Stroke(width = 3.dp.toPx(), cap = StrokeCap.Round))
                }
                Icon(Icons.Filled.Stop, contentDescription = null, tint = palette.recording, modifier = Modifier.size(15.dp))
            } else {
                Icon(StudioIcons.Repeat, contentDescription = null, tint = Color.White, modifier = Modifier.size(23.dp))
            }
        }
        if (loops.isNotEmpty() && !loopRecording) {
            Box(
                Modifier.offset(x = 16.dp, y = (-16).dp).size(18.dp).clip(CircleShape).background(palette.mediaAccent),
                contentAlignment = Alignment.Center,
            ) { Text("${loops.size}", fontSize = 10.sp, fontWeight = FontWeight.Bold, fontFamily = StudioFonts.Rounded, color = palette.mediaOnAccent) }
        }
        ui.loopNotice?.let { message ->
            val saved = "saved" in message
            val rec = "Recording" in message
            val tint = when { saved -> Color.Green; rec -> Color.Red; else -> Color(0xFFFFA500) }
            Row(
                Modifier.zIndex(1f).wrapContentSize(Alignment.CenterStart, unbounded = true).offset(y = (-40).dp)
                    .clip(CircleShape).background(Color.Black.copy(alpha = 0.7f))
                    .border(1.dp, (if (saved) Color.Green else Color(0xFFFFA500)).copy(alpha = 0.3f), CircleShape)
                    .padding(horizontal = 12.dp, vertical = 6.dp)
                    .testTag("loop-notice"),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                Icon(
                    when { saved -> Icons.Filled.CheckCircle; rec -> Icons.Filled.FiberManualRecord; else -> Icons.Filled.Info },
                    contentDescription = null, tint = tint, modifier = Modifier.size(12.dp),
                )
                Text(message, fontSize = 11.sp, fontWeight = FontWeight.SemiBold, fontFamily = StudioFonts.Rounded, color = tint, softWrap = false)
            }
        }
    }
}
