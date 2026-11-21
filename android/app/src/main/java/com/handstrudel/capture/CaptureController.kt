package com.handstrudel.capture

import com.handstrudel.social.model.BackingCredit
import com.handstrudel.social.model.Video
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

/**
 * Recording / loops / play-along seam. Owner: capture (WS4). Shell forwards
 * lifecycle; navigator delegates play-along; studio-ui reads [isRecordingLocked].
 */
interface CaptureController {
    val state: StateFlow<CaptureState>

    /**
     * True while recording, counting in, or capturing a loop. Studio-ui disables
     * Presets, Close and Settings while it is true. (Moved here from
     * `CaptureEntryPoints` in Phase 0 so it is backed by the controller instance.)
     */
    val isRecordingLocked: StateFlow<Boolean>

    /** iOS `prepareBacking(video)`: re-fetch, check `backing_enabled`, download audio, apply sound if entitled. */
    fun prepareBacking(video: Video)
    /** Session closed: stop recording/backing, release the MediaProjection. */
    fun onSessionEnded()
    /** App went to background: stop recording and save the partial take. */
    fun onAppBackgrounded()
}

data class CaptureState(
    val isRecording: Boolean = false,
    /** Finishing/saving/exporting; buttons disabled. */
    val isBusy: Boolean = false,
    /** Count-in step remaining (4…1 or 3…1), null when not counting in. */
    val countdown: Int? = null,
    val isLoopCapturing: Boolean = false,
    /** 0…1. */
    val loopProgress: Double = 0.0,
    val backing: BackingState? = null,
)

data class BackingState(
    val credit: BackingCredit,
    val isPlaying: Boolean = false,
    /** 0…1, persisted as `playAlongBackingVolume` (default 0.55). */
    val volume: Double = 0.55,
    val isLoading: Boolean = false,
)

/** Phase 0 stub. Capture WS replaces it with `CaptureControllerImpl`. */
class NoopCaptureController : CaptureController {
    override val state: StateFlow<CaptureState> = MutableStateFlow(CaptureState())
    override val isRecordingLocked: StateFlow<Boolean> = MutableStateFlow(false)
    override fun prepareBacking(video: Video) = Unit
    override fun onSessionEnded() = Unit
    override fun onAppBackgrounded() = Unit
}
