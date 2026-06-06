import Foundation

final class GridModeManager {
    // Fingers must be nearly touching (0.8) to fire; open a bit (0.5) to release.
    private var leftPinch = PinchDetector(on: 0.8, off: 0.5)
    private var rightPinch = PinchDetector(on: 0.8, off: 0.5)

    // Track current held MIDI note per hand (for slide detection)
    private var leftHeldMidi: Int? = nil
    private var rightHeldMidi: Int? = nil

    var quantizeEnabled = false
    var quantizeDiv: Double = 8

    enum NoteAction {
        case noteOn(hand: String, midi: Int, noteName: String, velocity: Double)
        case noteOff(hand: String)
        case slide(hand: String, midi: Int, noteName: String)
    }

    func checkNotes(hands: HandsState, scaleNotes: [Int], currentBeat: Double) -> [NoteAction] {
        guard !scaleNotes.isEmpty else { return [] }
        var actions: [NoteAction] = []

        // Left hand
        if let left = hands.left {
            let noteIdx = yToNoteIndex(y: left.pinchY, noteCount: scaleNotes.count)
            let midi = scaleNotes[noteIdx]

            switch leftPinch.update(pinch: left.pinch) {
            case .began:
                // New pinch — note on
                leftHeldMidi = midi
                actions.append(.noteOn(hand: "left", midi: midi, noteName: midiNoteName(midi), velocity: min(1, left.pinch)))
            case .held:
                // Still pinching — check if lane changed (slide)
                if midi != leftHeldMidi {
                    leftHeldMidi = midi
                    actions.append(.slide(hand: "left", midi: midi, noteName: midiNoteName(midi)))
                }
            case .ended:
                // Released — note off
                leftHeldMidi = nil
                actions.append(.noteOff(hand: "left"))
            case .idle:
                break
            }
        } else if leftPinch.release() == .ended {
            leftHeldMidi = nil
            actions.append(.noteOff(hand: "left"))
        }

        // Right hand
        if let right = hands.right {
            let noteIdx = yToNoteIndex(y: right.pinchY, noteCount: scaleNotes.count)
            let midi = scaleNotes[noteIdx]

            switch rightPinch.update(pinch: right.pinch) {
            case .began:
                rightHeldMidi = midi
                actions.append(.noteOn(hand: "right", midi: midi, noteName: midiNoteName(midi), velocity: min(1, right.pinch)))
            case .held:
                if midi != rightHeldMidi {
                    rightHeldMidi = midi
                    actions.append(.slide(hand: "right", midi: midi, noteName: midiNoteName(midi)))
                }
            case .ended:
                rightHeldMidi = nil
                actions.append(.noteOff(hand: "right"))
            case .idle:
                break
            }
        } else if rightPinch.release() == .ended {
            rightHeldMidi = nil
            actions.append(.noteOff(hand: "right"))
        }

        return actions
    }

    /// Video aspect ratio for correcting Y position (set from HandTrackingManager)
    var videoAspect: CGFloat = 0.75
    var screenAspect: CGFloat = 0.46  // iPhone ~390/844

    func yToNoteIndex(y: Double, noteCount: Int) -> Int {
        guard noteCount > 0 else { return 0 }
        // Map Y from padded range (15% top, 20% bottom = usable 0.15-0.80)
        let topPad = 0.15
        let bottomPad = 0.20
        let usable = 1.0 - topPad - bottomPad
        let normalized = 1 - max(0, min(1, (y - topPad) / usable))
        return max(0, min(noteCount - 1, Int(normalized * Double(noteCount))))
    }

    func currentLanes(hands: HandsState, scaleNotes: [Int]) -> (left: Int?, right: Int?) {
        guard !scaleNotes.isEmpty else { return (nil, nil) }
        let leftIdx = hands.left.map { yToNoteIndex(y: $0.pinchY, noteCount: scaleNotes.count) }
        let rightIdx = hands.right.map { yToNoteIndex(y: $0.pinchY, noteCount: scaleNotes.count) }
        return (leftIdx, rightIdx)
    }

    var isLeftPinching: Bool { leftPinch.isPinching }
    var isRightPinching: Bool { rightPinch.isPinching }
}
