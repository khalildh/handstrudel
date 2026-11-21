package com.handstrudel.engine.modes

import com.handstrudel.engine.HandStrudelEngine

/** Port of iOS `DrumModeController`: hand Y picks a drum lane, pinch crossings strike it. */
internal class DrumModeController : ModeController {
    override fun tick(engine: HandStrudelEngine) {
        engine.strudel.updateDrumParams(engine.drumIntensity.value, engine.drumComplexity.value)
        val drums = engine.drumManager
        for (hit in drums.checkHits(engine.currentHands)) {
            engine.strudel.playHit(hit.hitType)
            engine.haptics.drumHit()
            engine.lastDrumHit = hit.hitType
        }
        engine.updateLanes {
            it.copy(
                drumLeftLane = drums.leftLane, drumRightLane = drums.rightLane,
                drumLeftPinching = drums.isLeftPinching, drumRightPinching = drums.isRightPinching,
                lastDrumHit = engine.lastDrumHit,
            )
        }
        engine.evaluateDrumLoopsIfChanged("drum")
    }
}
