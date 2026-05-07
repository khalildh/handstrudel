package com.handstrudel.engine

import android.content.Context
import com.handstrudel.models.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow

class EngineController(context: Context) {
    val strudelBridge = StrudelBridge(context)
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

    // Last evaluated code (avoid re-eval)
    private var lastCode = ""
    private var structIdx = 0
    private var structTimer = 0L

    init {
        strudelBridge.onBeat = { beat ->
            currentBeat.value = beat
        }

        handTracker.onHandsDetected = { hands ->
            handsState.value = hands
            tick(hands)
        }

        recomputeScaleNotes()
    }

    fun start(preset: Preset) {
        selectedPreset = preset
        strudelBridge.initialize()
        isRunning.value = true
    }

    fun stop() {
        strudelBridge.stop()
        isRunning.value = false
    }

    fun recomputeScaleNotes() {
        cachedScaleNotes = scaleNotes(selectedKey, selectedScale, gridBaseOctave, gridOctaveRange)
    }

    private fun tick(hands: HandsState) {
        if (!isRunning.value) return

        val now = System.currentTimeMillis()
        // Rotate struct every 8 seconds
        if (now - structTimer > 8000) {
            structTimer = now
            structIdx = (structIdx + 1) % STRUCTS.size
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

        // Build Strudel code
        val noteIdx = smoothedParams["noteIdx"]?.toInt()?.coerceIn(0, NOTES.size - 1) ?: 10
        val note = NOTES[noteIdx]
        val bpm = smoothedParams["bpm"] ?: manualBPM
        val cpm = String.format("%.1f", bpm / 4)
        val st = STRUCTS[structIdx]

        var code = "note(\"$note\").s(\"$selectedWaveform\").struct(\"$st\").cpm($cpm)"

        val extraIds = preset.leftMapping.values + preset.rightMapping.values
        for (id in extraIds.toSet()) {
            if (id == "noteIdx" || id == "bpm" || id == "none") continue
            val def = PARAM_MAP[id] ?: continue
            val v = smoothedParams[id] ?: def.defaultValue
            code += ".${def.strudelKey}(${String.format("%.2f", v)})"
        }

        if (code != lastCode) {
            lastCode = code
            strudelBridge.evaluate(code)
        }

        // Update __hp for signal-based params
        val hpParams = mutableMapOf<String, Double>()
        hpParams["_cpm"] = (bpm) / 4
        hpParams["_midi"] = (48 + noteIdx * 2).toDouble()
        for ((id, v) in smoothedParams) {
            hpParams[id] = v
        }
        strudelBridge.updateParams(hpParams)
    }

    private fun tickGridMode(hands: HandsState) {
        val events = gridManager.checkActions(hands, cachedScaleNotes)
        gridLeftLane.value = gridManager.leftLane
        gridRightLane.value = gridManager.rightLane
        gridLeftPinching.value = gridManager.isLeftPinching
        gridRightPinching.value = gridManager.isRightPinching

        for (event in events) {
            when (event.action) {
                NoteAction.NOTE_ON -> strudelBridge.noteOn(event.hand, event.midi, selectedWaveform, event.velocity)
                NoteAction.NOTE_OFF -> strudelBridge.noteOff(event.hand)
                NoteAction.SLIDE -> strudelBridge.noteSlide(event.hand, event.midi)
            }
        }
    }

    private fun tickDrumMode(hands: HandsState) {
        val hits = drumManager.checkHits(hands)
        drumLeftLane.value = drumManager.leftLane
        drumRightLane.value = drumManager.rightLane
        drumLeftPinching.value = drumManager.isLeftPinching
        drumRightPinching.value = drumManager.isRightPinching

        strudelBridge.setDrumParams(drumIntensity, drumComplexity)

        for (hit in hits) {
            strudelBridge.playHit(hit.hitType)
        }
    }

    private fun axisValue(hand: HandData, axis: String): Double {
        return when (axis) {
            "y" -> 1.0 - hand.y // Invert: top = high
            "x" -> hand.x
            "spread" -> hand.spread
            "pinch" -> hand.pinch
            "fist" -> hand.fist
            else -> 0.5
        }
    }
}
