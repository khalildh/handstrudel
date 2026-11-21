package com.handstrudel.ui.capture

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/**
 * Capture UI slots embedded by studio-ui and shell. Owner: capture (WS4).
 * Composables read `LocalAppServices.current.capture` / `.engine` themselves.
 * (`isRecordingLocked` lives on `CaptureController`, see 3.0 decisions.)
 */
object CaptureEntryPoints {

    /** The Stage's bottom row: loop button + "Loops" (left), ½× over record (centre), settings (right). */
    @Composable
    fun StageBottomControls(onOpenSettings: () -> Unit) {
        // Phase 0 stub: only the settings button, so the control sheet stays reachable.
        Row(
            Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 24.dp),
            horizontalArrangement = Arrangement.End,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(
                Modifier
                    .testTag("settings-button")
                    .size(48.dp)
                    .clip(CircleShape)
                    .background(Color.White.copy(alpha = 0.10f))
                    .clickable(onClick = onOpenSettings),
                contentAlignment = Alignment.Center,
            ) { Text("⚙", fontSize = 22.sp, color = Color.White.copy(alpha = 0.85f)) }
        }
    }

    /** Count-in, watermark, backing controls, recording toasts. Drawn above the stage. */
    @Composable
    fun StageOverlays() = Unit

    /** Control sheet → Capture tab, first section (iOS `recordingSection`). */
    @Composable
    fun RecordingSettingsSection() = Unit

    /** Private drafts library. */
    @Composable
    fun DraftsSheet(onDismiss: () -> Unit) = StubSheet("Private drafts", onDismiss)

    /** Saved audio loops (iOS `LoopShelfView`). */
    @Composable
    fun LoopShelfSheet(onDismiss: () -> Unit) = StubSheet("Loops", onDismiss)
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun StubSheet(title: String, onDismiss: () -> Unit) {
    ModalBottomSheet(onDismissRequest = onDismiss) {
        Column(Modifier.padding(24.dp)) { Text("$title aren't available yet.") }
    }
}
