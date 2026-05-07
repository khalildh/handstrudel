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

final class GridModeManagerTests: XCTestCase {

    // MARK: - yToNoteIndex

    func testYToNoteIndex_topPosition_returnsHighIndex() {
        let manager = GridModeManager()
        // y=0.0 is top; normalized = 1 - max(0, min(1, (0 - 0.15)/0.65))
        // (0 - 0.15)/0.65 = negative, clamped to 0, so normalized = 1 - 0 = 1
        // Int(1.0 * noteCount) clamped to noteCount - 1
        let idx = manager.yToNoteIndex(y: 0.0, noteCount: 14)
        XCTAssertEqual(idx, 13, "y=0 (top of screen) should map to highest note index")
    }

    func testYToNoteIndex_bottomPosition_returnsLowIndex() {
        let manager = GridModeManager()
        // y=1.0 is bottom; (1.0 - 0.15)/0.65 = 1.307... clamped to 1, normalized = 1 - 1 = 0
        let idx = manager.yToNoteIndex(y: 1.0, noteCount: 14)
        XCTAssertEqual(idx, 0, "y=1.0 (bottom) should map to lowest note index")
    }

    func testYToNoteIndex_midRange_returnsMidIndex() {
        let manager = GridModeManager()
        // Usable range: 0.15 to 0.80 (height = 0.65)
        // Mid y = 0.475, normalized = 1 - 0.5 = 0.5
        // Int(0.5 * 14) = 7
        let idx = manager.yToNoteIndex(y: 0.475, noteCount: 14)
        XCTAssertEqual(idx, 7)
    }

    func testYToNoteIndex_zeroNoteCount_returnsZero() {
        let manager = GridModeManager()
        let idx = manager.yToNoteIndex(y: 0.5, noteCount: 0)
        XCTAssertEqual(idx, 0)
    }

    func testYToNoteIndex_singleNote_alwaysReturnsZero() {
        let manager = GridModeManager()
        XCTAssertEqual(manager.yToNoteIndex(y: 0.0, noteCount: 1), 0)
        XCTAssertEqual(manager.yToNoteIndex(y: 0.5, noteCount: 1), 0)
        XCTAssertEqual(manager.yToNoteIndex(y: 1.0, noteCount: 1), 0)
    }

    func testYToNoteIndex_negativeY_clampedToMax() {
        let manager = GridModeManager()
        let idx = manager.yToNoteIndex(y: -1.0, noteCount: 14)
        XCTAssertEqual(idx, 13, "Negative y should clamp to highest index (inverted)")
    }

    func testYToNoteIndex_yAboveOne_clampedToMin() {
        let manager = GridModeManager()
        let idx = manager.yToNoteIndex(y: 2.0, noteCount: 14)
        XCTAssertEqual(idx, 0, "y > 1 should clamp to lowest index")
    }

    func testYToNoteIndex_allNotesReachable() {
        let manager = GridModeManager()
        let noteCount = 7
        var reachedNotes = Set<Int>()
        for i in 0...200 {
            let y = Double(i) / 200.0
            reachedNotes.insert(manager.yToNoteIndex(y: y, noteCount: noteCount))
        }
        XCTAssertEqual(reachedNotes.count, noteCount, "All \(noteCount) notes should be reachable")
    }

    // MARK: - checkNotes: note on

    func testCheckNotes_pinchAboveThreshold_triggersNoteOn() {
        let manager = GridModeManager()
        let notes = scaleNotes(key: .C, scale: .major, baseOctave: 3, octaveRange: 2)
        let hand = makeHandData(pinch: 0.9, pinchY: 0.5)
        let hands = HandsState(left: hand, right: nil)
        let actions = manager.checkNotes(hands: hands, scaleNotes: notes, currentBeat: 0)

        XCTAssertEqual(actions.count, 1)
        if case .noteOn(let hand, let midi, _, _) = actions.first {
            XCTAssertEqual(hand, "left")
            XCTAssertTrue(notes.contains(midi))
        } else {
            XCTFail("Expected noteOn action")
        }
    }

    func testCheckNotes_pinchBelowThreshold_noAction() {
        let manager = GridModeManager()
        let notes = scaleNotes(key: .C, scale: .major, baseOctave: 3, octaveRange: 2)
        let hand = makeHandData(pinch: 0.3, pinchY: 0.5)
        let hands = HandsState(left: hand, right: nil)
        let actions = manager.checkNotes(hands: hands, scaleNotes: notes, currentBeat: 0)
        XCTAssertTrue(actions.isEmpty)
    }

    func testCheckNotes_emptyScaleNotes_returnsNoActions() {
        let manager = GridModeManager()
        let hand = makeHandData(pinch: 0.9, pinchY: 0.5)
        let hands = HandsState(left: hand, right: nil)
        let actions = manager.checkNotes(hands: hands, scaleNotes: [], currentBeat: 0)
        XCTAssertTrue(actions.isEmpty)
    }

    // MARK: - checkNotes: note off

    func testCheckNotes_releasePinch_triggersNoteOff() {
        let manager = GridModeManager()
        let notes = scaleNotes(key: .C, scale: .major, baseOctave: 3, octaveRange: 2)

        // First: pinch to trigger note on
        let hand1 = makeHandData(pinch: 0.9, pinchY: 0.5)
        let hands1 = HandsState(left: hand1, right: nil)
        _ = manager.checkNotes(hands: hands1, scaleNotes: notes, currentBeat: 0)

        // Release below threshold
        let hand2 = makeHandData(pinch: 0.3, pinchY: 0.5)
        let hands2 = HandsState(left: hand2, right: nil)
        let actions = manager.checkNotes(hands: hands2, scaleNotes: notes, currentBeat: 1)

        XCTAssertEqual(actions.count, 1)
        if case .noteOff(let hand) = actions.first {
            XCTAssertEqual(hand, "left")
        } else {
            XCTFail("Expected noteOff action")
        }
    }

    func testCheckNotes_handRemoved_triggersNoteOff() {
        let manager = GridModeManager()
        let notes = scaleNotes(key: .C, scale: .major, baseOctave: 3, octaveRange: 2)

        // Pinch to start note
        let hand = makeHandData(pinch: 0.9, pinchY: 0.5)
        let hands1 = HandsState(left: hand, right: nil)
        _ = manager.checkNotes(hands: hands1, scaleNotes: notes, currentBeat: 0)

        // Remove hand
        let hands2 = HandsState(left: nil, right: nil)
        let actions = manager.checkNotes(hands: hands2, scaleNotes: notes, currentBeat: 1)

        XCTAssertEqual(actions.count, 1)
        if case .noteOff(let hand) = actions.first {
            XCTAssertEqual(hand, "left")
        } else {
            XCTFail("Expected noteOff when hand removed")
        }
    }

    // MARK: - checkNotes: slide

    func testCheckNotes_moveToDifferentNote_triggersSlide() {
        let manager = GridModeManager()
        let notes = scaleNotes(key: .C, scale: .major, baseOctave: 3, octaveRange: 2)

        // Start pinching at top
        let hand1 = makeHandData(pinch: 0.9, pinchY: 0.0)
        let hands1 = HandsState(left: hand1, right: nil)
        let actions1 = manager.checkNotes(hands: hands1, scaleNotes: notes, currentBeat: 0)
        XCTAssertEqual(actions1.count, 1)

        // Move to bottom while still pinching
        let hand2 = makeHandData(pinch: 0.9, pinchY: 1.0)
        let hands2 = HandsState(left: hand2, right: nil)
        let actions2 = manager.checkNotes(hands: hands2, scaleNotes: notes, currentBeat: 1)

        XCTAssertEqual(actions2.count, 1)
        if case .slide(let hand, _, _) = actions2.first {
            XCTAssertEqual(hand, "left")
        } else {
            XCTFail("Expected slide action when moving to different note while pinching")
        }
    }

    func testCheckNotes_stayOnSameNote_noSlide() {
        let manager = GridModeManager()
        let notes = scaleNotes(key: .C, scale: .major, baseOctave: 3, octaveRange: 2)

        // Pinch
        let hand1 = makeHandData(pinch: 0.9, pinchY: 0.5)
        let hands1 = HandsState(left: hand1, right: nil)
        _ = manager.checkNotes(hands: hands1, scaleNotes: notes, currentBeat: 0)

        // Same position, still pinching
        let hand2 = makeHandData(pinch: 0.85, pinchY: 0.5)
        let hands2 = HandsState(left: hand2, right: nil)
        let actions2 = manager.checkNotes(hands: hands2, scaleNotes: notes, currentBeat: 1)
        XCTAssertTrue(actions2.isEmpty, "No action when staying on same note")
    }

    // MARK: - checkNotes: held note tracking per hand

    func testCheckNotes_leftAndRightIndependent() {
        let manager = GridModeManager()
        let notes = scaleNotes(key: .C, scale: .major, baseOctave: 3, octaveRange: 2)

        // Both hands pinch at different positions
        let leftHand = makeHandData(pinch: 0.9, pinchY: 0.0)
        let rightHand = makeHandData(pinch: 0.9, pinchY: 1.0)
        let hands = HandsState(left: leftHand, right: rightHand)
        let actions = manager.checkNotes(hands: hands, scaleNotes: notes, currentBeat: 0)

        XCTAssertEqual(actions.count, 2)
        let handLabels = actions.compactMap { action -> String? in
            switch action {
            case .noteOn(let hand, _, _, _): return hand
            default: return nil
            }
        }
        XCTAssertTrue(handLabels.contains("left"))
        XCTAssertTrue(handLabels.contains("right"))
    }

    func testCheckNotes_releaseLeftKeepRight() {
        let manager = GridModeManager()
        let notes = scaleNotes(key: .C, scale: .major, baseOctave: 3, octaveRange: 2)

        // Both pinch
        let leftHand = makeHandData(pinch: 0.9, pinchY: 0.3)
        let rightHand = makeHandData(pinch: 0.9, pinchY: 0.7)
        let hands1 = HandsState(left: leftHand, right: rightHand)
        _ = manager.checkNotes(hands: hands1, scaleNotes: notes, currentBeat: 0)

        // Release left, keep right
        let leftReleased = makeHandData(pinch: 0.2, pinchY: 0.3)
        let hands2 = HandsState(left: leftReleased, right: rightHand)
        let actions = manager.checkNotes(hands: hands2, scaleNotes: notes, currentBeat: 1)

        // Should get noteOff for left only, no action for right (still holding same note)
        XCTAssertEqual(actions.count, 1)
        if case .noteOff(let hand) = actions.first {
            XCTAssertEqual(hand, "left")
        } else {
            XCTFail("Expected noteOff for left hand only")
        }
    }

    // MARK: - checkNotes: no hands

    func testCheckNotes_noHands_noActions() {
        let manager = GridModeManager()
        let notes = scaleNotes(key: .C, scale: .major, baseOctave: 3, octaveRange: 2)
        let hands = HandsState(left: nil, right: nil)
        let actions = manager.checkNotes(hands: hands, scaleNotes: notes, currentBeat: 0)
        XCTAssertTrue(actions.isEmpty)
    }

    func testCheckNotes_noHandsAfterPinch_triggersNoteOffForBoth() {
        let manager = GridModeManager()
        let notes = scaleNotes(key: .C, scale: .major, baseOctave: 3, octaveRange: 2)

        // Both hands pinch
        let leftHand = makeHandData(pinch: 0.9, pinchY: 0.3)
        let rightHand = makeHandData(pinch: 0.9, pinchY: 0.7)
        let hands1 = HandsState(left: leftHand, right: rightHand)
        _ = manager.checkNotes(hands: hands1, scaleNotes: notes, currentBeat: 0)

        // Both hands disappear
        let hands2 = HandsState(left: nil, right: nil)
        let actions = manager.checkNotes(hands: hands2, scaleNotes: notes, currentBeat: 1)

        XCTAssertEqual(actions.count, 2)
        let offHands = actions.compactMap { action -> String? in
            if case .noteOff(let hand) = action { return hand }
            return nil
        }
        XCTAssertTrue(offHands.contains("left"))
        XCTAssertTrue(offHands.contains("right"))
    }

    // MARK: - checkNotes: velocity

    func testCheckNotes_noteOn_velocityClampedToOne() {
        let manager = GridModeManager()
        let notes = scaleNotes(key: .C, scale: .major, baseOctave: 3, octaveRange: 2)

        // Pinch > 1.0 (hypothetical)
        let hand = makeHandData(pinch: 1.5, pinchY: 0.5)
        let hands = HandsState(left: hand, right: nil)
        let actions = manager.checkNotes(hands: hands, scaleNotes: notes, currentBeat: 0)

        if case .noteOn(_, _, _, let velocity) = actions.first {
            XCTAssertLessThanOrEqual(velocity, 1.0)
        } else {
            XCTFail("Expected noteOn action")
        }
    }

    // MARK: - currentLanes

    func testCurrentLanes_noHands_returnsNils() {
        let manager = GridModeManager()
        let notes = scaleNotes(key: .C, scale: .major, baseOctave: 3, octaveRange: 2)
        let hands = HandsState(left: nil, right: nil)
        let lanes = manager.currentLanes(hands: hands, scaleNotes: notes)
        XCTAssertNil(lanes.left)
        XCTAssertNil(lanes.right)
    }

    func testCurrentLanes_withHands_returnsIndices() {
        let manager = GridModeManager()
        let notes = scaleNotes(key: .C, scale: .major, baseOctave: 3, octaveRange: 2)
        let leftHand = makeHandData(pinchY: 0.3)
        let rightHand = makeHandData(pinchY: 0.7)
        let hands = HandsState(left: leftHand, right: rightHand)
        let lanes = manager.currentLanes(hands: hands, scaleNotes: notes)
        XCTAssertNotNil(lanes.left)
        XCTAssertNotNil(lanes.right)
        // Left y=0.3 is near top, right y=0.7 is near bottom
        XCTAssertTrue(lanes.left! > lanes.right!, "Higher y (lower on screen) -> lower index")
    }

    func testCurrentLanes_emptyScaleNotes_returnsNils() {
        let manager = GridModeManager()
        let leftHand = makeHandData(pinchY: 0.5)
        let hands = HandsState(left: leftHand, right: nil)
        let lanes = manager.currentLanes(hands: hands, scaleNotes: [])
        XCTAssertNil(lanes.left)
        XCTAssertNil(lanes.right)
    }

    // MARK: - Pinching state properties

    func testIsLeftPinching_initiallyFalse() {
        let manager = GridModeManager()
        XCTAssertFalse(manager.isLeftPinching)
    }

    func testIsRightPinching_initiallyFalse() {
        let manager = GridModeManager()
        XCTAssertFalse(manager.isRightPinching)
    }

    func testIsLeftPinching_trueAfterPinch() {
        let manager = GridModeManager()
        let notes = scaleNotes(key: .C, scale: .major, baseOctave: 3, octaveRange: 2)
        let hand = makeHandData(pinch: 0.9, pinchY: 0.5)
        let hands = HandsState(left: hand, right: nil)
        _ = manager.checkNotes(hands: hands, scaleNotes: notes, currentBeat: 0)
        XCTAssertTrue(manager.isLeftPinching)
    }

    func testIsLeftPinching_falseAfterRelease() {
        let manager = GridModeManager()
        let notes = scaleNotes(key: .C, scale: .major, baseOctave: 3, octaveRange: 2)

        // Pinch
        let hand1 = makeHandData(pinch: 0.9, pinchY: 0.5)
        _ = manager.checkNotes(hands: HandsState(left: hand1, right: nil), scaleNotes: notes, currentBeat: 0)

        // Release
        let hand2 = makeHandData(pinch: 0.3, pinchY: 0.5)
        _ = manager.checkNotes(hands: HandsState(left: hand2, right: nil), scaleNotes: notes, currentBeat: 1)
        XCTAssertFalse(manager.isLeftPinching)
    }
}
