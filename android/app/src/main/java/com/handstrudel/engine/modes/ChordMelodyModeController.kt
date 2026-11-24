package com.handstrudel.engine.modes

import com.handstrudel.engine.HandStrudelEngine
import com.handstrudel.engine.HandsState
import com.handstrudel.engine.StudioMode
import com.handstrudel.models.PARAM_MAP
import com.handstrudel.models.chordNotes
import com.handstrudel.models.chordNotesWithSeventh
import com.handstrudel.models.scaleNotesOneOctave
import uniffi.handstrudel_core.ChordMelodyAction
import uniffi.handstrudel_core.ChordToneTables

/**
 * Port of iOS `ChordMelodyModeController` (Strudel-voiced chord+melody: Chord+Melody
 * zones, and Radial/Split/Scale with "Voice through SoundFont" off).
 */
internal class ChordMelodyModeController : ModeController {
    private var lastBeat = -1

    override fun tick(engine: HandStrudelEngine) {
        val manager = engine.chordMelodyManager
        prepareManager(engine)
        val actions = manager.tick(
            engine.currentHands.core(), toneTables(engine), engine.quantizeOn,
            engine.quantize.boundaryCrossed(engine.nowSeconds()),
        )
        val strudel = engine.strudel
        for (action in actions) {
            when (action) {
                is ChordMelodyAction.PadOn -> {
                    publishChord(engine, action.degree)
                    action.midiNotes.forEachIndexed { i, midi -> strudel.noteOn("pad$i", midi, "triangle", engine.padVolume) }
                }
                is ChordMelodyAction.PadSlide -> {
                    publishChord(engine, action.degree)
                    action.midiNotes.forEachIndexed { i, midi -> strudel.noteSlide("pad$i", midi) }
                }
                is ChordMelodyAction.PadOff -> for (i in 0 until 4) strudel.noteOff("pad$i")
                is ChordMelodyAction.ChordAccent -> {
                    for (midi in action.midiNotes) strudel.playNote(midi, engine.waveform, action.velocity * 0.5, 0.5)
                    engine.haptics.noteTrigger()
                }
                is ChordMelodyAction.MelodyOn -> {
                    strudel.noteOn(action.hand, action.midi, engine.waveform, action.velocity)
                    engine.haptics.noteTrigger()
                    engine.lastGridNote = action.name
                }
                is ChordMelodyAction.MelodyOff -> strudel.noteOff(action.hand)
                is ChordMelodyAction.MelodySlide -> {
                    strudel.noteSlide(action.hand, action.midi)
                    engine.lastGridNote = action.name
                }
            }
        }
        publishZonesIfNeeded(engine, actions.isNotEmpty())

        // Melody-hand X → low-pass cutoff (timbre).
        val melodyHand = if (engine.swapHandsOn) engine.currentHands.left else engine.currentHands.right
        val lpf = PARAM_MAP["lpf"]
        if (melodyHand != null && lpf != null) {
            val mapped = lpf.min + melodyHand.pinchX.coerceIn(0.0, 1.0) * (lpf.max - lpf.min)
            engine.smoothed["lpf"] = mapped
            strudel.setSynthParam("lpf", mapped)
        }

        // Auto-strum: re-articulate the held chord on each beat.
        val chordMidi = manager.currentChordMidi()
        if (engine.autoStrum && chordMidi.isNotEmpty() && engine.currentBeat.value != lastBeat) {
            lastBeat = engine.currentBeat.value
            for (midi in chordMidi) strudel.playNote(midi, engine.waveform, 0.25, 0.4)
        }
        engine.evaluateDrumLoopsIfChanged("chordmelody")
    }

    companion object {
        private var preparedManager: Any? = null
        private var preparedLayout: Any? = null
        private var preparedSwap: Boolean? = null
        private var preparedVideoAspect = Double.NaN
        private var preparedScreenAspect = Double.NaN

        /**
         * Push layout, hand swap and aspects into the manager when they change. They are plain
         * setters in Rust, and each Rust call costs a slow phone a noticeable slice of a frame.
         */
        fun prepareManager(engine: HandStrudelEngine) {
            val manager = engine.chordMelodyManager
            if (manager !== preparedManager) {
                preparedManager = manager; preparedLayout = null; preparedSwap = null
                preparedVideoAspect = Double.NaN; preparedScreenAspect = Double.NaN
            }
            val layout = engine.layout
            if (layout != preparedLayout) { manager.setLayout(layout); preparedLayout = layout }
            val swap = engine.swapHandsOn
            if (swap != preparedSwap) { manager.setSwapHands(swap); preparedSwap = swap }
            val video = engine.handTracker.videoAspect
            val screen = engine.screenAspect
            if (video != preparedVideoAspect || screen != preparedScreenAspect) {
                manager.setAspects(video, screen); preparedVideoAspect = video; preparedScreenAspect = screen
            }
        }

        /**
         * iOS chordTones/melodyTones closures as tables per degree: triads (7ths in
         * Scale) and the melody snap targets (triad × 3 octaves, or one scale octave).
         */
        private var tablesKey: Any? = null
        private var tables: ChordToneTables? = null

        /** [buildToneTables], rebuilt only when the key, scale or mode changes (ticks every frame). */
        fun toneTables(engine: HandStrudelEngine): ChordToneTables {
            val key = Triple(engine.key, engine.scale, engine.mode.value == StudioMode.SCALE)
            if (key == tablesKey) tables?.let { return it }
            return buildToneTables(engine).also { tablesKey = key; tables = it }
        }

        private fun buildToneTables(engine: HandStrudelEngine): ChordToneTables {
            val scaleMode = engine.mode.value == StudioMode.SCALE
            // Progressions use degrees 0–6; chordNotes wraps them for shorter scales (iOS closures do too).
            val degrees = 0 until maxOf(7, engine.scale.intervals.size)
            val chord = degrees.map { d ->
                if (scaleMode) chordNotesWithSeventh(engine.key, engine.scale, d) else chordNotes(engine.key, engine.scale, d)
            }
            val melody = if (scaleMode) {
                val octave = scaleNotesOneOctave(engine.key, engine.scale)
                degrees.map { octave }
            } else degrees.map { d ->
                val triad = chordNotes(engine.key, engine.scale, d)
                (0 until 3).flatMap { oct -> triad.map { it + oct * 12 } }.sorted()
            }
            return ChordToneTables(chord, melody)
        }

        fun publishChord(engine: HandStrudelEngine, degree: Int) {
            val shift = engine.chordMelodyManager.currentOctaveShift()
            engine.updateChordMelodyDisplay {
                it.copy(currentChordName = engine.chordName(degree), currentDegree = degree, octaveShift = shift)
            }
        }

        /** Publish zones every frame (touch overrides change state without actions). */
        private var publishedHands: HandsState? = null
        private var publishedAtNanos = 0L

        /**
         * [publishZones] when the hands changed or something played, otherwise at most every
         * [IDLE_PUBLISH_NANOS] (touch overrides change state without actions). Each publish is
         * about ten Rust calls, which cost a slow phone most of its frame budget at 60 Hz.
         */
        fun publishZonesIfNeeded(engine: HandStrudelEngine, played: Boolean) {
            val now = System.nanoTime()
            if (!played && engine.currentHands === publishedHands && now - publishedAtNanos < IDLE_PUBLISH_NANOS) return
            publishedHands = engine.currentHands
            publishedAtNanos = now
            publishZones(engine)
        }

        private const val IDLE_PUBLISH_NANOS = 50_000_000L

        fun publishZones(engine: HandStrudelEngine) {
            val manager = engine.chordMelodyManager
            val zones = manager.currentZones(engine.currentHands.core())
            val degree = manager.currentChordDegree()
            val scaleMode = engine.mode.value == StudioMode.SCALE
            engine.updateChordMelodyDisplay { d ->
                var next = d.copy(
                    chordHandLane = zones.chordZoneIndex,
                    chordZoneIndex = zones.chordZoneIndex,
                    melodyLane = zones.melodyLane,
                    octaveShift = manager.currentOctaveShift(),
                    melodyOctaveShift = manager.currentMelodyOctaveShift(),
                    zoneDegrees = manager.zoneDegrees(),
                    isChordHandPinching = manager.isChordHandPinching(),
                    isMelodyHandPinching = manager.isMelodyHandPinching(),
                    chordResting = zones.chordResting,
                    melodyResting = zones.melodyResting,
                    melodyLaneCount = if (scaleMode) engine.scale.intervals.size else 9,
                )
                if (degree != null) next = next.copy(currentDegree = degree, currentChordName = engine.chordName(degree))
                else if (zones.chordZoneIndex != null && d.currentDegree == null) {
                    next = next.copy(currentChordName = engine.chordName(manager.degreeForZone(zones.chordZoneIndex!!)))
                }
                next
            }
        }
    }
}
