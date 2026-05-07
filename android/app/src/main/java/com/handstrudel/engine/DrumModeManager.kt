package com.handstrudel.engine

data class DrumZone(val name: String, val hitType: String, val color: String)

data class DrumHit(val hand: String, val hitType: String)

class DrumModeManager {
    companion object {
        val allDrums = listOf(
            DrumZone("Crash", "crash", "yellow"),
            DrumZone("Hi-Hat", "hihat", "cyan"),
            DrumZone("Snare", "snare", "orange"),
            DrumZone("Ride", "ride", "pink"),
            DrumZone("Tom", "tom", "purple"),
            DrumZone("Kick", "kick", "red"),
        )
    }

    private val pinchThreshold = 0.7
    private val releaseThreshold = 0.4

    private var leftPinching = false
    private var rightPinching = false
    private var leftLastDrum: String? = null
    private var rightLastDrum: String? = null

    var leftLane: Int? = null
        private set
    var rightLane: Int? = null
        private set
    val isLeftPinching get() = leftPinching
    val isRightPinching get() = rightPinching

    fun yToDrumIndex(y: Double): Int {
        val topPad = 0.15
        val bottomPad = 0.20
        val usable = 1.0 - topPad - bottomPad
        val normalized = ((y - topPad) / usable).coerceIn(0.0, 1.0)
        return (normalized * allDrums.size).toInt().coerceIn(0, allDrums.size - 1)
    }

    fun checkHits(hands: HandsState): List<DrumHit> {
        val hits = mutableListOf<DrumHit>()

        // Left hand
        val left = hands.left
        if (left != null) {
            val drumIdx = yToDrumIndex(left.pinchY)
            leftLane = drumIdx
            val drum = allDrums[drumIdx]
            val isPinching = left.pinch > pinchThreshold

            if (isPinching && !leftPinching) {
                leftPinching = true
                leftLastDrum = drum.hitType
                hits.add(DrumHit("left", drum.hitType))
            } else if (isPinching && leftPinching) {
                if (drum.hitType != leftLastDrum) {
                    leftLastDrum = drum.hitType
                    hits.add(DrumHit("left", drum.hitType))
                }
            } else if (left.pinch < releaseThreshold) {
                leftPinching = false
                leftLastDrum = null
            }
        } else {
            leftPinching = false
            leftLastDrum = null
            leftLane = null
        }

        // Right hand
        val right = hands.right
        if (right != null) {
            val drumIdx = yToDrumIndex(right.pinchY)
            rightLane = drumIdx
            val drum = allDrums[drumIdx]
            val isPinching = right.pinch > pinchThreshold

            if (isPinching && !rightPinching) {
                rightPinching = true
                rightLastDrum = drum.hitType
                hits.add(DrumHit("right", drum.hitType))
            } else if (isPinching && rightPinching) {
                if (drum.hitType != rightLastDrum) {
                    rightLastDrum = drum.hitType
                    hits.add(DrumHit("right", drum.hitType))
                }
            } else if (right.pinch < releaseThreshold) {
                rightPinching = false
                rightLastDrum = null
            }
        } else {
            rightPinching = false
            rightLastDrum = null
            rightLane = null
        }

        return hits
    }
}
