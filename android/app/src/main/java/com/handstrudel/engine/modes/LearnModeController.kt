package com.handstrudel.engine.modes

import com.handstrudel.engine.HandStrudelEngine
import com.handstrudel.engine.LearnLaneLayout

/** Port of iOS `LearnModeController`: camera lanes + pinch score falling notes. */
internal class LearnModeController : ModeController {
    override fun tick(engine: HandStrudelEngine) {
        val notes = engine.gridNotes()
        if (notes.isEmpty()) return
        val left = engine.currentHands.left
        val right = engine.currentHands.right
        val videoAspect = engine.handTracker.videoAspect
        fun lane(y: Double?) = y?.let { LearnLaneLayout.cameraLane(it, notes.size, videoAspect, engine.learnViewportAspect) }
        val leftLane = lane(left?.pinchY)
        val rightLane = lane(right?.pinchY)
        engine.updateLanes { it.copy(gridLeftLane = leftLane, gridRightLane = rightLane) }
        val hits = engine.learnManager.tick(
            engine.elapsed(), leftLane, rightLane, (left?.pinch ?: 0.0) > 0.8, (right?.pinch ?: 0.0) > 0.8,
        )
        for (hit in hits) {
            engine.strudel.playNote(hit.midi, engine.waveform, 0.7, 0.3)
            engine.haptics.learnPerfectHit()
        }
        engine.updateLearnUi()
    }
}
