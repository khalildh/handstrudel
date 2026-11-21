import XCTest
@testable import HandStrudel

/// "Make an instrument": the client's request, response decoding through the
/// loader, error mapping, and My instruments (local + account) with a mocked
/// transport.
final class AIInstrumentTests: XCTestCase {
    private let instrument = """
    {"format":"handstrudel.instrument","format_version":1,"id":"ai.0123456789ab","name":"Glow Wheel",
     "description":"Big chord wedges.","ai_generated":true,
     "surface":{"type":"split_wheel","radius":1.0,"rest_radius":0.3,"octave_band_radius":0.82},
     "chords":{"side":"right"},"notes":{"source":"scale_one_octave","octave_band":true,"highlight_chord_tones":true},
     "future_field":{"kept":true}}
    """

    private func response(status: String = "ok", suggestion: String = "null") -> Data {
        Data("""
        {"instrument":\(instrument),"suggested_music":\(suggestion),"status":"\(status)","ai_generated":true,
         "seed_id":"builtin.scale-wheel","attempts":1,"latency_ms":1200,"quota":{"used":1,"limit":5,"remaining":4}}
        """.utf8)
    }

    private func endpoint(token: String? = "token-1") -> SupabaseEndpoint {
        SupabaseEndpoint(baseURL: URL(string: "http://127.0.0.1:9")!, anonKey: "anon", accessToken: { token })
    }

    private func http(_ status: Int, _ body: Data = Data("{}".utf8)) -> (Data, URLResponse) {
        (body, HTTPURLResponse(url: URL(string: "http://127.0.0.1:9")!, statusCode: status, httpVersion: nil, headerFields: nil)!)
    }

    func testGeneratedInstrumentLoadsThroughTheLoaderWithItsAIMarker() throws {
        let generated = try AIInstrumentClient.decode(response(), status: 200)
        XCTAssertEqual(generated.spec.name, "Glow Wheel")
        XCTAssertTrue(generated.spec.isAIGenerated)
        XCTAssertEqual(generated.spec.chords.side, .right)
        XCTAssertEqual(generated.status, "ok")
        XCTAssertEqual(generated.quotaRemaining, 4)
        XCTAssertNil(generated.suggestion)
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: generated.body) as? [String: Any])
        XCTAssertNotNil(body["future_field"], "the file is kept as sent, including fields this app doesn't know")
        XCTAssertEqual(generated.spec.rules.noteSource, .scaleOneOctave, "it plays like any instrument file")
        XCTAssertFalse(InstrumentLibrary.scaleWheel.isAIGenerated)
    }

    func testMusicComesBackOnlyAsASuggestion() throws {
        let generated = try AIInstrumentClient.decode(response(suggestion: #"{"key":"D","scale":"Minor","bpm":70}"#), status: 200)
        let suggestion = try XCTUnwrap(generated.suggestion)
        XCTAssertEqual(suggestion.musicKey, .D)
        XCTAssertEqual(suggestion.builtInScale, .minor)
        XCTAssertEqual(suggestion.summary, "D Minor · 70 BPM")
        let empty = try AIInstrumentClient.decode(response(suggestion: #"{"key":"H","scale":null,"bpm":null}"#), status: 200)
        XCTAssertNil(empty.suggestion, "unknown values are dropped")
    }

    func testFallbackIsAPlayableBuiltIn() throws {
        let body = Data("""
        {"instrument":{"format":"handstrudel.instrument","format_version":1,"id":"builtin.scale-wheel","name":"Scale Wheel",
          "surface":{"type":"split_wheel","radius":1.0,"rest_radius":0.36,"octave_band_radius":0.8},"chords":{"side":"left"},
          "notes":{"source":"scale_one_octave","octave_band":true,"highlight_chord_tones":true}},
         "suggested_music":null,"status":"fallback","ai_generated":false}
        """.utf8)
        let generated = try AIInstrumentClient.decode(body, status: 200)
        XCTAssertTrue(generated.isFallback)
        XCTAssertFalse(generated.spec.isAIGenerated)
        XCTAssertTrue(generated.spec.isBuiltIn)
    }

    func testErrorsMapToMessagesNotCrashes() {
        let cases: [(Int, AIInstrumentError)] = [
            (401, .signInRequired),
            (429, .quotaExceeded("You've made 5 instruments today. Try again tomorrow.")),
            (422, .promptBlocked("You've made 5 instruments today. Try again tomorrow.")),
            (400, .invalidPrompt("You've made 5 instruments today. Try again tomorrow.")),
            (500, .server("You've made 5 instruments today. Try again tomorrow.")),
        ]
        let body = Data(#"{"error":"You've made 5 instruments today. Try again tomorrow.","code":"x"}"#.utf8)
        for (status, expected) in cases {
            XCTAssertThrowsError(try AIInstrumentClient.decode(body, status: status)) { error in
                XCTAssertEqual(error as? AIInstrumentError, expected, "HTTP \(status)")
            }
        }
        let newer = Data(#"{"instrument":{"format":"handstrudel.instrument","format_version":99,"id":"ai.x","name":"X"},"status":"ok"}"#.utf8)
        XCTAssertThrowsError(try AIInstrumentClient.decode(newer, status: 200))
    }

    func testRequestCarriesThePromptAndForRefinesTheCurrentFile() async throws {
        var sent: [URLRequest] = []
        let client = AIInstrumentClient(endpoint: endpoint()) { request in
            sent.append(request)
            return self.http(200, self.response())
        }
        let first = try await client.generate(AIInstrumentRequest(prompt: "glow wheel"))
        _ = try await client.generate(AIInstrumentRequest(prompt: "bigger zones", current: first.body, originalPrompt: "glow wheel"))

        XCTAssertEqual(sent[0].url?.absoluteString, "http://127.0.0.1:9/functions/v1/generate-instrument")
        XCTAssertEqual(sent[0].httpMethod, "POST")
        XCTAssertEqual(sent[0].value(forHTTPHeaderField: "Authorization"), "Bearer token-1")
        XCTAssertEqual(sent[0].value(forHTTPHeaderField: "apikey"), "anon")
        let create = try XCTUnwrap(JSONSerialization.jsonObject(with: sent[0].httpBody!) as? [String: Any])
        XCTAssertEqual(create["prompt"] as? String, "glow wheel")
        XCTAssertNil(create["current"])
        let refine = try XCTUnwrap(JSONSerialization.jsonObject(with: sent[1].httpBody!) as? [String: Any])
        XCTAssertEqual(refine["prompt"] as? String, "bigger zones")
        XCTAssertEqual(refine["original_prompt"] as? String, "glow wheel")
        XCTAssertEqual((refine["current"] as? [String: Any])?["id"] as? String, "ai.0123456789ab")
    }

    func testSignedOutAndOfflineAreFriendlyErrors() async {
        let signedOut = AIInstrumentClient(endpoint: endpoint(token: nil)) { _ in XCTFail("nothing is sent"); return self.http(200) }
        do { _ = try await signedOut.generate(AIInstrumentRequest(prompt: "x")); XCTFail() } catch {
            XCTAssertEqual(error as? AIInstrumentError, .signInRequired)
        }
        let offline = AIInstrumentClient(endpoint: endpoint()) { _ in throw URLError(.notConnectedToInternet) }
        do { _ = try await offline.generate(AIInstrumentRequest(prompt: "x")); XCTFail() } catch {
            XCTAssertEqual(error as? AIInstrumentError, .unreachable)
        }
    }

    @MainActor
    func testMyInstrumentsSaveLocallyAndToTheAccountAndComeBackAfterAReinstall() async throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("my-instruments-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: file) }
        var uploads: [URLRequest] = []
        let store = MyInstruments(fileURL: file, endpoint: { self.endpoint() }) { request in
            uploads.append(request)
            return self.http(201)
        }
        let generated = try AIInstrumentClient.decode(response(), status: 200)
        let saved = await store.save(body: generated.body, prompt: "glow wheel")
        XCTAssertTrue(saved)
        XCTAssertEqual(store.instruments.map(\.id), ["ai.0123456789ab"])
        XCTAssertTrue(store.instruments[0].isAIGenerated)
        XCTAssertNil(store.syncError)

        let upload = try XCTUnwrap(uploads.first)
        XCTAssertEqual(upload.httpMethod, "POST")
        XCTAssertEqual(upload.url?.path, "/rest/v1/my_instruments")
        XCTAssertEqual(upload.url?.query, "on_conflict=user_id,id")
        XCTAssertEqual(upload.value(forHTTPHeaderField: "Prefer"), "resolution=merge-duplicates,return=minimal")
        let row = try XCTUnwrap(JSONSerialization.jsonObject(with: upload.httpBody!) as? [String: Any])
        XCTAssertEqual(row["id"] as? String, "ai.0123456789ab")
        XCTAssertEqual(row["prompt"] as? String, "glow wheel")
        XCTAssertEqual((row["body"] as? [String: Any])?["ai_generated"] as? Bool, true)

        // Same device, next launch: read from disk.
        let relaunched = MyInstruments(fileURL: file, endpoint: { self.endpoint() }) { _ in self.http(200, Data("[]".utf8)) }
        XCTAssertEqual(relaunched.instruments.map(\.name), ["Glow Wheel"])

        // Reinstall: empty disk, rows come back from the account (bad rows dropped).
        let accountRows = Data("""
        [{"id":"ai.0123456789ab","prompt":"glow wheel","created_at":"2026-11-21T00:00:00Z","body":\(instrument)},
         {"id":"ai.broken","prompt":null,"created_at":"2026-11-20T00:00:00Z","body":{"format":"handstrudel.instrument","format_version":1,"id":"ai.broken","name":""}}]
        """.utf8)
        let fresh = MyInstruments(fileURL: file.appendingPathExtension("fresh"), endpoint: { self.endpoint() }) { request in
            XCTAssertEqual(request.httpMethod, "GET")
            return self.http(200, accountRows)
        }
        await fresh.pullFromAccount()
        XCTAssertEqual(fresh.instruments.map(\.id), ["ai.0123456789ab"])
        try? FileManager.default.removeItem(at: file.appendingPathExtension("fresh"))
    }

    @MainActor
    func testMyInstrumentsRejectBuiltInsAndKeepLocalCopiesWhenSyncFails() async throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("my-instruments-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: file) }
        let store = MyInstruments(fileURL: file, endpoint: { self.endpoint() }) { _ in self.http(500) }
        let builtIn = try JSONEncoder().encode(InstrumentLibrary.scaleWheel)
        let rejected = await store.save(body: builtIn, prompt: nil)
        XCTAssertFalse(rejected, "built-ins are already in the app")
        let generated = try AIInstrumentClient.decode(response(), status: 200)
        let saved = await store.save(body: generated.body, prompt: nil)
        XCTAssertTrue(saved)
        XCTAssertEqual(store.instruments.count, 1)
        XCTAssertNotNil(store.syncError, "the account copy failed but the local one is kept")
        await store.delete("ai.0123456789ab")
        XCTAssertTrue(store.instruments.isEmpty)
    }

    func testInstrumentSpecRoundTripsTheAIMarker() throws {
        let spec = try XCTUnwrap(InstrumentSpec.load(Data(instrument.utf8)).spec)
        let encoded = try JSONEncoder().encode(spec)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        XCTAssertEqual(object["ai_generated"] as? Bool, true)
        let plain = try JSONEncoder().encode(InstrumentLibrary.splitWheel)
        XCTAssertNil((try JSONSerialization.jsonObject(with: plain) as? [String: Any])?["ai_generated"], "absent unless set")
    }
}
