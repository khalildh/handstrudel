import XCTest

/// Instruments that travel with posts, against the feed fixture server:
///
///     FIXTURE_INSTRUMENTS=1 PORT=54331 node scripts/notification-ui-fixture.mjs
///     HANDSTRUDEL_INSTRUMENT_FIXTURE_URL=http://127.0.0.1:54331 (passed as TEST_RUNNER_…)
///
/// The fixture's first post was played on "Fixture Wheel" (AI-made, remixes allowed) with a
/// Violin sound on the Scale wheel.
final class PostInstrumentUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        guard let endpoint = ProcessInfo.processInfo.environment["HANDSTRUDEL_INSTRUMENT_FIXTURE_URL"] else {
            throw XCTSkip("Set HANDSTRUDEL_INSTRUMENT_FIXTURE_URL to the feed fixture started with FIXTURE_INSTRUMENTS=1.")
        }
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "-hasSeenOnboarding", "YES"]
        app.launchEnvironment["SUPABASE_URL"] = endpoint
        app.launchEnvironment["SUPABASE_ANON_KEY"] = "instrument-fixture-key"
        app.launchEnvironment["MEDIA_BASE_URL"] = endpoint
        app.launchEnvironment["HANDSTRUDEL_TEST_RESET_INSTRUMENTS"] = "1"
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func waitFor(_ element: XCUIElement, _ format: String, _ args: CVarArg..., timeout: TimeInterval = 10,
                         file: StaticString = #filePath, line: UInt = #line) {
        let predicate = NSPredicate(format: format, argumentArray: args)
        let result = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: element)], timeout: timeout)
        XCTAssertEqual(result, .completed, "\(element) never matched \(format) \(args)", file: file, line: line)
    }

    /// The player's sound on the start screen ("Grand Piano"), made different from the post's Violin.
    private func startingSound() -> String {
        let artwork = element("sound-artwork")
        XCTAssertTrue(artwork.waitForExistence(timeout: 10))
        func name() -> String { String(((artwork.value as? String) ?? "").split(separator: ",").first ?? "") }
        if name() == "Violin" { artwork.swipeLeft() }
        XCTAssertNotEqual(name(), "Violin")
        return name()
    }

    private func openInstrumentSheet() {
        element("tab-feed").tap()
        let chip = app.buttons["post-instrument-chip"].firstMatch
        XCTAssertTrue(chip.waitForExistence(timeout: 10), "The post shows the instrument it was played on.")
        XCTAssertTrue(chip.label.contains("Fixture Wheel"), chip.label)
        XCTAssertTrue(chip.label.contains("made with AI"), chip.label)
        chip.tap()
        XCTAssertTrue(app.navigationBars["Instrument"].waitForExistence(timeout: 5))
    }

    private func endSession() {
        let close = element("close-button")
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        close.tap()
        XCTAssertTrue(element("tab-feed").waitForExistence(timeout: 10))
    }

    func testPlayKeepAndShareAPostsInstrument() throws {
        app.launch()
        let mySound = startingSound()

        // The sheet credits the maker and shows the remix count and chain.
        openInstrumentSheet()
        XCTAssertTrue(element("post-instrument-ai").exists, "Made with AI")
        XCTAssertEqual(element("post-instrument-credit").label, "Instrument by @loopmaker")
        XCTAssertTrue(element("post-instrument-remix-count").label.contains("1 remix"))

        // Play this instrument: the wheel loads it, the sound stays the player's.
        app.buttons["play-post-instrument"].tap()
        let stage = element("stage-instrument")
        XCTAssertTrue(stage.waitForExistence(timeout: 15), "The wheel should open with the post's instrument.")
        XCTAssertEqual(stage.label, "Instrument: Fixture Wheel")
        waitFor(stage, "value == %@", "Sound: \(mySound)")
        endSession()

        // Play this exactly: instrument and sound both change.
        openInstrumentSheet()
        app.buttons["play-post-instrument-exactly"].tap()
        XCTAssertTrue(stage.waitForExistence(timeout: 15))
        XCTAssertEqual(stage.label, "Instrument: Fixture Wheel")
        waitFor(stage, "value == %@", "Sound: Violin")
        endSession()

        // Save it, then find it in My instruments.
        openInstrumentSheet()
        app.buttons["save-post-instrument"].tap()
        XCTAssertTrue(element("post-instrument-message").waitForExistence(timeout: 5))
        waitFor(app.buttons["save-post-instrument"], "label == %@", "Saved to My instruments")
        app.navigationBars["Instrument"].buttons["Done"].tap()
        element("tab-music").tap()
        element("my-instruments-button").tap()
        let saved = app.descendants(matching: .any).matching(NSPredicate(
            format: "identifier == 'my-instrument' AND label CONTAINS 'Fixture Wheel' AND label CONTAINS 'Saved from @loopmaker'")).firstMatch
        XCTAssertTrue(saved.waitForExistence(timeout: 5), "The saved instrument is listed in My instruments.")

        // Playing it from My instruments opens the wheel with it.
        app.buttons["play-my-instrument"].firstMatch.tap()
        XCTAssertTrue(stage.waitForExistence(timeout: 15))
        XCTAssertEqual(stage.label, "Instrument: Fixture Wheel")
        endSession()
    }

    func testRemixOpensAnEditableCreditedCopy() throws {
        app.launch()
        _ = startingSound()
        openInstrumentSheet()
        app.buttons["remix-post-instrument"].tap()
        XCTAssertTrue(app.navigationBars["Remix"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Remix of @loopmaker's instrument"].exists)
        let name = app.textFields["instrument-editor-name"]
        XCTAssertEqual(name.value as? String, "Fixture Wheel remix")
        name.tap()
        name.typeText(" 2")
        app.buttons["play-edited-instrument"].tap()
        let stage = element("stage-instrument")
        XCTAssertTrue(stage.waitForExistence(timeout: 15))
        XCTAssertEqual(stage.label, "Instrument: Fixture Wheel remix 2")
        endSession()
        element("tab-music").tap()
        element("my-instruments-button").tap()
        let remix = app.descendants(matching: .any).matching(NSPredicate(
            format: "identifier == 'my-instrument' AND label CONTAINS 'Fixture Wheel remix 2' AND label CONTAINS 'Remix of @loopmaker'")).firstMatch
        XCTAssertTrue(remix.waitForExistence(timeout: 5))
    }

    func testExportAndImportAnInstrumentFile() throws {
        let exports = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("instrument-exports-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: exports, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: exports) }
        app.launchEnvironment["HANDSTRUDEL_TEST_EXPORT_DIR"] = exports.path
        app.launch()

        // Keep the post's instrument, then export it from My instruments.
        openInstrumentSheet()
        let save = app.buttons["save-post-instrument"]
        if save.isEnabled { save.tap() }
        waitFor(save, "label == %@", "Saved to My instruments")
        app.navigationBars["Instrument"].buttons["Done"].tap()
        element("tab-music").tap()
        element("my-instruments-button").tap()
        XCTAssertTrue(app.navigationBars["My instruments"].waitForExistence(timeout: 5))
        let row = app.descendants(matching: .any).matching(NSPredicate(
            format: "identifier == 'my-instrument' AND label CONTAINS 'Fixture Wheel'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        app.buttons.matching(NSPredicate(format: "label == 'More for Fixture Wheel'")).firstMatch.tap()
        app.buttons["Export file"].tap()
        // The system share sheet offers the file (Save to Files, AirDrop, Messages…).
        let shareSheet = app.otherElements["ActivityListView"]
        XCTAssertTrue(shareSheet.waitForExistence(timeout: 10) || app.navigationBars["UIActivityContentView"].exists,
                      "The share sheet should open with the exported file.")

        let file = exports.appendingPathComponent("Fixture Wheel.handstrudel-instrument")
        let data = try Data(contentsOf: file)
        var json = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(json["format"] as? String, "handstrudel.instrument")
        XCTAssertEqual(json["name"] as? String, "Fixture Wheel")
        XCTAssertEqual(json["ai_generated"] as? Bool, true, "The file keeps the AI marker.")
        XCTAssertNil(json["instrument"], "The file is the instrument only, no sound.")

        // A friend edits and sends it back: opening the file imports it into My instruments.
        json["id"] = "friend.fixture-wheel"
        json["name"] = "Imported Wheel"
        let incoming = exports.appendingPathComponent("Imported Wheel.handstrudel-instrument")
        try JSONSerialization.data(withJSONObject: json).write(to: incoming)
        app.terminate()
        app.launchEnvironment["HANDSTRUDEL_TEST_RESET_INSTRUMENTS"] = nil
        app.launchEnvironment["HANDSTRUDEL_TEST_OPEN_FILE"] = incoming.path
        app.launch()
        XCTAssertTrue(app.navigationBars["My instruments"].waitForExistence(timeout: 10))
        let added = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Added Imported Wheel'")).firstMatch
        XCTAssertTrue(added.waitForExistence(timeout: 5), "Opening the file says it was added.")
        let imported = app.descendants(matching: .any).matching(NSPredicate(
            format: "identifier == 'my-instrument' AND label CONTAINS 'Imported Wheel' AND label CONTAINS 'Imported file'")).firstMatch
        XCTAssertTrue(imported.waitForExistence(timeout: 5))

        // A file the loader rejects is refused, not added.
        json["format_version"] = 99
        json["name"] = "From The Future"
        try JSONSerialization.data(withJSONObject: json).write(to: incoming)
        app.terminate()
        app.launch()
        XCTAssertTrue(app.navigationBars["My instruments"].waitForExistence(timeout: 10))
        let refused = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Update the app'")).firstMatch
        XCTAssertTrue(refused.waitForExistence(timeout: 5), "A newer file asks for an update instead of being added.")
        XCTAssertFalse(app.staticTexts["From The Future"].exists)
    }
}
