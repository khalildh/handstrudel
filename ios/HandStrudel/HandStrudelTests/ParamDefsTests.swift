import XCTest
@testable import HandStrudel

final class ParamDefsTests: XCTestCase {

    // MARK: - buildDefaultParams

    func testBuildDefaultParams_returnsCorrectDefaults_defaultMapping() {
        let params = buildDefaultParams(DEFAULT_MAPPING)
        // DEFAULT_MAPPING uses: noteIdx, lpf, reverb (left), gain, bpm, delay (right)
        XCTAssertEqual(params["noteIdx"], 10)
        XCTAssertEqual(params["lpf"], 3000)
        XCTAssertEqual(params["reverb"], 0.2)
        XCTAssertEqual(params["gain"], 0.55)
        XCTAssertEqual(params["bpm"], 120)
        XCTAssertEqual(params["delay"], 0.12)
    }

    func testBuildDefaultParams_onlyIncludesMappedParams() {
        let config = MappingConfig(
            left:  ["y": "noteIdx", "x": "lpf"],
            right: ["y": "gain"]
        )
        let params = buildDefaultParams(config)
        XCTAssertNotNil(params["noteIdx"])
        XCTAssertNotNil(params["lpf"])
        XCTAssertNotNil(params["gain"])
        // These are not in the config
        XCTAssertNil(params["reverb"])
        XCTAssertNil(params["delay"])
        XCTAssertNil(params["crush"])
    }

    func testBuildDefaultParams_ignoresNoneAndSave() {
        let config = MappingConfig(
            left:  ["y": "none", "x": "save"],
            right: ["y": "gain"]
        )
        let params = buildDefaultParams(config)
        XCTAssertNil(params["none"])
        XCTAssertNil(params["save"])
        XCTAssertNotNil(params["gain"])
    }

    func testBuildDefaultParams_valuesMatchParamDefaults() {
        let config = MappingConfig(
            left:  ["y": "noteIdx", "x": "crush", "spread": "shape"],
            right: ["y": "pan", "x": "attack", "spread": "release"]
        )
        let params = buildDefaultParams(config)
        XCTAssertEqual(params["noteIdx"], 10)
        XCTAssertEqual(params["crush"], 8)
        XCTAssertEqual(params["shape"], 0)
        XCTAssertEqual(params["pan"], 0.5)
        XCTAssertEqual(params["attack"], 0.01)
        XCTAssertEqual(params["release"], 0.1)
    }

    // MARK: - extraParamIds

    func testExtraParamIds_excludesNoteIdx() {
        let config = MappingConfig(
            left:  ["y": "noteIdx", "x": "lpf"],
            right: ["y": "gain", "x": "bpm"]
        )
        let extras = extraParamIds(config)
        XCTAssertFalse(extras.contains("noteIdx"))
    }

    func testExtraParamIds_excludesBpm() {
        let config = MappingConfig(
            left:  ["y": "noteIdx", "x": "lpf"],
            right: ["y": "gain", "x": "bpm"]
        )
        let extras = extraParamIds(config)
        XCTAssertFalse(extras.contains("bpm"))
    }

    func testExtraParamIds_excludesNone() {
        let config = MappingConfig(
            left:  ["y": "none", "x": "lpf"],
            right: ["y": "gain"]
        )
        let extras = extraParamIds(config)
        XCTAssertFalse(extras.contains("none"))
    }

    func testExtraParamIds_excludesSave() {
        let config = MappingConfig(
            left:  ["y": "save", "x": "lpf"],
            right: ["y": "gain"]
        )
        let extras = extraParamIds(config)
        XCTAssertFalse(extras.contains("save"))
    }

    func testExtraParamIds_isSorted() {
        let extras = extraParamIds(DEFAULT_MAPPING)
        XCTAssertEqual(extras, extras.sorted())
    }

    func testExtraParamIds_defaultMapping_containsExpected() {
        let extras = extraParamIds(DEFAULT_MAPPING)
        // DEFAULT_MAPPING: noteIdx, lpf, reverb, gain, bpm, delay
        // After removing noteIdx and bpm: delay, gain, lpf, reverb (sorted)
        XCTAssertTrue(extras.contains("delay"))
        XCTAssertTrue(extras.contains("gain"))
        XCTAssertTrue(extras.contains("lpf"))
        XCTAssertTrue(extras.contains("reverb"))
    }

    // MARK: - buildCode

    func testBuildCode_producesValidStrudelCode() {
        let params = buildDefaultParams(DEFAULT_MAPPING)
        let code = buildCode(params, structIdx: 0, config: DEFAULT_MAPPING)
        XCTAssertTrue(code.contains("note("))
        XCTAssertTrue(code.contains(".s(\"sawtooth\")"))
        XCTAssertTrue(code.contains(".struct("))
        XCTAssertTrue(code.contains(".cpm("))
    }

    func testBuildCode_withSawtoothWaveform() {
        let params = buildDefaultParams(DEFAULT_MAPPING)
        let code = buildCode(params, structIdx: 0, config: DEFAULT_MAPPING, waveform: "sawtooth")
        XCTAssertTrue(code.contains(".s(\"sawtooth\")"))
    }

    func testBuildCode_withSquareWaveform() {
        let params = buildDefaultParams(DEFAULT_MAPPING)
        let code = buildCode(params, structIdx: 0, config: DEFAULT_MAPPING, waveform: "square")
        XCTAssertTrue(code.contains(".s(\"square\")"))
    }

    func testBuildCode_withTriangleWaveform() {
        let params = buildDefaultParams(DEFAULT_MAPPING)
        let code = buildCode(params, structIdx: 0, config: DEFAULT_MAPPING, waveform: "triangle")
        XCTAssertTrue(code.contains(".s(\"triangle\")"))
    }

    func testBuildCode_withSineWaveform() {
        let params = buildDefaultParams(DEFAULT_MAPPING)
        let code = buildCode(params, structIdx: 0, config: DEFAULT_MAPPING, waveform: "sine")
        XCTAssertTrue(code.contains(".s(\"sine\")"))
    }

    func testBuildCode_includesCorrectStruct() {
        let params = buildDefaultParams(DEFAULT_MAPPING)
        for i in 0..<STRUCTS.count {
            let code = buildCode(params, structIdx: i, config: DEFAULT_MAPPING)
            XCTAssertTrue(code.contains(".struct(\"\(STRUCTS[i])\")"),
                          "structIdx \(i) should produce struct \(STRUCTS[i])")
        }
    }

    func testBuildCode_structIdx_clampsNegativeToZero() {
        let params = buildDefaultParams(DEFAULT_MAPPING)
        let code = buildCode(params, structIdx: -1, config: DEFAULT_MAPPING)
        XCTAssertTrue(code.contains(".struct(\"\(STRUCTS[0])\")"))
    }

    func testBuildCode_structIdx_clampsAboveMaxToMax() {
        let params = buildDefaultParams(DEFAULT_MAPPING)
        let code = buildCode(params, structIdx: 100, config: DEFAULT_MAPPING)
        XCTAssertTrue(code.contains(".struct(\"\(STRUCTS[STRUCTS.count - 1])\")"))
    }

    func testBuildCode_noteIdx_clampsToValidRange() {
        var params: MusicParams = ["noteIdx": -5, "bpm": 120]
        let code = buildCode(params, structIdx: 0, config: DEFAULT_MAPPING)
        // Should use NOTES[0]
        XCTAssertTrue(code.contains("note(\"\(NOTES[0])\")"))

        params["noteIdx"] = 999
        let code2 = buildCode(params, structIdx: 0, config: DEFAULT_MAPPING)
        // Should use NOTES[last]
        XCTAssertTrue(code2.contains("note(\"\(NOTES[NOTES.count - 1])\")"))
    }

    func testBuildCode_includesExtraParamCalls() {
        let params = buildDefaultParams(DEFAULT_MAPPING)
        let code = buildCode(params, structIdx: 0, config: DEFAULT_MAPPING)
        // Extra params for DEFAULT_MAPPING: delay, gain, lpf, reverb
        XCTAssertTrue(code.contains(".delay("))
        XCTAssertTrue(code.contains(".gain("))
        XCTAssertTrue(code.contains(".lpf("))
        XCTAssertTrue(code.contains(".room("))  // reverb's strudelKey is "room"
    }

    func testBuildCode_bpmConvertedToCpm() {
        var params: MusicParams = ["noteIdx": 10, "bpm": 120]
        let code = buildCode(params, structIdx: 0, config: MappingConfig(left: ["y": "noteIdx"], right: ["x": "bpm"]))
        // cpm = 120 / 4 = 30.0
        XCTAssertTrue(code.contains(".cpm(30.0)"))
    }

    func testBuildCode_defaultBpmWhenMissing() {
        let params: MusicParams = ["noteIdx": 10]
        let code = buildCode(params, structIdx: 0, config: MappingConfig(left: ["y": "noteIdx"], right: [:]))
        // Default bpm=120, cpm = 120/4 = 30.0
        XCTAssertTrue(code.contains(".cpm(30.0)"))
    }

    // MARK: - buildSignalCode

    func testBuildSignalCode_includesSignalWrappers() {
        let code = buildSignalCode(structIdx: 0, config: DEFAULT_MAPPING)
        XCTAssertTrue(code.contains("signal(() => __hp._midi)"))
        XCTAssertTrue(code.contains("signal(() => __hp._cpm)"))
    }

    func testBuildSignalCode_includesWaveform() {
        let code = buildSignalCode(structIdx: 0, config: DEFAULT_MAPPING, waveform: "triangle")
        XCTAssertTrue(code.contains(".s(\"triangle\")"))
    }

    func testBuildSignalCode_includesStruct() {
        let code = buildSignalCode(structIdx: 2, config: DEFAULT_MAPPING)
        XCTAssertTrue(code.contains(".struct(\"\(STRUCTS[2])\")"))
    }

    func testBuildSignalCode_includesExtraParamSignals() {
        let code = buildSignalCode(structIdx: 0, config: DEFAULT_MAPPING)
        // Extra params with signal wrappers
        XCTAssertTrue(code.contains("signal(() => __hp.delay)"))
        XCTAssertTrue(code.contains("signal(() => __hp.gain)"))
        XCTAssertTrue(code.contains("signal(() => __hp.lpf)"))
        XCTAssertTrue(code.contains("signal(() => __hp.reverb)"))
    }

    func testBuildSignalCode_structIdxClamped() {
        let code = buildSignalCode(structIdx: -1, config: DEFAULT_MAPPING)
        XCTAssertTrue(code.contains(".struct(\"\(STRUCTS[0])\")"))
    }

    // MARK: - buildChordSignalCode

    func testBuildChordSignalCode_producesStackOf3Voices() {
        let code = buildChordSignalCode(structIdx: 0, config: DEFAULT_MAPPING)
        XCTAssertTrue(code.contains("stack("))
        XCTAssertTrue(code.contains("__hp._cm0"))
        XCTAssertTrue(code.contains("__hp._cm1"))
        XCTAssertTrue(code.contains("__hp._cm2"))
    }

    func testBuildChordSignalCode_includesWaveform() {
        let code = buildChordSignalCode(structIdx: 0, config: DEFAULT_MAPPING, waveform: "square")
        // All 3 voices should have the waveform
        let occurrences = code.components(separatedBy: ".s(\"square\")").count - 1
        XCTAssertEqual(occurrences, 3)
    }

    func testBuildChordSignalCode_includesStruct() {
        let code = buildChordSignalCode(structIdx: 1, config: DEFAULT_MAPPING)
        XCTAssertTrue(code.contains(".struct(\"\(STRUCTS[1])\")"))
    }

    func testBuildChordSignalCode_eachVoiceHasCpm() {
        let code = buildChordSignalCode(structIdx: 0, config: DEFAULT_MAPPING)
        let cpmOccurrences = code.components(separatedBy: "signal(() => __hp._cpm)").count - 1
        XCTAssertEqual(cpmOccurrences, 3)
    }

    // MARK: - STRUCTS bounds check

    func testStructs_hasExpectedCount() {
        XCTAssertEqual(STRUCTS.count, 5)
    }

    func testStructs_allContainX() {
        for pattern in STRUCTS {
            XCTAssertTrue(pattern.contains("x"), "Pattern '\(pattern)' should contain 'x'")
        }
    }

    // MARK: - NOTES bounds check

    func testNotes_hasExpectedCount() {
        XCTAssertEqual(NOTES.count, 18)
    }

    func testMidiNotes_matchesNotesCount() {
        XCTAssertEqual(MIDI_NOTES.count, NOTES.count)
    }

    func testNoteDisplay_matchesNotesCount() {
        XCTAssertEqual(NOTE_DISPLAY.count, NOTES.count)
    }

    func testNotes_areValidStrudelNoteFormat() {
        for note in NOTES {
            // Strudel notes are like "c2", "d3", "gb4"
            XCTAssertTrue(note.count >= 2, "Note \(note) should be at least 2 characters")
            let lastChar = note.last!
            XCTAssertTrue(lastChar.isNumber, "Note \(note) should end with a digit")
        }
    }

    // MARK: - DrumLoop

    func testDrumLoops_haveUniqueIds() {
        let ids = DRUM_LOOPS.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "DrumLoop IDs should be unique")
    }

    func testDrumLoops_premiumItems_haveValidPackIds() {
        let premiumLoops = DRUM_LOOPS.filter { $0.isPremium }
        XCTAssertGreaterThan(premiumLoops.count, 0)
        for loop in premiumLoops {
            XCTAssertNotNil(loop.packId, "Premium loop '\(loop.id)' should have a packId")
            XCTAssertFalse(loop.packId!.isEmpty, "Premium loop '\(loop.id)' packId should not be empty")
        }
    }

    func testDrumLoops_freeItems_haveNilPackId() {
        let freeLoops = DRUM_LOOPS.filter { !$0.isPremium }
        XCTAssertGreaterThan(freeLoops.count, 0)
        for loop in freeLoops {
            XCTAssertNil(loop.packId, "Free loop '\(loop.id)' should have nil packId")
        }
    }

    func testDrumLoops_nonNone_haveNonEmptyCode() {
        for loop in DRUM_LOOPS where loop.id != "none" {
            XCTAssertFalse(loop.code.isEmpty, "DrumLoop '\(loop.id)' should have non-empty code")
        }
    }

    func testDrumLoops_noneHasEmptyCode() {
        let noneLoop = DRUM_LOOPS.first { $0.id == "none" }
        XCTAssertNotNil(noneLoop)
        XCTAssertTrue(noneLoop!.code.isEmpty)
    }

    func testDrumLoops_allHaveEmoji() {
        for loop in DRUM_LOOPS {
            XCTAssertFalse(loop.emoji.isEmpty, "DrumLoop '\(loop.id)' should have an emoji")
        }
    }

    func testDrumLoops_allHaveName() {
        for loop in DRUM_LOOPS {
            XCTAssertFalse(loop.name.isEmpty, "DrumLoop '\(loop.id)' should have a name")
        }
    }

    // MARK: - PARAM_DEFS validation

    func testParamDefs_hasExpectedCount() {
        XCTAssertEqual(PARAM_DEFS.count, 12)
    }

    func testParamDefs_eachHasMinLessThanMax() {
        for def in PARAM_DEFS {
            XCTAssertTrue(def.min < def.max, "\(def.id): min (\(def.min)) should be < max (\(def.max))")
        }
    }

    func testParamDefs_eachDefaultWithinRange() {
        for def in PARAM_DEFS {
            XCTAssertTrue(def.defaultValue >= def.min && def.defaultValue <= def.max,
                          "\(def.id): default (\(def.defaultValue)) not in [\(def.min), \(def.max)]")
        }
    }

    func testParamDefs_allHaveUniqueIds() {
        let ids = PARAM_DEFS.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "PARAM_DEFS should have unique IDs")
    }

    func testParamDefs_allHaveNonEmptyStrudelKey() {
        for def in PARAM_DEFS {
            XCTAssertFalse(def.strudelKey.isEmpty, "\(def.id) should have a non-empty strudelKey")
        }
    }

    // MARK: - PARAM_MAP

    func testParamMap_containsAllParamDefs() {
        for def in PARAM_DEFS {
            XCTAssertNotNil(PARAM_MAP[def.id], "PARAM_MAP should contain \(def.id)")
        }
    }

    func testParamMap_totalCount() {
        XCTAssertEqual(PARAM_MAP.count, PARAM_DEFS.count)
    }

    // MARK: - buildTrackCode

    func testBuildTrackCode_singleSlot_returnsCode() {
        let snippets = [SavedSnippet(code: "note(\"c4\").s(\"sawtooth\")", bpm: 120)]
        let code = buildTrackCode(slots: [0], speed: 1.0, snippets: snippets)
        XCTAssertEqual(code, "note(\"c4\").s(\"sawtooth\")")
    }

    func testBuildTrackCode_multipleSlots_usesSlowcat() {
        let snippets = [
            SavedSnippet(code: "code_a", bpm: 120),
            SavedSnippet(code: "code_b", bpm: 130),
        ]
        let code = buildTrackCode(slots: [0, 1], speed: 1.0, snippets: snippets)
        XCTAssertEqual(code, "slowcat(code_a, code_b)")
    }

    func testBuildTrackCode_speedNotOne_appliesSlow() {
        let snippets = [SavedSnippet(code: "code_a", bpm: 120)]
        let code = buildTrackCode(slots: [0], speed: 2.0, snippets: snippets)
        XCTAssertEqual(code, "(code_a).slow(\(1.0 / 2.0))")
    }

    func testBuildTrackCode_emptySlots_returnsNil() {
        let code = buildTrackCode(slots: [], speed: 1.0, snippets: [])
        XCTAssertNil(code)
    }

    func testBuildTrackCode_invalidSlotIndex_skipsIt() {
        let snippets = [SavedSnippet(code: "code_a", bpm: 120)]
        let code = buildTrackCode(slots: [5], speed: 1.0, snippets: snippets)
        // Index 5 is out of bounds, compactMap returns nil for it
        XCTAssertNil(code)
    }

    // MARK: - Array safe subscript

    func testSafeSubscript_validIndex_returnsElement() {
        let arr = [10, 20, 30]
        XCTAssertEqual(arr[safe: 1], 20)
    }

    func testSafeSubscript_outOfBounds_returnsNil() {
        let arr = [10, 20, 30]
        XCTAssertNil(arr[safe: 5])
        XCTAssertNil(arr[safe: -1])
    }
}
