package com.handstrudel.capture

import android.app.Activity
import android.app.Application
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import android.os.Bundle
import android.os.SystemClock
import android.util.Log
import com.handstrudel.app.AppAnalytics
import com.handstrudel.app.AppAnalyticsEvent
import com.handstrudel.app.AppPrefs
import com.handstrudel.app.ReviewPrompt
import com.handstrudel.capture.drafts.DraftExport
import com.handstrudel.capture.drafts.RecordingDraft
import com.handstrudel.capture.drafts.RecordingDrafts
import com.handstrudel.capture.upload.AndroidUploadPlatform
import com.handstrudel.capture.upload.CaptureMessageException
import com.handstrudel.capture.upload.DraftPostUpdate
import com.handstrudel.capture.upload.UploadPlatform
import com.handstrudel.capture.upload.VideoUploader
import com.handstrudel.engine.StudioEngine
import com.handstrudel.engine.StudioMode
import com.handstrudel.models.SoundSetup
import com.handstrudel.social.AuthSession
import com.handstrudel.social.SocialEntryPoints
import com.handstrudel.social.model.BackingCredit
import com.handstrudel.social.model.PerformanceLink
import com.handstrudel.social.model.Video
import com.handstrudel.store.StoreGate
import com.handstrudel.ui.nav.AppNavigator
import com.handstrudel.ui.nav.Destination
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeout
import java.io.File
import java.util.UUID
import kotlin.math.max
import kotlin.math.min

/**
 * The capture workstream's [CaptureController]: ports the iOS `ContentView`
 * recording, audio-loop and play-along orchestration. Main thread.
 */
class CaptureControllerImpl(
    private val context: Context,
    private val prefs: AppPrefs,
    private val engine: StudioEngine,
    private val store: StoreGate,
    val auth: AuthSession,
    private val analytics: AppAnalytics,
    private val reviewPrompt: ReviewPrompt,
    val drafts: RecordingDrafts = RecordingDrafts(File(context.filesDir, "drafts")),
    private val uploadPlatform: UploadPlatform = AndroidUploadPlatform(context, auth),
) : CaptureController {

    /** Capture-only UI state (not part of the seam). */
    data class Ui(
        val countingBeats: Boolean = false,
        /** Non-null while the watermark is drawn (recording); the credit decides its copy/QR. */
        val watermark: WatermarkState? = null,
        val loopNotice: String? = null,
        /** The take to review right after recording (iOS `reviewingDraft`). */
        val reviewingDraftId: UUID? = null,
        val consent: ConsentStep? = null,
        /** Identifies [consent]; each request is launched once even if several activity instances observe it. */
        val consentRequestId: Int = 0,
        val showBackingMixer: Boolean = false,
        /** Bumped to ask open draft sheets to close (posting returns to Music / opens the post). */
        val closeDraftsToken: Int = 0,
    )

    data class WatermarkState(val credit: BackingCredit?)

    enum class ConsentStep { AUDIO_PERMISSION, EXPLAINER, SCREEN_CAPTURE }

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private val _state = MutableStateFlow(CaptureState(backing = null))
    override val state: StateFlow<CaptureState> = _state
    override val isRecordingLocked: StateFlow<Boolean> = _state
        .map { it.isRecording || it.isBusy || it.countdown != null || it.isLoopCapturing }
        .distinctUntilChanged()
        .stateIn(scope, SharingStarted.Eagerly, false)
    private val _ui = MutableStateFlow(Ui())
    val ui: StateFlow<Ui> = _ui

    private var navigator: AppNavigator? = null
    private var startedActivities = 0
    private val isForeground: Boolean get() = startedActivities > 0

    // Recording
    private var recorder: ScreenRecorder? = null
    private var activeDraft: RecordingDraft? = null
    private var captureJob: Job? = null
    private var countInJob: Job? = null
    private var countInClick: AudioTrack? = null
    private var recordingUsesMicrophone = false
    private var retakeRequested = false

    // Loops
    private var activeLoop: LoopCapture? = null
    private var loopJob: Job? = null
    private var loopNoticeJob: Job? = null

    // Play-along
    private var backing: BackingTrack? = null
    private var backingLoad: Job? = null
    private var backingAutoplayPending = false

    // Consent
    private var consentResult: CompletableDeferred<Any?>? = null
    private var launchedConsentId = 0
    private var explainerShown = false

    private val uploaders = mutableMapOf<UUID, VideoUploader>()

    init {
        DraftExport.sweep(context)
        (context.applicationContext as? Application)?.registerActivityLifecycleCallbacks(object : Application.ActivityLifecycleCallbacks {
            override fun onActivityStarted(activity: Activity) { startedActivities++ }
            override fun onActivityStopped(activity: Activity) {
                startedActivities = max(0, startedActivities - 1)
                if (startedActivities == 0) handleBackgrounded()
            }
            override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) = Unit
            override fun onActivityResumed(activity: Activity) = Unit
            override fun onActivityPaused(activity: Activity) = Unit
            override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) = Unit
            override fun onActivityDestroyed(activity: Activity) = Unit
        })
        CaptureProjection.onStopped = { onProjectionStopped() }
        scope.launch {
            engine.isRunning.collect { running -> if (running) onSessionStarted() else onSessionEnded() }
        }
        scope.launch {
            prefs.playAlongBackingVolume.collect { volume ->
                backing?.setVolume(volume)
                _state.update { s -> s.copy(backing = s.backing?.copy(volume = BackingTrackVolume.clamped(volume))) }
            }
        }
    }

    override fun attach(navigator: AppNavigator) { this.navigator = navigator }

    private val recording get() = _state.value.isRecording
    private val busy get() = _state.value.isBusy
    private val countingDown get() = _state.value.countdown != null

    private fun recordingError(message: String) {
        navigator?.showError("Recording", message) ?: Log.w(TAG, message)
    }

    private fun soundError(message: String) {
        navigator?.showError("HandStrudel", message) ?: Log.w(TAG, message)
    }

    // ---- Session lifecycle -------------------------------------------------------------

    private fun onSessionStarted() {
        if (backingAutoplayPending) {
            backingAutoplayPending = false
            backing?.let { if (isForeground) playBacking(it) }
        }
    }

    override fun onSessionEnded() {
        cancelCountdown()
        backingLoad?.cancel()
        stopBacking()
        if (activeLoop != null) finishAudioLoop()
        if (recording) stopRecording()
        releaseProjectionIfIdle()
    }

    override fun onAppBackgrounded() {
        // Shell calls this from onStop. Another instance of the activity may still be visible
        // (the "Share one app" picker relaunches the main activity), so only act when none is.
        if (startedActivities > 1) return
        handleBackgrounded()
    }

    private fun handleBackgrounded() {
        backingLoad?.cancel()
        backingAutoplayPending = false
        backing?.pause()
        setBackingPlaying(false)
        when {
            recording -> stopRecording(interrupted = true)
            _state.value.isLoopCapturing && activeLoop != null -> finishAudioLoop()
            // The consent and permission dialogs are activities too; don't cancel while they're up.
            !busy && _ui.value.consent == null -> cancelCountdown()
        }
    }

    private fun onProjectionStopped() {
        // The user or the system ended screen capture (status-bar chip, another app took over…).
        if (activeLoop != null && _state.value.isLoopCapturing) {
            resolveAudioLoop(activeLoop!!, interrupted = true)
            return
        }
        if (recording && !busy) stopRecording(interrupted = true)
    }

    // ---- Consent (MediaProjection + RECORD_AUDIO) --------------------------------------

    /**
     * The consent UI calls this before launching a system dialog. True only for the first
     * caller of a request: the "Share one app" picker relaunches the app's main activity,
     * whose composition must not ask again.
     */
    fun claimConsentLaunch(requestId: Int): Boolean {
        if (requestId == 0 || requestId == launchedConsentId) return false
        launchedConsentId = requestId
        return true
    }

    /** The consent UI reports each step's result here. */
    fun onConsentStepResult(result: Any?) {
        Log.d(TAG, "consent step ${_ui.value.consent} -> ${(result as? Pair<*, *>)?.first ?: result}")
        _ui.update { it.copy(consent = null) }
        // Clear first: completing resumes the asker inline, which may install the next step.
        val pending = consentResult
        consentResult = null
        pending?.complete(result)
    }

    private suspend fun ask(step: ConsentStep): Any? {
        val deferred = CompletableDeferred<Any?>()
        consentResult?.complete(null)
        consentResult = deferred
        _ui.update { it.copy(consent = step, consentRequestId = it.consentRequestId + 1) }
        return deferred.await()
    }

    /**
     * Projection for this studio session, asking once (Android 14 tokens are single-use).
     * True when ready, false when it failed, null when the user declined.
     */
    private suspend fun ensureProjection(): Boolean? {
        if (CaptureProjection.isActive) return true
        if (!AppAudioCapture.hasRecordPermission(context)) ask(ConsentStep.AUDIO_PERMISSION)
        if (!explainerShown) {
            if (ask(ConsentStep.EXPLAINER) != true) return null
            explainerShown = true
        }
        val result = ask(ConsentStep.SCREEN_CAPTURE) as? Pair<*, *> ?: return null
        val code = result.first as? Int ?: return null
        val data = result.second as? Intent
        if (code != Activity.RESULT_OK || data == null) return null
        Log.d(TAG, "screen capture granted; starting the projection service")
        val started = CaptureProjection.beginStart()
        CaptureService.start(context, code, data)
        return try {
            withTimeout(10_000) { started.await() }
            true
        } catch (e: kotlinx.coroutines.TimeoutCancellationException) {
            false
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            Log.w(TAG, "projection", e)
            false
        }
    }

    // ---- Video recording ---------------------------------------------------------------

    fun toggleRecord() {
        when {
            recording -> stopRecording()
            countingDown -> cancelCountdown()
            else -> startRecordingCountdown()
        }
    }

    fun setHalfSpeed(enabled: Boolean) = prefs.setRecordAtHalfSpeed(enabled)

    fun startRecordingCountdown() {
        if (!engine.isRunning.value || recording || busy || activeLoop != null || countingDown || countInJob != null) return
        val halfSpeed = prefs.recordAtHalfSpeed.value
        if (halfSpeed && !engine.supportsHalfSpeedRecording) {
            recordingError("Half speed is available in solo play. End the jam, guided lesson, or saved sequence first.")
            return
        }
        countInJob = scope.launch {
            when (ensureProjection()) {
                true -> Unit
                false -> { countInJob = null; recordingError("Screen recording isn’t available right now."); return@launch }
                null -> { countInJob = null; return@launch }
            }
            val countIn = RecordingCountIn(backing?.savedBPM, halfSpeed)
            backing?.pause()
            setBackingPlaying(false)
            _ui.update { it.copy(showBackingMixer = false, countingBeats = countIn.usesBeats) }
            _state.update { it.copy(countdown = countIn.steps) }
            countInClick = countIn.clickSamples()?.let(::clickTrack)
            val start = SystemClock.elapsedRealtime()
            countInClick?.play()
            for (elapsedSteps in 1..countIn.steps) {
                val target = start + (elapsedSteps * countIn.secondsPerStep * 1000).toLong()
                delay(max(0, target - SystemClock.elapsedRealtime()))
                val remaining = countIn.steps - elapsedSteps
                _state.update { it.copy(countdown = remaining.takeIf { r -> r > 0 }) }
            }
            clearCountdown()
            if (engine.isRunning.value && isForeground) startRecording()
        }
    }

    private fun clickTrack(samples: ShortArray): AudioTrack? = runCatching {
        AudioTrack.Builder()
            .setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_MEDIA)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build())
            .setAudioFormat(AudioFormat.Builder().setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                .setSampleRate(RecordingCountIn.SAMPLE_RATE).setChannelMask(AudioFormat.CHANNEL_OUT_MONO).build())
            .setTransferMode(AudioTrack.MODE_STATIC)
            .setBufferSizeInBytes(samples.size * 2)
            .build()
            .also { it.write(samples, 0, samples.size) }
    }.getOrNull()

    fun cancelCountdown() {
        if (!countingDown && countInJob == null) return
        countInJob?.cancel()
        clearCountdown()
    }

    private fun clearCountdown() {
        countInClick?.let { runCatching { it.stop() }; it.release() }
        countInClick = null
        countInJob = null
        _state.update { it.copy(countdown = null) }
        _ui.update { it.copy(countingBeats = false) }
    }

    private fun currentModeName(): String = when (engine.mode.value) {
        StudioMode.SCALE -> "scale"
        StudioMode.SPLIT -> "split"
        StudioMode.RADIAL -> "radial"
        StudioMode.CHORD_MELODY -> "chord-melody"
        StudioMode.GRID -> "grid"
        StudioMode.DRUM -> "drums"
        StudioMode.LEARN -> "learn"
        else -> "melodic"
    }

    private fun startRecording() {
        val halfSpeed = prefs.recordAtHalfSpeed.value
        if (halfSpeed && !engine.supportsHalfSpeedRecording) {
            recordingError("Half-speed recording is unavailable in this session.")
            return
        }
        val draft = try {
            val sound = engine.currentSoundSetup
            drafts.begin(sound?.instrumentName, currentModeName(), sound, backing?.credit, halfSpeed)
        } catch (e: Exception) {
            recordingError("Couldn’t create a private draft. ${e.message ?: ""}".trim())
            return
        }
        activeDraft = draft
        _state.update { it.copy(isBusy = true) }
        engine.setRecordingTempo(draft.recordedAtHalfSpeed == true)
        backing?.setRate(if (draft.recordedAtHalfSpeed == true) 0.5 else 1.0)
        backing?.pause()
        setBackingPlaying(false)
        recordingUsesMicrophone = prefs.recordPerformanceMicrophone.value && AppAudioCapture.hasRecordPermission(context)
        _ui.update { it.copy(watermark = WatermarkState(draft.backingCredit)) }

        scope.launch {
            val started = try {
                // Let the watermark draw before the first frame is captured.
                delay(50)
                val projection = CaptureProjection.projection.value ?: throw IllegalStateException("Screen capture isn't active.")
                val audio = AppAudioCapture.create(context, projection, recordingUsesMicrophone)
                ScreenRecorder(context, drafts.videoFile(draft.id), audio) { onRecorderFailure() }.also { it.start() }
            } catch (e: Exception) {
                Log.w(TAG, "start", e)
                drafts.discardUnfinished(draft)
                finishRecordingUI()
                recordingError("Couldn’t start recording. ${e.message ?: ""}".trim())
                return@launch
            }
            recorder = started
            _state.update { it.copy(isBusy = false, isRecording = true) }
            analytics.record(AppAnalyticsEvent.RECORDING_STARTED)
            if (!isForeground) { stopRecording(interrupted = true); return@launch }
            if (draft.recordedAtHalfSpeed == true && !engine.supportsHalfSpeedRecording) { stopRecording(); return@launch }
            if (!started.hasAudio) {
                navigator?.showNotice("Recording without app sound. Allow microphone access in Settings so Android can capture HandStrudel's audio.")
            }
            backing?.let { track ->
                track.rewind()
                val ok = track.play()
                setBackingPlaying(ok)
                if (!ok) {
                    recordingError("The backing track couldn't start. Check the take before sharing.")
                    stopRecording()
                    return@launch
                }
            }
            captureJob = scope.launch {
                val limitSeconds = RecordingDrafts.RECORDING_LIMIT / draft.outputScale
                delay((limitSeconds * 1000).toLong())
                stopRecording()
            }
        }
    }

    private fun onRecorderFailure() {
        if (recording && !busy) stopRecording(interrupted = true)
    }

    fun stopRecording(interrupted: Boolean = false) {
        val draft = activeDraft ?: return
        val active = recorder ?: return
        if (!recording || busy) return
        _state.update { it.copy(isBusy = true) }
        captureJob?.cancel()
        engine.setRecordingTempo(false)
        scope.launch {
            val stopError = withContext(Dispatchers.IO) { runCatching { active.stop() }.exceptionOrNull() }
            val heardSound = active.heardSound
            val hadAudio = active.hasAudio
            finishRecordingUI()
            releaseProjectionIfIdle()
            val completed = runCatching { completeLiveRecording(draft) }.isSuccess
            when {
                !completed -> {
                    drafts.discardUnfinished(draft)
                    recordingError("Couldn’t save this take. ${(stopError?.message ?: "")}".trim())
                }
                interrupted || stopError != null ->
                    recordingError("Recording interrupted. Check Private drafts for the saved take.")
                else -> {
                    if (hadAudio && !heardSound) {
                        navigator?.showNotice("This take has no app sound. Some devices block audio capture.")
                    }
                    if (isForeground) _ui.update { it.copy(reviewingDraftId = draft.id) }
                }
            }
        }
    }

    /** Release the projection if the session ended while a take or loop was finishing. */
    private fun releaseProjectionIfIdle() {
        if (!engine.isRunning.value && !recording && activeLoop == null) CaptureService.stop(context)
    }

    private fun completeLiveRecording(draft: RecordingDraft) {
        drafts.complete(draft)
        analytics.record(AppAnalyticsEvent.RECORDING_SAVED)
    }

    private fun finishRecordingUI() {
        captureJob?.cancel()
        captureJob = null
        backing?.pause()
        backing?.setRate(1.0)
        engine.setRecordingTempo(false)
        setBackingPlaying(false)
        recordingUsesMicrophone = false
        recorder = null
        activeDraft = null
        _state.update { it.copy(isRecording = false, isBusy = false) }
        _ui.update { it.copy(watermark = null) }
    }

    // ---- Review sheet after a take -------------------------------------------------------

    fun onReviewShown() { if (engine.isRunning.value) engine.pause() }

    fun requestRetake() {
        retakeRequested = true
        _ui.update { it.copy(reviewingDraftId = null) }
    }

    fun onReviewDismissed() {
        _ui.update { it.copy(reviewingDraftId = null) }
        if (engine.isRunning.value) engine.resume()
        if (retakeRequested) {
            retakeRequested = false
            startRecordingCountdown()
        }
    }

    // ---- Audio loops -------------------------------------------------------------------

    fun toggleAudioLoop() {
        if (activeLoop != null) { finishAudioLoop(); return }
        if (!engine.isRunning.value || recording || busy || countingDown || loopJob != null) return
        if (engine.savedLoops.value.size >= StudioEngine.MAX_LOOPS) {
            showLoopNotice("Delete a saved loop before recording another.")
            return
        }
        engine.updateLoopCapture(isRecording = false, busy = true, progress = 0.0)
        _state.update { it.copy(isLoopCapturing = true, loopProgress = 0.0) }
        loopJob = scope.launch {
            val ready = ensureProjection()
            if (ready == null) { resetLoopState(); return@launch }
            val projection = if (ready) CaptureProjection.projection.value else null
            val audio = projection?.let { AppAudioCapture.create(context, it, includeMicrophone = false) }
            if (audio == null) {
                resetLoopState()
                recordingError("Audio capture isn't available right now.")
                return@launch
            }
            val capture = LoopCapture(File(File(context.cacheDir, "loop-capture"), "${UUID.randomUUID()}.wav"), audio)
            try {
                capture.start()
            } catch (e: Exception) {
                capture.discard()
                resetLoopState()
                recordingError("Couldn't start loop recording. ${e.message ?: ""}".trim())
                return@launch
            }
            activeLoop = capture
            val bpm = engine.manualBPM.value
            val duration = min(StudioEngine.MAX_LOOP_SECONDS, max(1.0, engine.loopDurationSeconds(bpm)))
            engine.updateLoopCapture(isRecording = true, busy = false, progress = 0.0)
            if (!isForeground) { finishAudioLoop(); return@launch }
            showLoopNotice("Recording app audio. Tap again to stop.")
            val start = SystemClock.elapsedRealtime()
            while (true) {
                val elapsed = (SystemClock.elapsedRealtime() - start) / 1000.0
                val progress = min(1.0, elapsed / duration)
                engine.updateLoopCapture(isRecording = true, busy = false, progress = progress)
                _state.update { it.copy(loopProgress = progress) }
                if (elapsed >= duration) { finishAudioLoop(); return@launch }
                delay(100)
            }
        }
    }

    private fun resetLoopState() {
        activeLoop = null
        loopJob = null
        engine.updateLoopCapture(isRecording = false, busy = false, progress = 0.0)
        _state.update { it.copy(isLoopCapturing = false, loopProgress = 0.0) }
    }

    fun finishAudioLoop() {
        val capture = activeLoop ?: return
        if (engine.loopCaptureBusy.value) return
        resolveAudioLoop(capture, interrupted = false)
    }

    private fun resolveAudioLoop(capture: LoopCapture, interrupted: Boolean) {
        if (activeLoop !== capture) return
        engine.updateLoopCapture(isRecording = engine.isLoopRecording.value, busy = true, progress = engine.loopRecordingProgress.value)
        val job = loopJob
        loopJob = null
        job?.cancel()
        scope.launch {
            val result = withContext(Dispatchers.IO) { runCatching { capture.finish() } }
            activeLoop = null
            engine.updateLoopCapture(isRecording = false, busy = false, progress = 0.0)
            _state.update { it.copy(isLoopCapturing = false, loopProgress = 0.0) }
            releaseProjectionIfIdle()
            val duration = result.getOrElse { e ->
                capture.file.delete()
                recordingError("Couldn't save the loop. ${e.message ?: ""}".trim())
                return@launch
            }
            val autoplay = isForeground && !interrupted
            val saved = engine.saveCapturedLoop(capture.file, duration, engine.manualBPM.value, engine.currentModeString, autoplay)
            when {
                saved == null -> {
                    capture.file.delete()
                    recordingError("Couldn't save the loop. ${if (engine.savedLoops.value.size >= StudioEngine.MAX_LOOPS) "Delete a saved loop before recording another." else ""}".trim())
                }
                interrupted -> showLoopNotice("Recording interrupted. Partial loop saved as WAV.")
                autoplay && saved.id !in engine.playingLoopIds.value ->
                    recordingError("The loop was saved, but it couldn't start playing. Try it from the loop shelf.")
                else -> showLoopNotice("Loop saved as WAV.")
            }
        }
    }

    private fun showLoopNotice(message: String) {
        _ui.update { it.copy(loopNotice = message) }
        loopNoticeJob?.cancel()
        loopNoticeJob = scope.launch {
            delay(2_500)
            if (_ui.value.loopNotice == message) _ui.update { it.copy(loopNotice = null) }
        }
    }

    // ---- Play-along --------------------------------------------------------------------

    override fun prepareBacking(video: Video) {
        if (recording || busy || countingDown || activeLoop != null) {
            soundError("Finish the current recording before starting Play Along.")
            return
        }
        backingLoad?.cancel()
        backingLoad = scope.launch {
            try {
                val source = SocialEntryPoints.fetchVideo(video.id)
                if (source == null || source.backingEnabled != true) {
                    throw CaptureMessageException("The creator no longer allows play-along on this performance.")
                }
                val username = source.username?.takeIf { it.isNotEmpty() }
                    ?: throw CaptureMessageException("This performance is missing the creator credit needed for Play Along.")
                _state.update { it.copy(backing = BackingState(BackingCredit(source.id, username), isLoading = true,
                    volume = BackingTrackVolume.clamped(prefs.playAlongBackingVolume.value))) }
                val track = BackingTrack.load(context, source, username)
                if (recording || busy || countingDown || activeLoop != null) {
                    track.remove()
                    throw CaptureMessageException("Finish the current recording before starting Play Along.")
                }
                stopBacking()
                track.setVolume(prefs.playAlongBackingVolume.value)
                track.onError = { error -> onBackingError(track, error) }
                backing = track
                _state.update { it.copy(backing = BackingState(track.credit, volume = BackingTrackVolume.clamped(prefs.playAlongBackingVolume.value))) }
                navigator?.select(Destination.Music)
                if (engine.isRunning.value) {
                    playBacking(track)
                    return@launch
                }
                backingAutoplayPending = true
                val setup: SoundSetup? = source.soundSetup?.takeIf { sound -> sound.requiredPacks.all { store.isUnlocked(it) } }
                navigator?.startSession(setup, useCurrentSoundAsFallback = true)
                    ?: Log.w(TAG, "prepareBacking: no navigator attached")
            } catch (e: CancellationException) {
                if (backing == null) _state.update { it.copy(backing = null) }
                throw e
            } catch (e: Exception) {
                Log.w(TAG, "Play Along load failed", e)
                if (backing == null) _state.update { it.copy(backing = null) }
                soundError((e as? CaptureMessageException)?.message ?: "Couldn't load the backing audio. Try again.")
            }
        }
    }

    fun toggleBackingPlayback() {
        val track = backing ?: return
        if (track.isPlaying) { track.pause(); setBackingPlaying(false) } else playBacking(track)
    }

    fun toggleBackingMixer() = _ui.update { it.copy(showBackingMixer = !it.showBackingMixer) }

    fun setBackingVolume(volume: Double) = prefs.setPlayAlongBackingVolume(volume)

    private fun playBacking(track: BackingTrack) {
        val ok = track.play()
        setBackingPlaying(ok)
        if (!ok) soundError("Couldn't start the backing audio. Tap Play to try again.")
    }

    /**
     * ExoPlayer reports playback failures asynchronously, after `play()` returned. Treat them
     * like iOS treats `AVAudioPlayer.play()` returning false: block the take while recording
     * (so it isn't shared without its backing), otherwise ask to try again.
     */
    private fun onBackingError(track: BackingTrack, error: Exception) {
        if (backing !== track) return
        Log.w(TAG, "backing playback failed", error)
        setBackingPlaying(false)
        if (recording) {
            recordingError("The backing track couldn't start. Check the take before sharing.")
            stopRecording()
        } else {
            soundError("Couldn't start the backing audio. Tap Play to try again.")
        }
    }

    private fun stopBacking() {
        backing?.remove()
        backing = null
        backingAutoplayPending = false
        _ui.update { it.copy(showBackingMixer = false) }
        _state.update { it.copy(backing = null) }
    }

    private fun setBackingPlaying(playing: Boolean) =
        _state.update { s -> s.copy(backing = s.backing?.copy(isPlaying = playing)) }

    // ---- Drafts, export and posting ------------------------------------------------------

    fun uploader(draftId: UUID): VideoUploader = uploaders.getOrPut(draftId) {
        VideoUploader(uploadPlatform, onPosted = { analytics.record(AppAnalyticsEvent.RECORDING_POSTED) })
    }

    val canPost: Boolean get() = auth.isConfigured
    val isSignedInForPosting: Boolean get() = auth.userId.value != null && !auth.needsProfileSetup

    fun recordSuccessfulTake(draftId: UUID) = reviewPrompt.recordSuccessfulTake(draftId)

    /** iOS `PostComposerView.post()`. [onLeave] closes the composer when screening starts or the post lands. */
    fun post(
        draft: RecordingDraft,
        clip: DraftExport,
        caption: String,
        soundSetup: SoundSetup?,
        commentsEnabled: Boolean,
        backingEnabled: Boolean,
        onLeave: () -> Unit,
    ) {
        val accountId = auth.userId.value ?: return
        val uploader = uploader(draft.id)
        scope.launch {
            var handedOff = false
            fun leaveComposer() {
                handedOff = true
                onLeave()
                returnToMusicAfterPosting()
            }
            val posted = uploader.post(
                clip.file, draft.id, accountId, drafts, caption, draft.instrument, draft.mode, soundSetup,
                commentsEnabled, backingEnabled, draft.backingCredit,
            ) {
                if (auth.userId.value == accountId) {
                    leaveComposer()
                    showPostUpdate(DraftPostUpdate.Checking)
                }
            }
            if (auth.userId.value != accountId) return@launch
            if (posted) {
                if (!handedOff) leaveComposer()
                recordSuccessfulTake(draft.id)
                showPostUpdate(DraftPostUpdate.Posted)
            } else {
                val phase = uploader.phase.value
                if (handedOff && phase is VideoUploader.Phase.Failed) showPostUpdate(DraftPostUpdate.Failed(phase.message))
            }
        }
    }

    private fun showPostUpdate(update: DraftPostUpdate) { navigator?.showNotice(update.notice) }

    private fun returnToMusicAfterPosting() {
        navigator?.select(Destination.Music)
        _ui.update { it.copy(reviewingDraftId = null, closeDraftsToken = it.closeDraftsToken + 1) }
    }

    fun viewPost(id: UUID) {
        _ui.update { it.copy(reviewingDraftId = null, closeDraftsToken = it.closeDraftsToken + 1) }
        navigator?.openPerformance(PerformanceLink.Watch(id))
    }

    /** Background work tied to the app (exports for sharing etc.), not to a composable. */
    fun launch(block: suspend CoroutineScope.() -> Unit): Job = scope.launch(block = block)

    companion object {
        private const val TAG = "Capture"
    }
}
