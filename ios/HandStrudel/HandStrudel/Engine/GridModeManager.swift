import Foundation

final class GridModeManager {
    private var leftPinching = false
    private var rightPinching = false
    private let pinchThreshold: Double = 0.8   // fingers must be nearly touching
    private let releaseThreshold: Double = 0.5  // open a bit to release

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
            let isPinching = left.pinch > pinchThreshold

            if isPinching && !leftPinching {
                // New pinch — note on
                leftPinching = true
                leftHeldMidi = midi
                actions.append(.noteOn(hand: "left", midi: midi, noteName: midiNoteName(midi), velocity: min(1, left.pinch)))
            } else if isPinching && leftPinching {
                // Still pinching — check if lane changed (slide)
                if midi != leftHeldMidi {
                    leftHeldMidi = midi
                    actions.append(.slide(hand: "left", midi: midi, noteName: midiNoteName(midi)))
                }
            } else if left.pinch < releaseThreshold && leftPinching {
                // Released — note off
                leftPinching = false
                leftHeldMidi = nil
                actions.append(.noteOff(hand: "left"))
            }
        } else if leftPinching {
            leftPinching = false
            leftHeldMidi = nil
            actions.append(.noteOff(hand: "left"))
        }

        // Right hand
        if let right = hands.right {
            let noteIdx = yToNoteIndex(y: right.pinchY, noteCount: scaleNotes.count)
            let midi = scaleNotes[noteIdx]
            let isPinching = right.pinch > pinchThreshold

            if isPinching && !rightPinching {
                rightPinching = true
                rightHeldMidi = midi
                actions.append(.noteOn(hand: "right", midi: midi, noteName: midiNoteName(midi), velocity: min(1, right.pinch)))
            } else if isPinching && rightPinching {
                if midi != rightHeldMidi {
                    rightHeldMidi = midi
                    actions.append(.slide(hand: "right", midi: midi, noteName: midiNoteName(midi)))
                }
            } else if right.pinch < releaseThreshold && rightPinching {
                rightPinching = false
                rightHeldMidi = nil
                actions.append(.noteOff(hand: "right"))
            }
        } else if rightPinching {
            rightPinching = false
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
        // Correct for aspect fill cropping (same math as HandOverlayView)
        var correctedY = y
        if videoAspect < screenAspect {
            // Height is cropped
            let visibleFrac = Double(videoAspect / screenAspect)
            let offset = (1 - visibleFrac) / 2
            correctedY = (y - offset) / visibleFrac
        }
        let normalized = 1 - max(0, min(1, correctedY))
        return max(0, min(noteCount - 1, Int(normalized * Double(noteCount))))
    }

    func currentLanes(hands: HandsState, scaleNotes: [Int]) -> (left: Int?, right: Int?) {
        guard !scaleNotes.isEmpty else { return (nil, nil) }
        let leftIdx = hands.left.map { yToNoteIndex(y: $0.pinchY, noteCount: scaleNotes.count) }
        let rightIdx = hands.right.map { yToNoteIndex(y: $0.pinchY, noteCount: scaleNotes.count) }
        return (leftIdx, rightIdx)
    }

    var isLeftPinching: Bool { leftPinching }
    var isRightPinching: Bool { rightPinching }
}
