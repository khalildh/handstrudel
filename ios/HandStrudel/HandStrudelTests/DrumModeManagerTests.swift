import XCTest
@testable import HandStrudel

private func makeHandData(
    x: Double = 0.5, y: Double = 0.5, spread: Double = 0.5,
    pinch: Double = 0.0, pinchX: Double = 0.5, pinchY: Double = 0.5,
    fist: Double = 0.0, rotation: Double = 0.5,
    thumbCurl: Double = 0.5, indexCurl: Double = 0.5, middleCurl: Double = 0.5,
    ringCurl: Double = 0.5, pinkyCurl: Double = 0.5
) -> HandData {
    HandData(
        x: x, y: y, spread: spread,
        pinch: pinch, pinchX: pinchX, pinchY: pinchY,
        fist: fist, rotation: rotation,
        thumbCurl: thumbCurl, indexCurl: indexCurl, middleCurl: middleCurl,
        ringCurl: ringCurl, pinkyCurl: pinkyCurl,
        landmarks: []
    )
}

final class DrumModeManagerTests: XCTestCase {

    // MARK: - allDrums

    func testAllDrums_has6Zones() {
        XCTAssertEqual(DrumModeManager.allDrums.count, 6)
    }

    func testAllDrums_topIsCrash() {
        XCTAssertEqual(DrumModeManager.allDrums.first?.name, "Crash")
        XCTAssertEqual(DrumModeManager.allDrums.first?.hitType, "crash")
    }

    func testAllDrums_bottomIsKick() {
        XCTAssertEqual(DrumModeManager.allDrums.last?.name, "Kick")
        XCTAssertEqual(DrumModeManager.allDrums.last?.hitType, "kick")
    }

    func testAllDrums_orderIsCorrect() {
        let names = DrumModeManager.allDrums.map(\.name)
        XCTAssertEqual(names, ["Crash", "Hi-Hat", "Snare", "Ride", "Tom", "Kick"])
    }

    // MARK: - yToDrumIndex

    func testYToDrumIndex_0_mapsToTopZone() {
        let manager = DrumModeManager()
        let idx = manager.yToDrumIndex(y: 0.0)
        XCTAssertEqual(idx, 0, "y=0.0 should map to top drum (Crash)")
    }

    func testYToDrumIndex_1_mapsToBottomZone() {
        let manager = DrumModeManager()
        let idx = manager.yToDrumIndex(y: 1.0)
        // y=1.0: (1.0 - 0.15) / 0.65 = 0.85/0.65 = 1.307... clamped to 1.0
        // Int(1.0 * 6) = 6, clamped to 5
        XCTAssertEqual(idx, 5, "y=1.0 should map to bottom drum (Kick)")
    }

    func testYToDrumIndex_negativeY_clampedToZero() {
        let manager = DrumModeManager()
        let idx = manager.yToDrumIndex(y: -0.5)
        XCTAssertEqual(idx, 0, "Negative y should clamp to index 0")
    }

    func testYToDrumIndex_yAbove1_clampedToMax() {
        let manager = DrumModeManager()
        let idx = manager.yToDrumIndex(y: 1.5)
        XCTAssertEqual(idx, 5, "y > 1 should clamp to last index")
    }

    func testYToDrumIndex_midRange_returnsMidZone() {
        let manager = DrumModeManager()
        // Usable range: 0.15 to 0.80 (1 - 0.15 - 0.20 = 0.65)
        // Midpoint: 0.15 + 0.65/2 = 0.475
        // normalized = (0.475 - 0.15) / 0.65 = 0.5
        // Int(0.5 * 6) = 3
        let idx = manager.yToDrumIndex(y: 0.475)
        XCTAssertEqual(idx, 3, "Middle y should map to middle zone")
    }

    func testYToDrumIndex_topPadding_stillMapsToZero() {
        let manager = DrumModeManager()
        // y = 0.15 is the start of usable range, normalized = 0
        let idx = manager.yToDrumIndex(y: 0.15)
        XCTAssertEqual(idx, 0, "y at top padding boundary should be zone 0")
    }

    func testYToDrumIndex_allZonesReachable() {
        let manager = DrumModeManager()
        var reachedZones = Set<Int>()
        // Sample many y values to verify all 6 zones are reachable
        for i in 0...100 {
            let y = Double(i) / 100.0
            reachedZones.insert(manager.yToDrumIndex(y: y))
        }
        XCTAssertEqual(reachedZones.count, 6, "All 6 drum zones should be reachable")
    }

    // MARK: - checkHits: pinch trigger

    func testCheckHits_pinchCrossesThreshold_triggersHit() {
        let manager = DrumModeManager()
        let hand = makeHandData(pinch: 0.8, pinchY: 0.5)
        let hands = HandsState(left: hand, right: nil)
        let hits = manager.checkHits(hands: hands, currentTime: 1.0)
        XCTAssertEqual(hits.count, 1)
        XCTAssertEqual(hits.first?.hand, "left")
    }

    func testCheckHits_pinchBelowThreshold_noHit() {
        let manager = DrumModeManager()
        let hand = makeHandData(pinch: 0.5, pinchY: 0.5)
        let hands = HandsState(left: hand, right: nil)
        let hits = manager.checkHits(hands: hands, currentTime: 1.0)
        XCTAssertTrue(hits.isEmpty)
    }

    func testCheckHits_noHands_returnsEmpty() {
        let manager = DrumModeManager()
        let hands = HandsState(left: nil, right: nil)
        let hits = manager.checkHits(hands: hands, currentTime: 1.0)
        XCTAssertTrue(hits.isEmpty)
    }

    // MARK: - checkHits: no re-trigger while still pinching same drum

    func testCheckHits_samePositionStillPinching_noRetrigger() {
        let manager = DrumModeManager()
        // First call: pinch above threshold
        let hand1 = makeHandData(pinch: 0.8, pinchY: 0.5)
        let hands1 = HandsState(left: hand1, right: nil)
        let hits1 = manager.checkHits(hands: hands1, currentTime: 1.0)
        XCTAssertEqual(hits1.count, 1)

        // Second call: still pinching at same position
        let hand2 = makeHandData(pinch: 0.85, pinchY: 0.5)
        let hands2 = HandsState(left: hand2, right: nil)
        let hits2 = manager.checkHits(hands: hands2, currentTime: 1.1)
        XCTAssertTrue(hits2.isEmpty, "Should not re-trigger same drum while still pinching")
    }

    // MARK: - checkHits: re-trigger on moving to new drum while pinching

    func testCheckHits_moveToDifferentDrum_retriggersWhilePinching() {
        let manager = DrumModeManager()
        // First call: pinch at top (Crash zone)
        let hand1 = makeHandData(pinch: 0.8, pinchY: 0.0)
        let hands1 = HandsState(left: hand1, right: nil)
        let hits1 = manager.checkHits(hands: hands1, currentTime: 1.0)
        XCTAssertEqual(hits1.count, 1)
        let firstHitType = hits1.first?.hitType

        // Second call: still pinching but move to bottom (Kick zone)
        let hand2 = makeHandData(pinch: 0.85, pinchY: 1.0)
        let hands2 = HandsState(left: hand2, right: nil)
        let hits2 = manager.checkHits(hands: hands2, currentTime: 1.1)
        XCTAssertEqual(hits2.count, 1, "Should trigger when moving to different drum while still pinching")
        XCTAssertNotEqual(hits2.first?.hitType, firstHitType, "New hit should be a different drum")
    }

    // MARK: - checkHits: release

    func testCheckHits_pinchDropsBelowReleaseThreshold_releasesState() {
        let manager = DrumModeManager()
        // Start pinching
        let hand1 = makeHandData(pinch: 0.8, pinchY: 0.5)
        let hands1 = HandsState(left: hand1, right: nil)
        _ = manager.checkHits(hands: hands1, currentTime: 1.0)

        // Release (below 0.4)
        let hand2 = makeHandData(pinch: 0.3, pinchY: 0.5)
        let hands2 = HandsState(left: hand2, right: nil)
        _ = manager.checkHits(hands: hands2, currentTime: 1.1)

        // Pinch again -- should trigger fresh hit
        let hand3 = makeHandData(pinch: 0.8, pinchY: 0.5)
        let hands3 = HandsState(left: hand3, right: nil)
        let hits3 = manager.checkHits(hands: hands3, currentTime: 1.2)
        XCTAssertEqual(hits3.count, 1, "Should trigger again after release")
    }

    func testCheckHits_pinchInDeadZone_noReleaseNoRetrigger() {
        let manager = DrumModeManager()
        // Start pinching
        let hand1 = makeHandData(pinch: 0.8, pinchY: 0.5)
        let hands1 = HandsState(left: hand1, right: nil)
        _ = manager.checkHits(hands: hands1, currentTime: 1.0)

        // Go to dead zone (between release 0.4 and threshold 0.7)
        let hand2 = makeHandData(pinch: 0.5, pinchY: 0.5)
        let hands2 = HandsState(left: hand2, right: nil)
        _ = manager.checkHits(hands: hands2, currentTime: 1.1)

        // Still in dead zone -- state should not be released yet
        // Pinch above threshold again -- should NOT re-trigger (still considered "pinching")
        // Actually, 0.5 < 0.7 so !isPinching, and 0.5 > 0.4 so doesn't release either
        // So leftPinching stays true, but isPinching is false => no branch executes
        // Try pinching again
        let hand3 = makeHandData(pinch: 0.8, pinchY: 0.5)
        let hands3 = HandsState(left: hand3, right: nil)
        let hits3 = manager.checkHits(hands: hands3, currentTime: 1.2)
        // Since leftPinching is still true (wasn't released), this enters "still pinching" branch
        // Same drum -> no retrigger
        XCTAssertTrue(hits3.isEmpty, "Should not retrigger from dead zone without release")
    }

    // MARK: - checkHits: right hand

    func testCheckHits_rightHand_triggersHit() {
        let manager = DrumModeManager()
        let hand = makeHandData(pinch: 0.8, pinchY: 0.3)
        let hands = HandsState(left: nil, right: hand)
        let hits = manager.checkHits(hands: hands, currentTime: 1.0)
        XCTAssertEqual(hits.count, 1)
        XCTAssertEqual(hits.first?.hand, "right")
    }

    func testCheckHits_bothHands_triggerIndependently() {
        let manager = DrumModeManager()
        let leftHand = makeHandData(pinch: 0.8, pinchY: 0.0)
        let rightHand = makeHandData(pinch: 0.8, pinchY: 1.0)
        let hands = HandsState(left: leftHand, right: rightHand)
        let hits = manager.checkHits(hands: hands, currentTime: 1.0)
        XCTAssertEqual(hits.count, 2)
        let handLabels = Set(hits.map(\.hand))
        XCTAssertTrue(handLabels.contains("left"))
        XCTAssertTrue(handLabels.contains("right"))
    }

    // MARK: - checkHits: hand removal resets state

    func testCheckHits_handRemoved_resetsState() {
        let manager = DrumModeManager()
        // Start pinching with left hand
        let hand1 = makeHandData(pinch: 0.8, pinchY: 0.5)
        let hands1 = HandsState(left: hand1, right: nil)
        _ = manager.checkHits(hands: hands1, currentTime: 1.0)

        // Remove left hand
        let hands2 = HandsState(left: nil, right: nil)
        _ = manager.checkHits(hands: hands2, currentTime: 1.1)

        // Bring hand back and pinch -- should trigger fresh
        let hand3 = makeHandData(pinch: 0.8, pinchY: 0.5)
        let hands3 = HandsState(left: hand3, right: nil)
        let hits3 = manager.checkHits(hands: hands3, currentTime: 1.2)
        XCTAssertEqual(hits3.count, 1, "Should trigger fresh hit after hand was removed and returned")
    }

    // MARK: - currentZones

    func testCurrentZones_noHands_returnsNils() {
        let manager = DrumModeManager()
        let hands = HandsState(left: nil, right: nil)
        // Need to call checkHits first to update lane state
        _ = manager.checkHits(hands: hands, currentTime: 1.0)
        let zones = manager.currentZones(hands: hands)
        XCTAssertNil(zones.left)
        XCTAssertNil(zones.right)
    }

    func testCurrentZones_leftHandPresent_returnsZoneName() {
        let manager = DrumModeManager()
        let hand = makeHandData(pinch: 0.8, pinchY: 0.0) // Top zone = Crash
        let hands = HandsState(left: hand, right: nil)
        _ = manager.checkHits(hands: hands, currentTime: 1.0)
        let zones = manager.currentZones(hands: hands)
        XCTAssertNotNil(zones.left)
        // Should be one of the drum names
        let allNames = DrumModeManager.allDrums.map(\.name)
        XCTAssertTrue(allNames.contains(zones.left!))
    }

    func testCurrentZones_bothHands_returnsBothZoneNames() {
        let manager = DrumModeManager()
        let leftHand = makeHandData(pinch: 0.8, pinchY: 0.0)
        let rightHand = makeHandData(pinch: 0.8, pinchY: 1.0)
        let hands = HandsState(left: leftHand, right: rightHand)
        _ = manager.checkHits(hands: hands, currentTime: 1.0)
        let zones = manager.currentZones(hands: hands)
        XCTAssertNotNil(zones.left)
        XCTAssertNotNil(zones.right)
    }

    // MARK: - Lane tracking properties

    func testLeftLane_updatedByCheckHits() {
        let manager = DrumModeManager()
        XCTAssertNil(manager.leftLane)

        let hand = makeHandData(pinch: 0.8, pinchY: 0.0)
        let hands = HandsState(left: hand, right: nil)
        _ = manager.checkHits(hands: hands, currentTime: 1.0)
        XCTAssertNotNil(manager.leftLane)
    }

    func testRightLane_updatedByCheckHits() {
        let manager = DrumModeManager()
        XCTAssertNil(manager.rightLane)

        let hand = makeHandData(pinch: 0.8, pinchY: 0.5)
        let hands = HandsState(left: nil, right: hand)
        _ = manager.checkHits(hands: hands, currentTime: 1.0)
        XCTAssertNotNil(manager.rightLane)
    }

    func testIsLeftPinching_tracksState() {
        let manager = DrumModeManager()
        XCTAssertFalse(manager.isLeftPinching)

        // Pinch
        let hand = makeHandData(pinch: 0.8, pinchY: 0.5)
        let hands = HandsState(left: hand, right: nil)
        _ = manager.checkHits(hands: hands, currentTime: 1.0)
        XCTAssertTrue(manager.isLeftPinching)

        // Release
        let hand2 = makeHandData(pinch: 0.3, pinchY: 0.5)
        let hands2 = HandsState(left: hand2, right: nil)
        _ = manager.checkHits(hands: hands2, currentTime: 1.1)
        XCTAssertFalse(manager.isLeftPinching)
    }

    func testIsRightPinching_tracksState() {
        let manager = DrumModeManager()
        XCTAssertFalse(manager.isRightPinching)

        let hand = makeHandData(pinch: 0.8, pinchY: 0.5)
        let hands = HandsState(left: nil, right: hand)
        _ = manager.checkHits(hands: hands, currentTime: 1.0)
        XCTAssertTrue(manager.isRightPinching)
    }

    // MARK: - Legacy compat

    func testLeftZones_sameAsAllDrums() {
        XCTAssertEqual(DrumModeManager.leftZones.count, DrumModeManager.allDrums.count)
    }

    func testRightZones_sameAsAllDrums() {
        XCTAssertEqual(DrumModeManager.rightZones.count, DrumModeManager.allDrums.count)
    }

    // MARK: - Hit type matches zone

    func testCheckHits_hitTypeMatchesZoneAtPosition() {
        let manager = DrumModeManager()
        // Pinch at very top -> should be crash
        let hand = makeHandData(pinch: 0.8, pinchY: 0.0)
        let hands = HandsState(left: hand, right: nil)
        let hits = manager.checkHits(hands: hands, currentTime: 1.0)
        XCTAssertEqual(hits.first?.hitType, "crash")
    }

    func testCheckHits_bottomPosition_hitsKick() {
        let manager = DrumModeManager()
        let hand = makeHandData(pinch: 0.8, pinchY: 1.0)
        let hands = HandsState(left: hand, right: nil)
        let hits = manager.checkHits(hands: hands, currentTime: 1.0)
        XCTAssertEqual(hits.first?.hitType, "kick")
    }
}
