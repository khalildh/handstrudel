package com.handstrudel.ui.nav

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.util.Log
import androidx.core.content.ContextCompat
import com.handstrudel.app.AppServices
import com.handstrudel.app.DeepLinkRouter
import com.handstrudel.engine.CameraIssue
import com.handstrudel.engine.PlayInput
import com.handstrudel.engine.StudioMode
import com.handstrudel.models.ScaleSelection
import com.handstrudel.models.SoundSetup
import com.handstrudel.social.SocialEntryPoints
import com.handstrudel.social.model.PerformanceLink
import com.handstrudel.social.model.Video
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.drop
import kotlinx.coroutines.launch
import java.util.UUID

/**
 * The app's [AppNavigator] (iOS `ContentView` actions and `@State`). Owner: shell.
 * App-scoped (created once in `HandStrudelApplication`) so tab, session and alert state
 * survive activity recreation. The activity attaches a [PermissionHost] while it exists.
 *
 * Besides the interface it exposes host state ([notice], [error], [sheet],
 * [isStartingSession], [feedFullscreen]) that the root composable renders.
 */
class DefaultAppNavigator(
    private val services: AppServices,
    private val scope: CoroutineScope,
    private val appContext: Context,
) : AppNavigator {

    data class Notice(val text: String, val id: Long = System.nanoTime())
    data class ErrorAlert(val title: String, val message: String, val id: Long = System.nanoTime())
    sealed interface Sheet {
        data class Post(val video: Video) : Sheet
        data class Comments(val video: Video) : Sheet
    }

    /**
     * Launches a runtime-permission request; implemented by the current activity, which
     * reports the answer through [onPermissionResult]. The pending callback lives here
     * (app-scoped), so an answer still lands if the activity is recreated meanwhile.
     */
    fun interface PermissionHost {
        fun launch(permission: String)
    }

    var permissionHost: PermissionHost? = null
    private var pendingPermission: String? = null
    private val pendingPermissionCallbacks = mutableListOf<(Boolean) -> Unit>()

    /** Social seams, replaceable for tests and the debug fake (see `DebugFakeSocial`). */
    var socialConfigured: () -> Boolean = { services.auth.isConfigured }
    var fetchVideo: suspend (UUID) -> Video? = { SocialEntryPoints.fetchVideo(it) }

    private val _destination = MutableStateFlow(Destination.Music)
    override val destination: StateFlow<Destination> = _destination
    private val _startingSession = MutableStateFlow(false)
    /** iOS `startingSession`: tabs and Start are disabled until the engine runs or errors. */
    override val isStartingSession: StateFlow<Boolean> = _startingSession
    private val _feedFullscreen = MutableStateFlow(false)
    /** iOS `feedFullscreen`: hides the status bar and blacks out the background. */
    val feedFullscreen: StateFlow<Boolean> = _feedFullscreen
    private val _notice = MutableStateFlow<Notice?>(null)
    val notice: StateFlow<Notice?> = _notice
    private val _error = MutableStateFlow<ErrorAlert?>(null)
    val error: StateFlow<ErrorAlert?> = _error
    private val _sheet = MutableStateFlow<Sheet?>(null)
    val sheet: StateFlow<Sheet?> = _sheet

    private var noticeJob: Job? = null
    private var linkJob: Job? = null
    private var startWatchdog: Job? = null

    init {
        val engine = services.engine
        // iOS onChange(of: engine.isRunning) / onChange(of: engine.status).
        scope.launch {
            combine(engine.isRunning, engine.status) { running, status -> running to status }.collect { (running, status) ->
                if (running || status.startsWith("error:")) endStarting()
            }
        }
        scope.launch {
            engine.isRunning.drop(1).distinctUntilChanged().collect { running ->
                if (!running) services.capture.onSessionEnded()
            }
        }
        // iOS `.onChange(of: auth.userId) { draftPostNotice = nil }`.
        scope.launch {
            services.auth.userId.drop(1).distinctUntilChanged().collect { clearNotice() }
        }
    }

    override fun select(d: Destination) {
        if (_startingSession.value) return // iOS disables the tab bar while starting.
        _destination.value = d
        if (d != Destination.Feed) _feedFullscreen.value = false
    }

    /** Feed's `onFullscreenChanged` (only honoured on the Feed tab, like iOS). */
    fun setFeedFullscreen(fullscreen: Boolean) {
        _feedFullscreen.value = fullscreen && _destination.value == Destination.Feed
    }

    override fun startSession(setup: SoundSetup?, useCurrentSoundAsFallback: Boolean) {
        val engine = services.engine
        if (engine.isRunning.value || _startingSession.value) return
        val applied = setup?.let { engine.applySoundSetup(it, services.store) } ?: false
        if (setup != null && !applied && !useCurrentSoundAsFallback) {
            showError(ALERT_TITLE, SETUP_UNAVAILABLE)
            return
        }
        limitScaleToEntitlement()
        beginStarting()
        _destination.value = Destination.Music
        _feedFullscreen.value = false
        _sheet.value = null
        if (!applied) engine.switchMode(StudioMode.SCALE)
        val input = services.prefs.studioPlayInput.value
        if (input == PlayInput.AIR && !isGranted(Manifest.permission.CAMERA)) {
            // Lazily, only when a session starts with Air input. Denial plays by touch (iOS fallBackToTouch).
            requestPermission(Manifest.permission.CAMERA) { granted ->
                if (engine.isRunning.value) return@requestPermission
                if (!granted) engine.reportCameraIssue(CameraIssue.PERMISSION_DENIED)
                engine.start(if (granted) PlayInput.AIR else PlayInput.TOUCH)
            }
        } else {
            engine.start(input)
        }
    }

    override fun changePlayInput(input: PlayInput) {
        val engine = services.engine
        services.prefs.setStudioPlayInput(input) // iOS sets `preferredInput` first, even if access is then denied.
        if (input == PlayInput.AIR && engine.isRunning.value && !isGranted(Manifest.permission.CAMERA)) {
            requestPermission(Manifest.permission.CAMERA) { _ ->
                // Granted: the engine starts the camera. Denied: its access check reports
                // PERMISSION_DENIED and falls back to touch (iOS `startSession` → `fallBackToTouch`).
                if (engine.isRunning.value) engine.setPlayInput(PlayInput.AIR)
            }
            return
        }
        engine.setPlayInput(input)
    }

    /** iOS `limitScaleToEntitlement`: an unentitled scale becomes Pentatonic. */
    private fun limitScaleToEntitlement() {
        val engine = services.engine
        val pack = engine.selectedScale.value.packId ?: return
        if (!services.store.isUnlocked(pack)) engine.setScale(ScaleSelection.PENTATONIC)
    }

    override fun trySharedSound(setup: SoundSetup) {
        if (services.engine.isRunning.value || _startingSession.value) {
            showError(ALERT_TITLE, CLOSE_SESSION_FIRST)
            return
        }
        startSession(setup)
    }

    override fun prepareBacking(video: Video) {
        _sheet.value = null
        _destination.value = Destination.Music
        _feedFullscreen.value = false
        services.capture.prepareBacking(video)
    }

    override fun openPerformance(link: PerformanceLink) {
        if (!socialConfigured()) {
            Log.i(TAG, "openPerformance ignored (social unavailable): $link")
            return
        }
        Log.i(TAG, "openPerformance $link")
        linkJob?.cancel()
        linkJob = scope.launch {
            val video = try {
                fetchVideo(link.videoId)
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                Log.i(TAG, "openPerformance fetch failed: ${e.javaClass.simpleName}")
                showError(ALERT_TITLE, DeepLinkRouter.LINK_FAILED)
                return@launch
            }
            when (val outcome = DeepLinkRouter.resolve(link, video)) {
                is DeepLinkRouter.Outcome.ShowPost -> _sheet.value = Sheet.Post(outcome.video)
                is DeepLinkRouter.Outcome.ShowComments -> _sheet.value = Sheet.Comments(outcome.video)
                is DeepLinkRouter.Outcome.PlayAlong -> prepareBacking(outcome.video)
                is DeepLinkRouter.Outcome.TrySound -> trySharedSound(outcome.setup)
                is DeepLinkRouter.Outcome.Error -> showError(ALERT_TITLE, outcome.message)
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

    private fun clearNotice() {
        noticeJob?.cancel()
        _notice.value = null
    }

    override fun showError(title: String, message: String) { _error.value = ErrorAlert(title, message) }

    override fun requestPermission(permission: String, onResult: (granted: Boolean) -> Unit) {
        if (isGranted(permission)) return onResult(true)
        val host = permissionHost ?: return onResult(false)
        when (pendingPermission) {
            null -> {
                pendingPermission = permission
                pendingPermissionCallbacks += onResult
                host.launch(permission)
            }
            permission -> pendingPermissionCallbacks += onResult // already asking: share the answer
            else -> onResult(false) // one system dialog at a time
        }
    }

    /** The activity's permission launcher result. */
    fun onPermissionResult(granted: Boolean) {
        val callbacks = pendingPermissionCallbacks.toList()
        pendingPermission = null
        pendingPermissionCallbacks.clear()
        callbacks.forEach { it(granted) }
    }

    private fun isGranted(permission: String): Boolean =
        ContextCompat.checkSelfPermission(appContext, permission) == PackageManager.PERMISSION_GRANTED

    /**
     * System back (Android only; iOS has no equivalent). Returns true when consumed:
     * during a session it never ends the performance by accident (✕ does), on Feed or
     * Account it returns to Music. On Music it falls through and the app goes to the background.
     */
    fun handleBack(): Boolean {
        if (services.engine.isRunning.value) {
            showNotice(BACK_DURING_SESSION, 2000)
            return true
        }
        if (_destination.value != Destination.Music) {
            select(Destination.Music)
            return true
        }
        return false
    }

    private fun beginStarting() {
        _startingSession.value = true
        startWatchdog?.cancel()
        // Safety net: never leave the tab bar disabled if an engine start is silently dropped.
        startWatchdog = scope.launch {
            delay(START_TIMEOUT_MS)
            if (!services.engine.isRunning.value) _startingSession.value = false
        }
    }

    private fun endStarting() {
        startWatchdog?.cancel()
        _startingSession.value = false
    }

    companion object {
        private const val TAG = "AppNavigator"
        private const val START_TIMEOUT_MS = 20_000L
        const val ALERT_TITLE = "HandStrudel"
        const val SETUP_UNAVAILABLE = "This setup is unavailable or requires a sound pack you don't own."
        const val CLOSE_SESSION_FIRST = "Close your current session, then open this sound again."
        const val BACK_DURING_SESSION = "Tap ✕ to end the session."
    }
}
