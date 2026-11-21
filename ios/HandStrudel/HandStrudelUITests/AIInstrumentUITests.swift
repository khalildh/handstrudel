import Network
import XCTest

/// "Make an instrument" end to end in the Simulator against a loopback mock of
/// the `generate-instrument` function and the `my_instruments` table: consent,
/// prompt, generated instrument plays (MIDI sent), music suggestion, refine,
/// save to the account.
final class AIInstrumentUITests: XCTestCase {
    private var app: XCUIApplication!
    private var server: MockSupabase!

    override func setUpWithError() throws {
        continueAfterFailure = false
        server = try MockSupabase()
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-studio-input", "--uitest-camera-denied", "-hasSeenOnboarding", "YES",
                               "--force-ai-instruments", "-aiInstrumentConsent.v1", "NO"]
        app.launchEnvironment["HANDSTRUDEL_AI_INSTRUMENT_BASE_URL"] = server.baseURL
        app.launchEnvironment["HANDSTRUDEL_AI_INSTRUMENT_TOKEN"] = "uitest-token"
        app.launchEnvironment["HANDSTRUDEL_INSTRUMENT_CATALOG_FIXTURE"] = "[]"
        app.launchEnvironment["HANDSTRUDEL_REMOTE_CONFIG_FIXTURE"] = "[]"
    }

    override func tearDown() {
        server?.stop()
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func probeCount() -> Int {
        let label = element("debug-midi-probe").label // "notes 3 last 64"
        return Int(label.split(separator: " ")[1]) ?? -1
    }

    private func waitForLabel(_ element: XCUIElement, _ label: String, timeout: TimeInterval = 10) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", label), object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    func testPromptPlayRefineAndSave() throws {
        app.launch()
        let start = element("start-button")
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        start.tap()
        XCTAssertTrue(element("close-button").waitForExistence(timeout: 8))
        let noteLabelsBefore = (0..<12).map { app.buttons["wheel-note-\($0)"] }.filter(\.exists).map(\.label)
        XCTAssertFalse(noteLabelsBefore.isEmpty)

        // One-time consent names Anthropic before anything is sent.
        element("make-instrument-button").tap()
        XCTAssertTrue(element("ai-consent").waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Anthropic'")).firstMatch.exists)
        XCTAssertEqual(server.requests.count, 0, "nothing leaves the device before consent")
        element("ai-consent-accept").tap()

        // Prompt → instrument.
        let field = element("ai-prompt-field")
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        XCTAssertTrue(element("ai-example-0").exists, "example chips")
        field.tap()
        field.typeText("A sad piano in D minor with chords on the right")
        element("ai-make-button").tap()
        let name = element("ai-result-name")
        XCTAssertTrue(name.waitForExistence(timeout: 10))
        XCTAssertEqual(name.label, "Glow Wheel")
        XCTAssertTrue(element("ai-made-with-ai").exists, "labelled Made with AI")
        let create = try XCTUnwrap(server.requests.first { $0.path == "/functions/v1/generate-instrument" })
        XCTAssertEqual(create.authorization, "Bearer uitest-token")
        XCTAssertEqual(create.json?["prompt"] as? String, "A sad piano in D minor with chords on the right")
        add(screenshot("1-generated"))

        // The wheel now plays the generated instrument: same notes (the
        // instrument adapts to the player's scale), and touching a zone sends MIDI.
        let noteLabelsAfter = (0..<12).map { app.buttons["wheel-note-\($0)"] }.filter(\.exists).map(\.label)
        XCTAssertEqual(noteLabelsAfter, noteLabelsBefore, "music stays the player's")
        let before = probeCount()
        let topNote = app.buttons["wheel-note-\(noteLabelsAfter.count - 1)"]
        topNote.tap()
        let played = XCTNSPredicateExpectation(predicate: NSPredicate(format: "NOT (label BEGINSWITH %@)", "notes \(before) "),
                                               object: element("debug-midi-probe"))
        XCTAssertEqual(XCTWaiter().wait(for: [played], timeout: 5), .completed, "touching a zone started a note")
        XCTAssertGreaterThan(probeCount(), before)

        // Music implied by the prompt is only a suggestion; applying it changes the player's settings.
        let suggestion = element("ai-apply-suggestion")
        XCTAssertTrue(suggestion.exists)
        XCTAssertTrue(suggestion.label.contains("D Minor · 70 BPM"), suggestion.label)
        suggestion.tap()
        XCTAssertTrue(waitForLabel(element("ai-message"), "Applied D Minor · 70 BPM."))
        XCTAssertNotEqual((0..<12).map { app.buttons["wheel-note-\($0)"] }.filter(\.exists).map(\.label), noteLabelsBefore,
                          "the key changed, so the same zones now play D minor")

        // Refine sends the current file and plays the result.
        element("ai-refine-chip-0").tap() // "Bigger zones"
        XCTAssertTrue(waitForLabel(name, "Glow Wheel Plus"))
        let refine = try XCTUnwrap(server.requests.last { $0.path == "/functions/v1/generate-instrument" })
        XCTAssertEqual(refine.json?["prompt"] as? String, "Bigger zones")
        XCTAssertEqual(refine.json?["original_prompt"] as? String, "A sad piano in D minor with chords on the right")
        XCTAssertEqual((refine.json?["current"] as? [String: Any])?["id"] as? String, "ai.uitest000001")
        let beforeRefinedTap = probeCount()
        app.buttons["wheel-note-\(noteLabelsAfter.count - 1)"].tap()
        let playedAgain = XCTNSPredicateExpectation(predicate: NSPredicate(format: "NOT (label BEGINSWITH %@)", "notes \(beforeRefinedTap) "),
                                                    object: element("debug-midi-probe"))
        XCTAssertEqual(XCTWaiter().wait(for: [playedAgain], timeout: 5), .completed, "the refined instrument plays")
        add(screenshot("2-refined"))

        // Save: local list + the account.
        element("ai-save").tap()
        XCTAssertTrue(waitForLabel(element("ai-message"), "Saved to My instruments."))
        let upload = try XCTUnwrap(server.requests.first { $0.method == "POST" && $0.path == "/rest/v1/my_instruments" })
        XCTAssertEqual(upload.query, "on_conflict=user_id,id")
        XCTAssertEqual(upload.json?["id"] as? String, "ai.uitest000001")
        XCTAssertEqual((upload.json?["body"] as? [String: Any])?["name"] as? String, "Glow Wheel Plus")
        XCTAssertEqual((upload.json?["body"] as? [String: Any])?["ai_generated"] as? Bool, true)
        element("ai-new-prompt").tap()
        let mine = element("my-instrument-ai.uitest000001")
        XCTAssertTrue(mine.waitForExistence(timeout: 5), "saved instruments are listed")
        XCTAssertEqual(mine.label, "Glow Wheel Plus, made with AI")
        add(screenshot("3-saved"))
    }

    func testDecliningConsentSendsNothing() {
        app.launch()
        element("start-button").tap()
        XCTAssertTrue(element("make-instrument-button").waitForExistence(timeout: 8))
        element("make-instrument-button").tap()
        element("ai-consent-decline").tap()
        XCTAssertTrue(element("make-instrument-panel").waitForNonExistence(timeout: 3))
        XCTAssertEqual(server.requests.count, 0)
    }

    private func screenshot(_ name: String) -> XCTAttachment {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        return attachment
    }
}

/// A tiny HTTP/1.1 server on 127.0.0.1 that plays the generate-instrument
/// function (deterministic instruments, no model) and the my_instruments table.
final class MockSupabase {
    struct Request {
        let method: String
        let path: String
        let query: String?
        let authorization: String?
        let body: Data
        var json: [String: Any]? { try? JSONSerialization.jsonObject(with: body) as? [String: Any] }
    }

    private let listener: NWListener
    private let queue = DispatchQueue(label: "mock-supabase")
    private let lock = NSLock()
    private var recorded: [Request] = []
    private(set) var baseURL = ""

    var requests: [Request] { lock.withLock { recorded } }

    init() throws {
        listener = try NWListener(using: .tcp, on: .any)
        let ready = DispatchSemaphore(value: 0)
        listener.stateUpdateHandler = { state in if case .ready = state { ready.signal() } }
        listener.newConnectionHandler = { [weak self] connection in self?.serve(connection) }
        listener.start(queue: queue)
        guard ready.wait(timeout: .now() + 5) == .success, let port = listener.port?.rawValue else {
            throw XCTSkip("Couldn't start the loopback mock")
        }
        baseURL = "http://127.0.0.1:\(port)"
    }

    func stop() { listener.cancel() }

    private func serve(_ connection: NWConnection) {
        connection.start(queue: queue)
        receive(connection, buffer: Data())
    }

    private func receive(_ connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, done, error in
            guard let self else { return }
            var buffer = buffer
            if let data { buffer.append(data) }
            if let request = Self.parse(buffer) {
                self.lock.withLock { self.recorded.append(request) }
                let (status, body) = self.respond(to: request)
                let head = "HTTP/1.1 \(status) OK\r\nContent-Type: application/json\r\nContent-Length: \(body.count)\r\nConnection: close\r\n\r\n"
                connection.send(content: Data(head.utf8) + body, completion: .contentProcessed { _ in connection.cancel() })
            } else if done || error != nil {
                connection.cancel()
            } else {
                self.receive(connection, buffer: buffer)
            }
        }
    }

    /// A complete request (headers plus Content-Length bytes), or nil.
    private static func parse(_ data: Data) -> Request? {
        guard let split = data.range(of: Data("\r\n\r\n".utf8)) else { return nil }
        let head = String(decoding: data[..<split.lowerBound], as: UTF8.self).components(separatedBy: "\r\n")
        let parts = head[0].split(separator: " ")
        guard parts.count >= 2 else { return nil }
        var headers: [String: String] = [:]
        for line in head.dropFirst() {
            guard let colon = line.firstIndex(of: ":") else { continue }
            headers[line[..<colon].lowercased()] = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
        }
        let length = Int(headers["content-length"] ?? "0") ?? 0
        let body = data[split.upperBound...]
        guard body.count >= length else { return nil }
        let target = String(parts[1]).split(separator: "?", maxSplits: 1).map(String.init)
        return Request(method: String(parts[0]), path: target[0], query: target.count > 1 ? target[1].removingPercentEncoding : nil,
                       authorization: headers["authorization"], body: Data(body.prefix(length)))
    }

    private func respond(to request: Request) -> (Int, Data) {
        guard request.authorization == "Bearer uitest-token" else { return (401, Data(#"{"error":"sign in required"}"#.utf8)) }
        switch (request.method, request.path) {
        case ("POST", "/functions/v1/generate-instrument"):
            var instrument: [String: Any] = [
                "format": "handstrudel.instrument", "format_version": 1, "id": "ai.uitest000001", "name": "Glow Wheel",
                "description": "Chords on the right, every scale note on the left.", "ai_generated": true,
                "surface": ["type": "split_wheel", "radius": 1.0, "rest_radius": 0.3, "octave_band_radius": 0.82],
                "chords": ["side": "right"],
                "notes": ["source": "scale_one_octave", "octave_band": true, "highlight_chord_tones": true],
            ]
            var suggestion: Any = ["key": "D", "scale": "Minor", "bpm": 70]
            if let current = request.json?["current"] as? [String: Any] {
                instrument = current
                instrument["name"] = "Glow Wheel Plus"
                instrument["surface"] = ["type": "split_wheel", "radius": 1.0, "rest_radius": 0.25, "octave_band_radius": 0.85]
                suggestion = NSNull()
            }
            let body: [String: Any] = ["instrument": instrument, "suggested_music": suggestion, "status": "ok",
                                       "ai_generated": true, "attempts": 1, "latency_ms": 900,
                                       "quota": ["used": 1, "limit": 5, "remaining": 4]]
            return (200, try! JSONSerialization.data(withJSONObject: body))
        case ("POST", "/rest/v1/my_instruments"):
            return (201, Data())
        case ("GET", "/rest/v1/my_instruments"):
            return (200, Data("[]".utf8))
        default:
            return (404, Data(#"{"error":"not found"}"#.utf8))
        }
    }
}
