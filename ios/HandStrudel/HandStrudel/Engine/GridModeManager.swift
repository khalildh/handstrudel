import Foundation

final class GridModeManager {
    // Pinch detection
    private var leftPinching = false
    private var rightPinching = false
    private let pinchThreshold: Double = 0.6   // pinch value to trigger
    private let releaseThreshold: Double = 0.3  // pinch value to release

    // Beat quantization
    var quantizeEnabled = false
    var quantizeDiv: Double = 8  // 8 = eighth notes, 16 = sixteenth notes

    struct NoteEvent {
        let midi: Int
        let noteName: String
        let hand: String  // "left" or "right"
        let velocity: Double // 0-1
    }

    /// Given hand state and available scale notes, determine which note lane each hand is in
    /// and whether a pinch trigger happened.
    func checkNotes(hands: HandsState, scaleNotes: [Int], currentBeat: Double) -> [NoteEvent] {
        guard !scaleNotes.isEmpty else { return [] }
        var events: [NoteEvent] = []

        // Left hand
        if let left = hands.left {
            let noteIdx = yToNoteIndex(y: left.y, noteCount: scaleNotes.count)
            let midi = scaleNotes[noteIdx]
            let wasPinching = leftPinching
            let isPinching = left.pinch > pinchThreshold

            if isPinching && !wasPinching {
                // New pinch — trigger note
                leftPinching = true
                events.append(NoteEvent(
                    midi: midi,
                    noteName: midiNoteName(midi),
                    hand: "left",
                    velocity: min(1, left.pinch)
                ))
            } else if left.pinch < releaseThreshold {
                leftPinching = false
            }
        } else {
            leftPinching = false
        }

        // Right hand
        if let right = hands.right {
            let noteIdx = yToNoteIndex(y: right.y, noteCount: scaleNotes.count)
            let midi = scaleNotes[noteIdx]
            let wasPinching = rightPinching
            let isPinching = right.pinch > pinchThreshold

            if isPinching && !wasPinching {
                rightPinching = true
                events.append(NoteEvent(
                    midi: midi,
                    noteName: midiNoteName(midi),
                    hand: "right",
                    velocity: min(1, right.pinch)
                ))
            } else if right.pinch < releaseThreshold {
                rightPinching = false
            }
        } else {
            rightPinching = false
        }

        return events
    }

    /// Map Y position (0=top, 1=bottom) to note index (0=highest, count-1=lowest)
    /// This makes moving hand UP = higher pitch (natural mapping)
    func yToNoteIndex(y: Double, noteCount: Int) -> Int {
        guard noteCount > 0 else { return 0 }
        // Invert: y=0 (top) → highest note, y=1 (bottom) → lowest note
        let normalized = 1 - max(0, min(1, y))
        return max(0, min(noteCount - 1, Int(normalized * Double(noteCount))))
    }

    /// Get the current note lane each hand is hovering over (for visual display)
    func currentLanes(hands: HandsState, scaleNotes: [Int]) -> (left: Int?, right: Int?) {
        guard !scaleNotes.isEmpty else { return (nil, nil) }
        let leftIdx = hands.left.map { yToNoteIndex(y: $0.y, noteCount: scaleNotes.count) }
        let rightIdx = hands.right.map { yToNoteIndex(y: $0.y, noteCount: scaleNotes.count) }
        return (leftIdx, rightIdx)
    }

    /// Check if either hand is currently pinching (for visual feedback)
    var isLeftPinching: Bool { leftPinching }
    var isRightPinching: Bool { rightPinching }
}
