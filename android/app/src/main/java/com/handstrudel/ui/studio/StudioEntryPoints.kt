package com.handstrudel.ui.studio

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
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
import com.handstrudel.engine.LegacyStudioEngine
import com.handstrudel.engine.PlayInput
import com.handstrudel.ui.capture.CaptureEntryPoints
import com.handstrudel.ui.nav.LocalAppNavigator
import com.handstrudel.ui.theme.LocalStudioPalette

/**
 * Music tab entry points. Owner: studio-ui (WS3). Shell shows [MusicHome] on the
 * Music tab when idle and [Stage] full-screen while `engine.isRunning`.
 *
 * Phase 0: a minimal home and the pre-existing Split performance screen. The
 * Split overlay and settings sheet still take the legacy `EngineController`
 * (via [LegacyStudioEngine]); studio-ui ports them to `StudioEngine`.
 */
object StudioEntryPoints {

    /** iOS `StartOverlayView`. */
    @Composable
    fun MusicHome() {
        val navigator = LocalAppNavigator.current
        val engine = LocalAppServices.current.engine
        val palette = LocalStudioPalette.current
        val status by engine.status.collectAsState()
        Column(
            Modifier.fillMaxSize().padding(horizontal = 24.dp).padding(top = 72.dp, bottom = 120.dp),
        ) {
            Text("Play the air.", fontSize = 40.sp, fontWeight = FontWeight.Black, color = palette.ink)
            Text("Play music with a gesture or a touch.", fontSize = 16.sp, color = palette.muted)
            Spacer(Modifier.weight(1f))
            if (status.startsWith("error")) Text(status, color = palette.recording)
            Button(
                onClick = { navigator.startSession() },
                modifier = Modifier.testTag("start-button").fillMaxWidth().height(56.dp),
                shape = RoundedCornerShape(16.dp),
                colors = ButtonDefaults.buttonColors(containerColor = palette.accent, contentColor = palette.onAccent),
            ) { Text("Start playing", fontSize = 18.sp, fontWeight = FontWeight.Bold) }
        }
    }

    /** The full performance view (iOS `ContentView` performance sections). */
    @Composable
    fun Stage() {
        val services = LocalAppServices.current
        val engine = services.engine
        val legacy = (engine as? LegacyStudioEngine)?.controller
        val handsState by engine.handsState.collectAsState()
        val beat by engine.currentBeat.collectAsState()
        val playInput by engine.playInput.collectAsState()
        val cameraIssue by engine.cameraIssue.collectAsState()
        val locked by services.capture.isRecordingLocked.collectAsState()
        val palette = LocalStudioPalette.current
        var showSettings by remember { mutableStateOf(false) }

        Box(Modifier.fillMaxSize().background(androidx.compose.ui.graphics.Color.Black)) {
            if (playInput == PlayInput.AIR && cameraIssue == null) {
                CameraPreview(modifier = Modifier.fillMaxSize(), handTracker = engine.handTracker)
            }
            if (legacy != null && legacy.chordMelodyModeEnabled) {
                SplitChordMelodyOverlay(engine = legacy, modifier = Modifier.fillMaxSize())
            }
            HandOverlay(handsState = handsState, modifier = Modifier.fillMaxSize())

            // Top bar: beat dots, logo, close.
            Row(
                Modifier.fillMaxWidth().padding(top = 48.dp, start = 20.dp, end = 20.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                    for (i in 0..3) {
                        Box(
                            Modifier.size(if (i == beat) 10.dp else 6.dp).clip(CircleShape)
                                .background(if (i == beat) palette.mediaAccent else palette.ink.copy(alpha = 0.2f)),
                        )
                    }
                }
                Spacer(Modifier.weight(1f))
                Text("handstrudel", fontSize = 18.sp, fontWeight = FontWeight.Black, color = palette.ink.copy(alpha = 0.8f))
                Spacer(Modifier.weight(1f))
                Box(
                    Modifier.testTag("close-button").size(40.dp).clip(CircleShape)
                        .background(palette.ink.copy(alpha = 0.1f))
                        .clickable(enabled = !locked) {
                            engine.stop()
                            services.capture.onSessionEnded()
                        },
                    contentAlignment = Alignment.Center,
                ) { Text("✕", color = palette.ink) }
            }

            CaptureEntryPoints.StageOverlays()
            Box(Modifier.align(Alignment.BottomCenter)) {
                CaptureEntryPoints.StageBottomControls(onOpenSettings = { if (!locked) showSettings = true })
            }
        }

        if (showSettings && legacy != null) {
            SplitSettingsSheet(engine = legacy, onDismiss = { showSettings = false })
        }
    }
}
