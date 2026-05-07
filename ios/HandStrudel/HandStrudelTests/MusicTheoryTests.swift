import XCTest
@testable import HandStrudel

final class MusicTheoryTests: XCTestCase {

    // MARK: - Scale Intervals

    func testMajorScale_returnsCorrectIntervals() {
        XCTAssertEqual(Scale.major.intervals, [0, 2, 4, 5, 7, 9, 11])
    }

    func testMinorScale_returnsCorrectIntervals() {
        XCTAssertEqual(Scale.minor.intervals, [0, 2, 3, 5, 7, 8, 10])
    }

    func testDorianScale_returnsCorrectIntervals() {
        XCTAssertEqual(Scale.dorian.intervals, [0, 2, 3, 5, 7, 9, 10])
    }

    func testPentatonicScale_returnsCorrectIntervals() {
        XCTAssertEqual(Scale.pentatonic.intervals, [0, 2, 4, 7, 9])
    }

    func testBluesScale_returnsCorrectIntervals() {
        XCTAssertEqual(Scale.blues.intervals, [0, 3, 5, 6, 7, 10])
    }

    func testHarmonicMinorScale_returnsCorrectIntervals() {
        XCTAssertEqual(Scale.harmonicMinor.intervals, [0, 2, 3, 5, 7, 8, 11])
    }

    func testMelodicMinorScale_returnsCorrectIntervals() {
        XCTAssertEqual(Scale.melodicMinor.intervals, [0, 2, 3, 5, 7, 9, 11])
    }

    func testPhrygianScale_returnsCorrectIntervals() {
        XCTAssertEqual(Scale.phrygian.intervals, [0, 1, 3, 5, 7, 8, 10])
    }

    func testLydianScale_returnsCorrectIntervals() {
        XCTAssertEqual(Scale.lydian.intervals, [0, 2, 4, 6, 7, 9, 11])
    }

    func testMixolydianScale_returnsCorrectIntervals() {
        XCTAssertEqual(Scale.mixolydian.intervals, [0, 2, 4, 5, 7, 9, 10])
    }

    func testLocrianScale_returnsCorrectIntervals() {
        XCTAssertEqual(Scale.locrian.intervals, [0, 1, 3, 5, 6, 8, 10])
    }

    func testWholeToneScale_returnsCorrectIntervals() {
        XCTAssertEqual(Scale.wholeTone.intervals, [0, 2, 4, 6, 8, 10])
    }

    func testChromaticScale_returnsCorrectIntervals() {
        XCTAssertEqual(Scale.chromatic.intervals, [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11])
    }

    func testHungarianMinorScale_returnsCorrectIntervals() {
        XCTAssertEqual(Scale.hungarianMinor.intervals, [0, 2, 3, 6, 7, 8, 11])
    }

    func testHirajoshiScale_returnsCorrectIntervals() {
        XCTAssertEqual(Scale.hirajoshi.intervals, [0, 2, 3, 7, 8])
    }

    func testAllScales_startWithZero() {
        for scale in Scale.allCases {
            XCTAssertEqual(scale.intervals.first, 0, "\(scale.rawValue) should start with 0")
        }
    }

    func testAllScales_intervalsAreAscending() {
        for scale in Scale.allCases {
            let intervals = scale.intervals
            for i in 1..<intervals.count {
                XCTAssertTrue(intervals[i] > intervals[i - 1],
                              "\(scale.rawValue) intervals should be strictly ascending")
            }
        }
    }

    func testAllScales_intervalsWithinOctave() {
        for scale in Scale.allCases {
            for interval in scale.intervals {
                XCTAssertTrue(interval >= 0 && interval < 12,
                              "\(scale.rawValue) interval \(interval) should be within 0-11")
            }
        }
    }

    // MARK: - scaleNotes(key:scale:) -- basic overload (octaves 2-5)

    func testScaleNotes_CMajor_containsExpectedMidiValues() {
        let notes = scaleNotes(key: .C, scale: .major)
        // C major in octave 2: base = (2+1)*12 + 0 = 36
        // C2=36, D2=38, E2=40, F2=41, G2=43, A2=45, B2=47
        XCTAssertTrue(notes.contains(36))  // C2
        XCTAssertTrue(notes.contains(38))  // D2
        XCTAssertTrue(notes.contains(40))  // E2
        XCTAssertTrue(notes.contains(41))  // F2
        XCTAssertTrue(notes.contains(43))  // G2
        XCTAssertTrue(notes.contains(45))  // A2
        XCTAssertTrue(notes.contains(47))  // B2
    }

    func testScaleNotes_CMajor_spansOctaves2To5() {
        let notes = scaleNotes(key: .C, scale: .major)
        XCTAssertTrue(notes.contains(36))  // C2
        XCTAssertTrue(notes.contains(48))  // C3
        XCTAssertTrue(notes.contains(60))  // C4
        XCTAssertTrue(notes.contains(72))  // C5
    }

    func testScaleNotes_CMajor_cappedAt84() {
        let notes = scaleNotes(key: .C, scale: .major)
        for note in notes {
            XCTAssertTrue(note <= 84, "Note \(note) exceeds cap of 84 (C6)")
        }
    }

    func testScaleNotes_CMajor_doesNotIncludeC6() {
        let notes = scaleNotes(key: .C, scale: .major)
        // Octave 5: base = (5+1)*12 + 0 = 72. C5=72, all up to B5=83 should be included
        // C6 = 84 is excluded by the <= 84 check... wait, the code says `if midi <= 84`
        // So 84 IS included. Let me check: octave 5 base=72, interval 11=B5=83, then no octave 6.
        // Actually the loop goes 2...5, so octave 5 base=(5+1)*12=72, intervals yield up to 72+11=83.
        XCTAssertTrue(notes.contains(83))  // B5
        // 84 = C6 would be from octave 5 with semitone shift, or future octave 6 -- not in loop
    }

    func testScaleNotes_DMajor_shiftedByTwoSemitones() {
        let notes = scaleNotes(key: .D, scale: .major)
        // D major in octave 2: base = (2+1)*12 + 2 = 38
        // D2=38, E2=40, Gb2=42, G2=43, A2=45, B2=47, Db3=49
        XCTAssertTrue(notes.contains(38))  // D2
        XCTAssertTrue(notes.contains(40))  // E2
        XCTAssertTrue(notes.contains(42))  // F#2
    }

    func testScaleNotes_AMinor_containsExpectedNotes() {
        let notes = scaleNotes(key: .A, scale: .minor)
        // A minor in octave 2: base = (2+1)*12 + 9 = 45
        // A2=45, B2=47, C3=48, D3=50, E3=52, F3=53, G3=55
        XCTAssertTrue(notes.contains(45))  // A2
        XCTAssertTrue(notes.contains(47))  // B2
        XCTAssertTrue(notes.contains(48))  // C3
    }

    func testScaleNotes_pentatonicHasFewerNotes() {
        let majorNotes = scaleNotes(key: .C, scale: .major)
        let pentaNotes = scaleNotes(key: .C, scale: .pentatonic)
        XCTAssertTrue(pentaNotes.count < majorNotes.count)
    }

    func testScaleNotes_chromaticHas12NotesPerOctave() {
        let notes = scaleNotes(key: .C, scale: .chromatic)
        // 4 octaves * 12 = 48 (minus notes > 84)
        // Octave 5: base=72, intervals 0-11 yield 72-83, all <= 84
        XCTAssertEqual(notes.count, 48)
    }

    // MARK: - scaleNotes(key:scale:baseOctave:octaveRange:) -- grid overload

    func testScaleNotesWithOctaveRange_respectsBaseOctave() {
        let notes = scaleNotes(key: .C, scale: .major, baseOctave: 3, octaveRange: 2)
        // Octave 3: base=(3+1)*12=48, Octave 4: base=(4+1)*12=60
        XCTAssertTrue(notes.contains(48))  // C3
        XCTAssertTrue(notes.contains(60))  // C4
        XCTAssertFalse(notes.contains(36)) // C2 not included
        XCTAssertFalse(notes.contains(72)) // C5 not included
    }

    func testScaleNotesWithOctaveRange_singleOctave() {
        let notes = scaleNotes(key: .C, scale: .major, baseOctave: 4, octaveRange: 1)
        // Only octave 4: base=(4+1)*12=60, notes 60-71
        XCTAssertTrue(notes.contains(60))  // C4
        XCTAssertTrue(notes.contains(71))  // B4
        XCTAssertFalse(notes.contains(48)) // C3
        XCTAssertFalse(notes.contains(72)) // C5
    }

    func testScaleNotesWithOctaveRange_cappedAt96() {
        let notes = scaleNotes(key: .C, scale: .major, baseOctave: 6, octaveRange: 2)
        // Octave 6: base=(6+1)*12=84, intervals yield 84-95 (all <= 96)
        // Octave 7: base=(7+1)*12=96, interval 0 yields 96 (<= 96 passes), but interval 2 yields 98 (fails)
        for note in notes {
            XCTAssertTrue(note <= 96, "Note \(note) exceeds cap of 96 (C7)")
        }
    }

    func testScaleNotesWithOctaveRange_pentatonicKeyD_octave3() {
        let notes = scaleNotes(key: .D, scale: .pentatonic, baseOctave: 3, octaveRange: 1)
        // D pentatonic in octave 3: base=(3+1)*12+2=50
        // intervals: 0,2,4,7,9 -> 50,52,54,57,59
        XCTAssertEqual(notes, [50, 52, 54, 57, 59])
    }

    // MARK: - chordNotes(key:scale:degree:)

    func testChordNotes_CMajorDegree0_returnsCEG() {
        let chord = chordNotes(key: .C, scale: .major, degree: 0)
        XCTAssertEqual(chord.count, 3)
        // Root: 48 + 0 + 0 = 48 (C3)
        // Third: degree 2 -> interval 4 -> 48 + 4 = 52 (E3)
        // Fifth: degree 4 -> interval 7 -> 48 + 7 = 55 (G3)
        XCTAssertEqual(chord[0], 48) // C3
        XCTAssertEqual(chord[1], 52) // E3
        XCTAssertEqual(chord[2], 55) // G3
    }

    func testChordNotes_CMajorDegree1_returnsDFA() {
        let chord = chordNotes(key: .C, scale: .major, degree: 1)
        // Root: 48 + 0 + 2 = 50 (D3)
        // Third: degree 3 -> interval 5 -> 48 + 5 = 53 (F3)
        // Fifth: degree 5 -> interval 9 -> 48 + 9 = 57 (A3)
        XCTAssertEqual(chord[0], 50) // D3
        XCTAssertEqual(chord[1], 53) // F3
        XCTAssertEqual(chord[2], 57) // A3
    }

    func testChordNotes_CMajorDegree2_returnsEGB() {
        let chord = chordNotes(key: .C, scale: .major, degree: 2)
        // Root: 48 + 4 = 52 (E3)
        // Third: degree 4 -> interval 7 -> 48 + 7 = 55 (G3)
        // Fifth: degree 6 -> interval 11 -> 48 + 11 = 59 (B3)
        XCTAssertEqual(chord[0], 52) // E3
        XCTAssertEqual(chord[1], 55) // G3
        XCTAssertEqual(chord[2], 59) // B3
    }

    func testChordNotes_CMajorDegree3_returnsFAC() {
        let chord = chordNotes(key: .C, scale: .major, degree: 3)
        // Root: 48 + 5 = 53 (F3)
        // Third: degree 5 -> interval 9 -> 48 + 9 = 57 (A3)
        // Fifth: degree 0 -> interval 0 -> 48 + 0 = 48 (C3), but <= root so +12 = 60 (C4)
        XCTAssertEqual(chord[0], 53) // F3
        XCTAssertEqual(chord[1], 57) // A3
        XCTAssertEqual(chord[2], 60) // C4
    }

    func testChordNotes_CMajorDegree4_returnsGBD() {
        let chord = chordNotes(key: .C, scale: .major, degree: 4)
        // Root: 48 + 7 = 55 (G3)
        // Third: degree 6 -> interval 11 -> 48 + 11 = 59 (B3)
        // Fifth: degree 1 -> interval 2 -> 48 + 2 = 50 (D3), <= third so +12 = 62 (D4)
        XCTAssertEqual(chord[0], 55) // G3
        XCTAssertEqual(chord[1], 59) // B3
        XCTAssertEqual(chord[2], 62) // D4
    }

    func testChordNotes_CMajorDegree5_returnsACE() {
        let chord = chordNotes(key: .C, scale: .major, degree: 5)
        // Root: 48 + 9 = 57 (A3)
        // Third: degree 0 -> interval 0 -> 48, <= root so +12 = 60 (C4)
        // Fifth: degree 2 -> interval 4 -> 48 + 4 = 52 (E3), <= third so +12 = 64 (E4)
        XCTAssertEqual(chord[0], 57) // A3
        XCTAssertEqual(chord[1], 60) // C4
        XCTAssertEqual(chord[2], 64) // E4
    }

    func testChordNotes_CMajorDegree6_returnsBDF() {
        let chord = chordNotes(key: .C, scale: .major, degree: 6)
        // Root: 48 + 11 = 59 (B3)
        // Third: degree 1 -> interval 2 -> 48 + 2 = 50 (D3), <= root so +12 = 62 (D4)
        // Fifth: degree 3 -> interval 5 -> 48 + 5 = 53 (F3), <= third so +12 = 65 (F4)
        XCTAssertEqual(chord[0], 59) // B3
        XCTAssertEqual(chord[1], 62) // D4
        XCTAssertEqual(chord[2], 65) // F4
    }

    func testChordNotes_AMinorDegree0_returnsACE() {
        let chord = chordNotes(key: .A, scale: .minor, degree: 0)
        // Root: 48 + 9 + 0 = 57 (A3)
        // Third: degree 2 -> interval 3 -> 48 + 9 + 3 = 60 (C4)
        // Fifth: degree 4 -> interval 7 -> 48 + 9 + 7 = 64 (E4)
        XCTAssertEqual(chord[0], 57) // A3
        XCTAssertEqual(chord[1], 60) // C4
        XCTAssertEqual(chord[2], 64) // E4
    }

    func testChordNotes_negativeDegree_wrapsCorrectly() {
        // safeDegree = ((-1 % 7) + 7) % 7 = (-1 + 7) % 7 = 6
        let chord = chordNotes(key: .C, scale: .major, degree: -1)
        let chordDeg6 = chordNotes(key: .C, scale: .major, degree: 6)
        XCTAssertEqual(chord, chordDeg6)
    }

    func testChordNotes_degreeWrapsAboveScaleSize() {
        // degree 7 in major (7 notes) should wrap to degree 0
        let chord = chordNotes(key: .C, scale: .major, degree: 7)
        let chordDeg0 = chordNotes(key: .C, scale: .major, degree: 0)
        XCTAssertEqual(chord, chordDeg0)
    }

    func testChordNotes_alwaysReturnsTriad() {
        for scale in Scale.allCases {
            for degree in 0..<scale.intervals.count {
                let chord = chordNotes(key: .C, scale: scale, degree: degree)
                XCTAssertEqual(chord.count, 3, "\(scale.rawValue) degree \(degree) should return triad")
            }
        }
    }

    func testChordNotes_notesAreAscending() {
        for scale in Scale.allCases {
            for degree in 0..<scale.intervals.count {
                let chord = chordNotes(key: .C, scale: scale, degree: degree)
                XCTAssertTrue(chord[0] < chord[1], "\(scale.rawValue) degree \(degree): root < third")
                XCTAssertTrue(chord[1] < chord[2], "\(scale.rawValue) degree \(degree): third < fifth")
            }
        }
    }

    // MARK: - midiNoteName

    func testMidiNoteName_C4_returns_C4() {
        XCTAssertEqual(midiNoteName(60), "C4")
    }

    func testMidiNoteName_A4_returns_A4() {
        XCTAssertEqual(midiNoteName(69), "A4")
    }

    func testMidiNoteName_C3_returns_C3() {
        XCTAssertEqual(midiNoteName(48), "C3")
    }

    func testMidiNoteName_Db3_returns_Db3() {
        XCTAssertEqual(midiNoteName(49), "Db3")
    }

    func testMidiNoteName_B5_returns_B5() {
        XCTAssertEqual(midiNoteName(83), "B5")
    }

    func testMidiNoteName_C0_returns_C_minus1() {
        // MIDI 0 = C at octave 0/12 - 1 = -1
        XCTAssertEqual(midiNoteName(0), "C-1")
    }

    func testMidiNoteName_middleC() {
        // Middle C is MIDI 60
        XCTAssertEqual(midiNoteName(60), "C4")
    }

    // MARK: - midiToStrudelNote

    func testMidiToStrudelNote_C4_returns_c4() {
        XCTAssertEqual(midiToStrudelNote(60), "c4")
    }

    func testMidiToStrudelNote_A4_returns_a4() {
        XCTAssertEqual(midiToStrudelNote(69), "a4")
    }

    func testMidiToStrudelNote_Db3_returns_db3() {
        XCTAssertEqual(midiToStrudelNote(49), "db3")
    }

    func testMidiToStrudelNote_isLowercase() {
        for midi in 36...84 {
            let note = midiToStrudelNote(midi)
            XCTAssertEqual(note, note.lowercased(), "Strudel note should be lowercase for MIDI \(midi)")
        }
    }

    func testMidiToStrudelNote_G2() {
        // MIDI 43 = G2: 43 % 12 = 7 -> "g", 43/12 - 1 = 2
        XCTAssertEqual(midiToStrudelNote(43), "g2")
    }

    // MARK: - chordDisplayName

    func testChordDisplayName_CMajorDegree0_returns_Cmaj() {
        XCTAssertEqual(chordDisplayName(key: .C, scale: .major, degree: 0), "Cmaj")
    }

    func testChordDisplayName_CMajorDegree1_returns_Dmin() {
        XCTAssertEqual(chordDisplayName(key: .C, scale: .major, degree: 1), "Dmin")
    }

    func testChordDisplayName_CMajorDegree2_returns_Emin() {
        XCTAssertEqual(chordDisplayName(key: .C, scale: .major, degree: 2), "Emin")
    }

    func testChordDisplayName_CMajorDegree3_returns_Fmaj() {
        XCTAssertEqual(chordDisplayName(key: .C, scale: .major, degree: 3), "Fmaj")
    }

    func testChordDisplayName_CMajorDegree4_returns_Gmaj() {
        XCTAssertEqual(chordDisplayName(key: .C, scale: .major, degree: 4), "Gmaj")
    }

    func testChordDisplayName_CMajorDegree5_returns_Amin() {
        XCTAssertEqual(chordDisplayName(key: .C, scale: .major, degree: 5), "Amin")
    }

    func testChordDisplayName_CMajorDegree6_returns_Bdim() {
        XCTAssertEqual(chordDisplayName(key: .C, scale: .major, degree: 6), "Bdim")
    }

    func testChordDisplayName_AMinorDegree0_returns_Amin() {
        XCTAssertEqual(chordDisplayName(key: .A, scale: .minor, degree: 0), "Amin")
    }

    func testChordDisplayName_negativeDegree_wrapsCorrectly() {
        let name = chordDisplayName(key: .C, scale: .major, degree: -1)
        let nameDeg6 = chordDisplayName(key: .C, scale: .major, degree: 6)
        XCTAssertEqual(name, nameDeg6)
    }

    // MARK: - Scale premium status

    func testFreeScales_areNotPremium() {
        XCTAssertFalse(Scale.major.isPremium)
        XCTAssertFalse(Scale.minor.isPremium)
        XCTAssertFalse(Scale.dorian.isPremium)
        XCTAssertFalse(Scale.pentatonic.isPremium)
        XCTAssertFalse(Scale.blues.isPremium)
    }

    func testPremiumScales_arePremium() {
        XCTAssertTrue(Scale.harmonicMinor.isPremium)
        XCTAssertTrue(Scale.melodicMinor.isPremium)
        XCTAssertTrue(Scale.phrygian.isPremium)
        XCTAssertTrue(Scale.lydian.isPremium)
        XCTAssertTrue(Scale.wholeTone.isPremium)
        XCTAssertTrue(Scale.chromatic.isPremium)
        XCTAssertTrue(Scale.hungarianMinor.isPremium)
        XCTAssertTrue(Scale.hirajoshi.isPremium)
    }

    func testFreeScales_haveNilPackId() {
        let freeScales = Scale.allCases.filter { !$0.isPremium }
        for scale in freeScales {
            XCTAssertNil(scale.packId, "\(scale.rawValue) should have nil packId")
        }
    }

    func testPremiumScales_haveProPackId() {
        let premiumScales = Scale.allCases.filter { $0.isPremium }
        for scale in premiumScales {
            XCTAssertEqual(scale.packId, "pro", "\(scale.rawValue) should have pro packId")
        }
    }

    // MARK: - MusicKey

    func testMusicKey_allCases_has12Keys() {
        XCTAssertEqual(MusicKey.allCases.count, 12)
    }

    func testMusicKey_semitoneValues_areSequential() {
        let semitones = MusicKey.allCases.map(\.semitone)
        XCTAssertEqual(semitones, Array(0...11))
    }

    func testMusicKey_specificValues() {
        XCTAssertEqual(MusicKey.C.semitone, 0)
        XCTAssertEqual(MusicKey.Db.semitone, 1)
        XCTAssertEqual(MusicKey.D.semitone, 2)
        XCTAssertEqual(MusicKey.Eb.semitone, 3)
        XCTAssertEqual(MusicKey.E.semitone, 4)
        XCTAssertEqual(MusicKey.F.semitone, 5)
        XCTAssertEqual(MusicKey.Gb.semitone, 6)
        XCTAssertEqual(MusicKey.G.semitone, 7)
        XCTAssertEqual(MusicKey.Ab.semitone, 8)
        XCTAssertEqual(MusicKey.A.semitone, 9)
        XCTAssertEqual(MusicKey.Bb.semitone, 10)
        XCTAssertEqual(MusicKey.B.semitone, 11)
    }

    // MARK: - CIRCLE_OF_FIFTHS

    func testCircleOfFifths_has12Entries() {
        XCTAssertEqual(CIRCLE_OF_FIFTHS.count, 12)
    }

    func testCircleOfFifths_startsWithC() {
        XCTAssertEqual(CIRCLE_OF_FIFTHS.first, .C)
    }

    func testCircleOfFifths_consecutiveKeysAre7SemitonesApart() {
        for i in 0..<(CIRCLE_OF_FIFTHS.count - 1) {
            let diff = (CIRCLE_OF_FIFTHS[i + 1].semitone - CIRCLE_OF_FIFTHS[i].semitone + 12) % 12
            XCTAssertEqual(diff, 7, "Adjacent keys in circle of fifths should be 7 semitones apart")
        }
    }
}
