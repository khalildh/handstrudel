package com.handstrudel.engine

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.handstrudel.engine.synth.SoundFontEngine
import com.handstrudel.engine.synth.SynthEngine
import com.handstrudel.models.*
import kotlinx.coroutines.flow.MutableStateFlow
import uniffi.handstrudel_core.ChordMelodyAction
import uniffi.handstrudel_core.ChordMelodyModeManager
import uniffi.handstrudel_core.ChordMelodyZones
import uniffi.handstrudel_core.ChordToneTables
import uniffi.handstrudel_core.Layout as CoreLayout
import uniffi.handstrudel_core.MusicKey as CoreKey
import uniffi.handstrudel_core.Scale as CoreScale
import uniffi.handstrudel_core.chordNotes as coreChordNotes
import uniffi.handstrudel_core.scaleNotes as coreScaleNotes

class EngineController(context: Context) {
    private val mainHandler = Handler(Looper.getMainLooper())
    val synthEngine = SynthEngine()
    val handTracker = HandTrackingManager(context)
    private val gridManager = GridModeManager()
    private val drumManager = DrumModeManager()

    /// Real-instrument voice for chord-melody mode. Loaded once on startup;
    /// SynthEngine pulls samples from it each chunk via its `soundFont`
    /// reference. Null if the SF2 asset can't be loaded.
    val soundFont: SoundFontEngine? = SoundFontEngine
        .fromAsset(context, "soundfonts/GeneralUser-GS.sf2", sampleRate = 44100)
        .also { synthEngine.soundFont = it }

    private val _selectedInstrument = MutableStateFlow(DEFAULT_SOUNDFONT_INSTRUMENT)
    val selectedInstrumentFlow: kotlinx.coroutines.flow.StateFlow<SoundFontInstrument> = _selectedInstrument
    var selectedInstrument: SoundFontInstrument
        get() = _selectedInstrument.value
        set(value) {
            if (_selectedInstrument.value.id == value.id) return
            _selectedInstrument.value = value
            // Switching instruments mid-play would otherwise leave the old
            // preset's notes ringing. Cut everything cleanly first.
            soundFont?.allNotesOff()
            padVoices.clear()
            splitVoiceSubvoices.clear()
            soundFont?.setDefaultPreset(value.program)
        }

    /// Shared Rust-backed chord+melody state machine. Same struct used by iOS;
    /// drives Split / Radial / Grid layouts with one tick implementation.
    val chordMelodyManager = ChordMelodyModeManager().apply { setLayout(CoreLayout.SPLIT) }

    // State
    val handsState = MutableStateFlow(HandsState())
    val isRunning = MutableStateFlow(false)
    val currentBeat = MutableStateFlow(0)

    // Configuration
    var selectedPreset: Preset? = null
    var selectedWaveform = "sawtooth"
    var gridModeEnabled = false
    var drumModeEnabled = false
    /// Split chord+melody mode — the app's default. Toggle the other modes
    /// off when enabled.
    var chordMelodyModeEnabled = true
    var manualBPM = 120.0

    // Music selection — backed by StateFlows so the settings sheet can
    // observe live and the engine can react to changes via the setters.
    private val _selectedKey = MutableStateFlow(MusicKey.C)
    val selectedKeyFlow: kotlinx.coroutines.flow.StateFlow<MusicKey> = _selectedKey
    var selectedKey: MusicKey
        get() = _selectedKey.value
        set(value) {
            if (_selectedKey.value == value) return
            _selectedKey.value = value
            recomputeScaleNotes()
        }

    private val _selectedScale = MutableStateFlow(Scale.PENTATONIC)
    val selectedScaleFlow: kotlinx.coroutines.flow.StateFlow<Scale> = _selectedScale
    var selectedScale: Scale
        get() = _selectedScale.value
        set(value) {
            if (_selectedScale.value == value) return
            _selectedScale.value = value
            recomputeScaleNotes()
        }

    private val _selectedProgression = MutableStateFlow(FREE_PROGRESSION)
    val selectedProgressionFlow: kotlinx.coroutines.flow.StateFlow<ChordProgression> = _selectedProgression
    var selectedProgression: ChordProgression
        get() = _selectedProgression.value
        set(value) {
            if (_selectedProgression.value.id == value.id) return
            _selectedProgression.value = value
            chordMelodyManager.setZoneDegrees(value.degrees.map { it })
        }

    private val _swapHands = MutableStateFlow(false)
    val swapHandsFlow: kotlinx.coroutines.flow.StateFlow<Boolean> = _swapHands
    var swapHands: Boolean
        get() = _swapHands.value
        set(value) {
            if (_swapHands.value == value) return
            _swapHands.value = value
            chordMelodyManager.setSwapHands(value)
        }

    // Grid state
    var gridBaseOctave = 3
    var gridOctaveRange = 2
    val gridLeftLane = MutableStateFlow<Int?>(null)
    val gridRightLane = MutableStateFlow<Int?>(null)
    val gridLeftPinching = MutableStateFlow(false)
    val gridRightPinching = MutableStateFlow(false)

    // Drum state
    val drumLeftLane = MutableStateFlow<Int?>(null)
    val drumRightLane = MutableStateFlow<Int?>(null)
    val drumLeftPinching = MutableStateFlow(false)
    val drumRightPinching = MutableStateFlow(false)
    var drumIntensity = 0.5
    var drumComplexity = 0.5

    // Chord+melody published state for the Split overlay
    val chordMelodyCurrentDegree = MutableStateFlow<Int?>(null)
    val chordMelodyCurrentZoneIndex = MutableStateFlow<Int?>(null)
    val chordMelodyMelodyLane = MutableStateFlow<Int?>(null)
    val chordMelodyChordResting = MutableStateFlow(false)
    val chordMelodyMelodyResting = MutableStateFlow(false)
    val chordMelodyIsChordHandPinching = MutableStateFlow(false)
    val chordMelodyIsMelodyHandPinching = MutableStateFlow(false)
    val chordMelodyTouchedChordZones = MutableStateFlow<Set<ChordSubzone>>(emptySet())
    val chordMelodyTouchedMelodyLanes = MutableStateFlow<Set<Int>>(emptySet())

    // Touch-driven chord stack (latest finger wins for melody snap)
    private data class SplitTouchChord(val touchId: String, val degree: Int, val octave: Int, val tones: List<Int>)
    private val splitTouchChordStack = mutableListOf<SplitTouchChord>()
    private val splitVoiceSubvoices = mutableMapOf<String, List<String>>()

    // Cached scale notes
    private var cachedScaleNotes = listOf<Int>()
    /// `chordMelodyTones.chordTones[degree]` → triad MIDI notes;
    /// `chordMelodyTones.melodyTones[degree]` → snap targets for the melody hand.
    private var chordMelodyTones: ChordToneTables = buildChordToneTables(MusicKey.C, Scale.PENTATONIC)

    /// Sustained voice IDs that the chord-melody tick currently has noteOn-ed.
    /// Indexed by chord pitch, so PadSlide can release the previous voicing.
    private val padVoices = mutableListOf<String>()
    private val melodyVoiceId = "cmm-melody"

    // Smoothed params
    private val smoothedParams = mutableMapOf<String, Double>()
    private val alpha = 0.1

    // Struct rotation
    private var structIdx = 0
    private var structTimer = 0L

    init {
        synthEngine.onBeat = { beat ->
            mainHandler.post { currentBeat.value = beat }
        }

        handTracker.onHandsDetected = { hands ->
            mainHandler.post {
                handsState.value = hands
                tick(hands)
            }
        }

        recomputeScaleNotes()
    }

    fun start(preset: Preset) {
        selectedPreset = preset
        synthEngine.start()
        isRunning.value = true
    }

    fun stop() {
        synthEngine.stop()
        isRunning.value = false
    }

    fun recomputeScaleNotes() {
        cachedScaleNotes = scaleNotes(selectedKey, selectedScale, gridBaseOctave, gridOctaveRange)
        chordMelodyTones = buildChordToneTables(selectedKey, selectedScale)
    }

    private fun tick(hands: HandsState) {
        if (!isRunning.value) return

        val now = System.currentTimeMillis()
        if (now - structTimer > 8000) {
            structTimer = now
            structIdx = (structIdx + 1) % STRUCTS.size
            synthEngine.updateStructPattern(STRUCTS[structIdx])
        }

        when {
            gridModeEnabled -> tickGridMode(hands)
            drumModeEnabled -> tickDrumMode(hands)
            chordMelodyModeEnabled -> tickChordMelodyMode(hands)
            else -> tickMelodicMode(hands)
        }
    }

    private var logCounter = 0

    private fun tickMelodicMode(hands: HandsState) {
        val preset = selectedPreset ?: return

        if (logCounter++ % 30 == 0) {
            hands.left?.let { Log.d("Engine", "LEFT y=${String.format("%.2f", it.y)} x=${String.format("%.2f", it.x)} pinch=${String.format("%.2f", it.pinch)}") }
            hands.right?.let { Log.d("Engine", "RIGHT y=${String.format("%.2f", it.y)} x=${String.format("%.2f", it.x)} pinch=${String.format("%.2f", it.pinch)}") }
        }

        val rawParams = mutableMapOf<String, Double>()

        for ((axis, paramId) in preset.leftMapping) {
            if (paramId == "none") continue
            val def = PARAM_MAP[paramId] ?: continue
            val value = hands.left?.let { axisValue(it, axis) } ?: continue
            rawParams[paramId] = def.min + value * (def.max - def.min)
        }
        for ((axis, paramId) in preset.rightMapping) {
            if (paramId == "none") continue
            val def = PARAM_MAP[paramId] ?: continue
            val value = hands.right?.let { axisValue(it, axis) } ?: continue
            rawParams[paramId] = def.min + value * (def.max - def.min)
        }

        for ((id, raw) in rawParams) {
            val prev = smoothedParams[id] ?: raw
            smoothedParams[id] = prev + alpha * (raw - prev)
        }

        val noteIdx = smoothedParams["noteIdx"]?.toInt()?.coerceIn(0, NOTES.size - 1) ?: 10
        val midiNote = MIDI_NOTES.getOrElse(noteIdx) { 60 }

        synthEngine.melodicActive = hands.left != null || hands.right != null
        synthEngine.melodicMidi = midiNote
        synthEngine.melodicWaveform = selectedWaveform
        synthEngine.bpm = (smoothedParams["bpm"] ?: manualBPM).toFloat()
        synthEngine.gain = (smoothedParams["gain"] ?: 0.55).toFloat()
        synthEngine.lpfCutoff = (smoothedParams["lpf"] ?: 3000.0).toFloat()
        synthEngine.hpfCutoff = (smoothedParams["hpf"] ?: 20.0).toFloat()
        synthEngine.reverbMix = (smoothedParams["reverb"] ?: 0.2).toFloat()
        synthEngine.delayTime = (smoothedParams["delay"] ?: 0.12).toFloat()
        synthEngine.panValue = (smoothedParams["pan"] ?: 0.5).toFloat()
        synthEngine.crushBits = (smoothedParams["crush"] ?: 16.0).toFloat()
        synthEngine.shapeAmount = (smoothedParams["shape"] ?: 0.0).toFloat()
        synthEngine.attackTime = (smoothedParams["attack"] ?: 0.01).toFloat()
        synthEngine.releaseTime = (smoothedParams["release"] ?: 0.1).toFloat()
    }

    private fun tickGridMode(hands: HandsState) {
        val events = gridManager.checkActions(hands, cachedScaleNotes)
        gridLeftLane.value = gridManager.leftLane
        gridRightLane.value = gridManager.rightLane
        gridLeftPinching.value = gridManager.isLeftPinching
        gridRightPinching.value = gridManager.isRightPinching

        for (event in events) {
            when (event.action) {
                NoteAction.NOTE_ON -> synthEngine.noteOn(event.hand, event.midi, selectedWaveform, event.velocity.toFloat())
                NoteAction.NOTE_OFF -> synthEngine.noteOff(event.hand)
                NoteAction.SLIDE -> synthEngine.noteSlide(event.hand, event.midi)
            }
        }
    }

    private fun tickDrumMode(hands: HandsState) {
        val hits = drumManager.checkHits(hands)
        drumLeftLane.value = drumManager.leftLane
        drumRightLane.value = drumManager.rightLane
        drumLeftPinching.value = drumManager.isLeftPinching
        drumRightPinching.value = drumManager.isRightPinching

        synthEngine.drumSynth.intensity = drumIntensity.toFloat()
        synthEngine.drumSynth.complexity = drumComplexity.toFloat()

        for (hit in hits) {
            synthEngine.playHit(hit.hitType)
        }
    }

    // -----------------------------------------------------------------------
    // Chord+melody (Split) mode
    // -----------------------------------------------------------------------

    private fun tickChordMelodyMode(hands: HandsState) {
        // Silence the continuous melodic oscillator — chord-melody mode owns
        // the voice stack, the always-on hum from melodic mode would muddy it.
        synthEngine.melodicActive = false

        val coreHands = hands.toCoreHands()
        val actions = chordMelodyManager.tick(coreHands, chordMelodyTones, false, false)

        // Route every chord-melody voice through the SoundFont sampler when
        // it's available — same path iOS Split mode uses (real instrument
        // sound instead of a raw oscillator). Falls back to the oscillator
        // voice path if the SF2 asset failed to load.
        val sf = soundFont
        for (action in actions) {
            when (action) {
                is ChordMelodyAction.PadOn -> {
                    releasePadVoices()
                    for ((i, midi) in action.midiNotes.withIndex()) {
                        val voice = "cmm-pad-$i"
                        if (sf != null) sf.noteOn(voice, midi.toInt(), 0.55f)
                        else synthEngine.noteOn(voice, midi.toInt(), selectedWaveform, 0.5f)
                        padVoices.add(voice)
                    }
                }
                is ChordMelodyAction.PadSlide -> {
                    releasePadVoices()
                    for ((i, midi) in action.midiNotes.withIndex()) {
                        val voice = "cmm-pad-$i"
                        if (sf != null) sf.noteOn(voice, midi.toInt(), 0.55f)
                        else synthEngine.noteOn(voice, midi.toInt(), selectedWaveform, 0.5f)
                        padVoices.add(voice)
                    }
                }
                is ChordMelodyAction.PadOff -> releasePadVoices()
                is ChordMelodyAction.ChordAccent -> {
                    // Brief percussive strum on top of the pad — fire and forget.
                    for ((i, midi) in action.midiNotes.withIndex()) {
                        val accentVoice = "cmm-accent-$i"
                        if (sf != null) {
                            sf.noteOn(accentVoice, midi.toInt(), action.velocity.toFloat())
                            mainHandler.postDelayed({ sf.noteOff(accentVoice) }, 250)
                        } else {
                            synthEngine.noteOn(accentVoice, midi.toInt(), selectedWaveform, action.velocity.toFloat())
                            mainHandler.postDelayed({ synthEngine.noteOff(accentVoice) }, 250)
                        }
                    }
                }
                is ChordMelodyAction.MelodyOn -> {
                    if (sf != null) sf.noteOn(melodyVoiceId, action.midi.toInt(), action.velocity.toFloat())
                    else synthEngine.noteOn(melodyVoiceId, action.midi.toInt(), selectedWaveform, action.velocity.toFloat())
                }
                is ChordMelodyAction.MelodyOff -> {
                    if (sf != null) sf.noteOff(melodyVoiceId) else synthEngine.noteOff(melodyVoiceId)
                }
                is ChordMelodyAction.MelodySlide -> {
                    if (sf != null) sf.noteSlide(melodyVoiceId, action.midi.toInt(), 0.7f)
                    else synthEngine.noteSlide(melodyVoiceId, action.midi.toInt())
                }
            }
        }

        val zones: ChordMelodyZones = chordMelodyManager.currentZones(coreHands)
        chordMelodyCurrentDegree.value = chordMelodyManager.currentChordDegree()?.toInt()
        chordMelodyCurrentZoneIndex.value = zones.chordZoneIndex?.toInt()
        chordMelodyMelodyLane.value = zones.melodyLane?.toInt()
        chordMelodyChordResting.value = zones.chordResting
        chordMelodyMelodyResting.value = zones.melodyResting
        chordMelodyIsChordHandPinching.value = chordMelodyManager.isChordHandPinching()
        chordMelodyIsMelodyHandPinching.value = chordMelodyManager.isMelodyHandPinching()
    }

    private fun releasePadVoices() {
        val sf = soundFont
        for (v in padVoices) {
            if (sf != null) sf.noteOff(v) else synthEngine.noteOff(v)
        }
        padVoices.clear()
    }

    // -----------------------------------------------------------------------
    // Split-mode touch handlers — called by the Compose multitouch overlay
    // -----------------------------------------------------------------------

    /// A finger entered a chord sub-zone. Spawns sustained voices for each
    /// chord note keyed off the touch ID, and pushes the chord onto the touch
    /// stack so the camera-driven melody snap follows it.
    fun splitTouchEnterChord(touchId: String, wedge: Int, octave: Int) {
        val degree = chordMelodyManager.degreeForZone(wedge.toInt())
        val triad = coreChordNotes(selectedKey.toCoreKey(), selectedScale.toCoreScale(), degree.toInt())
        val tones = triad.map { it.toInt() + octave * 12 }
        val sf = soundFont
        val voices = tones.mapIndexed { i, midi ->
            val v = "$touchId-c$i"
            if (sf != null) sf.noteOn(v, midi, 0.7f)
            else synthEngine.noteOn(v, midi, selectedWaveform, 0.7f)
            v
        }
        splitVoiceSubvoices[touchId] = voices
        splitTouchChordStack.add(SplitTouchChord(touchId, degree.toInt(), octave, tones))
        syncTouchChord()
    }

    /// A finger entered a melody lane. Spawns one sustained voice snapped to
    /// the currently active chord (latest touch wins, else camera chord).
    fun splitTouchEnterMelody(touchId: String, lane: Int) {
        val degree = splitTouchChordStack.lastOrNull()?.degree
            ?: chordMelodyManager.currentChordDegree()?.toInt()
            ?: 0
        val triad = coreChordNotes(selectedKey.toCoreKey(), selectedScale.toCoreScale(), degree)
        val lanes = (0..2).flatMap { oct -> triad.map { it.toInt() + oct * 12 } }.sorted()
        if (lanes.isEmpty()) return
        val safeLane = lane.coerceIn(0, lanes.size - 1)
        val voice = "$touchId-m"
        val sf = soundFont
        if (sf != null) sf.noteOn(voice, lanes[safeLane], 0.75f)
        else synthEngine.noteOn(voice, lanes[safeLane], selectedWaveform, 0.75f)
        splitVoiceSubvoices[touchId] = listOf(voice)
    }

    /// A touch lifted (or drag crossed out of its zone). Releases every voice
    /// that touch had spawned and drops any chord-stack entry.
    fun splitTouchExit(touchId: String) {
        val sf = soundFont
        splitVoiceSubvoices.remove(touchId)?.forEach { v ->
            if (sf != null) sf.noteOff(v) else synthEngine.noteOff(v)
        }
        if (splitTouchChordStack.any { it.touchId == touchId }) {
            splitTouchChordStack.removeAll { it.touchId == touchId }
            syncTouchChord()
        }
    }

    private fun syncTouchChord() {
        val top = splitTouchChordStack.lastOrNull()
        if (top != null) {
            chordMelodyManager.setTouchChord(top.degree.toLong().toInt(), top.octave, top.tones.map { it.toLong().toInt() })
        } else {
            chordMelodyManager.setTouchChord(null, 0, emptyList())
        }
    }

    private fun axisValue(hand: HandData, axis: String): Double {
        return when (axis) {
            "y" -> 1.0 - hand.y
            "x" -> hand.x
            "spread" -> hand.spread
            "pinch" -> hand.pinch
            "fist" -> hand.fist
            else -> 0.5
        }
    }
}

private fun buildChordToneTables(key: MusicKey, scale: Scale): ChordToneTables {
    val coreKey = key.toCoreKey()
    val coreScale = scale.toCoreScale()
    val degreeCount = scale.intervals.size
    val chordTones = (0 until degreeCount).map { d -> coreChordNotes(coreKey, coreScale, d) }
    // Melody snap targets per chord degree: each chord's triad fanned across
    // 3 octaves and sorted ascending — exactly 9 notes, one per melody lane
    // on the Split wheel. This is what makes the melody re-snap to whatever
    // chord is currently sounding (matches iOS Split mode).
    val melodyTones = (0 until degreeCount).map { d ->
        val triad = coreChordNotes(coreKey, coreScale, d)
        (0..2).flatMap { oct -> triad.map { it.toInt() + oct * 12 } }.sorted()
    }
    return ChordToneTables(chordTones = chordTones, melodyTones = melodyTones)
}
