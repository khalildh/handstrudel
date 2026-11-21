import XCTest
@testable import HandStrudel

/// Instruments that travel with posts: the document model, capture at record → posted fields,
/// remix copies, `.handstrudel-instrument` export/import and the My instruments store.
final class PostInstrumentTests: XCTestCase {
    /// A valid instrument with fields this app version doesn't read (an AI marker, a future field).
    private static let generatedJSON = """
    {"format":"handstrudel.instrument","format_version":1,"id":"gen.orbit","name":"  Orbit  ",
     "ai_generated":true,"generator":{"kind":"ai","prompt":"a wheel for small hands"},"future_field":[1,2.5,"x",null],
     "surface":{"type":"split_wheel","radius":1.3,"rest_radius":0.3,"octave_band_radius":0.7},
     "chords":{"side":"right"},"notes":{"source":"scale_one_octave","octave_band":true}}
    """

    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("PostInstrumentTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func generated() throws -> InstrumentDocument { try InstrumentDocument(data: Data(Self.generatedJSON.utf8)) }

    private func object(_ data: Data) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    // MARK: Documents

    func testDocumentKeepsTheFileAndPlaysTheRepairedSpec() throws {
        let document = try generated()
        XCTAssertEqual(document.spec.name, "Orbit", "The loader trims the name for playing…")
        XCTAssertEqual(document.spec.surface.radius, 1.0, "…and clamps the wheel.")
        XCTAssertEqual(document.json["name"], .string("  Orbit  "), "The file itself is kept as received.")
        XCTAssertEqual(document.json["future_field"], .array([.int(1), .double(2.5), .string("x"), .null]))
        XCTAssertTrue(document.isAIGenerated)
        XCTAssertFalse(InstrumentDocument(spec: InstrumentLibrary.splitWheel).isAIGenerated)

        let again = try InstrumentDocument(data: document.data)
        XCTAssertEqual(again, document, "The compact encoding round-trips exactly.")
        let coded = try JSONDecoder().decode(InstrumentDocument.self, from: JSONEncoder().encode(document))
        XCTAssertEqual(coded, document)
    }

    func testReceivedFilesAreValidatedBeforeUse() throws {
        var rejected = Self.generatedJSON.replacingOccurrences(of: "\"gen.orbit\"", with: "\"Not An Id\"")
        XCTAssertThrowsError(try InstrumentDocument(data: Data(rejected.utf8))) {
            XCTAssertEqual($0 as? InstrumentDocument.LoadError, .rejected(.idInvalid))
        }
        rejected = Self.generatedJSON.replacingOccurrences(of: "\"format_version\":1", with: "\"format_version\":2")
        XCTAssertThrowsError(try InstrumentDocument(data: Data(rejected.utf8))) {
            XCTAssertEqual($0 as? InstrumentDocument.LoadError, .rejected(.unsupportedVersion))
            XCTAssertTrue($0.localizedDescription.contains("Update"), "Newer instruments ask for an update.")
        }
        XCTAssertThrowsError(try JSONDecoder().decode(InstrumentDocument.self, from: Data(#"{"format":"x"}"#.utf8)))
        XCTAssertThrowsError(try InstrumentDocument(data: Data(repeating: 32, count: InstrumentSpec.byteLimit + 1)))
    }

    func testRemixCopyGetsItsOwnIdAndKeepsUnknownFields() throws {
        let copy = try generated().remixCopy(suffix: "abc123")
        XCTAssertEqual(copy.spec.id, "gen.orbit.remix-abc123")
        XCTAssertEqual(copy.spec.name, "Orbit remix")
        XCTAssertTrue(copy.isAIGenerated)
        XCTAssertNotNil(copy.json["future_field"])

        let long = try generated().edited { $0["id"] = .string(String(repeating: "a", count: 80)) }
        XCTAssertEqual(long.remixCopy(suffix: "abc123").spec.id.count, 80, "Remix ids stay within the 80-character limit.")

        let edited = try copy.setting(["chords", "side"], to: .string("left")).setting(["surface", "rest_radius"], to: .double(0.4))
        XCTAssertEqual(edited.spec.chords.side, .left)
        XCTAssertEqual(edited.spec.surface.restRadius, 0.4)
        XCTAssertThrowsError(try copy.setting(["chords", "side"], to: .string("up")), "Edits are validated like any received file.")
    }

    // MARK: Capture → posted fields

    @MainActor
    func testPlayingAPostInstrumentKeepsTheSoundAndIsCapturedForPosting() throws {
        let engine = EngineController()
        let sound = engine.selectedSoundFontInstrument
        engine.selectedKey = .E
        let source = UUID()
        let document = try generated()

        engine.playInstrument(document, sourceVideoID: source)
        XCTAssertEqual(engine.customInstrument, document.spec)
        XCTAssertEqual(engine.selectedSoundFontInstrument, sound, "Play this instrument keeps the player's sound.")
        XCTAssertEqual(engine.selectedKey, .E)
        XCTAssertEqual(engine.instrumentForPosting, PostedInstrument(document: document, sourceVideoID: source))

        engine.switchMode(grid: false, drums: false, learn: false, scaleChordMelody: true)
        XCTAssertNil(engine.instrumentForPosting, "Built-in wheels aren't posted.")
        XCTAssertNil(engine.customInstrumentSource)

        engine.playInstrument(try XCTUnwrap(InstrumentLibrary.builtIn("demo.wide-wheel")))
        XCTAssertNil(engine.instrumentForPosting, "Instruments that ship with the app aren't posted.")

        var created = document.spec
        created.id = "made.here"
        engine.playInstrument(created)
        XCTAssertEqual(engine.instrumentForPosting?.document.spec, created, "Other instruments are posted as the player's own.")
        XCTAssertNil(engine.instrumentForPosting?.sourceVideoID)
    }

    @MainActor
    func testTheDraftKeepsTheInstrumentAndPostsItBesideTheSound() throws {
        let drafts = RecordingDrafts(directory: directory)
        let source = UUID()
        let played = PostedInstrument(document: try generated(), sourceVideoID: source)
        let setup = SoundSetup(instrument: "grand_piano", waveform: "sine", key: .D, scale: .minor, progression: "free",
                               customDegrees: nil, mode: .scalechordmelody, bpm: 96, useSoundFont: true, autoStrum: false,
                               padVolume: 0.3, gridOctave: 3, gridRange: 2)
        let draft = try drafts.begin(instrument: "Grand Piano", mode: "scale", soundSetup: setup, playedInstrument: played)
        XCTAssertEqual(draft.playedInstrument, played)
        // The draft's metadata survives a relaunch.
        let file = directory.appendingPathComponent(draft.id.uuidString).appendingPathComponent("draft.json")
        let stored = try FileManager.default.contentsOfDirectory(at: directory.appendingPathComponent(draft.id.uuidString),
                                                                 includingPropertiesForKeys: nil)
            .first { $0.pathExtension == "json" } ?? file
        let reloaded = try JSONDecoder().decode(RecordingDraft.self, from: Data(contentsOf: stored))
        XCTAssertEqual(reloaded.playedInstrument, played)

        var sharing = PostSharingOptions()
        sharing.allowRemixes = false
        var fields = VideoPostFields(caption: "", instrument: "Grand Piano", mode: "scale", durationS: 7, width: 720,
                                     height: 1560, soundSetup: sharing.sharedPreset(setup))
        fields.attach(sharing.sharedInstrument(reloaded.playedInstrument), allowRemixes: sharing.allowRemixes)
        let json = try object(JSONEncoder().encode(fields))
        let spec = try XCTUnwrap(json["instrument_spec"] as? [String: Any])
        XCTAssertEqual(spec["name"] as? String, "  Orbit  ", "The file is posted as received.")
        XCTAssertEqual(spec["ai_generated"] as? Bool, true)
        XCTAssertNotNil(spec["future_field"])
        XCTAssertEqual(json["instrument_source_id"] as? String, source.uuidString)
        XCTAssertEqual(json["instrument_remixes_allowed"] as? Bool, false)
        XCTAssertEqual(json["instrument_ai_generated"] as? Bool, true)
        let sound = try XCTUnwrap(json["sound_setup"] as? [String: Any])
        XCTAssertNil(sound["surface"], "The sound doesn't carry the instrument…")
        XCTAssertNil(spec["key"], "…and the instrument doesn't carry the sound.")
        XCTAssertEqual(sound["key"] as? String, "D")

        sharing.shareInstrument = false
        var withheld = fields
        withheld.attach(sharing.sharedInstrument(played), allowRemixes: true)
        let none = try object(JSONEncoder().encode(withheld))
        XCTAssertNil(none["instrument_spec"])
        XCTAssertNil(none["instrument_source_id"])
        XCTAssertNil(none["instrument_remixes_allowed"])
    }

    // MARK: Feed rows

    func testFeedRowsCarryTheInstrumentChip() throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let source = UUID()
        func video(_ extra: [String: Any]) throws -> Video {
            var row: [String: Any] = [
                "id": UUID().uuidString, "user_id": UUID().uuidString, "like_count": 0, "caption": "Take",
                "video_key": "clip.mp4", "thumb_key": "cover.jpg", "created_at": "2026-11-21T00:00:00Z", "username": "cyd",
            ]
            row.merge(extra) { $1 }
            return try decoder.decode(Video.self, from: JSONSerialization.data(withJSONObject: row))
        }
        XCTAssertNil(try video([:]).postInstrument)
        XCTAssertNil(try video(["has_instrument": false]).postInstrument)

        let remix = try XCTUnwrap(try video(["has_instrument": true, "instrument_spec_name": "Orbit", "instrument_kind": "remix",
                                             "instrument_remixes_allowed": true, "instrument_ai_generated": true,
                                             "instrument_source_id": source.uuidString, "instrument_source_username": "ana",
                                             "instrument_remix_count": 2]).postInstrument)
        XCTAssertEqual(remix, PostInstrumentSummary(name: "Orbit", kind: .remix, remixesAllowed: true, aiGenerated: true,
                                                    sourceVideoID: source, sourceUsername: "ana", remixCount: 2))
        XCTAssertEqual(remix.credit(poster: "cyd"), "Remix by @cyd")
        XCTAssertEqual(remix.remixLine, "Remix of @ana's instrument")
        XCTAssertEqual(remix.remixCountLine, "2 remixes")

        let own = PostInstrumentSummary(name: "Orbit", kind: .own, remixCount: 1)
        XCTAssertEqual(own.credit(poster: "ana"), "Instrument by @ana")
        XCTAssertEqual(own.remixCountLine, "1 remix")
        XCTAssertEqual(PostInstrumentSummary(name: "Orbit", kind: .copy, sourceUsername: "ana").credit(poster: "cyd"),
                       "Instrument by @ana", "A copy credits its maker, not the poster.")
        XCTAssertNil(PostInstrumentSummary(name: "Orbit", kind: .copy).credit(poster: "cyd"),
                     "Credit to a hidden or blocked maker is left out, never moved to the poster.")
        let closed = try XCTUnwrap(try video(["has_instrument": true, "instrument_kind": "own"]).postInstrument)
        XCTAssertFalse(closed.remixesAllowed, "Without the toggle in the row, saving and remixing stay off.")
    }

    // MARK: Files

    @MainActor
    func testExportAndImportRoundTrip() throws {
        let store = MyInstrumentsStore(directory: directory, remote: .offline)
        let document = try generated()
        let url = try document.exportFile(in: directory)
        XCTAssertEqual(url.pathExtension, InstrumentDocument.fileExtension)
        XCTAssertEqual(url.deletingPathExtension().lastPathComponent, "Orbit")
        XCTAssertTrue(InstrumentDocument.isInstrumentFile(url))
        XCTAssertEqual(try InstrumentDocument.importFile(at: url), document, "Exported files import exactly.")

        let imported = try store.importFile(at: url)
        XCTAssertEqual(imported.kind, .imported)
        XCTAssertEqual(imported.document, document)
        XCTAssertEqual(try store.importFile(at: url).id, imported.id, "Importing the same file twice keeps one.")
        XCTAssertEqual(store.items.count, 1)

        // Edit, export and import again: a new instrument.
        let edited = try imported.document.setting(["name"], to: .string("Orbit 2"))
        store.update(imported.id, document: edited)
        let second = try store.importFile(at: try XCTUnwrap(store.item(id: imported.id)).document.exportFile(in: directory))
        XCTAssertEqual(second.id, imported.id, "The edited copy is already kept.")

        let bad = directory.appendingPathComponent("bad.\(InstrumentDocument.fileExtension)")
        try Data(Self.generatedJSON.replacingOccurrences(of: "split_wheel", with: "hexagon").utf8).write(to: bad)
        XCTAssertThrowsError(try store.importFile(at: bad), "Imported files are validated by the loader.")
        try Data("not json".utf8).write(to: bad)
        XCTAssertThrowsError(try store.importFile(at: bad))
        XCTAssertEqual(store.items.count, 1)

        // The cache survives a relaunch.
        let relaunched = MyInstrumentsStore(directory: directory, remote: .offline)
        XCTAssertEqual(relaunched.items.map(\.name), ["Orbit 2"])
    }

    // MARK: My instruments sync

    @MainActor
    func testStoreSyncsToTheAccountAndKeepsRefusedInstrumentsOnDevice() async throws {
        let remote = FakeRemote()
        let store = MyInstrumentsStore(directory: directory, remote: remote.client)
        let post = UUID()
        let closedPost = UUID()
        let document = try generated()

        let saved = try store.save(document, fromPost: post, by: "ana")
        XCTAssertEqual(try store.save(document, fromPost: post, by: "ana").id, saved.id)
        XCTAssertTrue(store.hasSaved(post: post))
        let remix = try store.remix(document, fromPost: closedPost, by: "ben")
        XCTAssertEqual(remix.kind, .remixed)
        XCTAssertNotEqual(remix.document.spec.id, document.spec.id)
        await store.sync()
        XCTAssertTrue(remote.rows.isEmpty, "Nothing syncs while signed out.")

        // Signing in adopts the signed-out instruments; the server refuses the no-remix one.
        remote.refuse = [remix.id]
        let account = UUID()
        store.setAccount(account)
        XCTAssertEqual(store.items.count, 2)
        await store.sync()
        XCTAssertEqual(remote.rows.map(\.id), [saved.id])
        XCTAssertEqual(remote.rows.first?.kind, "saved")
        XCTAssertEqual(remote.rows.first?.sourceVideoID, post)
        XCTAssertEqual(remote.rows.first?.spec, document.json)
        XCTAssertTrue(store.isDeviceOnly(remix.id))
        XCTAssertFalse(store.isDeviceOnly(saved.id))
        XCTAssertNil(store.syncError)

        // Another device added one.
        let other = MyInstrumentsRemote.Row(id: UUID(), spec: try document.remixCopy(suffix: "other1").json, kind: "created",
                                            sourceVideoID: nil, createdAt: Date(), updatedAt: Date())
        remote.rows.append(other)
        await store.sync()
        XCTAssertTrue(store.items.contains { $0.id == other.id && $0.kind == .created })

        // Edits and deletes reach the server.
        store.delete(saved.id)
        let mine = try XCTUnwrap(store.item(id: other.id))
        store.update(mine.id, document: try mine.document.setting(["name"], to: .string("Renamed")))
        await store.sync()
        XCTAssertFalse(remote.rows.contains { $0.id == saved.id })
        XCTAssertEqual(remote.rows.first { $0.id == other.id }?.spec["name"], .string("Renamed"))

        // Deleted on another device.
        remote.rows.removeAll { $0.id == other.id }
        await store.sync()
        XCTAssertNil(store.item(id: other.id))
        XCTAssertNotNil(store.item(id: remix.id), "Device-only instruments stay.")

        // Another account starts empty; the first account's instruments come back with it.
        store.setAccount(UUID())
        XCTAssertTrue(store.items.isEmpty)
        store.setAccount(account)
        XCTAssertEqual(store.items.map(\.id), [remix.id])
    }

    @MainActor
    func testServerRowsThatDoNotLoadAreSkipped() async throws {
        let remote = FakeRemote()
        remote.rows = [.init(id: UUID(), spec: .object(["format": .string("handstrudel.instrument"), "format_version": .int(2),
                                                        "id": .string("future.pads"), "name": .string("Pads")]),
                             kind: "saved", sourceVideoID: nil, createdAt: Date(), updatedAt: Date())]
        let store = MyInstrumentsStore(directory: directory, remote: remote.client)
        store.setAccount(UUID())
        await store.sync()
        XCTAssertTrue(store.items.isEmpty, "Files this version can't load stay on the server, unused.")
    }
}

private final class FakeRemote: @unchecked Sendable {
    var rows: [MyInstrumentsRemote.Row] = []
    var refuse: Set<UUID> = []

    var client: MyInstrumentsRemote {
        MyInstrumentsRemote(
            fetch: { self.rows },
            insert: { row in
                if self.refuse.contains(row.id) { throw MyInstrumentsRemote.InsertError.refused }
                if self.rows.contains(where: { $0.id == row.id }) { throw MyInstrumentsRemote.InsertError.duplicate }
                var stored = row
                stored.createdAt = Date()
                stored.updatedAt = Date()
                self.rows.append(stored)
            },
            update: { id, spec in
                guard let index = self.rows.firstIndex(where: { $0.id == id }) else { return }
                let row = self.rows[index]
                self.rows[index] = .init(id: id, spec: spec, kind: row.kind, sourceVideoID: row.sourceVideoID,
                                         createdAt: row.createdAt, updatedAt: Date())
            },
            delete: { id in self.rows.removeAll { $0.id == id } })
    }
}

extension MyInstrumentsRemote {
    static let offline = MyInstrumentsRemote(fetch: { [] }, insert: { _ in }, update: { _, _ in }, delete: { _ in })
}
