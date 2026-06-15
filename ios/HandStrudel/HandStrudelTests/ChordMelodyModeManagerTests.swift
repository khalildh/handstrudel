import XCTest
@testable import HandStrudel

private func makeHand(
    pinchX: Double = 0.5, pinchY: Double = 0.5, pinch: Double = 0.0
) -> HandData {
    HandData(
        x: pinchX, y: pinchY, spread: 0.5,
        pinch: pinch, pinchX: pinchX, pinchY: pinchY,
        fist: 0.0, rotation: 0.5,
        thumbCurl: 0.5, indexCurl: 0.5, middleCurl: 0.5,
        ringCurl: 0.5, pinkyCurl: 0.5,
        landmarks: []
    )
}

/// Tests for the radial layout of the chord+melody manager. The grid layout is
/// exercised indirectly elsewhere; these focus on the wheel mapping and the
/// center "rest" behavior that the radial mode adds.
final class ChordMelodyModeManagerTests: XCTestCase {

    // MARK: - radialWedgeIndex (pure angle → wedge)

    func testRadialWedgeIndex_quadrants() {
        let m = ChordMelodyModeManager()
        XCTAssertEqual(m.radialWedgeIndex(angle: 0, count: 4), 0, "12 o'clock → wedge 0")
        XCTAssertEqual(m.radialWedgeIndex(angle: 90, count: 4), 1, "3 o'clock → wedge 1")
        XCTAssertEqual(m.radialWedgeIndex(angle: 180, count: 4), 2, "6 o'clock → wedge 2")
        XCTAssertEqual(m.radialWedgeIndex(angle: 270, count: 4), 3, "9 o'clock → wedge 3")
    }

    func testRadialWedgeIndex_wedgeZeroIsCenteredOnTop() {
        let m = ChordMelodyModeManager()
        // With 4 wedges (90° each), wedge 0 spans [-45°, 45°] around the top.
        XCTAssertEqual(m.radialWedgeIndex(angle: 44, count: 4), 0)
        XCTAssertEqual(m.radialWedgeIndex(angle: 46, count: 4), 1)
        XCTAssertEqual(m.radialWedgeIndex(angle: 359, count: 4), 0, "just shy of 360 wraps back to top")
    }

    func testRadialWedgeIndex_clampsAndGuards() {
        let m = ChordMelodyModeManager()
        XCTAssertEqual(m.radialWedgeIndex(angle: 0, count: 0), 0, "count 0 is guarded")
        XCTAssertEqual(m.radialWedgeIndex(angle: 720, count: 7), 0, "angle wraps modulo 360")
    }

    // MARK: - Center rest zone

    /// Identity aspect so `visibleX` is a no-op and the math is easy to follow.
    private func radialManager() -> ChordMelodyModeManager {
        let m = ChordMelodyModeManager()
        m.layout = .radial
        m.videoAspect = 0.5
        m.screenAspect = 0.5
        return m
    }

    func testChordHandInCenter_isResting() {
        let m = radialManager()
        // Both hands share one wheel centered on the screen: center is x = 0.5,
        // y = 0.5 regardless of which hand it is.
        let hands = HandsState(left: makeHand(pinchX: 0.5, pinchY: 0.5), right: nil)
        _ = m.currentZones(hands: hands)
        XCTAssertTrue(m.chordResting, "hand parked in the middle should be resting")
    }

    func testChordHandReachingUp_selectsTopWedge() {
        let m = radialManager()
        // Straight up from the shared center (dx = 0, dyUp > deadzone) → angle 0 → wedge 0.
        let hands = HandsState(left: makeHand(pinchX: 0.5, pinchY: 0.1), right: nil)
        let zones = m.currentZones(hands: hands)
        XCTAssertFalse(m.chordResting, "reaching out of the deadzone is not resting")
        XCTAssertEqual(zones.chordDegree, 0, "12 o'clock selects the first wedge")
    }

    func testMelodyHandInCenter_isResting() {
        let m = radialManager()
        let hands = HandsState(left: nil, right: makeHand(pinchX: 0.5, pinchY: 0.5))
        _ = m.currentZones(hands: hands)
        XCTAssertTrue(m.melodyResting, "melody hand parked in the middle should be resting")
    }

    func testGridLayout_neverRests() {
        let m = ChordMelodyModeManager()
        m.layout = .grid
        m.videoAspect = 0.5
        m.screenAspect = 0.5
        let hands = HandsState(left: makeHand(pinchX: 0.25, pinchY: 0.5),
                               right: makeHand(pinchX: 0.75, pinchY: 0.5))
        _ = m.currentZones(hands: hands)
        XCTAssertFalse(m.chordResting)
        XCTAssertFalse(m.melodyResting)
    }

    // MARK: - splitWedgeIndex (angle → wedge per semicircle)

    /// Left semicircle covers angles [180°, 360°). The arc fans from top
    /// (angle ~360°) at wedge 0 down through 9 o'clock to the bottom (angle
    /// 180°) at wedge `count-1`. Angles outside that range should return nil
    /// so the caller can treat the touch as resting / on the other half.
    func testSplitWedgeIndex_leftSide_topToBottom() {
        let m = ChordMelodyModeManager()
        m.zoneDegrees = [0, 1, 2, 3]   // count = 4 → 45° wedges
        XCTAssertEqual(m.splitWedgeIndex(side: .left, angle: 359, count: 4), 0,
                       "just shy of top of left arc lands in the first wedge")
        XCTAssertEqual(m.splitWedgeIndex(side: .left, angle: 270, count: 4), 2,
                       "9 o'clock is halfway down the left arc")
        XCTAssertEqual(m.splitWedgeIndex(side: .left, angle: 180, count: 4), 3,
                       "bottom of left arc clamps to the last wedge")
    }

    func testSplitWedgeIndex_rightSide_topToBottom() {
        let m = ChordMelodyModeManager()
        XCTAssertEqual(m.splitWedgeIndex(side: .right, angle: 0, count: 4), 0,
                       "12 o'clock on the right arc is the first wedge")
        XCTAssertEqual(m.splitWedgeIndex(side: .right, angle: 90, count: 4), 2,
                       "3 o'clock is halfway down the right arc")
        XCTAssertEqual(m.splitWedgeIndex(side: .right, angle: 179, count: 4), 3,
                       "just shy of the bottom on the right arc is the last wedge")
    }

    /// Each side is supposed to refuse to interpret angles on the other half,
    /// so the touch overlay can treat a chord hand that strayed into the
    /// melody half as "resting" rather than poaching the wrong wedge.
    func testSplitWedgeIndex_wrongHalf_returnsNil() {
        let m = ChordMelodyModeManager()
        XCTAssertNil(m.splitWedgeIndex(side: .left, angle: 0, count: 4),
                     "12 o'clock isn't on the left half")
        XCTAssertNil(m.splitWedgeIndex(side: .left, angle: 90, count: 4),
                     "3 o'clock isn't on the left half")
        XCTAssertNil(m.splitWedgeIndex(side: .right, angle: 270, count: 4),
                     "9 o'clock isn't on the right half")
        XCTAssertNil(m.splitWedgeIndex(side: .right, angle: 200, count: 4),
                     "below 6 o'clock isn't on the right half either")
    }

    func testSplitWedgeIndex_countZero_returnsNil() {
        let m = ChordMelodyModeManager()
        XCTAssertNil(m.splitWedgeIndex(side: .left, angle: 270, count: 0))
        XCTAssertNil(m.splitWedgeIndex(side: .right, angle: 90, count: 0))
    }

    // MARK: - splitOctaveShift (radial band → ±1 octave)

    /// Inside the inner band (radius < `splitOctaveBandThreshold`) the chord
    /// always plays at the base octave, no matter where in the wedge the
    /// hand is.
    func testSplitOctaveShift_innerBand_isZero() {
        let m = ChordMelodyModeManager()
        m.zoneDegrees = [0, 1, 2, 3]
        XCTAssertEqual(m.splitOctaveShift(side: .left, angle: 270, radius: 0.5, wedgeIndex: 2), 0)
        XCTAssertEqual(m.splitOctaveShift(side: .right, angle: 90, radius: 0.5, wedgeIndex: 2), 0)
    }

    /// The earlier bug: the +1 octave half should always be the angular half
    /// *closer to the top of the arc*, not "the angularly-leading half" as the
    /// visual once rendered it. On the left arc, "closer to top" = larger
    /// angle (because the arc goes counter-clockwise from 360° down to 180°);
    /// on the right arc it's the opposite. Both directions should produce the
    /// same `+1 = up, −1 = down` result.
    func testSplitOctaveShift_leftSide_closerToTopOfArc_isPlusOne() {
        let m = ChordMelodyModeManager()
        m.zoneDegrees = [0, 1, 2, 3]   // 4 wedges → wedge 0 spans [315°, 360°)
        // angle 350° sits in the top half of wedge 0 (closer to 360° = top of arc).
        XCTAssertEqual(m.splitOctaveShift(side: .left, angle: 350, radius: 0.9, wedgeIndex: 0), 1)
        // angle 320° sits in the bottom half of wedge 0 (closer to 9 o'clock).
        XCTAssertEqual(m.splitOctaveShift(side: .left, angle: 320, radius: 0.9, wedgeIndex: 0), -1)
    }

    func testSplitOctaveShift_rightSide_closerToTopOfArc_isPlusOne() {
        let m = ChordMelodyModeManager()
        m.zoneDegrees = [0, 1, 2, 3]   // wedge 0 spans [0°, 45°)
        // angle 10° is the top half of wedge 0 (closer to 12 o'clock = top).
        XCTAssertEqual(m.splitOctaveShift(side: .right, angle: 10, radius: 0.9, wedgeIndex: 0), 1)
        // angle 40° is the bottom half of wedge 0 (closer to 3 o'clock).
        XCTAssertEqual(m.splitOctaveShift(side: .right, angle: 40, radius: 0.9, wedgeIndex: 0), -1)
    }

    /// The same check applied to a middle wedge — guards against off-by-one
    /// in the wedge-relative offset math.
    func testSplitOctaveShift_middleWedge_bothSides() {
        let m = ChordMelodyModeManager()
        m.zoneDegrees = [0, 1, 2, 3]
        // Left, wedge 2 spans [225°, 270°). 265° is the top half (closer to 360°).
        XCTAssertEqual(m.splitOctaveShift(side: .left, angle: 265, radius: 0.9, wedgeIndex: 2), 1)
        XCTAssertEqual(m.splitOctaveShift(side: .left, angle: 230, radius: 0.9, wedgeIndex: 2), -1)
        // Right, wedge 2 spans [90°, 135°). 95° is the top half (closer to 0°).
        XCTAssertEqual(m.splitOctaveShift(side: .right, angle: 95, radius: 0.9, wedgeIndex: 2), 1)
        XCTAssertEqual(m.splitOctaveShift(side: .right, angle: 130, radius: 0.9, wedgeIndex: 2), -1)
    }

    // MARK: - Touch override (Split mode)

    /// ContentView sets `touchChordDegree` etc. when a finger is held on a
    /// chord wedge. The manager's `tick` should pull those into the published
    /// chord state even when no chord hand is in frame — otherwise the
    /// camera-tracked melody hand never sees the touched chord and the wheel
    /// labels stay stale (the bug spotted in the bottom-of-sheet PR).
    func testTouchOverride_withoutChordHand_setsPublishedChordState() {
        let m = ChordMelodyModeManager()
        m.zoneDegrees = [0, 4, 5, 3]
        m.touchChordDegree = 4
        m.touchChordOctave = 1
        m.touchChordMidi = [67, 71, 74]
        _ = m.tick(
            hands: HandsState(left: nil, right: nil),
            chordTones: { _ in [60, 64, 67] },
            melodyTones: { _ in [60, 64, 67] }
        )
        XCTAssertEqual(m.currentChordDegree, 4)
        XCTAssertEqual(m.currentChordMidi, [67, 71, 74])
        XCTAssertEqual(m.currentOctaveShift, 1,
                       "touched octave should reach the published octave indicator")
        XCTAssertFalse(m.chordResting,
                       "touch override should never read as resting")
    }

    /// When the override is cleared, the manager keeps the last published
    /// values around (no chord hand to overwrite them with), so a user who
    /// lifts their finger doesn't suddenly lose the inner-ring labels.
    func testTouchOverride_cleared_stateLingers() {
        let m = ChordMelodyModeManager()
        m.zoneDegrees = [0, 1, 2, 3]
        m.touchChordDegree = 2
        m.touchChordMidi = [62, 65, 69]
        _ = m.tick(
            hands: HandsState(left: nil, right: nil),
            chordTones: { _ in [60, 64, 67] },
            melodyTones: { _ in [60, 64, 67] }
        )
        XCTAssertEqual(m.currentChordDegree, 2)

        m.touchChordDegree = nil
        m.touchChordMidi = []
        _ = m.tick(
            hands: HandsState(left: nil, right: nil),
            chordTones: { _ in [60, 64, 67] },
            melodyTones: { _ in [60, 64, 67] }
        )
        XCTAssertEqual(m.currentChordDegree, 2,
                       "no chord hand + override cleared = last value sticks")
    }
}
