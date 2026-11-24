package com.handstrudel.engine

/** iOS `DrumZone`. */
data class DrumZone(val name: String, val hitType: String, val color: String)

/** iOS `DrumModeManager.DrumHit`. */
data class DrumHit(val hand: String, val hitType: String)

/**
 * Port of iOS `Engine/DrumModeManager.swift`: hand Y picks one of six drum
 * lanes (crash at the top, kick at the bottom); pinch onsets strike, and a held
 * pinch re-strikes when it slides into a new lane. Lighter 0.7/0.4 hysteresis.
 */
class DrumModeManager {
    private val leftPinch = PinchDetector(0.7, 0.4)
    private val rightPinch = PinchDetector(0.7, 0.4)
    private var leftLastDrum: String? = null
    private var rightLastDrum: String? = null

    var leftLane: Int? = null
        private set
    var rightLane: Int? = null
        private set
    val isLeftPinching: Boolean get() = leftPinch.isPinching
    val isRightPinching: Boolean get() = rightPinch.isPinching

    /** Map hand Y to a drum index (0 = top/crash, 5 = bottom/kick). */
    fun yToDrumIndex(y: Double): Int {
        val top = 0.15
        val bottom = 0.20
        val normalized = ((y - top) / (1 - top - bottom)).coerceIn(0.0, 1.0)
        return (normalized * ALL_DRUMS.size).toInt().coerceIn(0, ALL_DRUMS.size - 1)
    }

    fun checkHits(left: Pair<Double, Double>?, right: Pair<Double, Double>?): List<DrumHit> {
        val hits = mutableListOf<DrumHit>()
        // left/right = (pinchY, pinch)
        if (left != null) {
            val idx = yToDrumIndex(left.first)
            leftLane = idx
            val drum = ALL_DRUMS[idx]
            when (leftPinch.update(left.second)) {
                PinchDetector.Phase.BEGAN -> { leftLastDrum = drum.hitType; hits += DrumHit("left", drum.hitType) }
                PinchDetector.Phase.HELD -> if (drum.hitType != leftLastDrum) {
                    leftLastDrum = drum.hitType; hits += DrumHit("left", drum.hitType)
                }
                PinchDetector.Phase.ENDED -> leftLastDrum = null
                PinchDetector.Phase.IDLE -> Unit
            }
        } else {
            leftPinch.release(); leftLastDrum = null; leftLane = null
        }
        if (right != null) {
            val idx = yToDrumIndex(right.first)
            rightLane = idx
            val drum = ALL_DRUMS[idx]
            when (rightPinch.update(right.second)) {
                PinchDetector.Phase.BEGAN -> { rightLastDrum = drum.hitType; hits += DrumHit("right", drum.hitType) }
                PinchDetector.Phase.HELD -> if (drum.hitType != rightLastDrum) {
                    rightLastDrum = drum.hitType; hits += DrumHit("right", drum.hitType)
                }
                PinchDetector.Phase.ENDED -> rightLastDrum = null
                PinchDetector.Phase.IDLE -> Unit
            }
        } else {
            rightPinch.release(); rightLastDrum = null; rightLane = null
        }
        return hits
    }

    fun checkHits(hands: HandsState): List<DrumHit> =
        checkHits(hands.left?.let { it.pinchY to it.pinch }, hands.right?.let { it.pinchY to it.pinch })

    companion object {
        /** All six drums, top to bottom (matching the lanes). */
        val ALL_DRUMS: List<DrumZone> = listOf(
            DrumZone("Crash", "crash", "yellow"),
            DrumZone("Hi-Hat", "hihat", "cyan"),
            DrumZone("Snare", "snare", "orange"),
            DrumZone("Ride", "ride", "pink"),
            DrumZone("Tom", "tom", "purple"),
            DrumZone("Kick", "kick", "red"),
        )
        @Deprecated("Use ALL_DRUMS", ReplaceWith("ALL_DRUMS"))
        val allDrums: List<DrumZone> get() = ALL_DRUMS
    }
}

/** iOS `PinchDetector` (pure Kotlin twin of the core's internal detector). */
class PinchDetector(private val onThreshold: Double = 0.8, private val offThreshold: Double = 0.5) {
    enum class Phase { BEGAN, HELD, ENDED, IDLE }

    var isPinching: Boolean = false
        private set

    fun update(pinch: Double): Phase {
        if (pinch > onThreshold) {
            if (!isPinching) { isPinching = true; return Phase.BEGAN }
            return Phase.HELD
        }
        if (pinch < offThreshold) {
            if (isPinching) { isPinching = false; return Phase.ENDED }
            return Phase.IDLE
        }
        return Phase.IDLE
    }

    fun release(): Phase {
        if (isPinching) { isPinching = false; return Phase.ENDED }
        return Phase.IDLE
    }

    fun reset() { isPinching = false }
}
