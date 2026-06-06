import XCTest
@testable import HandStrudel

// MARK: - Helpers

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

// MARK: - HandMapper Tests

final class HandMapperTests: XCTestCase {

    // MARK: scaleAxis

    func testScaleAxis_zeroMapsToMin() {
        let result = HandMapper.scaleAxis(raw: 0, paramId: "gain", invert: false)
        XCTAssertEqual(result, 0.03, accuracy: 0.001) // gain min = 0.03
    }

    func testScaleAxis_oneMapsToMax() {
        let result = HandMapper.scaleAxis(raw: 1, paramId: "gain", invert: false)
        XCTAssertEqual(result, 0.9, accuracy: 0.001) // gain max = 0.9
    }

    func testScaleAxis_invertTrue_reverses() {
        let normal = HandMapper.scaleAxis(raw: 0.2, paramId: "gain", invert: false)
        let inverted = HandMapper.scaleAxis(raw: 0.2, paramId: "gain", invert: true)
        let normalAt08 = HandMapper.scaleAxis(raw: 0.8, paramId: "gain", invert: false)
        XCTAssertEqual(inverted, normalAt08, accuracy: 0.001)
    }

    func testScaleAxis_unknownParamId_returnsZero() {
        let result = HandMapper.scaleAxis(raw: 0.5, paramId: "nonexistent", invert: false)
        XCTAssertEqual(result, 0)
    }

    func testScaleAxis_midpoint() {
        let result = HandMapper.scaleAxis(raw: 0.5, paramId: "pan", invert: false)
        // pan: min=0, max=1, so 0.5 should map to 0.5
        XCTAssertEqual(result, 0.5, accuracy: 0.001)
    }

    // MARK: mapHandsToParams

    func testMapHandsToParams_updatesParams() {
        let leftHand = makeHandData(y: 0.5)
        let hands = HandsState(left: leftHand, right: nil)
        var params: MusicParams = [:]
        HandMapper.mapHandsToParams(hands, params: &params, config: DEFAULT_MAPPING)
        // Left y -> noteIdx (inverted), should produce a value
        XCTAssertNotNil(params["noteIdx"])
    }

    func testMapHandsToParams_skipsNoneAndSave() {
        let config = MappingConfig(
            left:  ["y": "none", "x": "save"],
            right: [:]
        )
        let leftHand = makeHandData(x: 0.5, y: 0.5)
        let hands = HandsState(left: leftHand, right: nil)
        var params: MusicParams = [:]
        HandMapper.mapHandsToParams(hands, params: &params, config: config)
        XCTAssertNil(params["none"])
        XCTAssertNil(params["save"])
    }

    func testMapHandsToParams_handlesNilHands() {
        let hands = HandsState(left: nil, right: nil)
        var params: MusicParams = ["gain": 0.5]
        HandMapper.mapHandsToParams(hands, params: &params, config: DEFAULT_MAPPING)
        // Params should remain unchanged
        XCTAssertEqual(params["gain"], 0.5)
    }

    func testMapHandsToParams_bothHands() {
        let leftHand = makeHandData(y: 0.3)
        let rightHand = makeHandData(y: 0.7)
        let hands = HandsState(left: leftHand, right: rightHand)
        var params: MusicParams = [:]
        HandMapper.mapHandsToParams(hands, params: &params, config: DEFAULT_MAPPING)
        XCTAssertNotNil(params["noteIdx"]) // from left y
        XCTAssertNotNil(params["gain"])    // from right y
    }

    func testMapHandsToParams_rightHandMapsCorrectly() {
        let rightHand = makeHandData(x: 1.0)
        let hands = HandsState(left: nil, right: rightHand)
        var params: MusicParams = [:]
        HandMapper.mapHandsToParams(hands, params: &params, config: DEFAULT_MAPPING)
        // Right x -> bpm (inverted x axis), raw=1.0, inverted -> t=0, so bpm = 50 (min)
        XCTAssertNotNil(params["bpm"])
        XCTAssertEqual(params["bpm"]!, 50, accuracy: 1) // min bpm
    }

    // MARK: getSaveAxes

    func testGetSaveAxes_findsSaveMappedAxes() {
        let config = MappingConfig(
            left:  ["y": "noteIdx", "spread": "save"],
            right: ["y": "gain", "x": "save"]
        )
        let axes = HandMapper.getSaveAxes(config)
        XCTAssertEqual(axes.count, 2)
    }

    func testGetSaveAxes_returnsEmptyForNoSave() {
        let axes = HandMapper.getSaveAxes(DEFAULT_MAPPING)
        XCTAssertTrue(axes.isEmpty)
    }

    func testGetSaveAxes_returnsSideAndAxisKey() {
        let config = MappingConfig(
            left:  ["spread": "save"],
            right: [:]
        )
        let axes = HandMapper.getSaveAxes(config)
        XCTAssertEqual(axes.count, 1)
        XCTAssertEqual(axes[0].side, "left")
        XCTAssertEqual(axes[0].axisKey, "spread")
    }

    func testScaleAxis_lpfRange() {
        let min = HandMapper.scaleAxis(raw: 0, paramId: "lpf", invert: false)
        let max = HandMapper.scaleAxis(raw: 1, paramId: "lpf", invert: false)
        XCTAssertEqual(min, 120, accuracy: 0.1)
        XCTAssertEqual(max, 6120, accuracy: 0.1)
    }

    func testScaleAxis_bpmRange() {
        let min = HandMapper.scaleAxis(raw: 0, paramId: "bpm", invert: false)
        let max = HandMapper.scaleAxis(raw: 1, paramId: "bpm", invert: false)
        XCTAssertEqual(min, 50, accuracy: 0.1)
        XCTAssertEqual(max, 205, accuracy: 0.1)
    }
}

// MARK: - ParamSmoother Tests

final class ParamSmootherTests: XCTestCase {

    func testSmooth_sameTargetAndSmoothed_noChange() {
        var smoothed: MusicParams = ["gain": 0.5]
        ParamSmoother.smooth(target: ["gain": 0.5], smoothed: &smoothed)
        XCTAssertEqual(smoothed["gain"]!, 0.5, accuracy: 0.0001)
    }

    func testSmooth_movesTowardTarget() {
        var smoothed: MusicParams = ["gain": 0.0]
        ParamSmoother.smooth(target: ["gain": 1.0], smoothed: &smoothed)
        XCTAssertTrue(smoothed["gain"]! > 0.0)
        XCTAssertTrue(smoothed["gain"]! < 1.0)
    }

    func testSmooth_alphaCreatesIntermediateValue() {
        var smoothed: MusicParams = ["gain": 0.0]
        ParamSmoother.smooth(target: ["gain": 1.0], smoothed: &smoothed)
        // alpha=0.6, so result = 0 + (1-0)*0.6 = 0.6
        XCTAssertEqual(smoothed["gain"]!, 0.6, accuracy: 0.001)
    }

    func testSmooth_newKeyAddsIt() {
        var smoothed: MusicParams = [:]
        ParamSmoother.smooth(target: ["reverb": 0.5], smoothed: &smoothed)
        XCTAssertEqual(smoothed["reverb"], 0.5)
    }

    func testSmooth_convergesOverMultipleIterations() {
        var smoothed: MusicParams = ["gain": 0.0]
        let target: MusicParams = ["gain": 1.0]
        for _ in 0..<20 {
            ParamSmoother.smooth(target: target, smoothed: &smoothed)
        }
        XCTAssertEqual(smoothed["gain"]!, 1.0, accuracy: 0.001)
    }

    func testSmooth_handlesEmptyParams() {
        var smoothed: MusicParams = [:]
        ParamSmoother.smooth(target: [:], smoothed: &smoothed)
        XCTAssertTrue(smoothed.isEmpty)
    }

    func testSmooth_multipleKeys() {
        var smoothed: MusicParams = ["gain": 0.0, "lpf": 1000.0]
        ParamSmoother.smooth(target: ["gain": 1.0, "lpf": 3000.0], smoothed: &smoothed)
        XCTAssertTrue(smoothed["gain"]! > 0.0)
        XCTAssertTrue(smoothed["lpf"]! > 1000.0)
    }

    func testSmooth_doesNotOvershoot() {
        var smoothed: MusicParams = ["gain": 0.0]
        ParamSmoother.smooth(target: ["gain": 1.0], smoothed: &smoothed)
        XCTAssertTrue(smoothed["gain"]! <= 1.0)
    }

    func testSmooth_preservesExistingKeys() {
        var smoothed: MusicParams = ["gain": 0.5, "lpf": 2000]
        ParamSmoother.smooth(target: ["gain": 0.8], smoothed: &smoothed)
        // lpf should still be present (not removed)
        XCTAssertEqual(smoothed["lpf"], 2000)
    }

    func testSmooth_movesCorrectDirection() {
        var smoothedUp: MusicParams = ["gain": 0.3]
        ParamSmoother.smooth(target: ["gain": 0.8], smoothed: &smoothedUp)
        XCTAssertTrue(smoothedUp["gain"]! > 0.3)

        var smoothedDown: MusicParams = ["gain": 0.8]
        ParamSmoother.smooth(target: ["gain": 0.3], smoothed: &smoothedDown)
        XCTAssertTrue(smoothedDown["gain"]! < 0.8)
    }
}

// MARK: - SaveGestureDetector Tests

final class SaveGestureDetectorTests: XCTestCase {

    func testTrigger_firesAboveThreshold() {
        let detector = SaveGestureDetector()
        let config = MappingConfig(left: ["spread": "save"], right: [:])
        let hand = makeHandData(spread: 0.9)
        let hands = HandsState(left: hand, right: nil)
        let result = detector.check(hands: hands, config: config, currentTime: 10.0)
        XCTAssertTrue(result)
    }

    func testNoTrigger_belowThreshold() {
        let detector = SaveGestureDetector()
        let config = MappingConfig(left: ["spread": "save"], right: [:])
        let hand = makeHandData(spread: 0.5)
        let hands = HandsState(left: hand, right: nil)
        let result = detector.check(hands: hands, config: config, currentTime: 10.0)
        XCTAssertFalse(result)
    }

    func testHysteresis_mustDropBelow03ToRearm() {
        let detector = SaveGestureDetector()
        let config = MappingConfig(left: ["spread": "save"], right: [:])

        // First trigger
        let hand1 = makeHandData(spread: 0.9)
        let hands1 = HandsState(left: hand1, right: nil)
        let first = detector.check(hands: hands1, config: config, currentTime: 10.0)
        XCTAssertTrue(first)

        // Try again at 0.7 (above 0.3 re-arm threshold), should not fire even after debounce
        let hand2 = makeHandData(spread: 0.7)
        let hands2 = HandsState(left: hand2, right: nil)
        let second = detector.check(hands: hands2, config: config, currentTime: 12.0)
        XCTAssertFalse(second)

        // Drop below 0.3 to re-arm
        let hand3 = makeHandData(spread: 0.1)
        let hands3 = HandsState(left: hand3, right: nil)
        _ = detector.check(hands: hands3, config: config, currentTime: 13.0)

        // Now trigger again
        let hand4 = makeHandData(spread: 0.9)
        let hands4 = HandsState(left: hand4, right: nil)
        let third = detector.check(hands: hands4, config: config, currentTime: 14.0)
        XCTAssertTrue(third)
    }

    func testDebounce_1secondMinimum() {
        let detector = SaveGestureDetector()
        let config = MappingConfig(left: ["spread": "save"], right: [:])

        // First trigger at t=10
        let hand1 = makeHandData(spread: 0.9)
        let hands1 = HandsState(left: hand1, right: nil)
        let first = detector.check(hands: hands1, config: config, currentTime: 10.0)
        XCTAssertTrue(first)

        // Re-arm
        let handLow = makeHandData(spread: 0.1)
        let handsLow = HandsState(left: handLow, right: nil)
        _ = detector.check(hands: handsLow, config: config, currentTime: 10.2)

        // Try at t=10.5 (< 1s debounce)
        let hand2 = makeHandData(spread: 0.9)
        let hands2 = HandsState(left: hand2, right: nil)
        let second = detector.check(hands: hands2, config: config, currentTime: 10.5)
        XCTAssertFalse(second)
    }

    func testMultipleAxes_triggerIndependently() {
        let detector = SaveGestureDetector()
        let config = MappingConfig(
            left: ["spread": "save"],
            right: ["spread": "save"]
        )
        let leftHand = makeHandData(spread: 0.9)
        let rightHand = makeHandData(spread: 0.1)
        let hands = HandsState(left: leftHand, right: rightHand)
        let result = detector.check(hands: hands, config: config, currentTime: 10.0)
        // Only left should trigger (right is below threshold)
        XCTAssertTrue(result)
    }

    func testNoSaveMapping_neverTriggers() {
        let detector = SaveGestureDetector()
        let hand = makeHandData(spread: 0.9)
        let hands = HandsState(left: hand, right: nil)
        let result = detector.check(hands: hands, config: DEFAULT_MAPPING, currentTime: 10.0)
        XCTAssertFalse(result)
    }

    func testNilHands_noTrigger() {
        let detector = SaveGestureDetector()
        let config = MappingConfig(left: ["spread": "save"], right: [:])
        let hands = HandsState(left: nil, right: nil)
        let result = detector.check(hands: hands, config: config, currentTime: 10.0)
        XCTAssertFalse(result)
    }

    func testTrigger_exactlyAt08_triggers() {
        let detector = SaveGestureDetector()
        let config = MappingConfig(left: ["spread": "save"], right: [:])
        // raw > 0.8 means 0.8 itself does NOT trigger (strict >)
        let hand = makeHandData(spread: 0.8)
        let hands = HandsState(left: hand, right: nil)
        let result = detector.check(hands: hands, config: config, currentTime: 10.0)
        XCTAssertFalse(result, "0.8 exactly should not trigger (threshold is >0.8)")
    }

    func testTrigger_justAbove08_triggers() {
        let detector = SaveGestureDetector()
        let config = MappingConfig(left: ["spread": "save"], right: [:])
        let hand = makeHandData(spread: 0.81)
        let hands = HandsState(left: hand, right: nil)
        let result = detector.check(hands: hands, config: config, currentTime: 10.0)
        XCTAssertTrue(result)
    }

    func testRearm_exactlyAt03_doesNotRearm() {
        let detector = SaveGestureDetector()
        let config = MappingConfig(left: ["spread": "save"], right: [:])

        // Trigger first
        let hand1 = makeHandData(spread: 0.9)
        _ = detector.check(hands: HandsState(left: hand1, right: nil), config: config, currentTime: 10.0)

        // Exactly 0.3 should NOT re-arm (threshold is < 0.3)
        let hand2 = makeHandData(spread: 0.3)
        _ = detector.check(hands: HandsState(left: hand2, right: nil), config: config, currentTime: 10.5)

        // Try to trigger again (should fail since not re-armed)
        let hand3 = makeHandData(spread: 0.9)
        let result = detector.check(hands: HandsState(left: hand3, right: nil), config: config, currentTime: 12.0)
        XCTAssertFalse(result)
    }
}

// MARK: - ChordMelodyModeManager quantize ("sync to beat")

final class ChordMelodyModeManagerQuantizeTests: XCTestCase {

    private let chordTones: (Int) -> [Int] = { _ in [60, 64, 67] }
    private let melodyTones: (Int) -> [Int] = { _ in [60, 64, 67, 72, 76, 79] }

    private func makeManager() -> ChordMelodyModeManager {
        let m = ChordMelodyModeManager()
        // Neutralize aspect-fill cropping so X maps straight through.
        m.videoAspect = 1
        m.screenAspect = 1
        return m
    }

    private func hasMelodyOn(_ actions: [ChordMelodyModeManager.Action]) -> Bool {
        actions.contains { if case .melodyOn = $0 { return true }; return false }
    }
    private func hasChordAccent(_ actions: [ChordMelodyModeManager.Action]) -> Bool {
        actions.contains { if case .chordAccent = $0 { return true }; return false }
    }
    private func hasPadSlide(_ actions: [ChordMelodyModeManager.Action]) -> Bool {
        actions.contains { if case .padSlide = $0 { return true }; return false }
    }

    func testQuantize_melodyWaitsForBoundary() {
        let m = makeManager()
        let chordHand = makeHandData(pinch: 0.0, pinchX: 0.1, pinchY: 0.5)   // left = chords, present
        let melodyHand = makeHandData(pinch: 0.9, pinchY: 0.1)               // right = melody, pinching
        let hands = HandsState(left: chordHand, right: melodyHand)

        let before = m.tick(hands: hands, chordTones: chordTones, melodyTones: melodyTones,
                            quantize: true, gridBoundaryCrossed: false)
        XCTAssertFalse(hasMelodyOn(before), "Melody should not fire before a grid boundary")

        let onBoundary = m.tick(hands: hands, chordTones: chordTones, melodyTones: melodyTones,
                                quantize: true, gridBoundaryCrossed: true)
        XCTAssertTrue(hasMelodyOn(onBoundary), "Melody fires on the grid boundary")
    }

    func testQuantize_melodyReleaseIsImmediate() {
        let m = makeManager()
        let chordHand = makeHandData(pinch: 0.0, pinchX: 0.1, pinchY: 0.5)
        let melodyHand = makeHandData(pinch: 0.9, pinchY: 0.1)
        _ = m.tick(hands: HandsState(left: chordHand, right: melodyHand),
                   chordTones: chordTones, melodyTones: melodyTones,
                   quantize: true, gridBoundaryCrossed: true)

        let released = makeHandData(pinch: 0.1, pinchY: 0.1)
        let actions = m.tick(hands: HandsState(left: chordHand, right: released),
                             chordTones: chordTones, melodyTones: melodyTones,
                             quantize: true, gridBoundaryCrossed: false)
        XCTAssertTrue(actions.contains { if case .melodyOff = $0 { return true }; return false },
                      "Melody note-off should be immediate even when quantized")
    }

    func testQuantize_chordAccentLatchesToBoundary() {
        let m = makeManager()
        let chordPinch = makeHandData(pinch: 0.9, pinchX: 0.1, pinchY: 0.5)  // chord hand pinching
        let hands = HandsState(left: chordPinch, right: nil)

        let before = m.tick(hands: hands, chordTones: chordTones, melodyTones: melodyTones,
                            quantize: true, gridBoundaryCrossed: false)
        XCTAssertFalse(hasChordAccent(before), "Strum accent should wait for a grid boundary")

        let onBoundary = m.tick(hands: hands, chordTones: chordTones, melodyTones: melodyTones,
                                quantize: true, gridBoundaryCrossed: true)
        XCTAssertTrue(hasChordAccent(onBoundary), "Strum accent strikes on the grid boundary")
    }

    func testQuantize_chordChangeWaitsForBoundary() {
        let m = makeManager()
        // Establish the pad at the far-left zone.
        let zoneA = makeHandData(pinch: 0.0, pinchX: 0.05, pinchY: 0.5)
        _ = m.tick(hands: HandsState(left: zoneA, right: nil),
                   chordTones: chordTones, melodyTones: melodyTones,
                   quantize: true, gridBoundaryCrossed: true)

        // Move to the far-right zone (different chord degree).
        let zoneB = makeHandData(pinch: 0.0, pinchX: 0.95, pinchY: 0.5)
        let before = m.tick(hands: HandsState(left: zoneB, right: nil),
                            chordTones: chordTones, melodyTones: melodyTones,
                            quantize: true, gridBoundaryCrossed: false)
        XCTAssertFalse(hasPadSlide(before), "Chord change should hold until the next boundary")

        let onBoundary = m.tick(hands: HandsState(left: zoneB, right: nil),
                                chordTones: chordTones, melodyTones: melodyTones,
                                quantize: true, gridBoundaryCrossed: true)
        XCTAssertTrue(hasPadSlide(onBoundary), "Chord change glides on the boundary")
    }
}
