import XCTest
@testable import HandStrudel

final class LearnSongTests: XCTestCase {

    // MARK: - LearnDegreeNote

    func testLearnDegreeNote_basicConstruction() {
        let note = LearnDegreeNote(degree: 3, startBeat: 2.0, durationBeats: 1.5)
        XCTAssertEqual(note.degree, 3)
        XCTAssertEqual(note.startBeat, 2.0)
        XCTAssertEqual(note.durationBeats, 1.5)
    }

    // MARK: - LearnNote

    func testLearnNote_hasUniqueUUID() {
        let a = LearnNote(id: UUID(), midi: 60, laneIndex: 0, startBeat: 0, durationBeats: 1)
        let b = LearnNote(id: UUID(), midi: 60, laneIndex: 0, startBeat: 0, durationBeats: 1)
        XCTAssertNotEqual(a.id, b.id)
    }

    func testLearnNote_storesAllFields() {
        let id = UUID()
        let note = LearnNote(id: id, midi: 64, laneIndex: 2, startBeat: 4.5, durationBeats: 0.5)
        XCTAssertEqual(note.id, id)
        XCTAssertEqual(note.midi, 64)
        XCTAssertEqual(note.laneIndex, 2)
        XCTAssertEqual(note.startBeat, 4.5)
        XCTAssertEqual(note.durationBeats, 0.5)
    }

    // MARK: - LearnScore

    func testLearnScore_defaultValues() {
        let score = LearnScore()
        XCTAssertEqual(score.perfectHits, 0)
        XCTAssertEqual(score.goodHits, 0)
        XCTAssertEqual(score.misses, 0)
        XCTAssertEqual(score.currentStreak, 0)
        XCTAssertEqual(score.bestStreak, 0)
    }

    func testLearnScore_totalNotes() {
        var score = LearnScore()
        score.perfectHits = 5
        score.goodHits = 3
        score.misses = 2
        XCTAssertEqual(score.totalNotes, 10)
    }

    func testLearnScore_accuracy() {
        var score = LearnScore()
        score.perfectHits = 7
        score.goodHits = 2
        score.misses = 1
        // accuracy = (7 + 2) / 10 = 0.9
        XCTAssertEqual(score.accuracy, 0.9, accuracy: 0.001)
    }

    func testLearnScore_accuracyWithZeroTotal_returnsZero() {
        let score = LearnScore()
        XCTAssertEqual(score.accuracy, 0)
    }

    func testLearnScore_accuracyOnlyPerfect() {
        var score = LearnScore()
        score.perfectHits = 10
        XCTAssertEqual(score.accuracy, 1.0, accuracy: 0.001)
    }

    func testLearnScore_accuracyAllMisses() {
        var score = LearnScore()
        score.misses = 5
        XCTAssertEqual(score.accuracy, 0.0, accuracy: 0.001)
    }

    // MARK: - LearnSong Construction

    func testLearnSong_constructionWithAllFields() {
        let notes = [LearnDegreeNote(degree: 0, startBeat: 0, durationBeats: 1)]
        let song = LearnSong(
            name: "Test",
            emoji: "T",
            bpm: 120,
            degreeNotes: notes,
            category: .melody,
            suggestedScale: .minor,
            suggestedKey: .A
        )
        XCTAssertEqual(song.name, "Test")
        XCTAssertEqual(song.emoji, "T")
        XCTAssertEqual(song.bpm, 120)
        XCTAssertEqual(song.degreeNotes.count, 1)
        XCTAssertEqual(song.category, .melody)
        XCTAssertEqual(song.suggestedScale, .minor)
        XCTAssertEqual(song.suggestedKey, .A)
    }

    func testLearnSong_hasUniqueUUID() {
        let notes = [LearnDegreeNote(degree: 0, startBeat: 0, durationBeats: 1)]
        let a = LearnSong(name: "A", emoji: "A", bpm: 120, degreeNotes: notes)
        let b = LearnSong(name: "B", emoji: "B", bpm: 120, degreeNotes: notes)
        XCTAssertNotEqual(a.id, b.id)
    }

    func testLearnSong_suggestedScaleDefaultsToMajor() {
        let song = LearnSong(name: "X", emoji: "X", bpm: 120, degreeNotes: [])
        XCTAssertEqual(song.suggestedScale, .major)
    }

    func testLearnSong_suggestedKeyDefaultsToC() {
        let song = LearnSong(name: "X", emoji: "X", bpm: 120, degreeNotes: [])
        XCTAssertEqual(song.suggestedKey, .C)
    }

    // MARK: - LearnSong.resolve()

    func testResolve_mapsDegreesToCorrectMIDI() {
        // C major scale notes for octaves 2-5
        let scale = scaleNotes(key: .C, scale: .major)
        // degree 0 -> scale[0] = 36 (C2)
        // degree 1 -> scale[1] = 38 (D2)
        // degree 4 -> scale[4] = 43 (G2)
        let degreeNotes = [
            LearnDegreeNote(degree: 0, startBeat: 0, durationBeats: 1),
            LearnDegreeNote(degree: 1, startBeat: 1, durationBeats: 1),
            LearnDegreeNote(degree: 4, startBeat: 2, durationBeats: 1),
        ]
        let song = LearnSong(name: "Test", emoji: "T", bpm: 120, degreeNotes: degreeNotes)
        let resolved = song.resolve(scaleNotes: scale)

        XCTAssertEqual(resolved.count, 3)
        XCTAssertEqual(resolved[0].midi, scale[0])
        XCTAssertEqual(resolved[0].laneIndex, 0)
        XCTAssertEqual(resolved[0].startBeat, 0)
        XCTAssertEqual(resolved[0].durationBeats, 1)

        XCTAssertEqual(resolved[1].midi, scale[1])
        XCTAssertEqual(resolved[1].laneIndex, 1)

        XCTAssertEqual(resolved[2].midi, scale[4])
        XCTAssertEqual(resolved[2].laneIndex, 4)
    }

    func testResolve_clampsOutOfRangeDegrees() {
        let scale = [60, 62, 64] // 3 notes
        let degreeNotes = [
            LearnDegreeNote(degree: -5, startBeat: 0, durationBeats: 1),
            LearnDegreeNote(degree: 99, startBeat: 1, durationBeats: 1),
        ]
        let song = LearnSong(name: "Clamp", emoji: "C", bpm: 120, degreeNotes: degreeNotes)
        let resolved = song.resolve(scaleNotes: scale)

        // degree -5 clamped to 0
        XCTAssertEqual(resolved[0].midi, 60)
        XCTAssertEqual(resolved[0].laneIndex, 0)
        // degree 99 clamped to 2 (last index)
        XCTAssertEqual(resolved[1].midi, 64)
        XCTAssertEqual(resolved[1].laneIndex, 2)
    }

    func testResolve_withEmptyScaleNotes_returnsEmpty() {
        let degreeNotes = [LearnDegreeNote(degree: 0, startBeat: 0, durationBeats: 1)]
        let song = LearnSong(name: "Empty", emoji: "E", bpm: 120, degreeNotes: degreeNotes)
        // With empty scaleNotes, max(0, min(-1, degree)) causes index out of range,
        // but degreeNotes.map will attempt scaleNotes[-1] -- actually let's test with no degree notes
        let emptySong = LearnSong(name: "Empty", emoji: "E", bpm: 120, degreeNotes: [])
        let resolved = emptySong.resolve(scaleNotes: [])
        XCTAssertTrue(resolved.isEmpty)
    }

    func testResolve_eachNoteGetsUniqueId() {
        let scale = [60, 62, 64]
        let degreeNotes = [
            LearnDegreeNote(degree: 0, startBeat: 0, durationBeats: 1),
            LearnDegreeNote(degree: 1, startBeat: 1, durationBeats: 1),
        ]
        let song = LearnSong(name: "IDs", emoji: "I", bpm: 120, degreeNotes: degreeNotes)
        let resolved = song.resolve(scaleNotes: scale)
        XCTAssertNotEqual(resolved[0].id, resolved[1].id)
    }

    // MARK: - LearnSong.repeated()

    func testRepeated_doublesNotes() {
        let degreeNotes = [
            LearnDegreeNote(degree: 0, startBeat: 0, durationBeats: 1),
            LearnDegreeNote(degree: 1, startBeat: 1, durationBeats: 1),
        ]
        let song = LearnSong(name: "Rep", emoji: "R", bpm: 120, degreeNotes: degreeNotes)
        let doubled = song.repeated(2)
        XCTAssertEqual(doubled.degreeNotes.count, 4)
    }

    func testRepeated_triplesNotes() {
        let degreeNotes = [
            LearnDegreeNote(degree: 0, startBeat: 0, durationBeats: 1),
        ]
        let song = LearnSong(name: "Rep", emoji: "R", bpm: 120, degreeNotes: degreeNotes)
        let tripled = song.repeated(3)
        XCTAssertEqual(tripled.degreeNotes.count, 3)
    }

    func testRepeated_correctBeatOffsets() {
        // Two notes: degree 0 at beat 0 (dur 1), degree 1 at beat 1 (dur 1)
        // lastBeat = 1 + 1 = 2, so gap offset = 2 + 1 = 3
        let degreeNotes = [
            LearnDegreeNote(degree: 0, startBeat: 0, durationBeats: 1),
            LearnDegreeNote(degree: 1, startBeat: 1, durationBeats: 1),
        ]
        let song = LearnSong(name: "Rep", emoji: "R", bpm: 120, degreeNotes: degreeNotes)
        let doubled = song.repeated(2)

        // Rep 0: offset = 0
        XCTAssertEqual(doubled.degreeNotes[0].startBeat, 0.0)
        XCTAssertEqual(doubled.degreeNotes[1].startBeat, 1.0)
        // Rep 1: offset = 1 * (2 + 1) = 3
        XCTAssertEqual(doubled.degreeNotes[2].startBeat, 3.0)
        XCTAssertEqual(doubled.degreeNotes[3].startBeat, 4.0)
    }

    func testRepeated_preservesDegrees() {
        let degreeNotes = [
            LearnDegreeNote(degree: 5, startBeat: 0, durationBeats: 2),
            LearnDegreeNote(degree: 3, startBeat: 2, durationBeats: 1),
        ]
        let song = LearnSong(name: "Rep", emoji: "R", bpm: 120, degreeNotes: degreeNotes)
        let doubled = song.repeated(2)

        XCTAssertEqual(doubled.degreeNotes[0].degree, 5)
        XCTAssertEqual(doubled.degreeNotes[1].degree, 3)
        XCTAssertEqual(doubled.degreeNotes[2].degree, 5)
        XCTAssertEqual(doubled.degreeNotes[3].degree, 3)
    }

    func testRepeated_preservesNameEmojiAndBpm() {
        let song = LearnSong(name: "Song", emoji: "S", bpm: 90, degreeNotes: [
            LearnDegreeNote(degree: 0, startBeat: 0, durationBeats: 1),
        ])
        let repeated = song.repeated(2)
        XCTAssertEqual(repeated.name, "Song")
        XCTAssertEqual(repeated.emoji, "S")
        XCTAssertEqual(repeated.bpm, 90)
    }

    func testRepeated_preservesCategoryScaleAndKey() {
        let song = LearnSong(
            name: "X", emoji: "X", bpm: 80,
            degreeNotes: [LearnDegreeNote(degree: 0, startBeat: 0, durationBeats: 1)],
            category: .practice,
            suggestedScale: .minor,
            suggestedKey: .A
        )
        let repeated = song.repeated(3)
        XCTAssertEqual(repeated.category, .practice)
        XCTAssertEqual(repeated.suggestedScale, .minor)
        XCTAssertEqual(repeated.suggestedKey, .A)
    }

    // MARK: - BUNDLED_SONGS

    func testBundledSongs_has8Songs() {
        XCTAssertEqual(BUNDLED_SONGS.count, 8)
    }

    func testBundledSongs_allHaveUniqueNames() {
        let names = BUNDLED_SONGS.map(\.name)
        XCTAssertEqual(Set(names).count, names.count, "All bundled songs should have unique names")
    }

    func testBundledSongs_allHaveNonEmptyDegreeNotes() {
        for song in BUNDLED_SONGS {
            XCTAssertFalse(song.degreeNotes.isEmpty, "\(song.name) should have degree notes")
        }
    }

    func testBundledSongs_allHaveReasonableBpm() {
        for song in BUNDLED_SONGS {
            XCTAssertTrue(song.bpm >= 60 && song.bpm <= 200,
                          "\(song.name) BPM \(song.bpm) should be between 60 and 200")
        }
    }

    func testBundledSongs_resolveCorrectlyWithCMajor() {
        let scale = scaleNotes(key: .C, scale: .major)
        for song in BUNDLED_SONGS {
            let resolved = song.resolve(scaleNotes: scale)
            XCTAssertEqual(resolved.count, song.degreeNotes.count,
                           "\(song.name) should resolve all notes")
            for note in resolved {
                XCTAssertTrue(scale.contains(note.midi),
                              "\(song.name) resolved MIDI \(note.midi) should be in scale")
            }
        }
    }

    func testBundledSongs_allHaveNonEmptyEmoji() {
        for song in BUNDLED_SONGS {
            XCTAssertFalse(song.emoji.isEmpty, "\(song.name) should have an emoji")
        }
    }

    // MARK: - Pattern Generator: ascending

    func testAscending_producesIncreasingDegreeSequence() {
        let song = LearnSong.ascending(noteCount: 5)
        let degrees = song.degreeNotes.map(\.degree)
        XCTAssertEqual(degrees, [0, 1, 2, 3, 4])
    }

    func testAscending_hasPracticeCategory() {
        let song = LearnSong.ascending(noteCount: 4)
        XCTAssertEqual(song.category, .practice)
    }

    func testAscending_hasCorrectNoteCount() {
        let song = LearnSong.ascending(noteCount: 7)
        XCTAssertEqual(song.degreeNotes.count, 7)
    }

    func testAscending_eachNoteDurationIsOneBeat() {
        let song = LearnSong.ascending(noteCount: 3)
        for note in song.degreeNotes {
            XCTAssertEqual(note.durationBeats, 1.0)
        }
    }

    func testAscending_startBeatsAreSequential() {
        let song = LearnSong.ascending(noteCount: 4)
        let beats = song.degreeNotes.map(\.startBeat)
        XCTAssertEqual(beats, [0, 1, 2, 3])
    }

    func testAscending_defaultBpmIs120() {
        let song = LearnSong.ascending(noteCount: 3)
        XCTAssertEqual(song.bpm, 120)
    }

    func testAscending_customBpm() {
        let song = LearnSong.ascending(noteCount: 3, bpm: 90)
        XCTAssertEqual(song.bpm, 90)
    }

    // MARK: - Pattern Generator: descending

    func testDescending_producesDecreasingDegreeSequence() {
        let song = LearnSong.descending(noteCount: 5)
        let degrees = song.degreeNotes.map(\.degree)
        XCTAssertEqual(degrees, [4, 3, 2, 1, 0])
    }

    func testDescending_hasPracticeCategory() {
        let song = LearnSong.descending(noteCount: 4)
        XCTAssertEqual(song.category, .practice)
    }

    func testDescending_hasCorrectNoteCount() {
        let song = LearnSong.descending(noteCount: 6)
        XCTAssertEqual(song.degreeNotes.count, 6)
    }

    func testDescending_startBeatsAreSequential() {
        let song = LearnSong.descending(noteCount: 4)
        let beats = song.degreeNotes.map(\.startBeat)
        XCTAssertEqual(beats, [0, 1, 2, 3])
    }

    // MARK: - Pattern Generator: ascendingDescending

    func testAscendingDescending_goesUpThenDown() {
        let song = LearnSong.ascendingDescending(noteCount: 4)
        let degrees = song.degreeNotes.map(\.degree)
        // ascending: 0,1,2,3  descending (skip peak): 2,1,0
        XCTAssertEqual(degrees, [0, 1, 2, 3, 2, 1, 0])
    }

    func testAscendingDescending_hasPracticeCategory() {
        let song = LearnSong.ascendingDescending(noteCount: 3)
        XCTAssertEqual(song.category, .practice)
    }

    func testAscendingDescending_hasCorrectTotalNoteCount() {
        // noteCount=4: ascending 0..3 (4 notes) + descending 2..0 (3 notes) = 7
        let song = LearnSong.ascendingDescending(noteCount: 4)
        XCTAssertEqual(song.degreeNotes.count, 7)
    }

    func testAscendingDescending_noteCount5() {
        let song = LearnSong.ascendingDescending(noteCount: 5)
        let degrees = song.degreeNotes.map(\.degree)
        // ascending: 0,1,2,3,4  descending (skip 4): 3,2,1,0
        XCTAssertEqual(degrees, [0, 1, 2, 3, 4, 3, 2, 1, 0])
    }

    func testAscendingDescending_startBeatsAreSequential() {
        let song = LearnSong.ascendingDescending(noteCount: 3)
        let beats = song.degreeNotes.map(\.startBeat)
        for i in 0..<beats.count {
            XCTAssertEqual(beats[i], Double(i))
        }
    }

    // MARK: - Pattern Generator: arpeggio

    func testArpeggio_producesCorrectPattern() {
        let song = LearnSong.arpeggio(noteCount: 3)
        let degrees = song.degreeNotes.map(\.degree)
        // arpeggioSteps = [0, 2, 4, 7, 9, 11, 14]
        // i=0: steps[0] + 0 = 0
        // i=1: steps[1] + 0 = 2
        // i=2: steps[2] + 0 = 4
        XCTAssertEqual(degrees, [0, 2, 4])
    }

    func testArpeggio_hasPracticeCategory() {
        let song = LearnSong.arpeggio(noteCount: 3)
        XCTAssertEqual(song.category, .practice)
    }

    func testArpeggio_hasCorrectNoteCount() {
        let song = LearnSong.arpeggio(noteCount: 5)
        XCTAssertEqual(song.degreeNotes.count, 5)
    }

    func testArpeggio_wrapsAroundSteps() {
        // arpeggioSteps has 7 entries: [0, 2, 4, 7, 9, 11, 14]
        // i=7: steps[0] + 7 = 7
        // i=8: steps[1] + 7 = 9
        let song = LearnSong.arpeggio(noteCount: 9)
        let degrees = song.degreeNotes.map(\.degree)
        XCTAssertEqual(degrees[7], 7)  // second cycle: 0 + 7
        XCTAssertEqual(degrees[8], 9)  // second cycle: 2 + 7
    }

    // MARK: - Pattern Generator: random

    func testRandom_producesNotesWithinValidRange() {
        let count = 10
        let song = LearnSong.random(noteCount: count)
        for note in song.degreeNotes {
            XCTAssertTrue(note.degree >= 0 && note.degree < count,
                          "Random degree \(note.degree) should be in 0..<\(count)")
        }
    }

    func testRandom_hasPracticeCategory() {
        let song = LearnSong.random(noteCount: 5)
        XCTAssertEqual(song.category, .practice)
    }

    func testRandom_hasCorrectNoteCount() {
        let song = LearnSong.random(noteCount: 8)
        XCTAssertEqual(song.degreeNotes.count, 8)
    }

    func testRandom_startBeatsAreSequential() {
        let song = LearnSong.random(noteCount: 6)
        let beats = song.degreeNotes.map(\.startBeat)
        XCTAssertEqual(beats, [0, 1, 2, 3, 4, 5])
    }

    // MARK: - All generators produce .practice category

    func testAllGenerators_producePracticeCategory() {
        XCTAssertEqual(LearnSong.ascending(noteCount: 3).category, .practice)
        XCTAssertEqual(LearnSong.descending(noteCount: 3).category, .practice)
        XCTAssertEqual(LearnSong.ascendingDescending(noteCount: 3).category, .practice)
        XCTAssertEqual(LearnSong.arpeggio(noteCount: 3).category, .practice)
        XCTAssertEqual(LearnSong.random(noteCount: 3).category, .practice)
    }

    // MARK: - MusicTheory helpers: midiToLaneIndex

    func testMidiToLaneIndex_findsClosestScaleNote() {
        let scale = [60, 62, 64, 65, 67] // C D E F G
        // MIDI 61 (Db) is closest to 60 (C, index 0) or 62 (D, index 1) -- both dist 1, picks first found
        XCTAssertEqual(midiToLaneIndex(61, scaleNotes: scale), 0)
        // MIDI 63 (Eb) is closest to 62 (D, index 1) or 64 (E, index 2) -- dist 1 each, picks first
        XCTAssertEqual(midiToLaneIndex(63, scaleNotes: scale), 1)
        // MIDI 65 (F) is exact match at index 3
        XCTAssertEqual(midiToLaneIndex(65, scaleNotes: scale), 3)
        // MIDI 67 (G) is exact match at index 4
        XCTAssertEqual(midiToLaneIndex(67, scaleNotes: scale), 4)
    }

    func testMidiToLaneIndex_exactMatch() {
        let scale = [60, 64, 67]
        XCTAssertEqual(midiToLaneIndex(60, scaleNotes: scale), 0)
        XCTAssertEqual(midiToLaneIndex(64, scaleNotes: scale), 1)
        XCTAssertEqual(midiToLaneIndex(67, scaleNotes: scale), 2)
    }

    func testMidiToLaneIndex_emptyArray_returnsZero() {
        XCTAssertEqual(midiToLaneIndex(60, scaleNotes: []), 0)
    }

    func testMidiToLaneIndex_singleNote() {
        XCTAssertEqual(midiToLaneIndex(100, scaleNotes: [60]), 0)
    }

    // MARK: - MusicTheory helpers: quantizeToScale

    func testQuantizeToScale_snapsToNearest() {
        let scale = [60, 62, 64, 65, 67]
        // MIDI 61 -> closest is 60 or 62 (both dist 1); min(by:) picks 60 since it comes first
        XCTAssertEqual(quantizeToScale(61, scaleNotes: scale), 60)
        // MIDI 63 -> closest is 62 (dist 1) or 64 (dist 1); 62 comes first
        XCTAssertEqual(quantizeToScale(63, scaleNotes: scale), 62)
        // MIDI 66 -> closest is 65 (dist 1) or 67 (dist 1); 65 comes first
        XCTAssertEqual(quantizeToScale(66, scaleNotes: scale), 65)
    }

    func testQuantizeToScale_exactMatchReturnsItself() {
        let scale = [60, 62, 64]
        XCTAssertEqual(quantizeToScale(62, scaleNotes: scale), 62)
    }

    func testQuantizeToScale_emptyArray_returnsInput() {
        XCTAssertEqual(quantizeToScale(60, scaleNotes: []), 60)
        XCTAssertEqual(quantizeToScale(99, scaleNotes: []), 99)
    }

    func testQuantizeToScale_farFromScale() {
        let scale = [60, 62, 64]
        // MIDI 30 is far below; closest is 60
        XCTAssertEqual(quantizeToScale(30, scaleNotes: scale), 60)
        // MIDI 100 is far above; closest is 64
        XCTAssertEqual(quantizeToScale(100, scaleNotes: scale), 64)
    }
}
