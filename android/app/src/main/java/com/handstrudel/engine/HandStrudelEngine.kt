package com.handstrudel.engine

import android.Manifest
import android.app.Activity
import android.app.Application
import android.content.Context
import android.content.pm.PackageManager
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import android.view.Choreographer
import android.view.View
import android.webkit.WebView
import androidx.core.content.ContextCompat
import com.handstrudel.BuildConfig
import com.handstrudel.app.SharedPrefsStore
import com.handstrudel.engine.audio.SoundFontEngine
import com.handstrudel.engine.loops.AudioLoopStore
import com.handstrudel.engine.modes.ChordMelodyModeController
import com.handstrudel.engine.modes.DrumModeController
import com.handstrudel.engine.modes.GridModeController
import com.handstrudel.engine.modes.LearnModeController
import com.handstrudel.engine.modes.MelodicModeController
import com.handstrudel.engine.modes.ModeController
import com.handstrudel.engine.modes.SoundFontModeController
import com.handstrudel.engine.persistence.EnginePersistence
import com.handstrudel.engine.persistence.SoundPresetPack
import com.handstrudel.engine.strudel.StrudelBridge
import com.handstrudel.models.CIRCLE_OF_FIFTHS
import com.handstrudel.models.ChordProgression
import com.handstrudel.models.CustomScale
import com.handstrudel.models.DEFAULT_MAPPING
import com.handstrudel.models.DEFAULT_PROGRESSION
import com.handstrudel.models.LearnSong
import com.handstrudel.models.MusicKey
import com.handstrudel.models.NOTES
import com.handstrudel.models.NOTE_DISPLAY
import com.handstrudel.models.NamedSoundSetup
import com.handstrudel.models.PARAM_MAP
import com.handstrudel.models.STRUCTS
import com.handstrudel.models.ScaleSelection
import com.handstrudel.models.SoundFontInstrument
import com.handstrudel.models.SoundSetup
import com.handstrudel.models.SoundSetupMode
import com.handstrudel.models.WAVEFORMS
import com.handstrudel.models.cameraFilter
import com.handstrudel.models.chordDisplayName
import com.handstrudel.models.chordNotes
import com.handstrudel.models.chordNotesWithSeventh
import com.handstrudel.models.drumLoop
import com.handstrudel.models.fmt
import com.handstrudel.models.handTheme
import com.handstrudel.models.learnSong
import com.handstrudel.models.midiNoteName
import com.handstrudel.models.midiToStrudelNote
import com.handstrudel.models.scaleNotes
import com.handstrudel.models.scaleNotesOneOctave
import com.handstrudel.models.soundFontInstrument
import com.handstrudel.store.StoreGate
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import uniffi.handstrudel_core.ChordMelodyModeManager
import uniffi.handstrudel_core.GridModeManager
import java.io.File
import java.util.UUID
import uniffi.handstrudel_core.Layout as CoreLayout

/**
 * The engine behind the [StudioEngine] seam: a port of iOS
 * `Engine/EngineController.swift`. Strudel (WebView) voices the melodic family,
 * Grid, Drums, both drum-loop tracks and non-SoundFont chord+melody;
 * TinySoundFont voices the SoundFont-routed chord+melody family. Main thread.
 */
class HandStrudelEngine(context: Context) : StudioEngine {
    private val appContext = context.applicationContext
    private val main = Handler(Looper.getMainLooper())
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)

    override val handTracker = HandTrackingManager(appContext)
    val haptics = HapticManager(appContext)
    internal val persistence = EnginePersistence(SharedPrefsStore(appContext, "engine"))
    internal val soundFont = SoundFontEngine(appContext).also { it.preload() }
    internal val strudel = StrudelBridge(appContext, debugMeter = BuildConfig.DEBUG)
    internal val loopStore = AudioLoopStore(File(appContext.filesDir, "loops"), persistence)

    /** Shared Rust chord+melody state machine (Grid/Radial/Split/Scale layouts). */
    val chordMelodyManager: ChordMelodyModeManager = ChordMelodyModeManager()
    internal val gridManager: GridModeManager = GridModeManager()
    internal val drumManager = DrumModeManager()
    internal val learnManager = LearnModeManager()
    internal val quantize = QuantizeClock()

    /**
     * Width / height of the stage the wheel / lanes are drawn into, for the hand mapping
     * (iOS reads the full-screen bounds every tick). Follows the visible activity's content
     * view (the Stage fills it edge to edge), so fold/unfold and window resizes take effect.
     */
    internal var screenAspect: Double = appContext.resources.displayMetrics.let {
        stageAspect(it.widthPixels.toDouble(), it.heightPixels.toDouble()) ?: 0.46
    }
        private set

    private val stageLayoutListener = View.OnLayoutChangeListener { v, _, _, _, _, _, _, _, _ -> updateStageAspect(v) }

    private fun updateStageAspect(v: View) {
        stageAspect(v.width.toDouble(), v.height.toDouble())?.let { screenAspect = it }
    }

    private fun trackStage(activity: Activity, attach: Boolean) {
        val content = activity.findViewById<View>(android.R.id.content) ?: return
        content.removeOnLayoutChangeListener(stageLayoutListener)
        if (attach) {
            content.addOnLayoutChangeListener(stageLayoutListener)
            updateStageAspect(content)
        }
    }

    // =====================================================================================
    // Lifecycle
    // =====================================================================================

    private val _isRunning = MutableStateFlow(false)
    override val isRunning: StateFlow<Boolean> = _isRunning
    private val _isPaused = MutableStateFlow(false)
    override val isPaused: StateFlow<Boolean> = _isPaused
    private val _status = MutableStateFlow("tap start")
    override val status: StateFlow<String> = _status
    private val _auxiliaryAudioIssue = MutableStateFlow<String?>(null)
    override val auxiliaryAudioIssue: StateFlow<String?> = _auxiliaryAudioIssue

    private var startupJob: Job? = null
    private var startupGeneration = 0
    private var startTimeNanos: Long? = null
    private var sceneActive = true
    internal var recordingTempoScale = 1.0
        private set
    private var lastReportedTempo = 0.0

    /** Seconds since the session opened (iOS `Date().timeIntervalSince(startTime)`). */
    internal fun elapsed(): Double = startTimeNanos?.let { (SystemClock.elapsedRealtimeNanos() - it) / 1e9 } ?: 0.0

    internal fun nowSeconds(): Double = SystemClock.elapsedRealtimeNanos() / 1e9

    override fun start(input: PlayInput) {
        if (_isRunning.value || startupJob != null) return
        _playInput.value = input
        _auxiliaryAudioIssue.value = null
        _isPaused.value = false
        rawParams.clear(); rawParams.putAll(config.defaultParams())
        smoothed.clear(); smoothed.putAll(rawParams)

        _status.value = "Preparing instrument…"
        startupGeneration += 1
        val generation = startupGeneration
        if (activeMode is SoundFontModeController && soundFont.startIfNeeded(_instrument.value.program)) {
            openStudioSession()
        }
        startupJob = scope.launch {
            try {
                strudel.initialize()
                if (generation != startupGeneration) return@launch
                connectWebAudio()
                if (!_isRunning.value) openStudioSession()
            } catch (e: kotlinx.coroutines.CancellationException) {
                throw e
            } catch (e: Exception) {
                if (generation != startupGeneration) return@launch
                Log.w(TAG, "start error", e)
                if (_isRunning.value) {
                    _auxiliaryAudioIssue.value = "Web synths and drum loops couldn't load. Your native instrument is still available."
                } else {
                    _status.value = "error: ${e.message ?: "The web audio engine couldn't start."} Try again."
                }
            } finally {
                if (generation == startupGeneration) startupJob = null
            }
        }
    }

    private fun openStudioSession() {
        startCameraIfRequested()
        startTimeNanos = SystemClock.elapsedRealtimeNanos()
        startFrameLoop()
        startTimers()
        _status.value = "Playing"
        _isRunning.value = true
        updateLearnPause()
    }

    private fun connectWebAudio() {
        if (!strudel.isReady) return
        strudel.setTempoScale(recordingTempoScale, _manualBPM.value)
        lastStructKey = ""
        strudel.onBeat = { beat ->
            if (_isRunning.value) {
                val old = _currentBeat.value
                _currentBeat.value = beat
                if (beat != old) {
                    haptics.beatPulse(isDownbeat = beat == 0)
                    quantize.onBeat(nowSeconds(), recordingTempoScale)
                }
            }
        }
    }

    override fun stop() {
        startupGeneration += 1
        startupJob?.cancel()
        startupJob = null
        _auxiliaryAudioIssue.value = null
        setRecordingTempo(false)
        persistState()
        loopStore.persist()

        stopFrameLoop()
        stopTimers()

        silenceAll()
        clearTouches()
        strudel.stop()
        stopAllLoops()
        handTracker.isActive = false
        strudel.onBeat = null

        // iOS resets every mode flag (→ melodic) and the lane state on stop.
        _mode.value = StudioMode.MELODIC
        leadVoiceMidi = null
        lastGridNote = ""
        lastDrumHit = ""
        lastStructKey = ""
        _lanes.value = LaneDisplay()
        currentHands = HandsState()
        _handsState.value = HandsState()
        startTimeNanos = null

        _isPaused.value = false
        _isRunning.value = false
        _status.value = "tap start"
    }

    override fun pause() {
        _isPaused.value = true
        updateLearnPause()
        loopStore.pauseAll()
        silenceAll()
    }

    override fun resume() {
        _isPaused.value = false
        updateLearnPause()
        if (sceneActive) loopStore.resumeAll()
    }

    /**
     * Shell forwards the activity's ON_START/ON_STOP. The process-wide [foreground] count
     * decides: ON_STOP only backgrounds the engine once no activity is visible (checked
     * after the stop has been counted).
     */
    override fun setSceneActive(active: Boolean) {
        if (active) applySceneActive(true)
        else main.post { if (!foreground.isForeground) applySceneActive(false) }
    }

    /**
     * iOS has no background audio mode, so going home suspends the app: drum loops, Strudel
     * patterns, layered audio loops and held notes all go silent, and the session is still
     * running when the user comes back. The backing track is paused by capture.
     */
    private fun applySceneActive(active: Boolean) {
        val changed = sceneActive != active
        sceneActive = active
        updateLearnPause()
        if (!active) {
            stopInstrumentPreview()
            persistState()
            if (changed && _isRunning.value) {
                if (!_isPaused.value) loopStore.pauseAll()
                silenceAll()
                clearTouches()
                currentHands = HandsState()
                _handsState.value = HandsState()
            }
        } else {
            if (changed && _isRunning.value && !_isPaused.value) {
                loopStore.resumeAll()
                lastStructKey = "" // re-evaluate the pattern and drum loops on the next tick
            }
            if (_isRunning.value && handTracker.cameraIssue.value != null) startCameraIfRequested()
        }
    }

    private val foreground = ForegroundTracker { visible -> applySceneActive(visible) }

    /** Kill all active sounds without stopping the engine (iOS `silenceAll`). */
    override fun silenceAll() {
        for (hand in listOf("left", "right", "touch1", "touch2", "lead")) strudel.noteOff(hand)
        leadVoiceMidi = null
        strudel.stop()
        soundFont.allNotesOff()
        lastStructKey = ""
    }

    // =====================================================================================
    // Input
    // =====================================================================================

    private val _playInput = MutableStateFlow(PlayInput.AIR)
    override val playInput: StateFlow<PlayInput> = _playInput
    override val cameraIssue: StateFlow<CameraIssue?> = handTracker.cameraIssue
    private val _handsState = MutableStateFlow(HandsState())
    override val handsState: StateFlow<HandsState> = _handsState

    internal var currentHands = HandsState()
    internal val config = DEFAULT_MAPPING
    private val rawParams = mutableMapOf<String, Double>()
    internal val smoothed = mutableMapOf<String, Double>()

    override fun setPlayInput(input: PlayInput) {
        if (input == _playInput.value) return
        _playInput.value = input
        if (!_isRunning.value) return
        if (input == PlayInput.AIR) startCameraIfRequested()
        else {
            handTracker.isActive = false
            currentHands = HandsState()
            _handsState.value = HandsState()
            silenceAll()
        }
    }

    override fun reportCameraIssue(issue: CameraIssue?) = handTracker.reportCameraIssue(issue)

    /**
     * iOS `HandTrackingManager.startSession`: clear the last issue and re-check camera access
     * on every start, so access granted later in Settings takes effect. No access reports
     * PERMISSION_DENIED, which falls back to touch. (The shell asks for the permission
     * before switching to Air; this is the check, not the prompt.)
     */
    override fun startCameraIfRequested() {
        if (_playInput.value != PlayInput.AIR) return
        val issue = handTracker.cameraIssue.value
        if (handTracker.isActive && issue == null) return
        handTracker.reportCameraIssue(null)
        if (ContextCompat.checkSelfPermission(appContext, Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
            handTracker.isActive = false
            handTracker.reportCameraIssue(CameraIssue.PERMISSION_DENIED)
            return
        }
        handTracker.isActive = true
    }

    /** iOS `fallBackToTouch`: blocked camera access switches play input to touch. */
    private fun fallBackToTouch() {
        if (_playInput.value != PlayInput.AIR) return
        _playInput.value = PlayInput.TOUCH
        handTracker.isActive = false
        currentHands = HandsState()
        _handsState.value = HandsState()
    }

    private fun handleHandsUpdate(hands: HandsState) {
        if (_playInput.value != PlayInput.AIR || !sceneActive) return
        applyHands(hands)
    }

    private fun applyHands(hands: HandsState) {
        currentHands = hands
        val m = _mode.value
        if (m != StudioMode.GRID && m != StudioMode.DRUM) HandMapper.mapHandsToParams(hands, rawParams, config)
    }

    /** Verification hook: feed synthetic hands as if the camera saw them (debug receiver). */
    fun injectHands(hands: HandsState) = applyHands(hands)

    // =====================================================================================
    // Mode
    // =====================================================================================

    private val _mode = MutableStateFlow(StudioMode.fromRaw(persistence.lastMode) ?: StudioMode.SPLIT)
    override val mode: StateFlow<StudioMode> = _mode
    override val currentModeString: String get() = _mode.value.raw

    private val melodicMode = MelodicModeController()
    private val gridMode = GridModeController()
    private val drumMode = DrumModeController()
    private val chordMelodyMode = ChordMelodyModeController()
    private val learnMode = LearnModeController()
    private val soundFontMode = SoundFontModeController()

    /** iOS `activeMode`. */
    internal val activeMode: ModeController
        get() = when (_mode.value) {
            StudioMode.LEARN -> learnMode
            StudioMode.SOUNDFONT -> soundFontMode
            StudioMode.RADIAL -> if (_radialSF.value) soundFontMode else chordMelodyMode
            StudioMode.SPLIT -> if (_splitSF.value) soundFontMode else chordMelodyMode
            StudioMode.SCALE -> if (_scaleSF.value) soundFontMode else chordMelodyMode
            StudioMode.CHORD_MELODY -> chordMelodyMode
            StudioMode.GRID -> gridMode
            StudioMode.DRUM -> drumMode
            else -> melodicMode
        }

    /** iOS `switchMode(...)`: silence, flip the mode, warm up the sampler for SoundFont. */
    override fun switchMode(mode: StudioMode) {
        silenceAll()
        clearTouches()
        _mode.value = mode
        if (mode == StudioMode.SOUNDFONT) soundFont.startIfNeeded(_instrument.value.program)
        if (mode != StudioMode.LEARN) persistence.lastMode = mode.raw
        updateLearnPause()
    }

    /** The current chord+melody layout (iOS sets `manager.layout` each tick). */
    internal val layout: CoreLayout
        get() = when (_mode.value) {
            StudioMode.SCALE -> CoreLayout.SCALE
            StudioMode.SPLIT -> CoreLayout.SPLIT
            StudioMode.RADIAL -> CoreLayout.RADIAL
            else -> CoreLayout.GRID
        }

    /** True when the active path voices through the native sampler (iOS `activeSoundFontRouting`). */
    val activeSoundFontRouting: Boolean
        get() = when (_mode.value) {
            StudioMode.SOUNDFONT -> true
            StudioMode.RADIAL -> _radialSF.value
            StudioMode.SPLIT -> _splitSF.value
            StudioMode.SCALE -> _scaleSF.value
            else -> false
        }

    // =====================================================================================
    // Sound
    // =====================================================================================

    private val _key = MutableStateFlow(MusicKey.fromRaw(persistence.lastKey) ?: MusicKey.C)
    override val selectedKey: StateFlow<MusicKey> = _key
    private val _scale = MutableStateFlow(persistence.lastScale)
    override val selectedScale: StateFlow<ScaleSelection> = _scale
    private val _instrument = MutableStateFlow(soundFontInstrument(persistence.lastSoundFont))
    override val selectedSoundFontInstrument: StateFlow<SoundFontInstrument> = _instrument
    private val _waveform = MutableStateFlow(persistence.lastWaveform.takeIf { id -> WAVEFORMS.any { it.id == id } } ?: "sawtooth")
    override val selectedWaveform: StateFlow<String> = _waveform
    private val _progression = MutableStateFlow(DEFAULT_PROGRESSION)
    override val chordMelodyProgression: StateFlow<ChordProgression> = _progression
    private val _manualBPM = MutableStateFlow(persistence.lastBPM)
    override val manualBPM: StateFlow<Double> = _manualBPM
    private val _quantizeEnabled = MutableStateFlow(persistence.lastQuantizeEnabled)
    override val quantizeEnabled: StateFlow<Boolean> = _quantizeEnabled
    private val _quantizeDiv = MutableStateFlow(persistence.lastQuantizeDiv.toInt())
    override val quantizeDiv: StateFlow<Int> = _quantizeDiv
    private val _swapHands = MutableStateFlow(false)
    override val chordMelodySwapHands: StateFlow<Boolean> = _swapHands
    private val _autoStrum = MutableStateFlow(false)
    override val chordMelodyAutoStrum: StateFlow<Boolean> = _autoStrum
    private val _padVolume = MutableStateFlow(0.6)
    override val chordMelodyPadVolume: StateFlow<Double> = _padVolume
    private val _radialSF = MutableStateFlow(false)
    private val _splitSF = MutableStateFlow(true)
    private val _scaleSF = MutableStateFlow(true)
    override val radialUseSoundFont: StateFlow<Boolean> = _radialSF
    override val splitUseSoundFont: StateFlow<Boolean> = _splitSF
    override val scaleUseSoundFont: StateFlow<Boolean> = _scaleSF
    private val _gridBaseOctave = MutableStateFlow(persistence.lastGridBaseOctave)
    override val gridBaseOctave: StateFlow<Int> = _gridBaseOctave
    private val _gridOctaveRange = MutableStateFlow(persistence.lastGridOctaveRange)
    override val gridOctaveRange: StateFlow<Int> = _gridOctaveRange
    private val _fingerOctave = MutableStateFlow(false)
    override val fingerOctaveEnabled: StateFlow<Boolean> = _fingerOctave
    override fun setFingerOctaveEnabled(enabled: Boolean) { _fingerOctave.value = enabled }
    internal val _fingerCount = MutableStateFlow(0)
    override val currentFingerCount: StateFlow<Int> = _fingerCount
    private val _chordMode = MutableStateFlow(false)
    override val chordMode: StateFlow<Boolean> = _chordMode
    private val _circleOfFifths = MutableStateFlow(false)
    override val circleOfFifthsEnabled: StateFlow<Boolean> = _circleOfFifths

    internal val key: MusicKey get() = _key.value
    internal val scale: ScaleSelection get() = _scale.value
    internal val waveform: String get() = _waveform.value
    internal val padVolume: Double get() = _padVolume.value
    internal val autoStrum: Boolean get() = _autoStrum.value
    internal val swapHandsOn: Boolean get() = _swapHands.value
    internal val chordModeOn: Boolean get() = _chordMode.value
    internal val instrumentProgram: Int get() = _instrument.value.program
    internal val quantizeOn: Boolean get() = _quantizeEnabled.value

    /** Cached scale notes (octaves 2–5) for the melodic family. */
    internal var cachedScaleNotes: List<Int> = scaleNotes(_key.value, _scale.value)
        private set

    internal fun recomputeScaleNotes() {
        cachedScaleNotes = scaleNotes(_key.value, _scale.value)
    }

    /** Grid / Learn lane notes (iOS `scaleNotes(key:scale:baseOctave:octaveRange:)`). */
    internal fun gridNotes(): List<Int> = scaleNotes(_key.value, _scale.value, _gridBaseOctave.value, _gridOctaveRange.value)

    override fun setKey(key: MusicKey) {
        if (_key.value == key) return
        _key.value = key
        recomputeScaleNotes()
        lastStructKey = ""
        persistence.lastKey = key.rawValue
    }

    /** iOS `selectScale`. */
    override fun setScale(scale: ScaleSelection) {
        _scale.value = scale
        recomputeScaleNotes()
        lastStructKey = ""
        persistence.lastScale = scale
    }

    override fun setSoundFontInstrument(instrument: SoundFontInstrument) {
        if (_instrument.value.id == instrument.id) return
        _instrument.value = instrument
        soundFont.setInstrument(instrument.program)
        persistence.lastSoundFont = instrument.id
    }

    override fun setWaveform(id: String) {
        if (WAVEFORMS.none { it.id == id }) return
        _waveform.value = id
        persistence.lastWaveform = id
    }

    override fun setProgression(progression: ChordProgression) {
        _progression.value = progression
        chordMelodyManager.setZoneDegrees(progression.degrees)
        _chordMelody.value = _chordMelody.value.copy(zoneDegrees = progression.degrees)
    }

    override fun setManualBPM(bpm: Double) {
        _manualBPM.value = bpm
        persistence.lastBPM = bpm
    }

    override fun setQuantizeEnabled(enabled: Boolean) {
        _quantizeEnabled.value = enabled
        quantize.enabled = enabled
        persistence.lastQuantizeEnabled = enabled
    }

    override fun setQuantizeDiv(div: Int) {
        if (div !in listOf(4, 8, 16)) return
        _quantizeDiv.value = div
        quantize.div = div.toDouble()
        persistence.lastQuantizeDiv = div.toDouble()
    }

    override fun setSwapHands(swap: Boolean) {
        _swapHands.value = swap
        chordMelodyManager.setSwapHands(swap)
    }

    override fun setAutoStrum(enabled: Boolean) { _autoStrum.value = enabled }

    override fun setPadVolume(volume: Double) { _padVolume.value = volume.coerceIn(0.0, 0.6) }

    override fun setUseSoundFont(mode: StudioMode, enabled: Boolean) {
        val flow = when (mode) {
            StudioMode.RADIAL -> _radialSF
            StudioMode.SPLIT -> _splitSF
            StudioMode.SCALE -> _scaleSF
            else -> return
        }
        if (flow.value == enabled) return
        if (_mode.value == mode) { silenceAll(); clearTouches() }
        flow.value = enabled
        if (enabled) soundFont.startIfNeeded(_instrument.value.program)
    }

    override fun setGridBaseOctave(octave: Int) {
        _gridBaseOctave.value = octave.coerceIn(1, 6)
        persistence.lastGridBaseOctave = _gridBaseOctave.value
    }

    override fun setGridOctaveRange(range: Int) {
        _gridOctaveRange.value = range.coerceIn(1, 3)
        persistence.lastGridOctaveRange = _gridOctaveRange.value
    }

    override fun setChordMode(enabled: Boolean) {
        _chordMode.value = enabled
        lastStructKey = ""
    }

    override fun setCircleOfFifths(enabled: Boolean) { _circleOfFifths.value = enabled }

    // ---- Drum tracks --------------------------------------------------------------------

    private val _drum1 = MutableStateFlow(DrumTrackState(loopId = "none"))
    private val _drum2 = MutableStateFlow(DrumTrackState(loopId = "none"))
    override val drumTrack1: StateFlow<DrumTrackState> = _drum1
    override val drumTrack2: StateFlow<DrumTrackState> = _drum2
    private fun track(n: Int) = if (n == 2) _drum2 else _drum1
    override fun setDrumLoop(track: Int, loopId: String) { track(track).value = track(track).value.copy(loopId = drumLoop(loopId).id) }
    override fun setDrumVolume(track: Int, volume: Double) { track(track).value = track(track).value.copy(volume = clampDrumVolume(volume)) }
    override fun setDrumBPM(track: Int, bpm: Double) { track(track).value = track(track).value.copy(bpm = bpm.coerceIn(20.0, 400.0)) }
    private val _drumIntensity = MutableStateFlow(0.5)
    override val drumIntensity: StateFlow<Double> = _drumIntensity
    override fun setDrumIntensity(value: Double) { _drumIntensity.value = value.coerceIn(0.0, 1.0) }
    private val _drumComplexity = MutableStateFlow(0.5)
    override val drumComplexity: StateFlow<Double> = _drumComplexity
    override fun setDrumComplexity(value: Double) { _drumComplexity.value = value.coerceIn(0.0, 1.0) }

    /** iOS `drumStateKey`: patterns re-evaluate only when a drum setting changed. */
    internal val drumStateKey: String
        get() {
            val d1 = _drum1.value
            val d2 = _drum2.value
            return "${d1.loopId}|${d1.volume}|${d1.bpm}|${d2.loopId}|${d2.volume}|${d2.bpm}|${_drumComplexity.value}|${_drumIntensity.value}"
        }

    internal fun buildDrumCodeParts(): List<String> =
        buildDrumCodeParts(_drum1.value, _drum2.value, _drumIntensity.value, _drumComplexity.value, recordingTempoScale)

    /** iOS `evaluateDrumLoopsIfChanged`. */
    internal fun evaluateDrumLoopsIfChanged(modePrefix: String) {
        if (!strudel.isReady) return
        val key = "$modePrefix|$drumStateKey"
        if (key == lastStructKey) return
        lastStructKey = key
        strudel.evaluate(stackCode(buildDrumCodeParts()))
    }

    // ---- Melodic params -----------------------------------------------------------------

    private val _lockedParams = MutableStateFlow<Set<String>>(emptySet())
    override val lockedParams: StateFlow<Set<String>> = _lockedParams
    private val _manualValues = MutableStateFlow<Map<String, Double>>(emptyMap())
    override val manualValues: StateFlow<Map<String, Double>> = _manualValues
    private val _smoothedParams = MutableStateFlow<Map<String, Double>>(emptyMap())
    override val smoothedParams: StateFlow<Map<String, Double>> = _smoothedParams
    override val bpmIsMapped: Boolean get() = config.bpmIsMapped
    override val mappedParamIds: List<String>
        get() = (config.left.values + config.right.values).filter { it in PARAM_MAP }.toSet().sorted()

    override fun setManualValue(paramId: String, value: Double) {
        _manualValues.value = _manualValues.value + (paramId to value)
        if (paramId in _lockedParams.value) rawParams[paramId] = value
    }

    override fun toggleLock(paramId: String) {
        val locked = _lockedParams.value
        if (paramId in locked) _lockedParams.value = locked - paramId
        else {
            _lockedParams.value = locked + paramId
            val v = _smoothedParams.value[paramId] ?: PARAM_MAP[paramId]?.defaultValue ?: 0.0
            _manualValues.value = _manualValues.value + (paramId to v)
        }
    }

    private fun updateManualOverrides() {
        if (!config.bpmIsMapped) rawParams["bpm"] = _manualBPM.value
        for (id in _lockedParams.value) _manualValues.value[id]?.let { rawParams[id] = it }
        if (_circleOfFifths.value) {
            currentHands.left?.let { left ->
                val newKey = CIRCLE_OF_FIFTHS[(left.x * 12).toInt().coerceIn(0, 11)]
                if (newKey != _key.value) { _key.value = newKey; recomputeScaleNotes() }
            }
        }
        structIdx = currentStructIdx
    }

    // ---- Visuals (persisted ids) --------------------------------------------------------

    private val _filter = MutableStateFlow(cameraFilter(persistence.lastFilterId).id)
    override val selectedFilter: StateFlow<String> = _filter
    override fun setFilter(id: String) {
        _filter.value = cameraFilter(id).id
        persistence.lastFilterId = _filter.value
    }
    private val _handTheme = MutableStateFlow(handTheme(persistence.lastHandThemeId).id)
    override val selectedHandTheme: StateFlow<String> = _handTheme
    override fun setHandTheme(id: String) {
        _handTheme.value = handTheme(id).id
        persistence.lastHandThemeId = _handTheme.value
    }

    // =====================================================================================
    // Display state
    // =====================================================================================

    private val _currentBeat = MutableStateFlow(0)
    override val currentBeat: StateFlow<Int> = _currentBeat
    private val _bpm = MutableStateFlow(120.0)
    override val bpm: StateFlow<Double> = _bpm
    private val _noteDisplay = MutableStateFlow("")
    override val noteDisplay: StateFlow<String> = _noteDisplay
    private val _codeDisplay = MutableStateFlow("")
    override val codeDisplay: StateFlow<String> = _codeDisplay
    private val _chordMelody = MutableStateFlow(ChordMelodyDisplay())
    override val chordMelody: StateFlow<ChordMelodyDisplay> = _chordMelody
    private val _lanes = MutableStateFlow(LaneDisplay())
    override val lanes: StateFlow<LaneDisplay> = _lanes

    internal var lastGridNote = ""
    internal var lastDrumHit = ""
    internal var leadVoiceMidi: Int? = null
    internal var structIdx = 0
    private var currentStructIdx = 0
    internal var lastStructKey = ""

    internal fun updateChordMelodyDisplay(transform: (ChordMelodyDisplay) -> ChordMelodyDisplay) {
        _chordMelody.value = transform(_chordMelody.value)
    }

    internal fun updateLanes(transform: (LaneDisplay) -> LaneDisplay) {
        _lanes.value = transform(_lanes.value)
    }

    internal fun chordName(degree: Int): String = chordDisplayName(_key.value, _scale.value, degree)

    // =====================================================================================
    // Frame loop and timers
    // =====================================================================================

    private var frameCallback: Choreographer.FrameCallback? = null
    private val uiTimer = object : Runnable {
        override fun run() { syncUi(); main.postDelayed(this, 125) }
    }
    private val structTimer = object : Runnable {
        override fun run() {
            currentStructIdx = (currentStructIdx + 1) % STRUCTS.size
            main.postDelayed(this, 8000)
        }
    }

    private fun startFrameLoop() {
        if (frameCallback != null) return
        val cb = object : Choreographer.FrameCallback {
            override fun doFrame(frameTimeNanos: Long) {
                if (frameCallback !== this) return
                try { tick() } catch (e: Exception) { Log.e(TAG, "tick failed", e) }
                Choreographer.getInstance().postFrameCallback(this)
            }
        }
        frameCallback = cb
        Choreographer.getInstance().postFrameCallback(cb)
    }

    private fun stopFrameLoop() {
        frameCallback?.let { Choreographer.getInstance().removeFrameCallback(it) }
        frameCallback = null
    }

    private fun startTimers() {
        stopTimers()
        main.postDelayed(uiTimer, 125)
        main.postDelayed(structTimer, 8000)
    }

    private fun stopTimers() {
        main.removeCallbacks(uiTimer)
        main.removeCallbacks(structTimer)
    }

    /** iOS `tick()` (60 fps). */
    private fun tick() {
        updateManualOverrides()
        ParamSmoother.smooth(rawParams, smoothed)
        // In the background nothing may re-evaluate (iOS is suspended).
        if (_isPaused.value || !sceneActive) return
        val mode = activeMode
        if (!strudel.isReady && mode !is SoundFontModeController) return
        if (recordingTempoScale != 1.0) {
            val effective = smoothed["bpm"] ?: _manualBPM.value
            if (effective != lastReportedTempo) { strudel.updateTempo(effective); lastReportedTempo = effective }
        }
        mode.tick(this)
    }

    /** iOS ~8 fps UI sync (`uiTimer`). */
    private fun syncUi() {
        val s = smoothed.toMap()
        _smoothedParams.value = s
        _handsState.value = currentHands
        _bpm.value = s["bpm"] ?: 120.0
        if (_mode.value == StudioMode.GRID) {
            _noteDisplay.value = lastGridNote.ifEmpty { "pinch to play" }
            _codeDisplay.value = "grid mode — ${_key.value.rawValue} ${_scale.value.displayName}"
            return
        }
        val notes = cachedScaleNotes
        _noteDisplay.value = when {
            _chordMode.value -> {
                val count = _scale.value.intervals.size
                val n = (s["noteIdx"] ?: 0.0) / (NOTES.size - 1)
                chordName(((n * (count - 1)) + 0.5).toInt().coerceIn(0, count - 1))
            }
            notes.isNotEmpty() -> {
                val n = (s["noteIdx"] ?: 10.0) / (NOTES.size - 1)
                midiNoteName(notes[((n * (notes.size - 1)) + 0.5).toInt().coerceIn(0, notes.size - 1)])
            }
            else -> NOTE_DISPLAY[Math.round(s["noteIdx"] ?: 10.0).toInt().coerceIn(0, NOTES.size - 1)]
        }
        _codeDisplay.value = buildDisplayCode(s)
    }

    /** iOS `buildDisplayCode`. */
    private fun buildDisplayCode(p: Map<String, Double>): String {
        val cpm = fmt((p["bpm"] ?: 120.0) / 4, 1)
        val st = STRUCTS[structIdx.coerceIn(0, STRUCTS.size - 1)]
        val notes = cachedScaleNotes
        val noteStr = when {
            _chordMode.value -> {
                val count = _scale.value.intervals.size
                val degree = ((p["noteIdx"] ?: 0.0) / (NOTES.size - 1) * (count - 1) + 0.5).toInt().coerceIn(0, count - 1)
                chordNotes(_key.value, _scale.value, degree).joinToString(",") { midiToStrudelNote(it) }
            }
            notes.isNotEmpty() -> {
                val idx = ((p["noteIdx"] ?: 10.0) / (NOTES.size - 1) * (notes.size - 1) + 0.5).toInt().coerceIn(0, notes.size - 1)
                midiToStrudelNote(notes[idx])
            }
            else -> NOTES[Math.round(p["noteIdx"] ?: 10.0).toInt().coerceIn(0, NOTES.size - 1)]
        }
        val lines = mutableListOf("note(\"$noteStr\")", "  .s(\"${_waveform.value}\")", "  .struct(\"$st\")", "  .cpm($cpm)")
        for (id in config.extraParamIds()) {
            val def = PARAM_MAP[id] ?: continue
            lines += "  .${def.strudelKey}(${def.toCode(p[id] ?: def.defaultValue)})"
        }
        return lines.joinToString("\n")
    }

    // =====================================================================================
    // Learn
    // =====================================================================================

    private val _learn = MutableStateFlow(LearnDisplay())
    override val learn: StateFlow<LearnDisplay> = _learn
    internal var learnViewportAspect = 0.5
        private set

    /** iOS `loadLearnSong`: the song sets key, scale and tempo. */
    override fun loadLearnSong(songId: String) {
        learnSong(songId)?.let(::loadLearnSong)
    }

    /** iOS `currentLearnSong`. */
    private var currentLearnSong: LearnSong? = null

    override fun replayLearnSong() {
        currentLearnSong?.let(::loadLearnSong)
    }

    private fun loadLearnSong(song: LearnSong) {
        currentLearnSong = song
        _key.value = song.suggestedKey
        _scale.value = song.suggestedScale
        recomputeScaleNotes()
        learnManager.loadSong(song, gridNotes(), song.bpm)
        _manualBPM.value = song.bpm
        updateLearnPause()
        updateLearnUi(song.id, song.name)
    }

    override fun updateLearnViewport(widthPx: Float, heightPx: Float) {
        if (!widthPx.isFinite() || !heightPx.isFinite() || widthPx <= 0 || heightPx <= 0) return
        learnViewportAspect = (widthPx / heightPx).toDouble()
    }

    override fun tapLearnLane(lane: Int) {
        if (_mode.value != StudioMode.LEARN || _learn.value.songComplete || _isPaused.value || !sceneActive) return
        val notes = gridNotes()
        if (lane !in notes.indices) return
        val hit = learnManager.tapLane(lane, elapsed())
        strudel.playNote(hit ?: notes[lane], _waveform.value, 0.7, 0.3)
        if (strudel.isReady) notifyFirstNote()
        if (hit != null) haptics.learnPerfectHit() else haptics.noteTrigger()
        updateLearnUi()
    }

    internal fun updateLearnUi(songId: String? = _learn.value.currentSongId, songName: String? = _learn.value.currentSongName) {
        _learn.value = LearnDisplay(
            currentSongId = songId,
            currentSongName = songName,
            score = learnManager.score,
            visibleNotes = learnManager.visibleNotes,
            hitEffects = learnManager.hitEffects,
            songComplete = learnManager.songComplete,
            countdownValue = learnManager.countdownValue,
            isCountingDown = learnManager.isCountingDown,
        )
    }

    private fun updateLearnPause() {
        // iOS `updateLearnPause`: only the control sheet and the scene pause the song clock;
        // leaving Learn mode doesn't (the song keeps running and unplayed notes become misses).
        learnManager.setPaused(_isPaused.value || !sceneActive, elapsed())
    }

    // =====================================================================================
    // Touch: iOS ContentView split/scale handlers, plus radial/zones/grid/drum lanes
    // =====================================================================================

    private data class TouchChord(val touchId: String, val degree: Int, val octave: Int, val tones: List<Int>)
    private data class TouchVoices(val native: Boolean, val voices: List<String>)

    private val touchChordStack = mutableListOf<TouchChord>()
    private val touchVoices = mutableMapOf<String, TouchVoices>()
    private val touchZones = mutableMapOf<String, ChordSubzone>()
    private val touchLanes = mutableMapOf<String, Int>()
    private val gridTouches = mutableMapOf<String, String>()

    private val touchEnabled: Boolean get() = _isRunning.value && !_isPaused.value && sceneActive

    private fun syncTouchChordToManager() {
        val top = touchChordStack.lastOrNull()
        if (top != null) chordMelodyManager.setTouchChord(top.degree, top.octave, top.tones)
        else chordMelodyManager.setTouchChord(null, 0, emptyList())
    }

    private fun touchNoteOn(voice: String, midi: Int, velocity: Double, native: Boolean) {
        if (native) soundFont.noteOn(voice, midi, velocity) else strudel.noteOn(voice, midi, _waveform.value, velocity)
    }

    private fun touchNoteOff(voice: String, native: Boolean) {
        if (native) soundFont.releaseTemporaryVoice(voice) else strudel.noteOff(voice)
    }

    private fun touchNative(): Boolean = activeSoundFontRouting && soundFont.startIfNeeded(_instrument.value.program)

    private fun publishTouches() {
        _chordMelody.value = _chordMelody.value.copy(
            touchedChordZones = touchZones.values.toSet(),
            touchedMelodyLanes = touchLanes.values.toSet(),
        )
    }

    /** A finger on a chord wedge/zone: sustained chord voices + the manager's touch override. */
    private fun wheelTouchEnterChord(touchId: String, zone: Int, octave: Int) {
        if (!touchEnabled) return
        wheelTouchExit(touchId)
        val native = touchNative()
        val degree = chordMelodyManager.degreeForZone(zone)
        val voicing = if (_mode.value == StudioMode.SCALE) chordNotesWithSeventh(_key.value, _scale.value, degree)
        else chordNotes(_key.value, _scale.value, degree)
        val tones = voicing.map { it + octave * 12 }
        val subs = tones.mapIndexed { i, note -> "$touchId-c$i".also { touchNoteOn(it, note, 0.7, native) } }
        touchVoices[touchId] = TouchVoices(native, subs)
        touchChordStack += TouchChord(touchId, degree, octave, tones)
        touchZones[touchId] = ChordSubzone(zone, octave)
        syncTouchChordToManager()
        publishTouches()
        haptics.noteTrigger()
    }

    /** A finger on a melody lane: one voice snapped to the held chord (Scale: the scale octave). */
    private fun wheelTouchEnterMelody(touchId: String, lane: Int) {
        if (!touchEnabled) return
        wheelTouchExit(touchId)
        val native = touchNative()
        val lanes = if (_mode.value == StudioMode.SCALE) scaleNotesOneOctave(_key.value, _scale.value)
        else {
            val degree = touchChordStack.lastOrNull()?.degree ?: _chordMelody.value.currentDegree
                ?: chordMelodyManager.zoneDegrees().firstOrNull() ?: 0
            val triad = chordNotes(_key.value, _scale.value, degree)
            (0 until 3).flatMap { oct -> triad.map { it + oct * 12 } }.sorted()
        }
        if (lanes.isEmpty()) return
        val voice = "$touchId-m"
        touchNoteOn(voice, lanes[lane.coerceIn(0, lanes.size - 1)], 0.75, native)
        touchVoices[touchId] = TouchVoices(native, listOf(voice))
        touchLanes[touchId] = lane
        publishTouches()
        haptics.noteTrigger()
    }

    private fun wheelTouchExit(touchId: String) {
        touchVoices.remove(touchId)?.let { route -> route.voices.forEach { touchNoteOff(it, route.native) } }
        if (touchChordStack.removeAll { it.touchId == touchId }) syncTouchChordToManager()
        val zone = touchZones.remove(touchId)
        val lane = touchLanes.remove(touchId)
        if (zone != null || lane != null) publishTouches()
    }

    private fun clearTouches() {
        for ((_, route) in touchVoices) route.voices.forEach { touchNoteOff(it, route.native) }
        touchVoices.clear()
        touchChordStack.clear()
        touchZones.clear()
        touchLanes.clear()
        gridTouches.values.forEach { strudel.noteOff(it) }
        gridTouches.clear()
        syncTouchChordToManager()
        publishTouches()
    }

    override fun splitTouchEnterChord(touchId: String, wedge: Int, octave: Int) = wheelTouchEnterChord(touchId, wedge, octave)
    override fun splitTouchEnterMelody(touchId: String, lane: Int) = wheelTouchEnterMelody(touchId, lane)
    override fun splitTouchExit(touchId: String) = wheelTouchExit(touchId)
    override fun scaleTouchEnterChord(touchId: String, wedge: Int, octave: Int) = wheelTouchEnterChord(touchId, wedge, octave)
    override fun scaleTouchEnterMelody(touchId: String, lane: Int) = wheelTouchEnterMelody(touchId, lane)
    override fun scaleTouchExit(touchId: String) = wheelTouchExit(touchId)
    override fun radialTouchEnterChord(touchId: String, zone: Int) = wheelTouchEnterChord(touchId, zone, 0)
    override fun radialTouchEnterMelody(touchId: String, lane: Int) = wheelTouchEnterMelody(touchId, lane)
    override fun radialTouchExit(touchId: String) = wheelTouchExit(touchId)
    override fun zonesTouchEnterChord(touchId: String, zone: Int) = wheelTouchEnterChord(touchId, zone, 0)
    override fun zonesTouchEnterMelody(touchId: String, lane: Int) = wheelTouchEnterMelody(touchId, lane)
    override fun zonesTouchEnterChord(touchId: String, zone: Int, octave: Int) = wheelTouchEnterChord(touchId, zone, octave)
    override fun zonesTouchExit(touchId: String) = wheelTouchExit(touchId)

    /** iOS `GridTouchOverlay.noteInfo`: `lane` is the visual row from the top. */
    private fun gridNote(lane: Int): Int? = gridNotes().let { it.getOrNull(it.size - 1 - lane) }

    override fun gridLaneTouchOn(touchId: String, lane: Int) {
        if (!touchEnabled) return
        val midi = gridNote(lane) ?: return
        val voice = gridTouches[touchId] ?: (if ("touch1" in gridTouches.values) "touch2" else "touch1").also { gridTouches[touchId] = it }
        strudel.noteOn(voice, midi, _waveform.value, 0.7)
        haptics.noteTrigger()
        lastGridNote = midiNoteName(midi)
        updateLanes { it.copy(lastGridNote = lastGridNote) }
    }

    override fun gridLaneTouchSlide(touchId: String, lane: Int) {
        val voice = gridTouches[touchId] ?: return gridLaneTouchOn(touchId, lane)
        val midi = gridNote(lane) ?: return
        strudel.noteSlide(voice, midi)
        lastGridNote = midiNoteName(midi)
        updateLanes { it.copy(lastGridNote = lastGridNote) }
        haptics.lightTap()
    }

    override fun gridLaneTouchOff(touchId: String) {
        gridTouches.remove(touchId)?.let { strudel.noteOff(it) }
    }

    /** Drum lane tap (0 = crash … 5 = kick), iOS `drumZoneOverlay`. */
    override fun drumLaneTap(lane: Int) {
        if (!touchEnabled) return
        val drum = DrumModeManager.ALL_DRUMS.getOrNull(lane) ?: return
        strudel.playHit(drum.hitType)
        haptics.drumHit()
        lastDrumHit = drum.hitType
        updateLanes { it.copy(lastDrumHit = drum.hitType) }
    }

    override fun drumPad(x: Double, y: Double) {
        setDrumIntensity(x)
        setDrumComplexity(y)
    }

    // =====================================================================================
    // Presets and custom scales
    // =====================================================================================

    override val currentSoundSetup: SoundSetup?
        get() {
            val setupMode = _mode.value.setupMode ?: return null
            return buildSoundSetup(setupMode, activeSoundFontRouting)
        }

    override val soundSetupForSaving: SoundSetup?
        get() = if (_isRunning.value) currentSoundSetup
        else buildSoundSetup(SoundSetupMode.SCALE_CHORD_MELODY, _scaleSF.value)

    private fun buildSoundSetup(mode: SoundSetupMode, useSoundFont: Boolean): SoundSetup {
        val p = _progression.value
        return SoundSetup(
            instrument = _instrument.value.id, waveform = _waveform.value, key = _key.value, scale = _scale.value,
            progression = p.id, customDegrees = if (p.isCustom) p.degrees else null, mode = mode, bpm = _manualBPM.value,
            useSoundFont = useSoundFont, autoStrum = _autoStrum.value, padVolume = _padVolume.value,
            gridOctave = _gridBaseOctave.value, gridRange = _gridOctaveRange.value,
        )
    }

    override fun applySoundSetup(setup: SoundSetup, store: StoreGate): Boolean {
        val progression = setup.resolvedProgression
        if (!setup.isValid || progression == null || !setup.requiredPacks.all { store.isUnlocked(it) }) return false
        val mode = StudioMode.from(setup.mode)
        silenceAll()
        setKey(setup.key)
        setScale(setup.scale)
        setProgression(progression)
        if (setup.useSoundFont) setup.resolvedInstrument?.let(::setSoundFontInstrument) else setWaveform(setup.waveform)
        when (mode) {
            StudioMode.RADIAL -> _radialSF.value = setup.useSoundFont
            StudioMode.SPLIT -> _splitSF.value = setup.useSoundFont
            StudioMode.SCALE -> _scaleSF.value = setup.useSoundFont
            else -> Unit
        }
        setManualBPM(setup.bpm)
        _autoStrum.value = setup.autoStrum
        _padVolume.value = setup.padVolume
        setGridBaseOctave(setup.gridOctave)
        setGridOctaveRange(setup.gridRange)
        switchMode(mode)
        return true
    }

    private val _presets = MutableStateFlow(persistence.loadSetups())
    override val presets: StateFlow<List<NamedSoundSetup>> = _presets

    override fun addPreset(sound: SoundSetup, name: String): Boolean =
        persistence.addPreset(sound, name).also { _presets.value = persistence.loadSetups() }

    override fun deletePreset(id: UUID) {
        persistence.deletePreset(id)
        _presets.value = persistence.loadSetups()
    }

    override fun importPresetPack(bytes: ByteArray): Result<Int> = runCatching {
        persistence.importPresetPack(SoundPresetPack.decode(bytes))
    }.also { _presets.value = persistence.loadSetups() }

    override fun exportPresetPack(ids: List<UUID>): Result<ByteArray> = runCatching {
        val wanted = ids.toSet()
        SoundPresetPack.from(_presets.value.filter { it.id in wanted }).encoded()
    }

    private val _customScales = MutableStateFlow(persistence.loadCustomScales())
    override val customScales: StateFlow<List<CustomScale>> = _customScales

    override fun saveCustomScale(scale: CustomScale): Boolean {
        if (!scale.isValid) return false
        val ok = persistence.saveCustomScale(scale)
        _customScales.value = persistence.loadCustomScales()
        // Editing the scale in use re-voices it immediately.
        if (ok && (_scale.value as? ScaleSelection.Custom)?.scale?.id == scale.id) setScale(ScaleSelection.Custom(scale))
        return ok
    }

    override fun deleteCustomScale(id: UUID) {
        persistence.removeCustomScale(id)
        _customScales.value = persistence.loadCustomScales()
        if ((_scale.value as? ScaleSelection.Custom)?.scale?.id == id) setScale(ScaleSelection.PENTATONIC)
    }

    // =====================================================================================
    // Recording hooks and loops
    // =====================================================================================

    override fun setRecordingTempo(halfSpeed: Boolean) {
        val scale = if (halfSpeed) 0.5 else 1.0
        if (scale == recordingTempoScale) return
        val bpm = smoothed["bpm"] ?: _manualBPM.value
        recordingTempoScale = scale
        strudel.setTempoScale(scale, bpm)
        quantize.reset(60 / maxOf(1.0, bpm * scale))
        lastStructKey = ""
        loopStore.setRate(scale)
    }

    override val supportsHalfSpeedRecording: Boolean
        get() = _mode.value != StudioMode.LEARN && loopStore.allPlayingAreAudio

    private val _isLoopRecording = MutableStateFlow(false)
    override val isLoopRecording: StateFlow<Boolean> = _isLoopRecording
    private val _loopBusy = MutableStateFlow(false)
    override val loopCaptureBusy: StateFlow<Boolean> = _loopBusy
    private val _loopProgress = MutableStateFlow(0.0)
    override val loopRecordingProgress: StateFlow<Double> = _loopProgress

    override fun updateLoopCapture(isRecording: Boolean, busy: Boolean, progress: Double) {
        _isLoopRecording.value = isRecording
        _loopBusy.value = busy
        _loopProgress.value = progress.coerceIn(0.0, 1.0)
    }

    private val _loopBars = MutableStateFlow(persistence.lastLoopBars)
    override val loopRecordingBars: StateFlow<Int> = _loopBars

    override fun setLoopRecordingBars(bars: Int) {
        if (bars !in EnginePersistence.LOOP_BAR_OPTIONS) return
        _loopBars.value = bars
        persistence.lastLoopBars = bars
    }

    override fun loopDurationSeconds(bpm: Double): Double = loopDuration(_loopBars.value, bpm)

    override val savedLoops: StateFlow<List<SavedLoop>> = loopStore.loops
    override val playingLoopIds: StateFlow<Set<UUID>> = loopStore.playing

    override fun saveCapturedLoop(file: File, durationSeconds: Double, bpm: Double, mode: String, autoplay: Boolean): SavedLoop? {
        val loop = loopStore.add(file, durationSeconds, bpm, mode) ?: return null
        if (autoplay) toggleLoopPlayback(loop.id)
        return loop
    }

    override fun toggleLoopPlayback(id: UUID): Boolean =
        loopStore.toggle(id, prepareOnly = _isRunning.value && _isPaused.value)

    override fun renameLoop(id: UUID, name: String): Boolean = loopStore.rename(id, name)
    override fun setLoopGain(id: UUID, gain: Double) = loopStore.setGain(id, gain)
    override fun toggleLoopMute(id: UUID) = loopStore.toggleMute(id)
    override fun deleteLoop(id: UUID) = loopStore.delete(id)
    override fun stopAllLoops() = loopStore.stopAll()

    // =====================================================================================
    // Hooks, previews
    // =====================================================================================

    override var onFirstNote: (() -> Unit)? = null

    internal fun notifyFirstNote() {
        if (_isRunning.value && !_isPaused.value) onFirstNote?.invoke()
    }

    override val audioSessionId: Int get() = soundFont.output.audioSessionId
    override val appAudioTap: AppAudioTap get() = soundFont.output
    override val strudelWebView: StateFlow<WebView?> = MutableStateFlow(strudel.webView)

    private var previewJob: Job? = null

    /**
     * iOS `StartOverlayView.playPreview`: [notes] on [instrument] through the native
     * sampler (250 ms steps, the last held 570 ms). Idle only; false if unavailable.
     */
    override fun previewInstrument(instrument: SoundFontInstrument, notes: List<Int>): Boolean {
        if (_isRunning.value) return false
        stopInstrumentPreview()
        if (!soundFont.startIfNeeded(instrument.program)) return false
        soundFont.setInstrument(instrument.program)
        previewJob = scope.launch {
            delay(120)
            for ((i, note) in notes.withIndex()) {
                if (!isActive) return@launch
                soundFont.noteOn(PREVIEW_VOICE, note, 0.7)
                delay(if (i == notes.size - 1) 570 else 250)
            }
            soundFont.hardStop(PREVIEW_VOICE)
            soundFont.releaseTemporaryVoice(PREVIEW_VOICE)
            previewJob = null
        }
        return true
    }

    override fun previewStart(instrument: SoundFontInstrument): Boolean {
        if (_isRunning.value) return false
        stopInstrumentPreview()
        if (!soundFont.startIfNeeded(instrument.program)) return false
        soundFont.setInstrument(instrument.program)
        return true
    }

    override fun previewNoteOn(midi: Int, velocity: Double) {
        if (!_isRunning.value) soundFont.noteOn(PREVIEW_VOICE, midi, velocity)
    }

    override fun previewStop() = stopInstrumentPreview()

    override fun previewPresetPack(bytes: ByteArray): Result<List<NamedSoundSetup>> = runCatching {
        SoundPresetPack.decode(bytes).presets.map { NamedSoundSetup(UUID.randomUUID(), it.name, it.sound) }
    }

    override val cameraAspect: Double get() = handTracker.videoAspect

    override fun stopInstrumentPreview() {
        previewJob?.cancel()
        previewJob = null
        soundFont.hardStop(PREVIEW_VOICE)
        soundFont.releaseTemporaryVoice(PREVIEW_VOICE)
    }

    /** iOS `ContentView.playFirstNote` (onboarding): the Scale instrument, else Strudel. */
    override fun playFirstNote(midi: Int) {
        if (_scaleSF.value && soundFont.startIfNeeded(_instrument.value.program)) {
            soundFont.oneShot(midi, 0.75, 0.48)
            notifyFirstNote()
        } else {
            strudel.playNote(midi, _waveform.value, 0.75, 0.48)
            if (strudel.isReady) notifyFirstNote()
        }
        haptics.noteTrigger()
    }

    private fun persistState() {
        persistence.saveEngineState(
            mode = if (_mode.value == StudioMode.LEARN) persistence.lastMode else currentModeString,
            key = _key.value, scale = _scale.value, waveform = _waveform.value, bpm = _manualBPM.value,
            filterId = _filter.value, gridBaseOctave = _gridBaseOctave.value, gridOctaveRange = _gridOctaveRange.value,
            quantizeEnabled = _quantizeEnabled.value, quantizeDiv = _quantizeDiv.value.toDouble(),
        )
        persistence.lastSoundFont = _instrument.value.id
    }

    init {
        chordMelodyManager.setZoneDegrees(_progression.value.degrees)
        _chordMelody.value = ChordMelodyDisplay(zoneDegrees = _progression.value.degrees)
        quantize.enabled = _quantizeEnabled.value
        quantize.div = _quantizeDiv.value.toDouble()
        val firstNote: () -> Unit = { notifyFirstNote() }
        soundFont.onNoteStarted = firstNote
        strudel.onNoteStarted = firstNote
        handTracker.isActive = false
        handTracker.onCameraIssue = { issue ->
            if (issue == CameraIssue.PERMISSION_DENIED || issue == CameraIssue.RESTRICTED) main.post { fallBackToTouch() }
        }
        handTracker.onHandsDetected = { hands -> main.post { handleHandsUpdate(hands) } }
        (appContext as? Application)?.registerActivityLifecycleCallbacks(object : Application.ActivityLifecycleCallbacks {
            override fun onActivityStarted(activity: Activity) {
                trackStage(activity, attach = true)
                foreground.activityStarted()
            }
            override fun onActivityStopped(activity: Activity) {
                trackStage(activity, attach = false)
                foreground.activityStopped()
            }
            override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) = Unit
            override fun onActivityResumed(activity: Activity) = Unit
            override fun onActivityPaused(activity: Activity) = Unit
            override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) = Unit
            override fun onActivityDestroyed(activity: Activity) = Unit
        })
        if (BuildConfig.DEBUG) com.handstrudel.engine.debug.EngineDebugReceiver.register(appContext, this)
    }

    companion object {
        private const val TAG = "HandStrudelEngine"
        private const val PREVIEW_VOICE = "studio-preview"

        /** `bars × 4 × 60 / bpm`, capped at 90 s. */
        fun loopDuration(bars: Int, bpm: Double): Double =
            minOf(StudioEngine.MAX_LOOP_SECONDS, bars * 4 * 60.0 / bpm.coerceIn(20.0, 400.0))

        /** Width / height of the stage as laid out (iOS `bounds.width / bounds.height`); null when empty. */
        fun stageAspect(width: Double, height: Double): Double? =
            if (width > 0 && height > 0 && width.isFinite() && height.isFinite()) width / height else null

        /** The Mix tab's VOL slider runs 20–200% (iOS `Slider(in: 0.2...2.0)`); iOS doesn't clamp further. */
        fun clampDrumVolume(volume: Double): Double = if (volume.isFinite()) volume.coerceIn(0.0, 2.0) else 1.0

        internal fun stackCode(parts: List<String>): String =
            if (parts.isEmpty()) "silence" else if (parts.size == 1) parts[0] else "stack(${parts.joinToString(", ")})"

        /** iOS `buildDrumCodeParts` as a pure function (unit-tested). */
        fun buildDrumCodeParts(
            track1: DrumTrackState, track2: DrumTrackState, intensity: Double, complexity: Double, tempoScale: Double,
        ): List<String> {
            val intensityGain = 0.3 + intensity * 1.2
            val complexitySpeed = 1.0 + complexity * 2.0
            return listOf(track1, track2).mapNotNull { t ->
                val code = drumLoop(t.loopId).code
                if (code.isEmpty()) return@mapNotNull null
                val withGain = "($code).gain(${fmt(t.volume * intensityGain, 2)})"
                "($withGain).cpm(${fmt(t.bpm / 4.0 * complexitySpeed * tempoScale, 1)})"
            }
        }
    }
}
