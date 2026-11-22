package com.handstrudel.ui.capture
import com.handstrudel.ui.theme.IosSlider
import com.handstrudel.ui.theme.IosControls

import com.handstrudel.ui.theme.StudioFonts
import android.Manifest
import android.app.Activity
import android.media.projection.MediaProjectionConfig
import android.media.projection.MediaProjectionManager
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.VolumeOff
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Tune
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.FilterQuality
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.handstrudel.app.LocalAppServices
import com.handstrudel.capture.BackingTrackVolume
import com.handstrudel.capture.CaptureControllerImpl.ConsentStep
import com.handstrudel.capture.Watermark
import com.handstrudel.social.model.BackingCredit
import com.handstrudel.ui.nav.LocalAppNavigator
import com.handstrudel.ui.theme.LocalStudioPalette
import kotlin.math.roundToInt

@Composable
internal fun StageOverlaysView() {
    val controller = captureController() ?: return
    val services = LocalAppServices.current
    val navigator = LocalAppNavigator.current
    LaunchedEffect(controller, navigator) { controller.attach(navigator) }
    val state by services.capture.state.collectAsState()
    val ui by controller.ui.collectAsState()
    val running by services.engine.isRunning.collectAsState()

    Box(Modifier.fillMaxSize()) {
        ui.watermark?.let { WatermarkOverlay(it.credit) }
        val backing = state.backing
        if (backing != null && !state.isRecording && !state.isBusy && state.countdown == null) {
            Box(Modifier.align(Alignment.TopCenter).padding(top = 100.dp, start = 16.dp, end = 16.dp)) {
                BackingControls()
            }
        }
    }

    ConsentFlow()

    ui.reviewingDraftId?.let { id ->
        LaunchedEffect(id) { controller.onReviewShown() }
        DraftsSheetView(
            openedDraftId = id,
            onRetake = if (running) ({ controller.requestRetake() }) else null,
            onDismiss = { controller.onReviewDismissed() },
        )
    }
}

/** iOS `WatermarkManager.createWatermarkView`: right side at 30 % height; captured with the screen. */
@Composable
private fun WatermarkOverlay(credit: BackingCredit?) {
    val density = LocalDensity.current
    val qr = remember(credit) {
        Watermark.qrBitmap(Watermark.link(credit), with(density) { Watermark.QR_DP.dp.roundToPx() }).asImageBitmap()
    }
    BoxWithConstraints(Modifier.fillMaxSize()) {
        val width = Watermark.widthDp(credit).dp
        Row(
            Modifier
                .offset(x = maxWidth - width - Watermark.RIGHT_INSET_DP.dp, y = maxHeight * Watermark.TOP_FRACTION)
                .size(width, Watermark.HEIGHT_DP.dp)
                .clip(RoundedCornerShape(12.dp))
                .background(Color.Black.copy(alpha = 0.5f))
                .clearAndSetSemantics { }
                .testTag("recording-watermark"),
            verticalAlignment = Alignment.Top,
        ) {
            Image(
                qr, contentDescription = null, filterQuality = FilterQuality.None,
                modifier = Modifier.padding(8.dp).size(Watermark.QR_DP.dp).clip(RoundedCornerShape(4.dp)).background(Color.White),
            )
            Column(Modifier.padding(top = 10.dp, end = 7.dp)) {
                Text(Watermark.title(credit), fontFamily = StudioFonts.Mono, fontWeight = FontWeight.Bold, fontSize = 11.sp,
                    color = Color(0xFF00FF9E), maxLines = 1, lineHeight = 16.sp)
                Text(Watermark.subtitle(credit), fontWeight = FontWeight.Medium, fontSize = 9.sp,
                    color = Color.White.copy(alpha = 0.7f), maxLines = 1, overflow = TextOverflow.Ellipsis, lineHeight = 14.sp)
            }
        }
    }
}

/** iOS `backingControls`. */
@Composable
private fun BackingControls() {
    val controller = captureController() ?: return
    val services = LocalAppServices.current
    val palette = LocalStudioPalette.current
    val state by services.capture.state.collectAsState()
    val ui by controller.ui.collectAsState()
    val volume by services.prefs.playAlongBackingVolume.collectAsState()
    val backing = state.backing ?: return
    Column(
        Modifier.clip(RoundedCornerShape(22.dp)).background(Color.Black.copy(alpha = 0.78f)).testTag("backing-controls"),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Row(
                Modifier.heightIn(min = 44.dp)
                    .semantics { contentDescription = if (backing.isPlaying) "Pause backing track" else "Play backing track" }
                    .clickable(enabled = !backing.isLoading) { controller.toggleBackingPlayback() }
                    .padding(horizontal = 12.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                if (backing.isLoading) CircularProgressIndicator(color = palette.mediaAccent, strokeWidth = 2.dp, modifier = Modifier.size(14.dp))
                else Icon(if (backing.isPlaying) Icons.Filled.Pause else Icons.Filled.PlayArrow, null, tint = palette.mediaAccent, modifier = Modifier.size(16.dp))
                Text("Play along with @${backing.credit.username}", color = palette.mediaAccent, fontSize = 12.sp,
                    fontWeight = FontWeight.SemiBold, maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
            Box(
                Modifier.size(44.dp).clip(RoundedCornerShape(22.dp))
                    .background(Color.White.copy(alpha = if (ui.showBackingMixer) 0.12f else 0f))
                    .semantics { contentDescription = if (ui.showBackingMixer) "Hide backing mixer" else "Show backing mixer" }
                    .clickable { controller.toggleBackingMixer() },
                contentAlignment = Alignment.Center,
            ) {
                Icon(if (volume == 0.0) Icons.AutoMirrored.Filled.VolumeOff else Icons.Filled.Tune, null,
                    tint = palette.mediaAccent, modifier = Modifier.size(18.dp))
            }
        }
        if (ui.showBackingMixer) {
            Column(Modifier.widthIn(max = 228.dp).padding(horizontal = 12.dp).padding(bottom = 4.dp)) {
                Row(Modifier.fillMaxWidth()) {
                    Text("Backing volume", color = Color.White, fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                    Spacer(Modifier.weight(1f))
                    Text("${(BackingTrackVolume.clamped(volume) * 100).roundToInt()}%", color = Color.White, fontSize = 12.sp,
                        fontWeight = FontWeight.SemiBold)
                }
                IosSlider(
                    value = volume.toFloat(),
                    onValueChange = { controller.setBackingVolume(((it / 0.05f).roundToInt() * 0.05).coerceIn(0.0, 1.0)) },
                    valueRange = 0f..1f,
                    steps = 19,
                    tint = palette.mediaAccent,
                    // Over the camera: iOS dark-appearance grey for the unfilled part.
                    inactiveTrack = IosControls.offTrack(light = false),
                    modifier = Modifier.semantics { contentDescription = "Backing volume" }.heightIn(min = 44.dp),
                )
            }
        }
    }
}

/**
 * Microphone permission (Android needs RECORD_AUDIO for app-audio capture), a
 * one-time explanation, then the MediaProjection consent dialog.
 */
@Composable
private fun ConsentFlow() {
    val controller = captureController() ?: return
    val context = LocalContext.current
    val ui by controller.ui.collectAsState()
    val audioPermission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        controller.onConsentStepResult(granted)
    }
    val screenCapture = rememberLauncherForActivityResult(ActivityResultContracts.StartActivityForResult()) { result ->
        controller.onConsentStepResult(result.resultCode to result.data)
    }
    LaunchedEffect(ui.consentRequestId) {
        if (ui.consent == null || !controller.claimConsentLaunch(ui.consentRequestId)) return@LaunchedEffect
        when (ui.consent) {
            ConsentStep.AUDIO_PERMISSION -> audioPermission.launch(Manifest.permission.RECORD_AUDIO)
            ConsentStep.SCREEN_CAPTURE -> {
                val manager = context.getSystemService(MediaProjectionManager::class.java)
                val intent = if (Build.VERSION.SDK_INT >= 34) {
                    manager.createScreenCaptureIntent(MediaProjectionConfig.createConfigForUserChoice())
                } else manager.createScreenCaptureIntent()
                runCatching { screenCapture.launch(intent) }.onFailure { controller.onConsentStepResult(Activity.RESULT_CANCELED to null) }
            }
            else -> Unit
        }
    }
    if (ui.consent == ConsentStep.EXPLAINER) {
        AlertDialog(
            onDismissRequest = { controller.onConsentStepResult(false) },
            title = { Text("Record your stage") },
            text = {
                Text("Android asks for permission each studio session before HandStrudel can record. " +
                    "Choose “A single app” and HandStrudel to capture only the stage and its sound.")
            },
            confirmButton = { TextButton(onClick = { controller.onConsentStepResult(true) }, Modifier.testTag("capture-consent-continue")) { Text("Continue") } },
            dismissButton = { TextButton(onClick = { controller.onConsentStepResult(false) }) { Text("Not now") } },
        )
    }
}
