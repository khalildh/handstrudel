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
        // Chord hand (left) at the wheel center: sx = 0.25*screenAspect.
        // x*screenAspect == 0.25*screenAspect → x = 0.25; y centered.
        let hands = HandsState(left: makeHand(pinchX: 0.25, pinchY: 0.5), right: nil)
        _ = m.currentZones(hands: hands)
        XCTAssertTrue(m.chordResting, "hand parked in the middle should be resting")
    }

    func testChordHandReachingUp_selectsTopWedge() {
        let m = radialManager()
        // Straight up from center (dx = 0, dyUp > deadzone) → angle 0 → wedge 0.
        let hands = HandsState(left: makeHand(pinchX: 0.25, pinchY: 0.15), right: nil)
        let zones = m.currentZones(hands: hands)
        XCTAssertFalse(m.chordResting, "reaching out of the deadzone is not resting")
        XCTAssertEqual(zones.chordDegree, 0, "12 o'clock selects the first wedge")
    }

    func testMelodyHandInCenter_isResting() {
        let m = radialManager()
        // Melody hand (right) center: sx = 0.75*screenAspect → x = 0.75.
        let hands = HandsState(left: nil, right: makeHand(pinchX: 0.75, pinchY: 0.5))
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
}
