package com.handstrudel.ui.capture

import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import com.handstrudel.app.LocalAppServices
import com.handstrudel.capture.CaptureController
import com.handstrudel.capture.CaptureControllerImpl

/**
 * Capture UI slots embedded by studio-ui and shell. Owner: capture (WS4).
 * Composables read `LocalAppServices.current.capture` / `.engine` themselves.
 * (`isRecordingLocked` lives on `CaptureController`, see 3.0 decisions.)
 *
 * With the Phase 0 `NoopCaptureController` the stage shows only the settings
 * button and the sheets say they're unavailable.
 */
object CaptureEntryPoints {

    /** The Stage's bottom row: loop button + "Loops" (left), ½× over record (centre), settings (right). */
    @Composable
    fun StageBottomControls(onOpenSettings: () -> Unit, itemModifier: Modifier = Modifier) =
        StageBottomControlsView(onOpenSettings, itemModifier)

    /** True while the Play Along backing mixer is open (the stage's filter swipe is off then, as on iOS). */
    @Composable
    fun isBackingMixerOpen(): Boolean {
        val controller = captureController() ?: return false
        val ui by controller.ui.collectAsState()
        return ui.showBackingMixer
    }

    /** Pauses the Play Along backing track if it is playing (iOS: opening Presets on the stage). */
    fun pauseBacking(capture: CaptureController) {
        val controller = capture as? CaptureControllerImpl ?: return
        if (controller.state.value.backing?.isPlaying == true) controller.toggleBackingPlayback()
    }

    /** Watermark, backing controls, loop notices, consent prompts and the post-take review. Drawn above the stage. */
    @Composable
    fun StageOverlays() = StageOverlaysView()

    /** Control sheet → Capture tab, first section (iOS `recordingSection`). */
    @Composable
    fun RecordingSettingsSection() = RecordingSettingsSectionView()

    /** Private drafts library. */
    @Composable
    fun DraftsSheet(onDismiss: () -> Unit) = DraftsSheetView(openedDraftId = null, onRetake = null, onDismiss = onDismiss)

    /** Saved audio loops (iOS `LoopShelfView`). */
    @Composable
    fun LoopShelfSheet(onDismiss: () -> Unit) = LoopShelfSheetView(onDismiss)
}

/** The real controller, or null with the Phase 0 stub. */
@Composable
internal fun captureController(): CaptureControllerImpl? = LocalAppServices.current.capture as? CaptureControllerImpl
