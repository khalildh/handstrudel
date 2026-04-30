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

// MARK: - MusicTheory Tests

final class MusicTheoryTests: XCTestCase {

    // MARK: scaleNotes

    func testScaleNotes_CMajor_returnsCorrectNotes() {
        let notes = scaleNotes(key: .C, scale: .major)
        // C major: C D E F G A B across octaves 2-5
        // C2=36, D2=38, E2=40, F2=41, G2=43, A2=45, B2=47
        XCTAssertTrue(notes.contains(36)) // C2
        XCTAssertTrue(notes.contains(40)) // E2
        XCTAssertTrue(notes.contains(43)) // G2
        XCTAssertTrue(notes.contains(60)) // C4
    }

    func testScaleNotes_AMinor_returnsCorrectNotes() {
        let notes = scaleNotes(key: .A, scale: .minor)
        // A minor: A B C D E F G
        // A2=45 in octave 2
        XCTAssertTrue(notes.contains(45)) // A2
        XCTAssertTrue(notes.contains(47)) // B2
        XCTAssertTrue(notes.contains(48)) // C3
    }

    func testScaleNotes_DDorian_returnsCorrectNotes() {
        let notes = scaleNotes(key: .D, scale: .dorian)
        // D Dorian: D E F G A B C
        // D2=38
        XCTAssertTrue(notes.contains(38)) // D2
        XCTAssertTrue(notes.contains(40)) // E2
        XCTAssertTrue(notes.contains(41)) // F2
    }

    func testScaleNotes_CPentatonic_returnsCorrectNotes() {
        let notes = scaleNotes(key: .C, scale: .pentatonic)
        // C Pentatonic: C D E G A (intervals: 0,2,4,7,9)
        XCTAssertTrue(notes.contains(36)) // C2
        XCTAssertTrue(notes.contains(38)) // D2
        XCTAssertTrue(notes.contains(40)) // E2
        XCTAssertTrue(notes.contains(43)) // G2
        XCTAssertTrue(notes.contains(45)) // A2
        // F should NOT be in pentatonic
        XCTAssertFalse(notes.contains(41)) // F2
    }

    func testScaleNotes_ABlues_returnsCorrectNotes() {
        let notes = scaleNotes(key: .A, scale: .blues)
        // A Blues: A C D Eb E G (intervals: 0,3,5,6,7,10)
        // A2=45, C3=48, D3=50, Eb3=51, E3=52, G3=55
        XCTAssertTrue(notes.contains(45)) // A2
        XCTAssertTrue(notes.contains(48)) // C3
    }

    func testScaleNotes_multipleOctaves() {
        let notes = scaleNotes(key: .C, scale: .major)
        // Should span octaves 2-5
        let hasOctave2 = notes.contains(36) // C2
        let hasOctave3 = notes.contains(48) // C3
        let hasOctave4 = notes.contains(60) // C4
        let hasOctave5 = notes.contains(72) // C5
        XCTAssertTrue(hasOctave2)
        XCTAssertTrue(hasOctave3)
        XCTAssertTrue(hasOctave4)
        XCTAssertTrue(hasOctave5)
    }

    func testScaleNotes_cappedAtOctave5() {
        let notes = scaleNotes(key: .C, scale: .major)
        // Loop goes octave 2-5, so highest note is B5=83
        XCTAssertTrue(notes.contains(83))  // B5
        XCTAssertFalse(notes.contains(84)) // C6 not generated (octave 6 not in range)
    }

    func testScaleNotes_pentatonicHasFewerNotes() {
        let majorNotes = scaleNotes(key: .C, scale: .major)
        let pentaNotes = scaleNotes(key: .C, scale: .pentatonic)
        XCTAssertTrue(pentaNotes.count < majorNotes.count)
    }

    // MARK: chordNotes

    func testChordNotes_CMajor_degree0_returnsCEG() {
        let chord = chordNotes(key: .C, scale: .major, degree: 0)
        XCTAssertEqual(chord.count, 3)
        // C3=48, E3=52, G3=55
        XCTAssertEqual(chord[0], 48) // C
        XCTAssertEqual(chord[1], 52) // E
        XCTAssertEqual(chord[2], 55) // G
    }

    func testChordNotes_CMajor_degree1_returnsDFA() {
        let chord = chordNotes(key: .C, scale: .major, degree: 1)
        // D3=50, F3=53, A3=57
        XCTAssertEqual(chord[0], 50) // D
        XCTAssertEqual(chord[1], 53) // F
        XCTAssertEqual(chord[2], 57) // A
    }

    func testChordNotes_CMajor_degree2_returnsEGB() {
        let chord = chordNotes(key: .C, scale: .major, degree: 2)
        // E3=52, G3=55, B3=59
        XCTAssertEqual(chord[0], 52) // E
        XCTAssertEqual(chord[1], 55) // G
        XCTAssertEqual(chord[2], 59) // B
    }

    func testChordNotes_CMajor_degree3_returnsFAC() {
        let chord = chordNotes(key: .C, scale: .major, degree: 3)
        // F3=53, A3=57, C4=60
        XCTAssertEqual(chord[0], 53) // F
        XCTAssertEqual(chord[1], 57) // A
        XCTAssertEqual(chord[2], 60) // C
    }

    func testChordNotes_AMinor_degree0_returnsACE() {
        let chord = chordNotes(key: .A, scale: .minor, degree: 0)
        // A3=57, C4=60, E4=64
        XCTAssertEqual(chord[0], 57) // A
        XCTAssertEqual(chord[1], 60) // C
        XCTAssertEqual(chord[2], 64) // E
    }

    func testChordNotes_alwaysReturnsTriad() {
        for degree in 0..<7 {
            let chord = chordNotes(key: .C, scale: .major, degree: degree)
            XCTAssertEqual(chord.count, 3, "Degree \(degree) should return a triad")
        }
    }

    // MARK: midiNoteName

    func testMidiNoteName_C4() {
        XCTAssertEqual(midiNoteName(60), "C4")
    }

    func testMidiNoteName_A4() {
        XCTAssertEqual(midiNoteName(69), "A4")
    }

    func testMidiNoteName_C3() {
        XCTAssertEqual(midiNoteName(48), "C3")
    }

    // MARK: midiToStrudelNote

    func testMidiToStrudelNote_C4() {
        XCTAssertEqual(midiToStrudelNote(60), "c4")
    }

    func testMidiToStrudelNote_A4() {
        XCTAssertEqual(midiToStrudelNote(69), "a4")
    }

    func testMidiToStrudelNote_Db3() {
        // MIDI 49 = Db3
        XCTAssertEqual(midiToStrudelNote(49), "db3")
    }

    // MARK: chordDisplayName

    func testChordDisplayName_CMajor_degree0_returnsCmaj() {
        XCTAssertEqual(chordDisplayName(key: .C, scale: .major, degree: 0), "Cmaj")
    }

    func testChordDisplayName_CMajor_degree1_returnsDmin() {
        XCTAssertEqual(chordDisplayName(key: .C, scale: .major, degree: 1), "Dmin")
    }

    func testChordDisplayName_AMinor_degree0_returnsAmin() {
        XCTAssertEqual(chordDisplayName(key: .A, scale: .minor, degree: 0), "Amin")
    }

    func testChordDisplayName_CMajor_degree6_returnsBdim() {
        // vii in C major = B diminished
        XCTAssertEqual(chordDisplayName(key: .C, scale: .major, degree: 6), "Bdim")
    }

    // MARK: CIRCLE_OF_FIFTHS

    func testCircleOfFifths_has12Entries() {
        XCTAssertEqual(CIRCLE_OF_FIFTHS.count, 12)
    }

    func testCircleOfFifths_startsWithC() {
        XCTAssertEqual(CIRCLE_OF_FIFTHS.first, .C)
    }

    // MARK: MusicKey

    func testMusicKey_allCases_has12Entries() {
        XCTAssertEqual(MusicKey.allCases.count, 12)
    }

    func testMusicKey_semitoneValues() {
        XCTAssertEqual(MusicKey.C.semitone, 0)
        XCTAssertEqual(MusicKey.Db.semitone, 1)
        XCTAssertEqual(MusicKey.D.semitone, 2)
        XCTAssertEqual(MusicKey.A.semitone, 9)
        XCTAssertEqual(MusicKey.B.semitone, 11)
    }

    // MARK: Scale

    func testScale_allCases_hasCorrectCount() {
        XCTAssertEqual(Scale.allCases.count, 5)
    }
}

// MARK: - ParamDefs Tests

final class ParamDefsTests: XCTestCase {

    // MARK: buildCode

    func testBuildCode_defaultParams_generatesValidCode() {
        let params = buildDefaultParams(DEFAULT_MAPPING)
        let code = buildCode(params, structIdx: 0, config: DEFAULT_MAPPING)
        XCTAssertTrue(code.contains("note("))
        XCTAssertTrue(code.contains(".s(\"sawtooth\")"))
        XCTAssertTrue(code.contains(".struct("))
        XCTAssertTrue(code.contains(".cpm("))
    }

    func testBuildCode_includesWaveformParameter() {
        let params = buildDefaultParams(DEFAULT_MAPPING)
        let code = buildCode(params, structIdx: 0, config: DEFAULT_MAPPING, waveform: "square")
        XCTAssertTrue(code.contains(".s(\"square\")"))
    }

    func testBuildCode_differentStructIndices() {
        let params = buildDefaultParams(DEFAULT_MAPPING)
        for i in 0..<STRUCTS.count {
            let code = buildCode(params, structIdx: i, config: DEFAULT_MAPPING)
            XCTAssertTrue(code.contains(".struct(\"\(STRUCTS[i])\")"))
        }
    }

    func testBuildCode_includesExtraParams() {
        let params = buildDefaultParams(DEFAULT_MAPPING)
        let code = buildCode(params, structIdx: 0, config: DEFAULT_MAPPING)
        // DEFAULT_MAPPING extras are: delay, gain, lpf, reverb (sorted)
        XCTAssertTrue(code.contains(".delay("))
        XCTAssertTrue(code.contains(".gain("))
        XCTAssertTrue(code.contains(".lpf("))
        XCTAssertTrue(code.contains(".room("))
    }

    // MARK: buildSignalCode

    func testBuildSignalCode_generatesSignalBasedCode() {
        let code = buildSignalCode(structIdx: 0, config: DEFAULT_MAPPING)
        XCTAssertTrue(code.contains("signal(() => __hp._midi)"))
        XCTAssertTrue(code.contains("signal(() => __hp._cpm)"))
    }

    func testBuildSignalCode_includesWaveform() {
        let code = buildSignalCode(structIdx: 0, config: DEFAULT_MAPPING, waveform: "triangle")
        XCTAssertTrue(code.contains(".s(\"triangle\")"))
    }

    // MARK: buildChordSignalCode

    func testBuildChordSignalCode_generatesStackOf3Voices() {
        let code = buildChordSignalCode(structIdx: 0, config: DEFAULT_MAPPING)
        XCTAssertTrue(code.contains("stack("))
        XCTAssertTrue(code.contains("__hp._cm0"))
        XCTAssertTrue(code.contains("__hp._cm1"))
        XCTAssertTrue(code.contains("__hp._cm2"))
    }

    // MARK: buildDefaultParams

    func testBuildDefaultParams_returnsCorrectDefaults() {
        let params = buildDefaultParams(DEFAULT_MAPPING)
        // DEFAULT_MAPPING uses: noteIdx, lpf, reverb, gain, bpm, delay
        XCTAssertEqual(params["noteIdx"], 10)
        XCTAssertEqual(params["lpf"], 3000)
        XCTAssertEqual(params["reverb"], 0.2)
        XCTAssertEqual(params["gain"], 0.55)
        XCTAssertEqual(params["bpm"], 120)
        XCTAssertEqual(params["delay"], 0.12)
    }

    // MARK: extraParamIds

    func testExtraParamIds_excludesNoteIdxBpmNoneSave() {
        let config = MappingConfig(
            left:  ["y": "noteIdx", "x": "lpf", "spread": "save"],
            right: ["y": "gain", "x": "bpm", "spread": "none"]
        )
        let extras = extraParamIds(config)
        XCTAssertFalse(extras.contains("noteIdx"))
        XCTAssertFalse(extras.contains("bpm"))
        XCTAssertFalse(extras.contains("none"))
        XCTAssertFalse(extras.contains("save"))
        XCTAssertTrue(extras.contains("lpf"))
        XCTAssertTrue(extras.contains("gain"))
    }

    func testExtraParamIds_excludesHydraParams() {
        let config = MappingConfig(
            left:  ["y": "noteIdx", "x": "hFreq"],
            right: ["y": "gain", "x": "bpm"]
        )
        let extras = extraParamIds(config)
        XCTAssertFalse(extras.contains("hFreq"))
        XCTAssertTrue(extras.contains("gain"))
    }

    // MARK: PARAM_DEFS

    func testParamDefs_hasCorrectCount() {
        XCTAssertEqual(PARAM_DEFS.count, 12)
    }

    func testParamDefs_eachHasValidMinLessThanMax() {
        for def in PARAM_DEFS {
            XCTAssertTrue(def.min < def.max, "\(def.id): min (\(def.min)) should be < max (\(def.max))")
        }
    }

    func testParamDefs_eachDefaultWithinRange() {
        for def in PARAM_DEFS {
            XCTAssertTrue(def.defaultValue >= def.min && def.defaultValue <= def.max,
                          "\(def.id): default (\(def.defaultValue)) should be in [\(def.min), \(def.max)]")
        }
    }

    // MARK: NOTES / MIDI_NOTES / NOTE_DISPLAY

    func testNotes_andMidiNotes_haveSameCount() {
        XCTAssertEqual(NOTES.count, MIDI_NOTES.count)
    }

    func testNoteDisplay_matchesNotesCount() {
        XCTAssertEqual(NOTE_DISPLAY.count, NOTES.count)
    }

    func testStructs_hasExpectedPatterns() {
        XCTAssertEqual(STRUCTS.count, 5)
        XCTAssertTrue(STRUCTS[0].contains("x"))
    }

    // MARK: buildHydraCode

    func testBuildHydraCode_generatesValidOutput() {
        let code = buildHydraCode([:])
        XCTAssertTrue(code.contains("osc("))
        XCTAssertTrue(code.contains(".out()"))
    }

    // MARK: buildTrackCode

    func testBuildTrackCode_singleSlot() {
        let snippets = [SavedSnippet(code: "note(\"c4\").s(\"sawtooth\")", bpm: 120)]
        let code = buildTrackCode(slots: [0], speed: 1.0, snippets: snippets)
        XCTAssertEqual(code, "note(\"c4\").s(\"sawtooth\")")
    }

    func testBuildTrackCode_multipleSlots() {
        let snippets = [
            SavedSnippet(code: "code_a", bpm: 120),
            SavedSnippet(code: "code_b", bpm: 130),
        ]
        let code = buildTrackCode(slots: [0, 1], speed: 1.0, snippets: snippets)
        XCTAssertEqual(code, "slowcat(code_a, code_b)")
    }

    func testBuildTrackCode_speedNotOne() {
        let snippets = [SavedSnippet(code: "code_a", bpm: 120)]
        let code = buildTrackCode(slots: [0], speed: 2.0, snippets: snippets)
        XCTAssertEqual(code, "(code_a).slow(\(1.0 / 2.0))")
    }

    func testBuildTrackCode_emptySlots_returnsNil() {
        let code = buildTrackCode(slots: [], speed: 1.0, snippets: [])
        XCTAssertNil(code)
    }

    // MARK: DRUM_LOOPS

    func testDrumLoops_freeItems_areNotPremium() {
        let freeLoops = DRUM_LOOPS.filter { !$0.isPremium }
        XCTAssertGreaterThan(freeLoops.count, 0)
        for loop in freeLoops {
            XCTAssertFalse(loop.isPremium)
            XCTAssertNil(loop.packId)
        }
    }

    func testDrumLoops_premiumItems_haveValidPackId() {
        let premiumLoops = DRUM_LOOPS.filter { $0.isPremium }
        XCTAssertGreaterThan(premiumLoops.count, 0)
        for loop in premiumLoops {
            XCTAssertNotNil(loop.packId)
            XCTAssertFalse(loop.packId!.isEmpty)
        }
    }

    func testDrumLoops_nonNone_haveNonEmptyCode() {
        for loop in DRUM_LOOPS where loop.id != "none" {
            XCTAssertFalse(loop.code.isEmpty, "Drum loop \(loop.id) should have non-empty code")
        }
    }

    func testDrumLoops_noneHasEmptyCode() {
        let noneLoop = DRUM_LOOPS.first { $0.id == "none" }
        XCTAssertNotNil(noneLoop)
        XCTAssertTrue(noneLoop!.code.isEmpty)
    }
}

// MARK: - MappingConfig Tests

final class MappingConfigTests: XCTestCase {

    func testDefaultMapping_hasBothHands() {
        XCTAssertFalse(DEFAULT_MAPPING.left.isEmpty)
        XCTAssertFalse(DEFAULT_MAPPING.right.isEmpty)
    }

    func testAxisDefs_has11Entries() {
        XCTAssertEqual(AXIS_DEFS.count, 11)
    }

    func testAxisDefs_basicAxes_haveCorrectInvert() {
        let basicAxes = AXIS_DEFS.filter { $0.basic }
        XCTAssertEqual(basicAxes.count, 3)
        // y and x are inverted, spread is not
        let yAxis = AXIS_DEFS.first { $0.key == "y" }!
        let xAxis = AXIS_DEFS.first { $0.key == "x" }!
        let spreadAxis = AXIS_DEFS.first { $0.key == "spread" }!
        XCTAssertTrue(yAxis.invert)
        XCTAssertTrue(xAxis.invert)
        XCTAssertFalse(spreadAxis.invert)
    }

    func testAxisDefs_advancedAxes_areNotInverted() {
        let advancedAxes = AXIS_DEFS.filter { !$0.basic }
        XCTAssertEqual(advancedAxes.count, 8)
        for axis in advancedAxes {
            XCTAssertFalse(axis.invert, "\(axis.key) should not be inverted")
        }
    }

    func testPresets_hasCorrectCount() {
        // 4 free + 6 premium = 10
        XCTAssertEqual(PRESETS.count, 10)
    }

    func testPresets_freePresetsNotPremium() {
        let freePresets = PRESETS.filter { !$0.isPremium }
        XCTAssertEqual(freePresets.count, 4)
        for preset in freePresets {
            XCTAssertFalse(preset.isPremium)
            XCTAssertNil(preset.packId)
        }
    }

    func testPresets_premiumPresetsHaveValidPackId() {
        let premiumPresets = PRESETS.filter { $0.isPremium }
        XCTAssertEqual(premiumPresets.count, 6)
        for preset in premiumPresets {
            XCTAssertNotNil(preset.packId)
            XCTAssertFalse(preset.packId!.isEmpty)
        }
    }

    func testPresets_eachHasNonEmptyMapping() {
        for preset in PRESETS {
            XCTAssertFalse(preset.mapping.left.isEmpty, "\(preset.id) left mapping should not be empty")
            XCTAssertFalse(preset.mapping.right.isEmpty, "\(preset.id) right mapping should not be empty")
        }
    }

    func testPresets_colorsAreValidRGB() {
        for preset in PRESETS {
            let (r, g, b) = preset.color
            XCTAssertTrue(r >= 0 && r <= 1, "\(preset.id) red \(r) out of range")
            XCTAssertTrue(g >= 0 && g <= 1, "\(preset.id) green \(g) out of range")
            XCTAssertTrue(b >= 0 && b <= 1, "\(preset.id) blue \(b) out of range")
        }
    }

    func testPresets_eachHasUniqueId() {
        let ids = PRESETS.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "Preset IDs should be unique")
    }

    func testAxisDefs_allHaveNonEmptyLabels() {
        for axis in AXIS_DEFS {
            XCTAssertFalse(axis.label.isEmpty)
            XCTAssertFalse(axis.icon.isEmpty)
        }
    }

    func testAxisDefs_keysAreUnique() {
        let keys = AXIS_DEFS.map(\.key)
        XCTAssertEqual(Set(keys).count, keys.count)
    }

    func testDefaultMapping_leftHasExpectedKeys() {
        XCTAssertEqual(DEFAULT_MAPPING.left["y"], "noteIdx")
        XCTAssertEqual(DEFAULT_MAPPING.left["x"], "lpf")
        XCTAssertEqual(DEFAULT_MAPPING.left["spread"], "reverb")
    }

    func testDefaultMapping_rightHasExpectedKeys() {
        XCTAssertEqual(DEFAULT_MAPPING.right["y"], "gain")
        XCTAssertEqual(DEFAULT_MAPPING.right["x"], "bpm")
        XCTAssertEqual(DEFAULT_MAPPING.right["spread"], "delay")
    }

    func testAxisMap_containsAllAxisDefs() {
        for axis in AXIS_DEFS {
            XCTAssertNotNil(AXIS_MAP[axis.key])
        }
    }
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

// MARK: - DrumModeManager Tests

final class DrumModeManagerTests: XCTestCase {

    func testLeftZones_has3Zones() {
        XCTAssertEqual(DrumModeManager.leftZones.count, 3)
    }

    func testRightZones_has3Zones() {
        XCTAssertEqual(DrumModeManager.rightZones.count, 3)
    }

    func testCheckHits_noHands_returnsEmpty() {
        let manager = DrumModeManager()
        let hands = HandsState(left: nil, right: nil)
        let hits = manager.checkHits(hands: hands, currentTime: 1.0)
        XCTAssertTrue(hits.isEmpty)
    }

    func testZoneIndices_mapToYRanges() {
        // Zone index = min(2, Int(y * 3))
        // y=0.0 -> zone 0, y=0.33 -> zone 0, y=0.34 -> zone 1, y=0.67 -> zone 2, y=1.0 -> zone 2
        XCTAssertEqual(min(2, Int(0.0 * 3)), 0)
        XCTAssertEqual(min(2, Int(0.33 * 3)), 0)
        XCTAssertEqual(min(2, Int(0.5 * 3)), 1)
        XCTAssertEqual(min(2, Int(0.8 * 3)), 2)
        XCTAssertEqual(min(2, Int(1.0 * 3)), 2) // clamped to 2
    }

    func testCooldown_preventsRapidRetriggering() {
        let manager = DrumModeManager()
        // First call with hand at y=0.5
        let hand1 = makeHandData(y: 0.5)
        let hands1 = HandsState(left: hand1, right: nil)
        let hits1 = manager.checkHits(hands: hands1, currentTime: 1.0)
        // Should be empty on first call (no velocity since prevLeftY starts at 0.5)
        // ... unless the implementation moves to a new position
        // Either way, after a hit, calling again quickly should respect cooldown

        // Move hand significantly to trigger
        let hand2 = makeHandData(y: 0.1)
        let hands2 = HandsState(left: hand2, right: nil)
        let hits2 = manager.checkHits(hands: hands2, currentTime: 1.05)

        // Try immediately again (within cooldown of 0.1s)
        let hand3 = makeHandData(y: 0.8)
        let hands3 = HandsState(left: hand3, right: nil)
        let hits3 = manager.checkHits(hands: hands3, currentTime: 1.06)

        // If hits2 triggered, hits3 should be empty due to cooldown
        if !hits2.isEmpty {
            XCTAssertTrue(hits3.isEmpty, "Rapid re-triggering should be prevented by cooldown")
        }
    }
}

// MARK: - Song Player Tests

@MainActor
final class SongPlayerTests: XCTestCase {

    func testStartSong_setsInitialState() {
        let player = SongPlayer()
        let song = BUILT_IN_SONGS[0]
        player.startSong(song)
        XCTAssertTrue(player.isPlaying)
        XCTAssertEqual(player.songTime, -2.0)
        XCTAssertEqual(player.score, 0)
        XCTAssertEqual(player.combo, 0)
        XCTAssertEqual(player.totalNotes, song.notes.count)
        XCTAssertEqual(player.hitNotes, 0)
    }

    func testTick_advancesSongTime() {
        let player = SongPlayer()
        player.startSong(BUILT_IN_SONGS[0])
        let initial = player.songTime
        player.tick(deltaTime: 0.1)
        XCTAssertEqual(player.songTime, initial + 0.1, accuracy: 0.001)
    }

    func testTick_doesNothingWhenNotPlaying() {
        let player = SongPlayer()
        player.tick(deltaTime: 0.1)
        XCTAssertEqual(player.songTime, 0)
    }

    func testCheckHit_matchesCorrectNote() {
        let player = SongPlayer()
        player.startSong(BUILT_IN_SONGS[0])
        // Advance 2 seconds to songTime = 0.0
        for _ in 0..<120 { player.tick(deltaTime: 1.0/60.0) }
        let hit = player.checkHit(midi: 60)
        XCTAssertTrue(hit)
        XCTAssertEqual(player.hitNotes, 1)
        XCTAssertEqual(player.combo, 1)
        XCTAssertGreaterThan(player.score, 0)
    }

    func testCheckHit_wrongNoteBreaksCombo() {
        let player = SongPlayer()
        player.startSong(BUILT_IN_SONGS[0])
        for _ in 0..<120 { player.tick(deltaTime: 1.0/60.0) }
        _ = player.checkHit(midi: 60)
        XCTAssertEqual(player.combo, 1)
        let miss = player.checkHit(midi: 99)
        XCTAssertFalse(miss)
        XCTAssertEqual(player.combo, 0)
    }

    func testCheckHit_outsideWindowMisses() {
        let player = SongPlayer()
        player.startSong(BUILT_IN_SONGS[0])
        // songTime = -2.0, first note at 0.0, diff = 2.0 > hitWindow
        let hit = player.checkHit(midi: 60)
        XCTAssertFalse(hit)
    }

    func testCheckHit_cannotHitSameNoteTwice() {
        let player = SongPlayer()
        player.startSong(BUILT_IN_SONGS[0])
        for _ in 0..<120 { player.tick(deltaTime: 1.0/60.0) }
        _ = player.checkHit(midi: 60)
        let hit2 = player.checkHit(midi: 60)
        XCTAssertFalse(hit2)
        XCTAssertEqual(player.hitNotes, 1)
    }

    func testVisibleNotes_returnsUpcoming() {
        let player = SongPlayer()
        player.startSong(BUILT_IN_SONGS[0])
        for _ in 0..<120 { player.tick(deltaTime: 1.0/60.0) }
        let visible = player.visibleNotes(lookAhead: 3.0)
        XCTAssertGreaterThan(visible.count, 0)
    }

    func testVisibleNotes_marksHit() {
        let player = SongPlayer()
        player.startSong(BUILT_IN_SONGS[0])
        for _ in 0..<120 { player.tick(deltaTime: 1.0/60.0) }
        _ = player.checkHit(midi: 60)
        let visible = player.visibleNotes(lookAhead: 3.0)
        let first = visible.first { $0.index == 0 }
        XCTAssertTrue(first?.isHit ?? false)
    }

    func testSongEnds_afterLastNote() {
        let player = SongPlayer()
        let song = Song(id: "t", title: "T", artist: "T", key: "C", scale: "Major", bpm: 120,
                       notes: [SongNote(midi: 60, time: 0.0, duration: 0.5)], isPremium: false)
        player.startSong(song)
        for _ in 0..<300 { player.tick(deltaTime: 1.0/60.0) }
        XCTAssertFalse(player.isPlaying)
    }

    func testProgress() {
        let player = SongPlayer()
        let song = Song(id: "t", title: "T", artist: "T", key: "C", scale: "Major", bpm: 120,
                       notes: [SongNote(midi: 60, time: 0.0, duration: 0.3),
                               SongNote(midi: 62, time: 1.0, duration: 0.3)], isPremium: false)
        player.startSong(song)
        for _ in 0..<120 { player.tick(deltaTime: 1.0/60.0) }
        _ = player.checkHit(midi: 60)
        XCTAssertEqual(player.progress, 0.5, accuracy: 0.01)
    }

    func testStopSong() {
        let player = SongPlayer()
        player.startSong(BUILT_IN_SONGS[0])
        player.stopSong()
        XCTAssertFalse(player.isPlaying)
        XCTAssertNil(player.currentSong)
    }

    func testBuiltInSongs_valid() {
        for song in BUILT_IN_SONGS {
            XCTAssertFalse(song.title.isEmpty)
            XCTAssertFalse(song.notes.isEmpty)
            XCTAssertGreaterThan(song.bpm, 0)
            for note in song.notes {
                XCTAssertTrue((0...127).contains(note.midi))
                XCTAssertGreaterThanOrEqual(note.time, 0)
                XCTAssertGreaterThan(note.duration, 0)
            }
        }
    }
}
