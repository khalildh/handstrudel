import Foundation

final class GridModeManager {
    // Fingers must be nearly touching (0.8) to fire; open a bit (0.5) to release.
    private var leftPinch = PinchDetector(on: 0.8, off: 0.5)
    private var rightPinch = PinchDetector(on: 0.8, off: 0.5)

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
                    pinch: &leftPinch, audibleMidi: &leftHeldMidi, actions: &actions)
        processHand(hands.right, handName: "right", scaleNotes: scaleNotes,
                    quantize: quantize, boundary: gridBoundaryCrossed,
                    pinch: &rightPinch, audibleMidi: &rightHeldMidi, actions: &actions)
        return actions
    }

    private func processHand(_ hand: HandData?, handName: String, scaleNotes: [Int],
                             quantize: Bool, boundary: Bool,
                             pinch: inout PinchDetector, audibleMidi: inout Int?,
                             actions: inout [NoteAction]) {
        guard let h = hand else {
            // Hand left the frame — stop any sounding note immediately. Releases
            // always fire live so letting go feels responsive even in quantize.
            if pinch.release() == .ended, audibleMidi != nil {
                actions.append(.noteOff(hand: handName))
                audibleMidi = nil
            }
            return
        }

        let phase = pinch.update(pinch: h.pinch)
        let noteIdx = yToNoteIndex(y: h.pinchY, noteCount: scaleNotes.count)
        let midi = scaleNotes[noteIdx]
        let allowChange = !quantize || boundary

        switch phase {
        case .began:
            // Defer the onset to the next grid boundary when quantized.
            if allowChange {
                audibleMidi = midi
                actions.append(.noteOn(hand: handName, midi: midi, noteName: midiNoteName(midi), velocity: min(1, h.pinch)))
            }
        case .held:
            if !allowChange { return }
            if audibleMidi == nil {
                audibleMidi = midi
                actions.append(.noteOn(hand: handName, midi: midi, noteName: midiNoteName(midi), velocity: min(1, h.pinch)))
            } else if midi != audibleMidi {
                audibleMidi = midi
                actions.append(.slide(hand: handName, midi: midi, noteName: midiNoteName(midi)))
            }
        case .ended:
            // Release immediately, regardless of quantize.
            if audibleMidi != nil {
                audibleMidi = nil
                actions.append(.noteOff(hand: handName))
            }
        case .idle:
            break
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

    var isLeftPinching: Bool { leftPinch.isPinching }
    var isRightPinching: Bool { rightPinch.isPinching }
}
