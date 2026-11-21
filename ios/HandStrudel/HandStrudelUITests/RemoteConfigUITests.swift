import XCTest

/// Remote config and downloadable instruments in the running app.
///
/// `RemoteConfigUITests` serve rows from a local fixture (DEBUG builds read
/// `HANDSTRUDEL_REMOTE_CONFIG_FIXTURE` / `HANDSTRUDEL_INSTRUMENT_CATALOG_FIXTURE`
/// instead of the network). `RemoteConfigLiveUITests` go through the app's
/// real network code against a local Supabase stack.
class RemoteConfigUITestCase: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-remote-content", "--reset-studio-input",
                               "--uitest-camera-denied", "-hasSeenOnboarding", "YES"]
    }

    func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    /// Tap an App Store button and check the link leaves the app. A device
    /// opens the App Store; the Simulator has no App Store app, so the link
    /// goes to Safari (which can't show apps.apple.com pages there).
    func assertOpensAppStoreLink(_ button: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
        safari.terminate()
        button.tap()
        let appStore = XCUIApplication(bundleIdentifier: "com.apple.AppStore")
        XCTAssertTrue(safari.wait(for: .runningForeground, timeout: 10) || appStore.state == .runningForeground,
                      "tapping Update leaves the app for the App Store link", file: file, line: line)
        safari.terminate()
        app.activate()
    }

    func openFeedTab() {
        let tab = element("tab-feed")
        XCTAssertTrue(tab.waitForExistence(timeout: 10))
        tab.tap()
    }

    func startSession() {
        let start = element("start-button")
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        start.tap()
        XCTAssertTrue(element("close-button").waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["wheel-chord-0"].waitForExistence(timeout: 10), "the Scale wheel is up")
    }

    func openMusicSettings(section: String? = nil) {
        element("settings-button").tap()
        if let section {
            let tab = app.buttons["music-settings-\(section)"]
            XCTAssertTrue(tab.waitForExistence(timeout: 5))
            if !tab.isSelected { tab.tap() }
        }
    }

    func reveal(_ item: XCUIElement) {
        let scroll = app.scrollViews["music-settings-scroll"].firstMatch
        XCTAssertTrue(scroll.waitForExistence(timeout: 5))
        for _ in 0..<6 where !item.isHittable { scroll.swipeUp() }
        XCTAssertTrue(item.isHittable)
    }

    /// The Store sheet, opened from music settings.
    func openStore() {
        openMusicSettings()
        let store = app.buttons["Store"].firstMatch
        XCTAssertTrue(store.waitForExistence(timeout: 5))
        store.tap()
        XCTAssertTrue(app.staticTexts["STORE"].waitForExistence(timeout: 5))
    }

    /// The DEBUG instrument-file picker's menu items.
    func openInstrumentPicker() -> XCUIElement {
        openMusicSettings(section: "play")
        let picker = app.buttons["instrument-file-picker"].firstMatch
        reveal(picker)
        picker.tap()
        return picker
    }

    /// True when the wheel's chord half is on the right of the screen.
    var chordsOnRight: Bool {
        let chord = app.buttons["wheel-chord-0"].firstMatch
        return chord.frame.midX > app.windows.firstMatch.frame.midX
    }

    static func catalogRow(id: String, name: String, formatVersion: Int = 1, chordSide: String = "right",
                           body override: [String: Any]? = nil) -> [String: Any] {
        let body = override ?? [
            "format": "handstrudel.instrument", "format_version": formatVersion, "id": id, "name": name,
            "surface": ["type": "split_wheel", "radius": 0.9, "rest_radius": 0.3, "octave_band_radius": 0.75],
            "chords": ["side": chordSide],
            "notes": ["source": "scale_one_octave", "octave_band": true, "highlight_chord_tones": true],
        ]
        let text = String(decoding: try! JSONSerialization.data(withJSONObject: body), as: UTF8.self)
        return ["id": id, "format_version": formatVersion, "body": text, "sort_order": 0]
    }
}

final class RemoteConfigUITests: RemoteConfigUITestCase {
    private func launch(rows: String, catalog: String = "[]") {
        app.launchEnvironment["HANDSTRUDEL_REMOTE_CONFIG_FIXTURE"] = rows
        app.launchEnvironment["HANDSTRUDEL_INSTRUMENT_CATALOG_FIXTURE"] = catalog
        app.launch()
    }

    func testFixtureTurnsOffTheFeedAndShowsTheUpdateBanner() {
        // A fresh version each run, since dismissing the banner is remembered per version.
        let version = "99.0.\(Int.random(in: 1...999_999))"
        launch(rows: """
        [{"id":1,"key":"feed.enabled","value":false,"rollout_percent":100,"priority":0},
         {"id":2,"key":"update.recommended_version","value":"\(version)","rollout_percent":100,"priority":0},
         {"id":3,"key":"update.message","value":"Fixture says update.","rollout_percent":100,"priority":0}]
        """)
        let banner = element("update-banner")
        XCTAssertTrue(banner.waitForExistence(timeout: 10), "the soft update banner appears")
        XCTAssertTrue(app.staticTexts["Fixture says update."].exists)
        XCTAssertFalse(element("update-required").exists)

        openFeedTab()
        let unavailable = element("feed-unavailable")
        XCTAssertTrue(unavailable.waitForExistence(timeout: 5), "the kill switch replaces the feed")
        XCTAssertTrue(unavailable.label.contains("taking a short break"), unavailable.label)

        assertOpensAppStoreLink(element("update-banner-open"))
        XCTAssertTrue(banner.waitForExistence(timeout: 5), "the banner stays until dismissed")

        element("update-banner-dismiss").tap()
        XCTAssertTrue(banner.waitForNonExistence(timeout: 5), "the banner can be dismissed")
        app.terminate()
        app.launchArguments.removeAll { $0 == "--reset-remote-content" }
        app.launch()
        XCTAssertTrue(element("tab-feed").waitForExistence(timeout: 10))
        XCTAssertFalse(element("update-banner").waitForExistence(timeout: 3), "dismissal sticks for that version")
    }

    func testFixtureBlocksAnUnsupportedVersion() {
        launch(rows: """
        [{"id":1,"key":"update.minimum_version","value":"99.0","rollout_percent":100,"priority":0}]
        """)
        XCTAssertTrue(element("update-required").waitForExistence(timeout: 10), "the hard block appears")
        XCTAssertTrue(app.staticTexts["Update required"].exists)

        // Taps on the app underneath don't get through.
        let feedTab = element("tab-feed")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.95)).tap()
        XCTAssertTrue(element("update-required").exists)
        XCTAssertFalse(element("feed-unavailable").exists)
        XCTAssertFalse(feedTab.isSelected)

        assertOpensAppStoreLink(element("update-required-open"))
        XCTAssertTrue(element("update-required").waitForExistence(timeout: 5), "the block is still there on return")
    }

    func testNoConfigLeavesTheAppAsItWas() {
        launch(rows: "[]")
        XCTAssertTrue(element("tab-feed").waitForExistence(timeout: 10))
        XCTAssertFalse(element("update-required").exists)
        XCTAssertFalse(element("update-banner").exists)
        openFeedTab()
        XCTAssertTrue(element("feed-unavailable").waitForNonExistence(timeout: 5), "the feed is on by default")

        app.activate()
        element("tab-music").tap()
        startSession()
        openStore()
        XCTAssertTrue(app.staticTexts["HandStrudel Pro"].exists, "default store copy")
        XCTAssertTrue(app.staticTexts["One-time purchase"].exists)
        XCTAssertFalse(element("store-pro-note").exists)
    }

    func testFixtureRewritesTheProStoreCopy() {
        launch(rows: """
        [{"id":1,"key":"store.pro_title","value":"Pro (fixture)","rollout_percent":100,"priority":0},
         {"id":2,"key":"store.pro_features","value":["Every instrument","Every scale"],"rollout_percent":100,"priority":0},
         {"id":3,"key":"store.pro_note","value":"Holiday sale: this week only","rollout_percent":100,"priority":0}]
        """)
        startSession()
        openStore()
        XCTAssertTrue(app.staticTexts["Pro (fixture)"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["HandStrudel Pro"].exists)
        XCTAssertTrue(app.staticTexts["Every instrument"].exists)
        XCTAssertTrue(app.staticTexts["Every scale"].exists)
        XCTAssertFalse(app.staticTexts["One-time purchase"].exists, "the bullets are replaced, not appended")
        XCTAssertEqual(element("store-pro-note").label, "Holiday sale: this week only")
    }

    func testDownloadedInstrumentPlaysTheWheel() throws {
        let rows: [[String: Any]] = [
            Self.catalogRow(id: "community.big-wheel", name: "Big Wheel", chordSide: "right"),
            Self.catalogRow(id: "community.future", name: "Future Wheel", formatVersion: 2),
            Self.catalogRow(id: "community.broken", name: "Broken", body: ["format_version": 1, "id": "community.broken"]),
            Self.catalogRow(id: "demo.wide-wheel", name: "Hijacked Wide"),
        ]
        let catalog = String(decoding: try JSONSerialization.data(withJSONObject: rows), as: UTF8.self)
        launch(rows: "[]", catalog: catalog)
        startSession()
        XCTAssertFalse(chordsOnRight, "the bundled Scale wheel has chords on the left")

        let picker = openInstrumentPicker()
        XCTAssertTrue(app.buttons["Big Wheel"].waitForExistence(timeout: 5), "the downloaded file is listed")
        XCTAssertFalse(app.buttons["Future Wheel"].exists, "newer formats are skipped")
        XCTAssertFalse(app.buttons["Broken"].exists, "invalid files are rejected")
        XCTAssertFalse(app.buttons["Hijacked Wide"].exists, "bundled files win on id collisions")
        XCTAssertTrue(app.buttons["Wide Wheel"].exists)
        app.buttons["Big Wheel"].tap()
        XCTAssertEqual(picker.label, "Big Wheel")
        app.buttons["music-settings-done"].tap()

        XCTAssertTrue(app.buttons["wheel-chord-0"].waitForExistence(timeout: 5))
        XCTAssertTrue(chordsOnRight, "the wheel now plays from the downloaded file (chords on the right)")
    }
}

/// End to end through the app's real network code against a local Supabase
/// stack. Opt-in: run with
/// `TEST_RUNNER_HANDSTRUDEL_LIVE_SUPABASE_URL=http://127.0.0.1:<port>`,
/// `TEST_RUNNER_HANDSTRUDEL_LIVE_ANON_KEY` and `TEST_RUNNER_HANDSTRUDEL_LIVE_SERVICE_KEY`.
/// Refuses any non-local URL, so it can never write to production.
final class RemoteConfigLiveUITests: RemoteConfigUITestCase {
    private var baseURL: URL!
    private var serviceKey = ""

    override func setUpWithError() throws {
        try super.setUpWithError()
        let env = ProcessInfo.processInfo.environment
        guard let url = env["HANDSTRUDEL_LIVE_SUPABASE_URL"].flatMap(URL.init(string:)),
              let anon = env["HANDSTRUDEL_LIVE_ANON_KEY"], let service = env["HANDSTRUDEL_LIVE_SERVICE_KEY"] else {
            throw XCTSkip("Set TEST_RUNNER_HANDSTRUDEL_LIVE_SUPABASE_URL / _ANON_KEY / _SERVICE_KEY to run against a local stack")
        }
        guard ["127.0.0.1", "localhost"].contains(url.host ?? "") else { throw XCTSkip("Local stacks only") }
        baseURL = url
        serviceKey = service
        app.launchEnvironment["SUPABASE_URL"] = url.absoluteString
        app.launchEnvironment["SUPABASE_ANON_KEY"] = anon
    }

    @discardableResult
    private func rest(_ method: String, _ path: String, _ body: Any? = nil) async throws -> Any {
        var request = URLRequest(url: URL(string: "rest/v1/\(path)", relativeTo: baseURL)!)
        request.httpMethod = method
        request.setValue(serviceKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(serviceKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        if let body { request.httpBody = try JSONSerialization.data(withJSONObject: body) }
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        XCTAssertTrue((200..<300).contains(status), "\(method) \(path): \(status) \(String(decoding: data, as: UTF8.self))")
        return data.isEmpty ? [] : try JSONSerialization.jsonObject(with: data)
    }

    private func relaunch() {
        app.terminate()
        app.launchArguments.removeAll { $0 == "--reset-remote-content" }
        app.launch()
    }

    @MainActor
    func testRealRPCsDriveTheAppAndRollBack() async throws {
        try await rest("DELETE", "app_config?id=gt.0")
        try await rest("DELETE", "instrument_catalog?id=neq.none")
        let version = "99.0.\(Int.random(in: 1...999_999))"
        let base: [String: Any] = ["platform": "all", "priority": 0, "max_app_version": NSNull(), "note": "live UI test"]
        let rows = try await rest("POST", "app_config", [
            ["key": "feed.enabled", "value": false],
            ["key": "store.pro_title", "value": "Pro (live)"],
            ["key": "store.pro_note", "value": "Live note"],
            ["key": "feed.page_size", "value": 15],
            ["key": "update.recommended_version", "value": version],
            // Android-only and older-version rows must not reach this app.
            ["key": "store.pro_note", "value": "Android only", "platform": "android", "priority": 5],
            ["key": "store.pro_title", "value": "Old builds", "max_app_version": "1.0.0", "priority": 5],
        ].map { base.merging($0) { $1 } }) as? [[String: Any]]
        let feedRow = try XCTUnwrap(rows?.first { $0["key"] as? String == "feed.enabled" }?["id"] as? Int)
        var catalog = [Self.catalogRow(id: "community.live-wheel", name: "Live Wheel", chordSide: "right"),
                       Self.catalogRow(id: "community.next-format", name: "Next Format", formatVersion: 2),
                       Self.catalogRow(id: "community.broken", name: "Broken", body: ["format_version": 1, "id": "community.broken"])]
        for index in catalog.indices {
            catalog[index]["body"] = try JSONSerialization.jsonObject(with: Data((catalog[index]["body"] as! String).utf8))
        }
        try await rest("POST", "instrument_catalog", catalog)

        // 1. Banner and kill switch from app_config_for().
        app.launch()
        XCTAssertTrue(element("update-banner").waitForExistence(timeout: 15), "banner from the real RPC")
        assertOpensAppStoreLink(element("update-banner-open"))
        openFeedTab()
        XCTAssertTrue(element("feed-unavailable").waitForExistence(timeout: 5), "kill switch from the real RPC")

        // 2. The downloaded instrument and the store copy.
        element("tab-music").tap()
        startSession()
        let picker = openInstrumentPicker()
        XCTAssertTrue(app.buttons["Live Wheel"].waitForExistence(timeout: 5), "instrument from instrument_catalog_for()")
        XCTAssertFalse(app.buttons["Next Format"].exists)
        XCTAssertFalse(app.buttons["Broken"].exists)
        app.buttons["Live Wheel"].tap()
        XCTAssertEqual(picker.label, "Live Wheel")
        app.buttons["music-settings-done"].tap()
        XCTAssertTrue(app.buttons["wheel-chord-0"].waitForExistence(timeout: 5))
        XCTAssertTrue(chordsOnRight, "the wheel plays the downloaded file")
        openStore()
        XCTAssertTrue(app.staticTexts["Pro (live)"].waitForExistence(timeout: 5))
        XCTAssertEqual(element("store-pro-note").label, "Live note", "platform and version targeting applied")

        // 3. Roll back: disable the kill switch row, unpublish the instrument.
        try await rest("PATCH", "app_config?id=eq.\(feedRow)", ["enabled": false])
        try await rest("PATCH", "instrument_catalog?id=eq.community.live-wheel", ["published": false])
        relaunch()
        openFeedTab()
        XCTAssertTrue(element("feed-unavailable").waitForNonExistence(timeout: 10), "the feed comes back after rollback")
        // Latest (unlike Discover, fixed at 24) pages by feed.page_size, read at
        // launch from the previous launch's cache. The request's limit is
        // checked in the stack's API log by the caller.
        let options = element("feed-options")
        XCTAssertTrue(options.waitForExistence(timeout: 10))
        options.tap()
        let latest = app.buttons["Latest"].firstMatch
        XCTAssertTrue(latest.waitForExistence(timeout: 5))
        latest.tap()
        XCTAssertEqual(options.value as? String, "Latest")
        sleep(3)
        element("tab-music").tap()
        startSession()
        _ = openInstrumentPicker()
        XCTAssertTrue(app.buttons["Wide Wheel"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Live Wheel"].exists, "an unpublished instrument disappears")
    }
}
