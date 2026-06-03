import Foundation

/// Two-hand chord+melody mode.
///
/// One hand picks one of 7 diatonic chord zones by horizontal position; pinch
/// crossings strike the chord. The other hand picks a melody note from the
/// current chord's tones by vertical position; pinch crossings articulate the
/// note. This is the chord-and-melody pattern every piano/guitar player knows,
/// adapted to hand tracking.
///
/// `swapHands == false` → left=chords, right=melody.
/// `swapHands == true`  → right=chords, left=melody (for left-handed users).
final class ChordMelodyModeManager {

    enum Action {
        // The chord hand drives a sustained pad. `padOn` fires once when the
        // hand becomes visible in frame; `padSlide` fires when it moves to a
        // different zone (smooth crossfade); `padOff` fires when it leaves.
        case padOn(midiNotes: [Int], degree: Int)
        case padSlide(midiNotes: [Int], degree: Int)
        case padOff

        // Pinch is a separate, additive accent on top of the pad.
        case chordAccent(midiNotes: [Int], degree: Int, velocity: Double)

        // Melody hand: one sustained voice that articulates on pinch.
        case melodyOn(hand: String, midi: Int, name: String, velocity: Double)
        case melodyOff(hand: String)
        case melodySlide(hand: String, midi: Int, name: String)
    }

    // MARK: - Config

    var swapHands: Bool = false

    private let pinchThreshold: Double = 0.8
    private let releaseThreshold: Double = 0.5

    /// The scale degrees that each chord zone resolves to. With "Free" this
    /// is [0,1,2,3,4,5,6] (all 7 diatonic chords). With a progression like
    /// Pop it's [0,4,5,3] (I, V, vi, IV) — only 4 zones, easier to play.
    var zoneDegrees: [Int] = [0, 1, 2, 3, 4, 5, 6]

    /// Number of chord zones currently in use.
    var zoneCount: Int { max(1, zoneDegrees.count) }

    // MARK: - State (mutated each tick)

    private var chordHandPinching = false
    private var melodyHandPinching = false
    private var heldMelodyMidi: Int? = nil

    /// Whether the pad is currently sounding (chord hand visible in frame).
    private var padOn = false
    /// The chord degree the pad is currently voicing.
    private var padDegree: Int? = nil
    /// The octave shift the pad is currently voicing (from chord-hand Y).
    private var padOctaveShift: Int = 0
    /// Latest chord-hand Y read, published for UI.
    private(set) var currentOctaveShift: Int = 0

    // MARK: - Aspect-fill correction (set from EngineController each tick)

    var videoAspect: CGFloat = 0.75
    var screenAspect: CGFloat = 0.46

    // MARK: - Public read state (for UI)

    private(set) var currentChordDegree: Int? = nil
    private(set) var currentChordMidi: [Int] = []
    var isChordHandPinching: Bool { chordHandPinching }
    var isMelodyHandPinching: Bool { melodyHandPinching }

    // MARK: - Hand routing

    private var chordHandName: String { swapHands ? "right" : "left" }
    private var melodyHandName: String { swapHands ? "left" : "right" }
    private func chordHand(_ hands: HandsState) -> HandData? { swapHands ? hands.right : hands.left }
    private func melodyHand(_ hands: HandsState) -> HandData? { swapHands ? hands.left : hands.right }

    // MARK: - Position → degree / lane

    /// Map normalized X (0..1) to a zone index (0..<zoneCount).
    ///
    /// The chord hand owns half of the screen — the left half by default, or
    /// the right half when `swapHands` is on. We first correct for aspect-fill
    /// cropping, then map the chord hand's half-screen range to the zones so
    /// the highlighted zone always lines up with where the player pinched.
    func xToZoneIndex(_ x: Double) -> Int {
        let visible = visibleX(x)
        let halfRange: Double = swapHands
            ? (visible - 0.5) * 2.0
            : visible * 2.0
        let clamped = max(0, min(0.9999, halfRange))
        return min(zoneCount - 1, Int(clamped * Double(zoneCount)))
    }

    /// Map a zone index to the actual scale degree via the current progression.
    func degreeForZone(_ zoneIndex: Int) -> Int {
        guard !zoneDegrees.isEmpty else { return 0 }
        let safe = max(0, min(zoneDegrees.count - 1, zoneIndex))
        return zoneDegrees[safe]
    }

    /// Convenience: pinch X → scale degree, going through the progression.
    func xToDegree(_ x: Double) -> Int {
        degreeForZone(xToZoneIndex(x))
    }

    /// Remap raw Vision X into the on-screen visible range [0, 1].
    private func visibleX(_ x: Double) -> Double {
        guard videoAspect > 0, screenAspect > 0 else { return x }
        if videoAspect > screenAspect {
            // Camera is wider than screen → sides are cropped.
            let visibleWidth = Double(screenAspect / videoAspect)
            let offset = (1.0 - visibleWidth) / 2.0
            return (x - offset) / visibleWidth
        }
        return x
    }

    /// Map normalized Y (0..1) to a melody-hand lane index 0..<count.
    /// Higher on screen → higher pitch (note count - 1 at the top).
    func yToMelodyLane(_ y: Double, noteCount: Int) -> Int {
        guard noteCount > 0 else { return 0 }
        let topPad = 0.15
        let bottomPad = 0.20
        let usable = 1.0 - topPad - bottomPad
        let normalized = 1 - max(0, min(1, (y - topPad) / usable))
        return max(0, min(noteCount - 1, Int(normalized * Double(noteCount))))
    }

    /// Map chord-hand Y to a discrete octave shift (-1, 0, +1).
    /// Top third of the screen = +1 octave, middle = 0, bottom third = -1.
    /// Discrete bands keep the pad steady — continuous mapping would jitter
    /// between voicings every frame.
    func yToOctaveShift(_ y: Double) -> Int {
        let clamped = max(0, min(0.9999, y))
        if clamped < 0.33 { return 1 }   // hand high on screen
        if clamped < 0.66 { return 0 }
        return -1                         // hand low on screen
    }

    // MARK: - Tick

    /// Process one frame of hand state and emit chord/melody actions.
    /// `chordTones(forDegree:)` returns the MIDI notes of the chord at that
    /// degree (root/third/fifth, three octaves' worth for the melody hand).
    func tick(
        hands: HandsState,
        chordTones: (Int) -> [Int],
        melodyTones: (Int) -> [Int]
    ) -> [Action] {
        var actions: [Action] = []

        // -------------------- Chord hand (pad + accent) --------------------
        if let h = chordHand(hands) {
            let degree = xToDegree(h.pinchX)
            let octave = yToOctaveShift(h.pinchY)
            currentOctaveShift = octave
            currentChordDegree = degree
            let baseTones = chordTones(degree)
            currentChordMidi = baseTones.map { $0 + octave * 12 }

            if !padOn {
                // First frame of presence — bring the pad up.
                padOn = true
                padDegree = degree
                padOctaveShift = octave
                actions.append(.padOn(midiNotes: currentChordMidi, degree: degree))
            } else if degree != padDegree || octave != padOctaveShift {
                // Hand moved to a new zone or octave — glide the pad.
                padDegree = degree
                padOctaveShift = octave
                actions.append(.padSlide(midiNotes: currentChordMidi, degree: degree))
            }

            // Pinch crossings trigger an additive accent on top of the pad.
            let isPinching = h.pinch > pinchThreshold
            if isPinching && !chordHandPinching {
                chordHandPinching = true
                actions.append(.chordAccent(
                    midiNotes: currentChordMidi,
                    degree: degree,
                    velocity: min(1, h.pinch)
                ))
            } else if h.pinch < releaseThreshold && chordHandPinching {
                chordHandPinching = false
            }
        } else {
            // Hand left the frame — fade the pad out and clear pinch latch.
            if padOn {
                padOn = false
                padDegree = nil
                actions.append(.padOff)
            }
            chordHandPinching = false
        }

        // -------------------- Melody hand --------------------
        // Melody snaps to the *current chord's* tones. If no chord is held
        // yet, fall back to degree 0 so the right hand still makes sound.
        let snapDegree = currentChordDegree ?? 0
        let melodySnapTargets = melodyTones(snapDegree)

        if let h = melodyHand(hands), !melodySnapTargets.isEmpty {
            let laneIdx = yToMelodyLane(h.pinchY, noteCount: melodySnapTargets.count)
            let midi = melodySnapTargets[laneIdx]
            let isPinching = h.pinch > pinchThreshold

            if isPinching && !melodyHandPinching {
                melodyHandPinching = true
                heldMelodyMidi = midi
                actions.append(.melodyOn(
                    hand: melodyHandName,
                    midi: midi,
                    name: midiNoteName(midi),
                    velocity: min(1, h.pinch)
                ))
            } else if isPinching && melodyHandPinching {
                if midi != heldMelodyMidi {
                    heldMelodyMidi = midi
                    actions.append(.melodySlide(
                        hand: melodyHandName,
                        midi: midi,
                        name: midiNoteName(midi)
                    ))
                }
            } else if h.pinch < releaseThreshold && melodyHandPinching {
                melodyHandPinching = false
                heldMelodyMidi = nil
                actions.append(.melodyOff(hand: melodyHandName))
            }
        } else if melodyHandPinching {
            melodyHandPinching = false
            heldMelodyMidi = nil
            actions.append(.melodyOff(hand: melodyHandName))
        }

        return actions
    }

    // Last-known indices, used when the hand briefly leaves the camera frame
    // so the highlight stays parked on whichever side the player drifted off
    // rather than vanishing.
    private var lastChordZoneIndex: Int? = nil
    private var lastMelodyLane: Int? = nil

    /// For UI: current chord zone index (0..<zoneCount, NOT scale degree) and
    /// melody lane. Zone index is what the overlay highlights; the actual
    /// chord degree is resolved via the progression in `zoneDegrees`.
    /// When a hand is out of frame, falls back to the last known value so the
    /// highlight feels "sticky" instead of flickering off.
    func currentZones(hands: HandsState) -> (chordDegree: Int?, melodyLane: Int?) {
        if let h = chordHand(hands) {
            lastChordZoneIndex = xToZoneIndex(h.pinchX)
        }
        if let h = melodyHand(hands) {
            let count = max(currentChordMidi.count, 9)
            lastMelodyLane = yToMelodyLane(h.pinchY, noteCount: count)
        }
        return (lastChordZoneIndex, lastMelodyLane)
    }
}
