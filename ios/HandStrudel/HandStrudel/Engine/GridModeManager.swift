import Foundation

final class GridModeManager {
    private var leftPinching = false
    private var rightPinching = false
    private let pinchThreshold: Double = 0.8   // fingers must be nearly touching
    private let releaseThreshold: Double = 0.5  // open a bit to release

    // The MIDI note each hand is currently *sounding* (nil = silent). Used both
    // for slide detection and, in quantized mode, to hold the audible note
    // steady between grid boundaries.
    private var leftHeldMidi: Int? = nil
    private var rightHeldMidi: Int? = nil

    enum NoteAction {
        case noteOn(hand: String, midi: Int, noteName: String, velocity: Double)
        case noteOff(hand: String)
        case slide(hand: String, midi: Int, noteName: String)
    }

    /// Process one frame of hand state into note actions.
    ///
    /// When `quantize` is false (the default), note-ons and slides fire the
    /// instant the hand pinches or crosses into a new lane — free, expressive
    /// timing. When `quantize` is true, the audible note is only allowed to
    /// change on a grid boundary (`gridBoundaryCrossed`), so onsets and slides
    /// snap to the beat. Releases always fire immediately so letting go feels
    /// responsive regardless of mode.
    func checkNotes(hands: HandsState, scaleNotes: [Int],
                    quantize: Bool = false,
                    gridBoundaryCrossed: Bool = false) -> [NoteAction] {
        guard !scaleNotes.isEmpty else { return [] }
        var actions: [NoteAction] = []
        processHand(hands.left, handName: "left", scaleNotes: scaleNotes,
                    quantize: quantize, boundary: gridBoundaryCrossed,
                    pinching: &leftPinching, audibleMidi: &leftHeldMidi, actions: &actions)
        processHand(hands.right, handName: "right", scaleNotes: scaleNotes,
                    quantize: quantize, boundary: gridBoundaryCrossed,
                    pinching: &rightPinching, audibleMidi: &rightHeldMidi, actions: &actions)
        return actions
    }

    private func processHand(_ hand: HandData?, handName: String, scaleNotes: [Int],
                             quantize: Bool, boundary: Bool,
                             pinching: inout Bool, audibleMidi: inout Int?,
                             actions: inout [NoteAction]) {
        guard let h = hand else {
            // Hand left the frame — stop any sounding note immediately.
            pinching = false
            if audibleMidi != nil {
                actions.append(.noteOff(hand: handName))
                audibleMidi = nil
            }
            return
        }

        // Hysteresis latch: pinch must reach pinchThreshold to engage and fall
        // below releaseThreshold to disengage — prevents flicker in the middle.
        if h.pinch > pinchThreshold {
            pinching = true
        } else if h.pinch < releaseThreshold {
            pinching = false
        }

        // Not pinching → release any held note right away. Releases stay live
        // even when quantized so let-go is always immediate.
        guard pinching else {
            if audibleMidi != nil {
                actions.append(.noteOff(hand: handName))
                audibleMidi = nil
            }
            return
        }

        let noteIdx = yToNoteIndex(y: h.pinchY, noteCount: scaleNotes.count)
        let midi = scaleNotes[noteIdx]

        // Quantized: only let the audible note change on a grid boundary.
        guard !quantize || boundary else { return }

        if audibleMidi == nil {
            actions.append(.noteOn(hand: handName, midi: midi, noteName: midiNoteName(midi), velocity: min(1, h.pinch)))
            audibleMidi = midi
        } else if midi != audibleMidi {
            actions.append(.slide(hand: handName, midi: midi, noteName: midiNoteName(midi)))
            audibleMidi = midi
        }
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

    var isLeftPinching: Bool { leftPinching }
    var isRightPinching: Bool { rightPinching }
}
