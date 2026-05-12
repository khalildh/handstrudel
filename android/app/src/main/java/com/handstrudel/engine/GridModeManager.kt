package com.handstrudel.engine

import kotlin.math.max
import kotlin.math.min

enum class NoteAction { NOTE_ON, NOTE_OFF, SLIDE }

data class GridEvent(
    val hand: String,
    val action: NoteAction,
    val midi: Int,
    val velocity: Double = 0.6
)

class GridModeManager {
    private val pinchThreshold = 0.8
    private val releaseThreshold = 0.5

    private var leftPinching = false
    private var rightPinching = false
    private var leftHeldMidi: Int? = null
    private var rightHeldMidi: Int? = null

    var leftLane: Int? = null
        private set
    var rightLane: Int? = null
        private set
    val isLeftPinching get() = leftPinching
    val isRightPinching get() = rightPinching

    fun yToNoteIndex(y: Double, noteCount: Int): Int {
        val topPad = 0.15
        val bottomPad = 0.20
        val usable = 1.0 - topPad - bottomPad
        val normalized = ((y - topPad) / usable).coerceIn(0.0, 1.0)
        // Invert: top = high notes, bottom = low notes
        val inverted = 1.0 - normalized
        return (inverted * noteCount).toInt().coerceIn(0, noteCount - 1)
    }

    fun checkActions(hands: HandsState, scaleNotes: List<Int>): List<GridEvent> {
        if (scaleNotes.isEmpty()) return emptyList()
        val events = mutableListOf<GridEvent>()

        // Left hand
        val left = hands.left
        if (left != null) {
            val noteIdx = yToNoteIndex(left.pinchY, scaleNotes.size)
            leftLane = noteIdx
            val midi = scaleNotes[noteIdx]
            val isPinching = left.pinch > pinchThreshold
            val vel = (0.3 + left.pinch * 0.7).coerceIn(0.0, 1.0)

            if (isPinching && !leftPinching) {
                leftPinching = true
                leftHeldMidi = midi
                events.add(GridEvent("left", NoteAction.NOTE_ON, midi, vel))
            } else if (isPinching && leftPinching) {
                if (midi != leftHeldMidi) {
                    leftHeldMidi = midi
                    events.add(GridEvent("left", NoteAction.SLIDE, midi, vel))
                }
            } else if (!isPinching && left.pinch < releaseThreshold && leftPinching) {
                leftPinching = false
                leftHeldMidi?.let { events.add(GridEvent("left", NoteAction.NOTE_OFF, it)) }
                leftHeldMidi = null
            }
        } else {
            if (leftPinching) {
                leftHeldMidi?.let { events.add(GridEvent("left", NoteAction.NOTE_OFF, it)) }
            }
            leftPinching = false
            leftHeldMidi = null
            leftLane = null
        }

        // Right hand
        val right = hands.right
        if (right != null) {
            val noteIdx = yToNoteIndex(right.pinchY, scaleNotes.size)
            rightLane = noteIdx
            val midi = scaleNotes[noteIdx]
            val isPinching = right.pinch > pinchThreshold
            val vel = (0.3 + right.pinch * 0.7).coerceIn(0.0, 1.0)

            if (isPinching && !rightPinching) {
                rightPinching = true
                rightHeldMidi = midi
                events.add(GridEvent("right", NoteAction.NOTE_ON, midi, vel))
            } else if (isPinching && rightPinching) {
                if (midi != rightHeldMidi) {
                    rightHeldMidi = midi
                    events.add(GridEvent("right", NoteAction.SLIDE, midi, vel))
                }
            } else if (!isPinching && right.pinch < releaseThreshold && rightPinching) {
                rightPinching = false
                rightHeldMidi?.let { events.add(GridEvent("right", NoteAction.NOTE_OFF, it)) }
                rightHeldMidi = null
            }
        } else {
            if (rightPinching) {
                rightHeldMidi?.let { events.add(GridEvent("right", NoteAction.NOTE_OFF, it)) }
            }
            rightPinching = false
            rightHeldMidi = null
            rightLane = null
        }

        return events
    }
}
