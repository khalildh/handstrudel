package com.handstrudel.engine.modes

import com.handstrudel.engine.HandStrudelEngine
import uniffi.handstrudel_core.NoteAction

/** Port of iOS `GridModeController`: hand Y picks a lane, pinch articulates (core `GridModeManager`). */
internal class GridModeController : ModeController {
    override fun tick(engine: HandStrudelEngine) {
        val grid = engine.gridManager
        grid.setAspects(engine.handTracker.videoAspect, engine.screenAspect)
        if (engine.fingerOctaveEnabled.value) applyFingerOctave(engine)
        val notes = engine.gridNotes()
        val hands = engine.currentHands.core()
        val actions = grid.checkNotes(hands, notes, engine.quantizeOn, engine.quantize.boundaryCrossed(engine.nowSeconds()))
        for (action in actions) {
            when (action) {
                is NoteAction.NoteOn -> {
                    engine.strudel.noteOn(action.hand, action.midi, engine.waveform, action.velocity)
                    engine.haptics.noteTrigger()
                    engine.lastGridNote = action.noteName
                }
                is NoteAction.NoteOff -> engine.strudel.noteOff(action.hand)
                is NoteAction.Slide -> {
                    engine.strudel.noteSlide(action.hand, action.midi)
                    engine.lastGridNote = action.noteName
                }
            }
        }
        val lanes = grid.currentLanes(hands, notes)
        engine.updateLanes {
            it.copy(
                gridLeftLane = lanes.left, gridRightLane = lanes.right,
                gridLeftPinching = grid.isLeftPinching(), gridRightPinching = grid.isRightPinching(),
                lastGridNote = engine.lastGridNote,
            )
        }
        engine.evaluateDrumLoopsIfChanged("grid")
    }

    /** iOS: the non-pinching hand's raised fingers (1–5) set the base octave (2–6). */
    private fun applyFingerOctave(engine: HandStrudelEngine) {
        val grid = engine.gridManager
        val left = engine.currentHands.left
        val right = engine.currentHands.right
        val lp = grid.isLeftPinching()
        val rp = grid.isRightPinching()
        val hand = when {
            lp && !rp -> right
            rp && !lp -> left
            !lp && !rp -> if ((left?.fingersUp ?: 0) >= (right?.fingersUp ?: 0)) left else right
            else -> null
        } ?: return
        engine._fingerCount.value = hand.fingersUp
        if (hand.fingersUp in 1..5 && hand.fingersUp + 1 != engine.gridBaseOctave.value) engine.setGridBaseOctave(hand.fingersUp + 1)
    }
}
