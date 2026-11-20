import XCTest
@testable import HandStrudel

/// "Learn to play": capturing a take's notes, fitting them to the posted clip,
/// and turning them into a Learn-mode song.
final class NoteTrackTests: XCTestCase {
    private typealias Note = NoteTrack.Note

    private final class FakeClock {
        var now: CFTimeInterval = 100
    }

    private func capture(_ clock: FakeClock) -> PerformanceNoteCapture {
        PerformanceNoteCapture(clock: { clock.now })
    }

    private let setup = SoundSetup(instrument: "violin", waveform: "sine", key: .C, scale: .major,
                                   progression: "custom", customDegrees: [0, 3, 4], mode: .scalechordmelody,
                                   bpm: 120, useSoundFont: true, autoStrum: false, padVolume: 0.3,
                                   gridOctave: 3, gridRange: 2)

    // MARK: Capture

    func testCaptureTimesHeldNotesFromStartAndIgnoresOtherPlayers() {
        let clock = FakeClock()
        let notes = capture(clock)
        notes.noteOn(voice: "right", midi: 60, role: .melody)   // before start: ignored
        notes.start()
        clock.now += 0.5
        notes.noteOn(voice: "right", midi: 62, role: .melody)
        notes.noteOn(voice: "jam-peer-1-0", midi: 40, role: .melody)
        notes.oneShot(midi: 50, duration: 0.2, role: .ignored)
        clock.now += 0.25
        notes.noteOff(voice: "right")
        clock.now += 0.25
        notes.oneShot(midi: 64, duration: 0.3, role: .melody)

        XCTAssertEqual(notes.stop(), [Note(t: 0.5, d: 0.25, m: 62), Note(t: 1, d: 0.3, m: 64)])
        XCTAssertFalse(notes.isCapturing)
        XCTAssertEqual(notes.stop(), [], "A stopped capture has nothing left to return.")
    }

    func testCaptureSplitsSlidesAndClosesNotesStillHeldAtStop() {
        let clock = FakeClock()
        let notes = capture(clock)
        notes.start()
        notes.noteOn(voice: "pad0", midi: 48, role: PerformanceNoteCapture.role(forVoice: "pad0"))
        notes.noteOn(voice: "left", midi: 67, role: .melody)
        clock.now += 1
        notes.slide(voice: "left", midi: 69)
        notes.slide(voice: "left", midi: 69)  // same pitch: no new note
        clock.now += 0.5
        notes.noteOn(voice: "left", midi: 71, role: .melody)  // re-strike closes the previous note
        clock.now += 0.5

        XCTAssertEqual(notes.stop(), [
            Note(t: 0, d: 2, m: 48, c: true),
            Note(t: 0, d: 1, m: 67),
            Note(t: 1, d: 0.5, m: 69),
            Note(t: 1.5, d: 0.5, m: 71),
        ])
    }

    // MARK: Posted timing

    func testPostedTrackFollowsTrimAndHalfSpeed() throws {
        let captured = [
            Note(t: 0.2, d: 0.5, m: 60),   // ends before the trim: dropped
            Note(t: 0.8, d: 0.6, m: 62),   // starts before the trim: clipped to it
            Note(t: 2, d: 1, m: 64),
            Note(t: 3.5, d: 1, m: 65),     // runs past the trim end: clipped
            Note(t: 5, d: 1, m: 67),       // after the trim: dropped
        ]
        let track = try XCTUnwrap(NoteTrack.posted(from: captured, trimStart: 1, trimEnd: 4, outputScale: 0.5))
        XCTAssertEqual(track.notes, [
            Note(t: 0, d: 0.2, m: 62),
            Note(t: 0.5, d: 0.5, m: 64),
            Note(t: 1.25, d: 0.25, m: 65),
        ])
        XCTAssertTrue(track.isValid)
        XCTAssertNil(NoteTrack.posted(from: captured, trimStart: 6, trimEnd: 7, outputScale: 1))
        XCTAssertNil(NoteTrack.posted(from: [], trimStart: nil, trimEnd: nil, outputScale: 1))
    }

    func testPostedTrackIsCappedAndRoundTripsCompactly() throws {
        let many = (0..<700).map { Note(t: Double($0) * 0.05, d: 0.05, m: 60) }
        let track = try XCTUnwrap(NoteTrack.posted(from: many, trimStart: nil, trimEnd: nil, outputScale: 1))
        XCTAssertEqual(track.notes.count, NoteTrack.maxNotes)
        let data = try JSONEncoder().encode(track)
        XCTAssertLessThan(data.count, 32_768, "Must fit the database's size check.")
        XCTAssertEqual(try JSONDecoder().decode(NoteTrack.self, from: data), track)
        let json = try XCTUnwrap(String(data: JSONEncoder().encode(NoteTrack(notes: [Note(t: 1, d: 0.5, m: 60)])), encoding: .utf8))
        XCTAssertFalse(json.contains("\"c\""), "Melody notes leave the chord flag out.")
    }

    func testDraftKeepsCapturedNotesAndExposesThePostedTrack() throws {
        var draft = RecordingDraft(id: UUID(), createdAt: Date(), instrument: "Violin", mode: "scale")
        XCTAssertNil(draft.postedNoteTrack)
        draft.recordedAtHalfSpeed = true
        draft.trimStart = 1
        draft.capturedNotes = [Note(t: 2, d: 1, m: 60)]
        let decoded = try JSONDecoder().decode(RecordingDraft.self, from: JSONEncoder().encode(draft))
        XCTAssertEqual(decoded.capturedNotes, draft.capturedNotes)
        XCTAssertEqual(decoded.postedNoteTrack?.notes, [Note(t: 0.5, d: 0.5, m: 60)])
    }

    // MARK: Learn song

    func testLearnSongTeachesMelodyOnScaleLanesAtTheSetupTempo() throws {
        let lanes = scaleNotes(key: .C, scale: .major, baseOctave: 4, octaveRange: 1)
        let track = NoteTrack(notes: [
            Note(t: 0, d: 2, m: 48, c: true),   // chord tone: skipped while there is melody
            Note(t: 0, d: 0.5, m: lanes[0]),
            Note(t: 0.5, d: 0.5, m: lanes[2]),
            Note(t: 0.52, d: 0.1, m: lanes[2]), // re-strike on top of the same lane: dropped
            Note(t: 1, d: 0.25, m: lanes[4] + 24), // two octaves up: folded into range
        ])
        let song = try XCTUnwrap(track.learnSong(title: "@maya's part", key: .C, scale: .major, bpm: 120, scaleNotes: lanes))
        XCTAssertEqual(song.name, "@maya's part")
        XCTAssertEqual(song.bpm, 120)
        XCTAssertEqual(song.suggestedKey, .C)
        XCTAssertEqual(song.suggestedScale, .major)
        XCTAssertEqual(song.degreeNotes.map(\.degree), [0, 2, 4])
        XCTAssertEqual(song.degreeNotes.map(\.startBeat), [0, 1, 2])
        XCTAssertEqual(song.degreeNotes.map(\.durationBeats), [1, 1, 0.5])
        XCTAssertEqual(song.resolve(scaleNotes: lanes).map(\.midi), [lanes[0], lanes[2], lanes[4]])
    }

    func testLearnSongFallsBackToChordRootsWhenATakeHasNoMelody() throws {
        let lanes = scaleNotes(key: .C, scale: .major, baseOctave: 4, octaveRange: 2)
        let track = NoteTrack(notes: [
            Note(t: 0, d: 1, m: 64, c: true), Note(t: 0.01, d: 1, m: 60, c: true), Note(t: 0.02, d: 1, m: 67, c: true),
            Note(t: 1, d: 1, m: 65, c: true), Note(t: 1, d: 1, m: 69, c: true),
        ])
        let song = try XCTUnwrap(track.learnSong(title: "Chords", key: .C, scale: .major, bpm: 60, scaleNotes: lanes))
        XCTAssertEqual(song.resolve(scaleNotes: lanes).map(\.midi), [64, 65],
                       "Each chord is taught by the first tone struck, once.")
        XCTAssertNil(NoteTrack(notes: []).learnSong(title: "Empty", key: .C, scale: .major, bpm: 60, scaleNotes: lanes))
        XCTAssertNil(track.learnSong(title: "No lanes", key: .C, scale: .major, bpm: 60, scaleNotes: []))
    }

    func testLaneFoldsOutOfRangePitchesToTheNearestScaleNote() {
        let lanes = [60, 62, 64, 65, 67, 69, 71]
        XCTAssertEqual(NoteTrack.lane(for: 64, in: lanes), 2)
        XCTAssertEqual(NoteTrack.lane(for: 63, in: lanes), 1, "Ties go to the lower lane.")
        XCTAssertEqual(NoteTrack.lane(for: 40, in: lanes), 2)
        XCTAssertEqual(NoteTrack.lane(for: 96, in: lanes), 6, "C7 folds to C5, nearest the top lane.")
    }

    // MARK: Sharing and decoding

    func testNotesAreSharedOnlyWithThePlayablePreset() {
        var options = PostSharingOptions()
        let track = NoteTrack(notes: [Note(t: 0, d: 1, m: 60)])
        XCTAssertEqual(options.sharedNotes(track, setup: setup), track)
        XCTAssertNil(options.sharedNotes(track, setup: nil))
        XCTAssertNil(options.sharedNotes(NoteTrack(notes: []), setup: setup))
        options.sharePlayablePreset = false
        XCTAssertNil(options.sharedNotes(track, setup: setup))
    }

    func testPostFieldsCarryTheTrackUnderItsDatabaseName() throws {
        let fields = VideoPostFields(caption: "", instrument: nil, mode: nil, durationS: 7, width: 720, height: 1560,
                                     soundSetup: setup, noteTrack: NoteTrack(notes: [Note(t: 0, d: 1, m: 60)]))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(fields)) as? [String: Any])
        let track = try XCTUnwrap(json["note_track"] as? [String: Any])
        XCTAssertEqual(track["v"] as? Int, 1)
        XCTAssertEqual((track["notes"] as? [[String: Any]])?.first?["m"] as? Int, 60)
    }

    func testVideoKnowsWhetherItHasNotesToLearn() throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        func video(_ extra: [String: Any]) throws -> Video {
            var row: [String: Any] = [
                "id": UUID().uuidString, "user_id": UUID().uuidString, "like_count": 0, "caption": "Take",
                "video_key": "clip.mp4", "thumb_key": "cover.jpg", "created_at": "2026-11-19T00:00:00Z",
                "username": "maya", "sound_setup": try JSONSerialization.jsonObject(with: JSONEncoder().encode(setup)),
            ]
            row.merge(extra) { $1 }
            return try decoder.decode(Video.self, from: JSONSerialization.data(withJSONObject: row))
        }
        XCTAssertEqual(try video(["has_note_track": true]).hasNoteTrack, true)
        XCTAssertEqual(try video(["has_note_track": false]).hasNoteTrack, false)
        XCTAssertNil(try video([:]).hasNoteTrack)
        XCTAssertEqual(try video(["note_track": ["v": 1, "notes": [["t": 0, "d": 1, "m": 60]]]]).hasNoteTrack, true)
        XCTAssertEqual(try video(["note_track": NSNull()]).hasNoteTrack, false)

        let request = try XCTUnwrap(LearnToPlayRequest(video: video(["has_note_track": true])))
        XCTAssertEqual(request.title, "@maya's part")
        XCTAssertEqual(request.setup, setup)
        XCTAssertNil(LearnToPlayRequest(video: try video(["has_note_track": false])))
    }
}
