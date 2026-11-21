package com.handstrudel.engine.modes

import com.handstrudel.engine.HandStrudelEngine
import uniffi.handstrudel_core.ChordMelodyAction

/**
 * Port of iOS `EngineController.tickSoundFontMode`: the chord+melody interaction
 * voiced by the native sampler (SoundFont mode, and Radial/Split/Scale with
 * "Voice through SoundFont" on). Runs free-time: no quantize.
 */
internal class SoundFontModeController : ModeController {
    private var lastBeat = -1

    override fun tick(engine: HandStrudelEngine) {
        val sf = engine.soundFont
        sf.startIfNeeded(engine.instrumentProgram)
        val manager = engine.chordMelodyManager
        ChordMelodyModeController.prepareManager(engine)
        val actions = manager.tick(engine.currentHands.core(), ChordMelodyModeController.toneTables(engine), false, false)
        for (action in actions) {
            when (action) {
                is ChordMelodyAction.PadOn -> {
                    ChordMelodyModeController.publishChord(engine, action.degree)
                    action.midiNotes.forEachIndexed { i, midi -> sf.noteOn("pad$i", midi, engine.padVolume) }
                }
                is ChordMelodyAction.PadSlide -> {
                    ChordMelodyModeController.publishChord(engine, action.degree)
                    action.midiNotes.forEachIndexed { i, midi -> sf.slide("pad$i", midi) }
                }
                // Hard cut so pads with long release tails go silent at once.
                is ChordMelodyAction.PadOff -> for (i in 0 until 4) sf.hardStop("pad$i")
                is ChordMelodyAction.ChordAccent -> {
                    for (midi in action.midiNotes) sf.oneShot(midi, action.velocity * 0.6, 0.5)
                    engine.haptics.noteTrigger()
                }
                is ChordMelodyAction.MelodyOn -> {
                    sf.noteOn(action.hand, action.midi, action.velocity)
                    engine.haptics.noteTrigger()
                    engine.lastGridNote = action.name
                }
                is ChordMelodyAction.MelodyOff -> sf.noteOff(action.hand)
                is ChordMelodyAction.MelodySlide -> {
                    sf.slide(action.hand, action.midi)
                    engine.lastGridNote = action.name
                }
            }
        }
        ChordMelodyModeController.publishZones(engine)

        val chordMidi = manager.currentChordMidi()
        if (engine.autoStrum && chordMidi.isNotEmpty() && engine.currentBeat.value != lastBeat) {
            lastBeat = engine.currentBeat.value
            for (midi in chordMidi) sf.oneShot(midi, 0.3, 0.4)
        }
        engine.evaluateDrumLoopsIfChanged("soundfont")
    }
}
