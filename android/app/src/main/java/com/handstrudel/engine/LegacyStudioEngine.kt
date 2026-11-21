package com.handstrudel.engine

import android.util.Log
import android.webkit.WebView
import com.handstrudel.models.ChordProgression
import com.handstrudel.models.CustomScale
import com.handstrudel.models.MusicKey
import com.handstrudel.models.NamedSoundSetup
import com.handstrudel.models.PRESETS
import com.handstrudel.models.ScaleSelection
import com.handstrudel.models.SoundFontInstrument
import com.handstrudel.models.SoundSetup
import com.handstrudel.store.StoreGate
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import java.io.File
import java.util.UUID

/**
 * Phase 0 adapter: exposes today's [EngineController] (Split + legacy Melodic/
 * Grid/Drum) through the [StudioEngine] seam so the app keeps playing while the
 * workstreams fan out. Owner: engine. WS2 replaces this with a full
 * implementation (EngineController implementing StudioEngine) and deletes it.
 *
 * Anything the legacy controller cannot do is held as plain state or ignored.
 */
class LegacyStudioEngine(val controller: EngineController) : StudioEngine {

    private fun todo(what: String) { Log.d(TAG, "Not implemented yet (engine WS): $what") }

    // ---- Lifecycle ----
    override val isRunning: StateFlow<Boolean> = controller.isRunning
    private val _isPaused = MutableStateFlow(false)
    override val isPaused: StateFlow<Boolean> = _isPaused
    private val _status = MutableStateFlow("tap start")
    override val status: StateFlow<String> = _status
    override val auxiliaryAudioIssue: StateFlow<String?> = MutableStateFlow(null)

    override fun start(input: PlayInput) {
        setPlayInput(input)
        controller.start(PRESETS.first())
        _isPaused.value = false
        _status.value = "Playing"
    }

    override fun stop() {
        controller.stop()
        _isPaused.value = false
        _status.value = "tap start"
    }

    override fun pause() { _isPaused.value = true }
    override fun resume() { _isPaused.value = false }
    override fun setSceneActive(active: Boolean) = todo("setSceneActive")
    override fun silenceAll() = todo("silenceAll")

    // ---- Input ----
    private val _playInput = MutableStateFlow(PlayInput.AIR)
    override val playInput: StateFlow<PlayInput> = _playInput
    override fun setPlayInput(input: PlayInput) { _playInput.value = input }
    private val _cameraIssue = MutableStateFlow<CameraIssue?>(null)
    override val cameraIssue: StateFlow<CameraIssue?> = _cameraIssue
    override fun reportCameraIssue(issue: CameraIssue?) {
        _cameraIssue.value = issue
        if (issue != null) _playInput.value = PlayInput.TOUCH
    }
    override fun startCameraIfRequested() = Unit // CameraPreview binds the camera itself today.
    override val handsState: StateFlow<HandsState> = controller.handsState
    override val handTracker: HandTrackingManager get() = controller.handTracker

    // ---- Mode ----
    private val _mode = MutableStateFlow(StudioMode.SPLIT)
    override val mode: StateFlow<StudioMode> = _mode
    override val currentModeString: String get() = _mode.value.raw
    override fun switchMode(mode: StudioMode) {
        _mode.value = mode
        controller.gridModeEnabled = mode == StudioMode.GRID
        controller.drumModeEnabled = mode == StudioMode.DRUM
        // Legacy controller has only the Split wheel for the whole chord+melody family.
        controller.chordMelodyModeEnabled = mode.isChordMelodyFamily
    }

    // ---- Sound ----
    override val selectedKey: StateFlow<MusicKey> = controller.selectedKeyFlow
    override fun setKey(key: MusicKey) { controller.selectedKey = key }
    private val _scale = MutableStateFlow<ScaleSelection>(ScaleSelection.BuiltIn(controller.selectedScale))
    override val selectedScale: StateFlow<ScaleSelection> = _scale
    override fun setScale(scale: ScaleSelection) {
        when (scale) {
            is ScaleSelection.BuiltIn -> { controller.selectedScale = scale.scale; _scale.value = scale }
            is ScaleSelection.Custom -> todo("custom scales")
        }
    }
    override val selectedSoundFontInstrument: StateFlow<SoundFontInstrument> = controller.selectedInstrumentFlow
    override fun setSoundFontInstrument(instrument: SoundFontInstrument) { controller.selectedInstrument = instrument }
    private val _waveform = MutableStateFlow(controller.selectedWaveform)
    override val selectedWaveform: StateFlow<String> = _waveform
    override fun setWaveform(id: String) { controller.selectedWaveform = id; _waveform.value = id }
    override val chordMelodyProgression: StateFlow<ChordProgression> = controller.selectedProgressionFlow
    override fun setProgression(progression: ChordProgression) { controller.selectedProgression = progression }
    private val _manualBPM = MutableStateFlow(controller.manualBPM)
    override val manualBPM: StateFlow<Double> = _manualBPM
    override fun setManualBPM(bpm: Double) { controller.manualBPM = bpm; _manualBPM.value = bpm }
    private val _quantizeEnabled = MutableStateFlow(false)
    override val quantizeEnabled: StateFlow<Boolean> = _quantizeEnabled
    override fun setQuantizeEnabled(enabled: Boolean) { _quantizeEnabled.value = enabled }
    private val _quantizeDiv = MutableStateFlow(8)
    override val quantizeDiv: StateFlow<Int> = _quantizeDiv
    override fun setQuantizeDiv(div: Int) { _quantizeDiv.value = div }
    override val chordMelodySwapHands: StateFlow<Boolean> = controller.swapHandsFlow
    override fun setSwapHands(swap: Boolean) { controller.swapHands = swap }
    private val _autoStrum = MutableStateFlow(false)
    override val chordMelodyAutoStrum: StateFlow<Boolean> = _autoStrum
    override fun setAutoStrum(enabled: Boolean) { _autoStrum.value = enabled }
    private val _padVolume = MutableStateFlow(0.6)
    override val chordMelodyPadVolume: StateFlow<Double> = _padVolume
    override fun setPadVolume(volume: Double) { _padVolume.value = volume.coerceIn(0.0, 0.6) }
    private val _radialSF = MutableStateFlow(false)
    private val _splitSF = MutableStateFlow(true)
    private val _scaleSF = MutableStateFlow(true)
    override val radialUseSoundFont: StateFlow<Boolean> = _radialSF
    override val splitUseSoundFont: StateFlow<Boolean> = _splitSF
    override val scaleUseSoundFont: StateFlow<Boolean> = _scaleSF
    override fun setUseSoundFont(mode: StudioMode, enabled: Boolean) {
        when (mode) {
            StudioMode.RADIAL -> _radialSF.value = enabled
            StudioMode.SPLIT -> _splitSF.value = enabled
            StudioMode.SCALE -> _scaleSF.value = enabled
            else -> Unit
        }
    }
    private val _gridBaseOctave = MutableStateFlow(controller.gridBaseOctave)
    override val gridBaseOctave: StateFlow<Int> = _gridBaseOctave
    override fun setGridBaseOctave(octave: Int) {
        controller.gridBaseOctave = octave; _gridBaseOctave.value = octave; controller.recomputeScaleNotes()
    }
    private val _gridOctaveRange = MutableStateFlow(controller.gridOctaveRange)
    override val gridOctaveRange: StateFlow<Int> = _gridOctaveRange
    override fun setGridOctaveRange(range: Int) {
        controller.gridOctaveRange = range; _gridOctaveRange.value = range; controller.recomputeScaleNotes()
    }

    private val _drum1 = MutableStateFlow(DrumTrackState(loopId = "none"))
    private val _drum2 = MutableStateFlow(DrumTrackState(loopId = "none"))
    override val drumTrack1: StateFlow<DrumTrackState> = _drum1
    override val drumTrack2: StateFlow<DrumTrackState> = _drum2
    private fun track(n: Int) = if (n == 2) _drum2 else _drum1
    override fun setDrumLoop(track: Int, loopId: String) { track(track).value = track(track).value.copy(loopId = loopId) }
    override fun setDrumVolume(track: Int, volume: Double) { track(track).value = track(track).value.copy(volume = volume) }
    override fun setDrumBPM(track: Int, bpm: Double) { track(track).value = track(track).value.copy(bpm = bpm) }
    private val _drumIntensity = MutableStateFlow(controller.drumIntensity)
    override val drumIntensity: StateFlow<Double> = _drumIntensity
    override fun setDrumIntensity(value: Double) { controller.drumIntensity = value; _drumIntensity.value = value }
    private val _drumComplexity = MutableStateFlow(controller.drumComplexity)
    override val drumComplexity: StateFlow<Double> = _drumComplexity
    override fun setDrumComplexity(value: Double) { controller.drumComplexity = value; _drumComplexity.value = value }

    private val _lockedParams = MutableStateFlow<Set<String>>(emptySet())
    override val lockedParams: StateFlow<Set<String>> = _lockedParams
    override fun setManualValue(paramId: String, value: Double) = todo("setManualValue")
    override fun toggleLock(paramId: String) {
        _lockedParams.value = _lockedParams.value.let { if (paramId in it) it - paramId else it + paramId }
    }
    override val smoothedParams: StateFlow<Map<String, Double>> = MutableStateFlow(emptyMap())

    private val _filter = MutableStateFlow("none")
    override val selectedFilter: StateFlow<String> = _filter
    override fun setFilter(id: String) { _filter.value = id }
    private val _handTheme = MutableStateFlow("default")
    override val selectedHandTheme: StateFlow<String> = _handTheme
    override fun setHandTheme(id: String) { _handTheme.value = id }

    // ---- Display ----
    override val currentBeat: StateFlow<Int> = controller.currentBeat
    override val bpm: StateFlow<Double> = _manualBPM
    override val noteDisplay: StateFlow<String> = MutableStateFlow("")
    override val codeDisplay: StateFlow<String> = MutableStateFlow("")
    override val chordMelody: StateFlow<ChordMelodyDisplay> = MutableStateFlow(ChordMelodyDisplay())
    override val lanes: StateFlow<LaneDisplay> = MutableStateFlow(LaneDisplay())

    // ---- Learn ----
    override val learn: StateFlow<LearnDisplay> = MutableStateFlow(LearnDisplay())
    override fun loadLearnSong(songId: String) = todo("learn")
    override fun updateLearnViewport(widthPx: Float, heightPx: Float) = Unit
    override fun tapLearnLane(lane: Int) = todo("learn")

    // ---- Touch ----
    override fun splitTouchEnterChord(touchId: String, wedge: Int, octave: Int) = controller.splitTouchEnterChord(touchId, wedge, octave)
    override fun splitTouchEnterMelody(touchId: String, lane: Int) = controller.splitTouchEnterMelody(touchId, lane)
    override fun splitTouchExit(touchId: String) = controller.splitTouchExit(touchId)
    override fun scaleTouchEnterChord(touchId: String, wedge: Int, octave: Int) = controller.splitTouchEnterChord(touchId, wedge, octave)
    override fun scaleTouchEnterMelody(touchId: String, lane: Int) = controller.splitTouchEnterMelody(touchId, lane)
    override fun scaleTouchExit(touchId: String) = controller.splitTouchExit(touchId)
    override fun radialTouchEnterChord(touchId: String, zone: Int) = todo("radial touch")
    override fun radialTouchEnterMelody(touchId: String, lane: Int) = todo("radial touch")
    override fun radialTouchExit(touchId: String) = Unit
    override fun zonesTouchEnterChord(touchId: String, zone: Int) = todo("zones touch")
    override fun zonesTouchEnterMelody(touchId: String, lane: Int) = todo("zones touch")
    override fun zonesTouchExit(touchId: String) = Unit
    override fun gridLaneTouchOn(touchId: String, lane: Int) = todo("grid touch")
    override fun gridLaneTouchSlide(touchId: String, lane: Int) = todo("grid touch")
    override fun gridLaneTouchOff(touchId: String) = Unit
    override fun drumLaneTap(lane: Int) = todo("drum touch")
    override fun drumPad(x: Double, y: Double) { setDrumIntensity(x); setDrumComplexity(y) }

    // ---- Presets ----
    override val currentSoundSetup: SoundSetup? get() = null.also { todo("currentSoundSetup") }
    override val soundSetupForSaving: SoundSetup? get() = null.also { todo("soundSetupForSaving") }
    override fun applySoundSetup(setup: SoundSetup, store: StoreGate): Boolean {
        val progression = setup.resolvedProgression
        if (!setup.isValid || progression == null || !setup.requiredPacks.all { store.isUnlocked(it) }) return false
        setKey(setup.key)
        setScale(setup.scale)
        setProgression(progression)
        if (setup.useSoundFont) setup.resolvedInstrument?.let { setSoundFontInstrument(it) } else setWaveform(setup.waveform)
        setManualBPM(setup.bpm)
        switchMode(StudioMode.from(setup.mode))
        return true
    }
    override val presets: StateFlow<List<NamedSoundSetup>> = MutableStateFlow(emptyList())
    override fun addPreset(sound: SoundSetup, name: String): Boolean = false.also { todo("presets") }
    override fun deletePreset(id: UUID) = todo("presets")
    override fun importPresetPack(bytes: ByteArray): Result<Int> =
        Result.failure(PresetPackException(PresetPackException.Kind.WRONG_FORMAT))
    override fun exportPresetPack(ids: List<UUID>): Result<ByteArray> =
        Result.failure(PresetPackException(PresetPackException.Kind.CAPACITY))
    override val customScales: StateFlow<List<CustomScale>> = MutableStateFlow(emptyList())
    override fun saveCustomScale(scale: CustomScale): Boolean = false.also { todo("custom scales") }
    override fun deleteCustomScale(id: UUID) = todo("custom scales")

    // ---- Recording hooks ----
    override fun setRecordingTempo(halfSpeed: Boolean) = todo("setRecordingTempo")
    override val supportsHalfSpeedRecording: Boolean get() = false
    private val _isLoopRecording = MutableStateFlow(false)
    private val _loopBusy = MutableStateFlow(false)
    private val _loopProgress = MutableStateFlow(0.0)
    override val isLoopRecording: StateFlow<Boolean> = _isLoopRecording
    override val loopCaptureBusy: StateFlow<Boolean> = _loopBusy
    override val loopRecordingProgress: StateFlow<Double> = _loopProgress
    override fun updateLoopCapture(isRecording: Boolean, busy: Boolean, progress: Double) {
        _isLoopRecording.value = isRecording; _loopBusy.value = busy; _loopProgress.value = progress
    }
    private val _loopBars = MutableStateFlow(4)
    override val loopRecordingBars: StateFlow<Int> = _loopBars
    override fun setLoopRecordingBars(bars: Int) { _loopBars.value = bars }
    override fun loopDurationSeconds(bpm: Double): Double =
        minOf(StudioEngine.MAX_LOOP_SECONDS, _loopBars.value * 4 * 60.0 / bpm.coerceIn(20.0, 400.0))

    // ---- Loops ----
    override val savedLoops: StateFlow<List<SavedLoop>> = MutableStateFlow(emptyList())
    override val playingLoopIds: StateFlow<Set<UUID>> = MutableStateFlow(emptySet())
    override fun saveCapturedLoop(file: File, durationSeconds: Double, bpm: Double, mode: String, autoplay: Boolean): SavedLoop? =
        null.also { todo("loops") }
    override fun toggleLoopPlayback(id: UUID): Boolean = false
    override fun renameLoop(id: UUID, name: String): Boolean = false
    override fun setLoopGain(id: UUID, gain: Double) = Unit
    override fun toggleLoopMute(id: UUID) = Unit
    override fun deleteLoop(id: UUID) = Unit
    override fun stopAllLoops() = Unit

    // ---- Hooks ----
    override var onFirstNote: (() -> Unit)? = null
    override val audioSessionId: Int get() = 0
    override val appAudioTap: AppAudioTap? get() = null
    override val strudelWebView: StateFlow<WebView?> = MutableStateFlow(null)

    private companion object { const val TAG = "LegacyStudioEngine" }
}
