package com.handstrudel.ui.nav

import com.handstrudel.app.AppServices
import com.handstrudel.engine.CameraIssue
import com.handstrudel.engine.PlayInput
import com.handstrudel.engine.StudioMode
import com.handstrudel.models.ScaleSelection
import com.handstrudel.models.SoundSetup
import com.handstrudel.social.SocialEntryPoints
import com.handstrudel.social.model.PerformanceLink
import com.handstrudel.social.model.Video
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch

/**
 * Phase 0 [AppNavigator]. Owner: shell (replace or extend freely). Besides the
 * interface it exposes host state ([notice], [error], [sheet]) that the root
 * composable renders.
 */
class DefaultAppNavigator(
    private val services: AppServices,
    private val scope: CoroutineScope,
    /** True when the CAMERA permission is granted. */
    private val hasCameraPermission: () -> Boolean,
    /** Asks for CAMERA and calls back with the result. */
    private val requestCameraPermission: (onResult: (Boolean) -> Unit) -> Unit,
) : AppNavigator {

    data class Notice(val text: String, val id: Long = System.nanoTime())
    data class ErrorAlert(val title: String, val message: String)
    sealed interface Sheet {
        data class Post(val video: Video) : Sheet
        data class Comments(val video: Video) : Sheet
    }

    private val _destination = MutableStateFlow(Destination.Music)
    override val destination: StateFlow<Destination> = _destination
    private val _notice = MutableStateFlow<Notice?>(null)
    val notice: StateFlow<Notice?> = _notice
    private val _error = MutableStateFlow<ErrorAlert?>(null)
    val error: StateFlow<ErrorAlert?> = _error
    private val _sheet = MutableStateFlow<Sheet?>(null)
    val sheet: StateFlow<Sheet?> = _sheet
    private var noticeJob: Job? = null

    override fun select(d: Destination) { _destination.value = d }

    override fun startSession(setup: SoundSetup?, useCurrentSoundAsFallback: Boolean) {
        val engine = services.engine
        if (engine.isRunning.value) return
        var applied = false
        if (setup != null) {
            applied = engine.applySoundSetup(setup, services.store)
            if (!applied && !useCurrentSoundAsFallback) {
                showError("Can't play this sound", "This setup is unavailable or requires a sound pack you don't own.")
                return
            }
        }
        if (!applied) {
            // iOS limitScaleToEntitlement: an unentitled scale becomes Pentatonic.
            val scale = engine.selectedScale.value
            if (!services.store.isUnlocked(scale.packId)) engine.setScale(ScaleSelection.PENTATONIC)
            engine.switchMode(StudioMode.SCALE)
        }
        _destination.value = Destination.Music
        val input = services.prefs.studioPlayInput.value
        if (input == PlayInput.AIR && !hasCameraPermission()) {
            requestCameraPermission { granted ->
                if (!granted) engine.reportCameraIssue(CameraIssue.PERMISSION_DENIED)
                engine.start(if (granted) PlayInput.AIR else PlayInput.TOUCH)
            }
        } else {
            engine.start(input)
        }
    }

    override fun trySharedSound(setup: SoundSetup) {
        if (services.engine.isRunning.value) {
            showError("Finish your session first", "Close the current session to play this sound.")
            return
        }
        startSession(setup)
    }

    override fun prepareBacking(video: Video) {
        _destination.value = Destination.Music
        services.capture.prepareBacking(video)
    }

    override fun openPerformance(link: PerformanceLink) {
        scope.launch {
            val video = SocialEntryPoints.fetchVideo(link.videoId)
            if (video == null) {
                showNotice("This performance isn't available.")
                return@launch
            }
            when (link) {
                is PerformanceLink.Watch -> _sheet.value = Sheet.Post(video)
                is PerformanceLink.Comments -> _sheet.value = Sheet.Comments(video)
                is PerformanceLink.Sound -> video.soundSetup?.let(::trySharedSound)
                    ?: showNotice("This performance has no playable sound.")
                is PerformanceLink.PlayAlong -> prepareBacking(video)
            }
        }
    }

    fun dismissSheet() { _sheet.value = null }
    fun dismissError() { _error.value = null }

    override fun showNotice(text: String, millis: Long) {
        val notice = Notice(text)
        _notice.value = notice
        noticeJob?.cancel()
        noticeJob = scope.launch {
            delay(millis)
            if (_notice.value == notice) _notice.value = null
        }
    }

    override fun showError(title: String, message: String) { _error.value = ErrorAlert(title, message) }
}
