package com.handstrudel.ui.capture

import androidx.compose.runtime.Composable
import com.handstrudel.app.LocalAppServices
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
    fun StageBottomControls(onOpenSettings: () -> Unit) = StageBottomControlsView(onOpenSettings)

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
