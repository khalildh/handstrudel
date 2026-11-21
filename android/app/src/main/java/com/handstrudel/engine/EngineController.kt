package com.handstrudel.engine

import android.content.Context
import com.handstrudel.models.ChordProgression
import com.handstrudel.models.MusicKey
import com.handstrudel.models.Scale
import com.handstrudel.models.ScaleSelection
import com.handstrudel.models.SoundFontInstrument
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import uniffi.handstrudel_core.ChordMelodyModeManager

/**
 * Phase 0 compatibility facade. studio-ui's unported `SplitChordMelodyOverlay`
 * and `SplitSettingsSheet` still take an `EngineController` with the old member
 * names; this forwards them to the real engine ([engine], a [HandStrudelEngine]).
 *
 * TODO(studio-ui): port those composables to `StudioEngine`; then engine deletes
 * this class and [LegacyStudioEngine] (spec 3.0.1 decision 10).
 */
class EngineController(context: Context) {
    val engine = HandStrudelEngine(context)
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)

    val handTracker: HandTrackingManager get() = engine.handTracker
    val handsState: StateFlow<HandsState> get() = engine.handsState
    val isRunning: StateFlow<Boolean> get() = engine.isRunning
    val currentBeat: StateFlow<Int> get() = engine.currentBeat
    val chordMelodyManager: ChordMelodyModeManager get() = engine.chordMelodyManager

    val chordMelodyModeEnabled: Boolean get() = engine.mode.value.isChordMelodyFamily

    val selectedKeyFlow: StateFlow<MusicKey> get() = engine.selectedKey
    var selectedKey: MusicKey
        get() = engine.selectedKey.value
        set(value) = engine.setKey(value)

    /** Built-in view of the scale (custom scales read as Pentatonic here). */
    val selectedScaleFlow: StateFlow<Scale> = engine.selectedScale
        .map { (it as? ScaleSelection.BuiltIn)?.scale ?: Scale.PENTATONIC }
        .stateIn(scope, SharingStarted.Eagerly, Scale.PENTATONIC)
    var selectedScale: Scale
        get() = selectedScaleFlow.value
        set(value) = engine.setScale(ScaleSelection.BuiltIn(value))

    val selectedInstrumentFlow: StateFlow<SoundFontInstrument> get() = engine.selectedSoundFontInstrument
    var selectedInstrument: SoundFontInstrument
        get() = engine.selectedSoundFontInstrument.value
        set(value) = engine.setSoundFontInstrument(value)

    val selectedProgressionFlow: StateFlow<ChordProgression> get() = engine.chordMelodyProgression
    var selectedProgression: ChordProgression
        get() = engine.chordMelodyProgression.value
        set(value) = engine.setProgression(value)

    val swapHandsFlow: StateFlow<Boolean> get() = engine.chordMelodySwapHands
    var swapHands: Boolean
        get() = engine.chordMelodySwapHands.value
        set(value) = engine.setSwapHands(value)

    val chordMelodyCurrentZoneIndex = MutableStateFlow<Int?>(null)
    val chordMelodyCurrentDegree = MutableStateFlow<Int?>(null)
    val chordMelodyMelodyLane = MutableStateFlow<Int?>(null)
    val chordMelodyChordResting = MutableStateFlow(false)
    val chordMelodyMelodyResting = MutableStateFlow(false)
    val chordMelodyIsChordHandPinching = MutableStateFlow(false)
    val chordMelodyIsMelodyHandPinching = MutableStateFlow(false)
    /** Written by the legacy overlay for its own highlights. */
    val chordMelodyTouchedChordZones = MutableStateFlow<Set<ChordSubzone>>(emptySet())
    val chordMelodyTouchedMelodyLanes = MutableStateFlow<Set<Int>>(emptySet())

    fun splitTouchEnterChord(touchId: String, wedge: Int, octave: Int) =
        if (engine.mode.value == StudioMode.SCALE) engine.scaleTouchEnterChord(touchId, wedge, octave)
        else engine.splitTouchEnterChord(touchId, wedge, octave)

    fun splitTouchEnterMelody(touchId: String, lane: Int) =
        if (engine.mode.value == StudioMode.SCALE) engine.scaleTouchEnterMelody(touchId, lane)
        else engine.splitTouchEnterMelody(touchId, lane)

    fun splitTouchExit(touchId: String) = engine.splitTouchExit(touchId)

    init {
        scope.launch {
            engine.chordMelody.collect { d ->
                chordMelodyCurrentZoneIndex.value = d.chordZoneIndex
                chordMelodyCurrentDegree.value = d.currentDegree
                chordMelodyMelodyLane.value = d.melodyLane
                chordMelodyChordResting.value = d.chordResting
                chordMelodyMelodyResting.value = d.melodyResting
                chordMelodyIsChordHandPinching.value = d.isChordHandPinching
                chordMelodyIsMelodyHandPinching.value = d.isMelodyHandPinching
            }
        }
    }
}
