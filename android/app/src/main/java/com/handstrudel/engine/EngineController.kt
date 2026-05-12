package com.handstrudel.engine

import android.content.Context
import android.os.Handler
import android.os.Looper
import com.handstrudel.engine.synth.Oscillator
import com.handstrudel.engine.synth.SynthEngine
import com.handstrudel.models.*
import kotlinx.coroutines.flow.MutableStateFlow

class EngineController(context: Context) {
    private val mainHandler = Handler(Looper.getMainLooper())
    val synthEngine = SynthEngine()
    val handTracker = HandTrackingManager(context)
    private val gridManager = GridModeManager()
    private val drumManager = DrumModeManager()

    // State
    val handsState = MutableStateFlow(HandsState())
    val isRunning = MutableStateFlow(false)
    val currentBeat = MutableStateFlow(0)

    // Configuration
    var selectedPreset: Preset? = null
    var selectedWaveform = "sawtooth"
    var selectedKey = MusicKey.C
    var selectedScale = Scale.PENTATONIC
    var gridModeEnabled = false
    var drumModeEnabled = false
    var manualBPM = 120.0

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

    // Cached scale notes
    private var cachedScaleNotes = listOf<Int>()

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
            else -> tickMelodicMode(hands)
        }
    }

    private fun tickMelodicMode(hands: HandsState) {
        val preset = selectedPreset ?: return
        val rawParams = mutableMapOf<String, Double>()

        // Map hand axes to params
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

        // Smooth params
        for ((id, raw) in rawParams) {
            val prev = smoothedParams[id] ?: raw
            smoothedParams[id] = prev + alpha * (raw - prev)
        }

        // Update synth engine directly
        val noteIdx = smoothedParams["noteIdx"]?.toInt()?.coerceIn(0, NOTES.size - 1) ?: 10
        val midiNote = MIDI_NOTES.getOrElse(noteIdx) { 60 }

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
