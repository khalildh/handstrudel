package com.handstrudel.engine.modes

import com.handstrudel.engine.HandStrudelEngine
import com.handstrudel.engine.StudioMode
import com.handstrudel.models.FLOW_STRUCT
import com.handstrudel.models.NOTES
import com.handstrudel.models.buildChordSignalCode
import com.handstrudel.models.buildSignalCode
import com.handstrudel.models.chordNotes

/**
 * Port of iOS `MelodicModeController`: Melodic (sparse STRUCTS), Flow (dense
 * 16ths), Hybrid (Strudel body + an imperative lead voice) and Lead (the lead
 * voice only, drum loops underneath).
 */
internal class MelodicModeController : ModeController {
    override fun tick(engine: HandStrudelEngine) {
        when (engine.mode.value) {
            StudioMode.LEAD -> tickLead(engine)
            StudioMode.HYBRID -> {
                tickStrudelCore(engine, "hybrid", null)
                driveLeadVoice(engine, 0.45)
            }
            StudioMode.FLOW -> tickStrudelCore(engine, "flow", FLOW_STRUCT)
            else -> tickStrudelCore(engine, "melodic", null)
        }
    }

    private fun tickLead(engine: HandStrudelEngine) {
        driveLeadVoice(engine, 0.6)
        engine.evaluateDrumLoopsIfChanged("lead")
    }

    private fun tickStrudelCore(engine: HandStrudelEngine, keyPrefix: String, structOverride: String?) {
        val strudel = engine.strudel
        val hasHands = engine.currentHands.left != null || engine.currentHands.right != null
        if (!hasHands) {
            // Mute when no hands are detected.
            engine.smoothed["gain"] = 0.0
            strudel.updateParams(engine.smoothed, engine.config)
            return
        }
        val notes = engine.cachedScaleNotes
        if (engine.chordModeOn) {
            val count = engine.scale.intervals.size
            val normalized = (engine.smoothed["noteIdx"] ?: 0.0) / maxOf(1, NOTES.size - 1)
            val degree = (normalized * (count - 1) + 0.5).toInt().coerceIn(0, count - 1)
            strudel.updateChordParams(engine.smoothed, engine.config, chordNotes(engine.key, engine.scale, degree))
        } else if (notes.isNotEmpty()) {
            val normalized = (engine.smoothed["noteIdx"] ?: 10.0) / maxOf(1, NOTES.size - 1)
            val idx = (normalized * (notes.size - 1) + 0.5).toInt().coerceIn(0, notes.size - 1)
            strudel.updateScaleParams(engine.smoothed, engine.config, notes[idx])
        }

        val harmonyKey = "${engine.key.rawValue}|${engine.scale.id}|${engine.chordModeOn}"
        val structKey = "$keyPrefix|${engine.structIdx}|${engine.drumStateKey}|${engine.waveform}|$harmonyKey"
        if (structKey != engine.lastStructKey) {
            engine.lastStructKey = structKey
            engine.recomputeScaleNotes()
            val synth = if (engine.chordModeOn) buildChordSignalCode(engine.structIdx, engine.config, engine.waveform, structOverride)
            else buildSignalCode(engine.structIdx, engine.config, engine.waveform, structOverride)
            strudel.evaluate(HandStrudelEngine.stackCode(listOf(synth) + engine.buildDrumCodeParts()))
        }
    }

    /** Scale-snapped monophonic note from `noteIdx` (shared by Lead and Hybrid). */
    private fun melodicMidi(engine: HandStrudelEngine): Int? {
        val notes = engine.cachedScaleNotes
        if (notes.isEmpty()) return null
        val normalized = (engine.smoothed["noteIdx"] ?: 10.0) / maxOf(1, NOTES.size - 1)
        return notes[(normalized * (notes.size - 1) + 0.5).toInt().coerceIn(0, notes.size - 1)]
    }

    /** noteOn on first contact, noteSlide while a hand is present, noteOff when hands leave. */
    private fun driveLeadVoice(engine: HandStrudelEngine, velocity: Double) {
        val hasHands = engine.currentHands.left != null || engine.currentHands.right != null
        val midi = if (hasHands) melodicMidi(engine) else null
        if (midi == null) {
            if (engine.leadVoiceMidi != null) {
                engine.strudel.noteOff("lead")
                engine.leadVoiceMidi = null
            }
            return
        }
        if (engine.leadVoiceMidi == null) {
            engine.strudel.noteOn("lead", midi, engine.waveform, velocity)
            engine.leadVoiceMidi = midi
        } else if (engine.leadVoiceMidi != midi) {
            engine.strudel.noteSlide("lead", midi)
            engine.leadVoiceMidi = midi
        }
    }
}
