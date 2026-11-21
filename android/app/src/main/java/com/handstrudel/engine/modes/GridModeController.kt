package com.handstrudel.engine.modes

import com.handstrudel.engine.HandStrudelEngine
import uniffi.handstrudel_core.NoteAction

/** Port of iOS `GridModeController`: hand Y picks a lane, pinch articulates (core `GridModeManager`). */
internal class GridModeController : ModeController {
    override fun tick(engine: HandStrudelEngine) {
        val grid = engine.gridManager
        grid.setAspects(engine.handTracker.videoAspect, engine.screenAspect)
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
}
