package com.handstrudel.engine

import android.webkit.WebView
import com.handstrudel.models.ChordProgression
import com.handstrudel.models.CustomScale
import com.handstrudel.models.MusicKey
import com.handstrudel.models.NamedSoundSetup
import com.handstrudel.models.ScaleSelection
import com.handstrudel.models.SoundFontInstrument
import com.handstrudel.models.SoundSetup
import com.handstrudel.store.StoreGate
import kotlinx.coroutines.flow.StateFlow
import java.io.File
import java.util.UUID

/**
 * The engine seam: everything studio-ui, capture and shell need from the audio
 * engine. Owner: engine (WS2). Mirrors the iOS `EngineController` `@Published`
 * names: observables are [StateFlow]s, actions are functions. All calls are on
 * the main thread unless noted.
 *
 * Implementation: [HandStrudelEngine] (exposed through [LegacyStudioEngine]
 * until studio-ui drops its Phase 0 cast).
 *
 * Members added after Phase 0 have default bodies so other workstreams'
 * fakes keep compiling.
 */
interface StudioEngine {

    // ---- Lifecycle ----------------------------------------------------------------
    val isRunning: StateFlow<Boolean>
    val isPaused: StateFlow<Boolean>
    /** "tap start", "Preparing instrument…", "Playing", "error: …". */
    val status: StateFlow<String>
    /** Non-fatal audio problem to surface (e.g. Strudel failed to load). */
    val auxiliaryAudioIssue: StateFlow<String?>

    /** Opens the session. SoundFont-routed modes play immediately; Strudel init continues in the background. */
    fun start(input: PlayInput)
    fun stop()
    /** Control sheet open, applying a preset, etc. */
    fun pause()
    fun resume()
    /** App foreground/background (shell forwards ON_START/ON_STOP). Also pauses Learn (`setLearnSceneActive`). */
    fun setSceneActive(active: Boolean)
    fun silenceAll()

    // ---- Input --------------------------------------------------------------------
    val playInput: StateFlow<PlayInput>
    fun setPlayInput(input: PlayInput)
    val cameraIssue: StateFlow<CameraIssue?>
    /** Shell reports permission denial here; engine reports CameraX failures itself. Denial falls back to TOUCH. */
    fun reportCameraIssue(issue: CameraIssue?)
    /** Starts the camera if play input is AIR and permission is granted. */
    fun startCameraIfRequested()
    val handsState: StateFlow<HandsState>
    /** For `CameraPreview` binding. */
    val handTracker: HandTrackingManager

    // ---- Mode ---------------------------------------------------------------------
    val mode: StateFlow<StudioMode>
    fun switchMode(mode: StudioMode)
    /** iOS `currentModeString` (= `mode.value.raw`). */
    val currentModeString: String

    // ---- Sound --------------------------------------------------------------------
    val selectedKey: StateFlow<MusicKey>
    fun setKey(key: MusicKey)
    val selectedScale: StateFlow<ScaleSelection>
    fun setScale(scale: ScaleSelection)
    val selectedSoundFontInstrument: StateFlow<SoundFontInstrument>
    fun setSoundFontInstrument(instrument: SoundFontInstrument)
    /** `Waveform.id` from `WAVEFORMS`. */
    val selectedWaveform: StateFlow<String>
    fun setWaveform(id: String)
    val chordMelodyProgression: StateFlow<ChordProgression>
    fun setProgression(progression: ChordProgression)
    val manualBPM: StateFlow<Double>
    fun setManualBPM(bpm: Double)
    val quantizeEnabled: StateFlow<Boolean>
    fun setQuantizeEnabled(enabled: Boolean)
    /** Subdivision: 4 (¼), 8 (⅛) or 16 (1/16). iOS stores it as a Double. */
    val quantizeDiv: StateFlow<Int>
    fun setQuantizeDiv(div: Int)
    val chordMelodySwapHands: StateFlow<Boolean>
    fun setSwapHands(swap: Boolean)
    val chordMelodyAutoStrum: StateFlow<Boolean>
    fun setAutoStrum(enabled: Boolean)
    /** 0…0.6, default 0.6. */
    val chordMelodyPadVolume: StateFlow<Double>
    fun setPadVolume(volume: Double)
    /** Defaults: radial false, split true, scale true. */
    val radialUseSoundFont: StateFlow<Boolean>
    val splitUseSoundFont: StateFlow<Boolean>
    val scaleUseSoundFont: StateFlow<Boolean>
    /** [mode] is RADIAL, SPLIT or SCALE. */
    fun setUseSoundFont(mode: StudioMode, enabled: Boolean)
    val gridBaseOctave: StateFlow<Int>
    fun setGridBaseOctave(octave: Int)
    val gridOctaveRange: StateFlow<Int>
    fun setGridOctaveRange(range: Int)
    /** iOS `chordMode` (melodic "Chords" pill): the pattern plays the degree's triad. */
    val chordMode: StateFlow<Boolean> get() = FALSE_FLOW
    fun setChordMode(enabled: Boolean) {}
    /** iOS `circleOfFifthsEnabled` ("Circle of 5ths" pill): left-hand X picks the key. */
    val circleOfFifthsEnabled: StateFlow<Boolean> get() = FALSE_FLOW
    fun setCircleOfFifths(enabled: Boolean) {}

    /** Drums 1 (iOS `selectedDrumLoop`, `drumVolume`, `drumBPM`). */
    val drumTrack1: StateFlow<DrumTrackState>
    /** Drums 2 (iOS `selectedDrumLoop2`, `drumVolume2`, `drumBPM2`). */
    val drumTrack2: StateFlow<DrumTrackState>
    /** [track] is 1 or 2. Locked loops are gated by the caller via `StoreGate`. */
    fun setDrumLoop(track: Int, loopId: String)
    fun setDrumVolume(track: Int, volume: Double)
    fun setDrumBPM(track: Int, bpm: Double)
    val drumIntensity: StateFlow<Double>
    fun setDrumIntensity(value: Double)
    val drumComplexity: StateFlow<Double>
    fun setDrumComplexity(value: Double)

    /** Melodic-family params (`PARAM_DEFS` ids). */
    val lockedParams: StateFlow<Set<String>>
    fun setManualValue(paramId: String, value: Double)
    fun toggleLock(paramId: String)
    val smoothedParams: StateFlow<Map<String, Double>>
    /** iOS `manualValues`: the slider value of a locked param. */
    val manualValues: StateFlow<Map<String, Double>> get() = EMPTY_PARAMS_FLOW
    /** iOS `bpmIsMapped`: true when a hand axis drives BPM (the BPM slider is then hidden). */
    val bpmIsMapped: Boolean get() = true

    /** Persisted visual selections (`lastFilterId`, hand theme id); drawing them is studio-ui's job. */
    val selectedFilter: StateFlow<String>
    fun setFilter(id: String)
    val selectedHandTheme: StateFlow<String>
    fun setHandTheme(id: String)

    // ---- Display state ------------------------------------------------------------
    /** 0…3. */
    val currentBeat: StateFlow<Int>
    /** Effective BPM (hand-mapped or manual). */
    val bpm: StateFlow<Double>
    val noteDisplay: StateFlow<String>
    val codeDisplay: StateFlow<String>
    val chordMelody: StateFlow<ChordMelodyDisplay>
    val lanes: StateFlow<LaneDisplay>

    // ---- Learn --------------------------------------------------------------------
    val learn: StateFlow<LearnDisplay>
    /** Id from the engine's learn-song catalog (`models/LearnSongs.kt`: `BUNDLED_SONGS` ids or `PRACTICE_SONG_IDS`). */
    fun loadLearnSong(songId: String)
    fun updateLearnViewport(widthPx: Float, heightPx: Float)
    fun tapLearnLane(lane: Int)

    // ---- Touch --------------------------------------------------------------------
    // Wheel layouts (Split / Scale / Radial). The engine routes by the current mode.
    fun splitTouchEnterChord(touchId: String, wedge: Int, octave: Int)
    fun splitTouchEnterMelody(touchId: String, lane: Int)
    fun splitTouchExit(touchId: String)
    fun scaleTouchEnterChord(touchId: String, wedge: Int, octave: Int)
    fun scaleTouchEnterMelody(touchId: String, lane: Int)
    fun scaleTouchExit(touchId: String)
    fun radialTouchEnterChord(touchId: String, zone: Int)
    fun radialTouchEnterMelody(touchId: String, lane: Int)
    fun radialTouchExit(touchId: String)
    /** Chord+Melody zones (and SoundFont mode) lanes. */
    fun zonesTouchEnterChord(touchId: String, zone: Int)
    fun zonesTouchEnterMelody(touchId: String, lane: Int)
    fun zonesTouchExit(touchId: String)
    /** Grid lanes: on / slide / off per touch (iOS `GridTouchOverlay`). */
    /** [lane] is the visual row from the top (iOS `GridTouchOverlay`); the note is `gridNotes[count - 1 - lane]`. */
    fun gridLaneTouchOn(touchId: String, lane: Int)
    fun gridLaneTouchSlide(touchId: String, lane: Int)
    fun gridLaneTouchOff(touchId: String)
    fun drumLaneTap(lane: Int)
    /** Drum XY pad: intensity (x) and complexity (y), 0…1. (iOS draws complexity on the
     *  horizontal axis and intensity rising upwards: pass `x = 1 - padY`, `y = padX` for that layout.) */
    fun drumPad(x: Double, y: Double)

    // ---- Presets ------------------------------------------------------------------
    /** Null in Learn (iOS `currentSoundSetup`). */
    val currentSoundSetup: SoundSetup?
    /** Running: current; idle: a Scale setup (iOS `soundSetupForSaving`). */
    val soundSetupForSaving: SoundSetup?
    /** False (and nothing changes) when invalid or a required pack is locked. */
    fun applySoundSetup(setup: SoundSetup, store: StoreGate): Boolean
    val presets: StateFlow<List<NamedSoundSetup>>
    /** Name trimmed, ≤40 chars, unique by (sound, name). False when rejected. */
    fun addPreset(sound: SoundSetup, name: String): Boolean
    fun deletePreset(id: UUID)
    /** Returns the number imported, or fails with a [PresetPackException] carrying the iOS message. */
    fun importPresetPack(bytes: ByteArray): Result<Int>
    fun exportPresetPack(ids: List<UUID>): Result<ByteArray>
    val customScales: StateFlow<List<CustomScale>>
    /** Insert or replace by id; false when the 64-scale limit is hit. */
    fun saveCustomScale(scale: CustomScale): Boolean
    fun deleteCustomScale(id: UUID)

    // ---- Recording hooks (capture) -------------------------------------------------
    /** Engine tempo ×0.5 while recording at half speed. */
    fun setRecordingTempo(halfSpeed: Boolean)
    val supportsHalfSpeedRecording: Boolean
    val isLoopRecording: StateFlow<Boolean>
    val loopCaptureBusy: StateFlow<Boolean>
    /** 0…1. */
    val loopRecordingProgress: StateFlow<Double>
    /** Capture publishes its loop-capture progress here (iOS keeps it on the engine). */
    fun updateLoopCapture(isRecording: Boolean, busy: Boolean, progress: Double)
    val loopRecordingBars: StateFlow<Int>
    fun setLoopRecordingBars(bars: Int)
    /** `bars × 4 × 60 / bpm`, capped at 90 s. */
    fun loopDurationSeconds(bpm: Double): Double

    // ---- Loops --------------------------------------------------------------------
    val savedLoops: StateFlow<List<SavedLoop>>
    val playingLoopIds: StateFlow<Set<UUID>>
    /** Moves [file] into the loop store. Null when refused (e.g. [MAX_LOOPS] reached). */
    fun saveCapturedLoop(file: File, durationSeconds: Double, bpm: Double, mode: String, autoplay: Boolean = true): SavedLoop?
    fun toggleLoopPlayback(id: UUID): Boolean
    fun renameLoop(id: UUID, name: String): Boolean
    fun setLoopGain(id: UUID, gain: Double)
    fun toggleLoopMute(id: UUID)
    fun deleteLoop(id: UUID)
    fun stopAllLoops()

    // ---- Hooks --------------------------------------------------------------------
    /** Shell analytics `first_note`; called only while running and not paused. */
    var onFirstNote: (() -> Unit)?
    /** AudioTrack session id of the native mix (0 when unknown). */
    val audioSessionId: Int
    /** Optional PCM tap of the native mix; null when unsupported. */
    val appAudioTap: AppAudioTap?
    /**
     * The hidden Strudel WebView. Shell keeps it attached in a 1×1 `AndroidView` for the
     * whole app lifetime (iOS keeps the WKWebView in the hierarchy). Null until created.
     */
    val strudelWebView: StateFlow<WebView?>

    // ---- Previews (studio-ui home and onboarding) ------------------------------------
    /** iOS `StartOverlayView.playPreview`: plays [notes] on [instrument] (idle only). False when unavailable. */
    fun previewInstrument(instrument: SoundFontInstrument, notes: List<Int>): Boolean = false
    fun stopInstrumentPreview() {}
    /** iOS `ContentView.playFirstNote` (onboarding): one note on the Scale instrument. */
    fun playFirstNote(midi: Int) {}

    companion object {
        const val MAX_LOOPS = 20
        const val MAX_LOOP_SECONDS = 90.0
        private val FALSE_FLOW: StateFlow<Boolean> = kotlinx.coroutines.flow.MutableStateFlow(false)
        private val EMPTY_PARAMS_FLOW: StateFlow<Map<String, Double>> = kotlinx.coroutines.flow.MutableStateFlow(emptyMap())
    }
}

/** iOS `SoundPresetPack.PackError`; [message] is the exact user-facing string. */
class PresetPackException(val kind: Kind) : Exception(kind.message) {
    enum class Kind(val message: String) {
        WRONG_FORMAT("This isn't a compatible HandStrudel preset file."),
        CAPACITY("Use a preset file with 1 to 128 presets and no more than 256 KB."),
        INVALID_PRESET("A preset in this file has unsupported or invalid settings. Nothing was imported."),
    }
}
