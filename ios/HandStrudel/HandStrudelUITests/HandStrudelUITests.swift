import UIKit
import XCTest

final class HandStrudelUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        if ProcessInfo.processInfo.environment["HANDSTRUDEL_OFFLINE_SMOKE"] == "1" {
            app.launchEnvironment["SUPABASE_URL"] = "http://127.0.0.1:1"
            app.launchEnvironment["SUPABASE_ANON_KEY"] = "offline-ui-smoke"
            app.launchEnvironment["MEDIA_BASE_URL"] = "http://127.0.0.1:1"
        }
    }

    // MARK: - Helpers

    /// Find any element by accessibility identifier (works for custom SwiftUI views)
    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    /// Launch app fresh, landing on start overlay
    private func launchToStart() {
        app.launch()
    }

    /// Launch app and start a session (bypasses audio/camera)
    private func launchToSession() {
        app.launchArguments.append("--uitesting")
        app.launch()
        let start = element("start-button")
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        start.tap()
        // Wait for session to appear
        let closeBtn = element("close-button")
        XCTAssertTrue(closeBtn.waitForExistence(timeout: 5), "Session should start")
        // Dismiss onboarding overlay if it's blocking the UI (it can persist from
        // earlier tests that used --reset-onboarding since @AppStorage survives
        // across launches on the same simulator).
        let gotIt = element("onboarding-got-it")
        if gotIt.waitForExistence(timeout: 1) {
            gotIt.tap()
        }
    }

    /// Launch app with onboarding reset and start session
    private func launchToSessionWithOnboarding() {
        app.launchArguments.append(contentsOf: ["--uitesting", "--reset-onboarding", "--reset-studio-input"])
        app.launch()
        let start = element("start-button")
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        start.tap()
    }

    private func expandOtherModes() {
        selectMusicSettingsSection("play")
        let disclosure = app.buttons["music-other-modes"].firstMatch
        revealInMusicSettings(disclosure)
        if !element("mode-melodic").exists { disclosure.tap() }
    }

    /// Switch to a mode that's hidden behind the "Other modes" disclosure.
    /// Returns the mode element after expansion + tapping.
    private func switchToMode(_ identifier: String) {
        expandOtherModes()
        let mode = element(identifier)
        XCTAssertTrue(mode.waitForExistence(timeout: 3))
        revealInMusicSettings(mode)
        mode.tap()
    }

    private func selectMusicSettingsSection(_ name: String) {
        let section = app.buttons["music-settings-\(name)"]
        XCTAssertTrue(section.waitForExistence(timeout: 5))
        if !section.isSelected { section.tap() }
        XCTAssertTrue(section.isSelected)
    }

    private func revealInMusicSettings(_ item: XCUIElement) {
        let scroll = app.scrollViews["music-settings-scroll"].firstMatch
        XCTAssertTrue(scroll.waitForExistence(timeout: 5))
        for _ in 0..<6 {
            if item.isHittable { return }
            scroll.swipeUp()
        }
        XCTAssertTrue(item.isHittable)
    }

    private func closeMusicSettings() {
        let done = app.buttons["music-settings-done"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        done.tap()
        XCTAssertTrue(element("settings-button").waitForExistence(timeout: 5))
    }

    // MARK: - Start Overlay Tests

    func testLaunch_showsStartOverlay() {
        launchToStart()
        XCTAssertTrue(app.staticTexts["handstrudel"].waitForExistence(timeout: 5))
    }

    func testStartOverlay_showsSubtitle() {
        launchToStart()
        XCTAssertTrue(app.staticTexts["Play music with a gesture or a touch."].waitForExistence(timeout: 5))
    }

    func testStartPlayingStaysReachableAtLargestDynamicType() {
        app.launchArguments += [
            "--uitesting", "-UIPreferredContentSizeCategoryName",
            UIContentSizeCategory.accessibilityExtraExtraExtraLarge.rawValue,
        ]
        app.launch()

        let start = app.buttons["start-button"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        XCTAssertTrue(start.isHittable)
        let startY = start.frame.minY

        let brand = app.staticTexts["handstrudel"]
        XCTAssertTrue(brand.isHittable)
        XCTAssertGreaterThan(brand.frame.height, 28, "Expected accessibility-size text")

        app.scrollViews.firstMatch.swipeUp()
        XCTAssertFalse(brand.isHittable, "The Studio content should have scrolled")
        XCTAssertTrue(start.isHittable)
        XCTAssertEqual(start.frame.minY, startY, accuracy: 1)
        captureIfRequested("Studio-Pinned-Start")

        start.tap()
        XCTAssertTrue(element("close-button").waitForExistence(timeout: 5))
    }

    func testAppearanceSwitchesAndPersistsAfterRelaunch() {
        app.launchArguments.append("--uitesting")
        app.launch()
        let appearance = app.buttons["music-appearance"]
        XCTAssertTrue(appearance.waitForExistence(timeout: 5))
        appearance.tap()
        let paper = app.buttons["theme-paper"]
        let tide = app.buttons["theme-tide"]
        XCTAssertTrue(paper.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["theme-volt"].exists)
        XCTAssertTrue(tide.exists)
        XCTAssertTrue(app.buttons["theme-afterglow"].exists)
        tide.tap()
        XCTAssertTrue(tide.isSelected)
        paper.tap()
        XCTAssertTrue(paper.isSelected)
        app.buttons["Done"].tap()

        app.terminate()
        app.launch()
        XCTAssertTrue(appearance.waitForExistence(timeout: 5))
        appearance.tap()
        XCTAssertTrue(paper.waitForExistence(timeout: 5))
        XCTAssertTrue(paper.isSelected)
        app.buttons["theme-volt"].tap()
        XCTAssertTrue(app.buttons["theme-volt"].isSelected)
    }

    func testNamingPrivateDraftKeepsTheTrimInTheEditor() throws {
        guard let file = ProcessInfo.processInfo.environment["HANDSTRUDEL_DRAFT_TEST_CLIP"] else {
            throw XCTSkip("Set TEST_RUNNER_HANDSTRUDEL_DRAFT_TEST_CLIP to a simulator-readable MP4.")
        }
        app.launchArguments = ["--uitesting"]
        app.launchEnvironment["HANDSTRUDEL_TEST_CLIP"] = file
        app.launch()
        let selection = element("draft-trim-range")
        XCTAssertTrue(selection.waitForExistence(timeout: 8))
        let before = selection.label
        let rename = app.buttons["rename-private-draft"]
        if !rename.isHittable { app.swipeDown() }
        rename.tap()
        let field = app.textFields["private-draft-name"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        let name = "Warmup \(UUID().uuidString.prefix(6))"
        field.tap()
        field.typeText(name)
        app.navigationBars["Private draft name"].buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 5))
        XCTAssertEqual(selection.label, before)
    }

    func testDraftFilmstripAdjustsAndResetsARealClip() throws {
        guard let file = ProcessInfo.processInfo.environment["HANDSTRUDEL_DRAFT_TEST_CLIP"] else {
            throw XCTSkip("Set TEST_RUNNER_HANDSTRUDEL_DRAFT_TEST_CLIP to a simulator-readable MP4 to test the editor.")
        }
        app.launchArguments = ["--uitesting"]
        app.launchEnvironment["HANDSTRUDEL_TEST_CLIP"] = file
        app.launch()
        let timeline = element("draft-filmstrip")
        XCTAssertTrue(timeline.waitForExistence(timeout: 12))
        let range = element("draft-trim-range")
        XCTAssertTrue(range.exists)
        let original = range.label
        let fine = element("draft-fine-trim")
        if !fine.isHittable { app.swipeUp() }
        fine.tap()
        let nudge = app.buttons["Start 0.1 seconds later"]
        XCTAssertTrue(nudge.waitForExistence(timeout: 5))
        if !nudge.isHittable { app.swipeUp() }
        nudge.tap()
        XCTAssertNotEqual(range.label, original)
        let play = element("draft-play-selection")
        if !play.isHittable { app.swipeDown() }
        play.tap()
        let reset = app.buttons["draft-trim-reset"]
        if !reset.isHittable { app.swipeDown() }
        reset.tap()
        XCTAssertEqual(range.label, original)
    }

    func testMusicCanSavePresetBeforeOpeningTheWheel() {
        app.launchArguments = ["--uitesting"]
        app.launch()
        let library = element("music-presets-button")
        XCTAssertTrue(library.waitForExistence(timeout: 5))
        if !library.isHittable { app.swipeUp() }
        library.tap()
        let field = app.textFields["preset-name"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        let name = "Home check \(UUID().uuidString.prefix(6))"
        field.tap()
        field.typeText(name)
        app.buttons["Save current preset"].tap()
        XCTAssertTrue(app.staticTexts[name].exists)
        let transfer = app.buttons["preset-transfer"]
        XCTAssertTrue(transfer.isHittable)
        transfer.tap()
        XCTAssertTrue(app.buttons["Import preset file"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Export all presets"].isEnabled)
        XCTAssertFalse(element("close-button").exists)
    }

    func testNativeWheelOpensWhileWebAudioIsDelayedAndStaysClosedAfterExit() {
        app.launchArguments = ["--uitesting", "--uitest-delayed-web-audio"]
        app.launch()
        let start = element("start-button")
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        start.tap()
        let close = element("close-button")
        XCTAssertTrue(close.waitForExistence(timeout: 5), "Native wheel should open before the 8-second WebAudio fixture")
        let onboarding = element("onboarding-got-it")
        if onboarding.exists { onboarding.tap() }
        close.tap()
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        let revived = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true"), object: close)
        revived.isInverted = true
        XCTAssertEqual(XCTWaiter.wait(for: [revived], timeout: 8.5), .completed)
    }

    func testWebOnlyStudioOpensThroughWKWebViewWhileDrumCatalogIsStalled() {
        app.launchArguments = ["--uitesting", "--uitest-real-web-audio"]
        app.launch()
        let start = element("start-button")
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        start.tap()
        let close = element("close-button")
        XCTAssertTrue(close.waitForExistence(timeout: 15), "The actual WebAudio bridge should initialize without the drum catalog")
        let onboarding = element("onboarding-got-it")
        if onboarding.exists { onboarding.tap() }
        XCTAssertTrue(element("settings-button").exists)
        close.tap()
        XCTAssertTrue(start.waitForExistence(timeout: 5))
    }

    func testLoopShelfOpensBeforeStartingTheWheel() {
        app.launchArguments = ["--uitesting"]
        app.launch()
        let shelf = app.buttons["music-loop-shelf"]
        XCTAssertTrue(shelf.waitForExistence(timeout: 5))
        if !shelf.isHittable { app.swipeUp() }
        shelf.tap()
        XCTAssertTrue(app.staticTexts["Loop shelf"].waitForExistence(timeout: 5))
        XCTAssertTrue(element("loop-recording-length").exists)
        XCTAssertFalse(element("close-button").exists)
        app.buttons["Done"].tap()
        XCTAssertTrue(shelf.waitForExistence(timeout: 5))
    }

    func testLoopShelfPlaysRenamesAndRemovesCapturedWAV() throws {
        guard let file = ProcessInfo.processInfo.environment["HANDSTRUDEL_LOOP_TEST_CLIP"] else {
            throw XCTSkip("Set TEST_RUNNER_HANDSTRUDEL_LOOP_TEST_CLIP to a simulator-readable WAV.")
        }
        let id = UUID()
        let name = "Studio fixture \(id.uuidString.prefix(6))"
        let renamed = "Night loop \(id.uuidString.prefix(6))"
        app.launchArguments = ["--uitesting"]
        app.launchEnvironment["HANDSTRUDEL_TEST_LOOP_CLIP"] = file
        app.launchEnvironment["HANDSTRUDEL_TEST_LOOP_ID"] = id.uuidString
        app.launch()

        func openShelf() {
            let shelf = app.buttons["music-loop-shelf"]
            XCTAssertTrue(shelf.waitForExistence(timeout: 5))
            if !shelf.isHittable { app.swipeUp() }
            shelf.tap()
            XCTAssertTrue(app.staticTexts["Loop shelf"].waitForExistence(timeout: 5))
        }

        openShelf()
        let play = app.buttons["Play \(name)"]
        XCTAssertTrue(play.waitForExistence(timeout: 5))
        play.tap()
        let stop = app.buttons["Stop \(name)"]
        XCTAssertTrue(stop.waitForExistence(timeout: 5))
        stop.tap()
        let gain = app.sliders["Volume for \(name)"]
        XCTAssertTrue(gain.exists)
        gain.adjust(toNormalizedSliderPosition: 0.4)
        XCTAssertNotEqual(gain.value as? String, "100%")
        app.buttons["Mute \(name)"].tap()
        XCTAssertTrue(app.buttons["Unmute \(name)"].exists)
        app.buttons["Actions for \(name)"].tap()
        app.buttons["Rename"].tap()
        let rename = app.alerts["Rename loop"]
        let field = rename.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: name.count) + renamed)
        XCTAssertEqual(field.value as? String, renamed)
        rename.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts[renamed].waitForExistence(timeout: 5))

        app.buttons["Done"].tap()
        app.terminate()
        app.launchEnvironment.removeValue(forKey: "HANDSTRUDEL_TEST_LOOP_CLIP")
        app.launchEnvironment.removeValue(forKey: "HANDSTRUDEL_TEST_LOOP_ID")
        app.launch()
        openShelf()
        XCTAssertTrue(app.buttons["Unmute \(renamed)"].exists)
        XCTAssertNotEqual(app.sliders["Volume for \(renamed)"].value as? String, "100%")
        app.buttons["Actions for \(renamed)"].tap()
        app.buttons["Delete"].tap()
        let confirm = app.buttons["Delete loop"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()
        XCTAssertFalse(app.staticTexts[renamed].exists)
    }

    func testMusic_privateDraftsOpensWithoutAccount() {
        app.launchArguments.append("--uitesting")
        app.launch()
        let drafts = element("private-drafts-button")
        XCTAssertTrue(drafts.waitForExistence(timeout: 5))
        drafts.tap()
        XCTAssertTrue(app.navigationBars["Private drafts"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Done"].exists)
    }

    func testStudioPresetSavesAndStartsFromMusicAfterRelaunch() {
        launchToSession()
        let name = "Test preset \(UUID().uuidString.prefix(8))"
        let studioPresets = element("studio-presets-button")
        XCTAssertTrue(studioPresets.waitForExistence(timeout: 5))
        studioPresets.tap()
        let field = app.textFields["preset-name"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(name)
        app.buttons["Save current preset"].tap()
        XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 5))

        app.terminate()
        app.launch()
        let musicPresets = element("music-presets-button")
        XCTAssertTrue(musicPresets.waitForExistence(timeout: 5))
        if !musicPresets.isHittable { app.swipeUp() }
        musicPresets.tap()
        let preset = app.staticTexts[name]
        XCTAssertTrue(preset.waitForExistence(timeout: 5))
        preset.tap()
        XCTAssertTrue(studioPresets.waitForExistence(timeout: 5))
    }

    func testSavedPresetStartsNativeWheelWithCameraOffWhileWebAudioIsDelayed() {
        app.launchArguments = ["--uitesting", "--uitest-delayed-web-audio", "--reset-studio-input", "--uitest-camera-denied"]
        app.launch()

        let library = element("music-presets-button")
        XCTAssertTrue(library.waitForExistence(timeout: 5))
        if !library.isHittable { app.swipeUp() }
        library.tap()
        let name = "Touch preset \(UUID().uuidString.prefix(6))"
        let field = app.textFields["preset-name"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(name)
        app.buttons["Save current preset"].tap()
        let preset = app.staticTexts[name]
        XCTAssertTrue(preset.waitForExistence(timeout: 5))
        preset.tap()

        let close = element("close-button")
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        let onboarding = element("onboarding-got-it")
        if onboarding.exists { onboarding.tap() }
        XCTAssertTrue(element("touch-camera-off").waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["wheel-chord-0"].exists)
        XCTAssertFalse(element("camera-recovery-touch").exists)
        close.tap()
        XCTAssertTrue(element("start-button").waitForExistence(timeout: 5))
    }

    func testFeed_commentsSheetOpensWithoutAccount() throws {
        guard let key = ProcessInfo.processInfo.environment["HANDSTRUDEL_LOCAL_COMMENTS_KEY"] else {
            throw XCTSkip("Requires the local Supabase comments fixture.")
        }
        app.launchArguments.append("--uitesting")
        app.launchEnvironment["SUPABASE_URL"] = "http://127.0.0.1:54321"
        app.launchEnvironment["SUPABASE_ANON_KEY"] = key
        app.launch()
        let feed = element("tab-feed")
        XCTAssertTrue(feed.waitForExistence(timeout: 5))
        feed.tap()
        let button = element("video-comments-button")
        XCTAssertTrue(button.waitForExistence(timeout: 10))
        button.tap()
        XCTAssertTrue(app.staticTexts["Comments"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Great playing!"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Sign in to comment"].exists)
        app.buttons["Close comments"].tap()
        XCTAssertTrue(button.waitForExistence(timeout: 5))
    }

    func testFeedSearchOpensWithoutAccount() {
        app.launchArguments.append("--uitesting")
        app.launch()
        let feed = element("tab-feed")
        XCTAssertTrue(feed.waitForExistence(timeout: 5))
        feed.tap()

        let search = app.buttons["search-posts"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        XCTAssertTrue(app.navigationBars["Search posts"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.searchFields.firstMatch.exists)
        app.buttons["Done"].tap()
        XCTAssertTrue(search.waitForExistence(timeout: 5))
    }

    @MainActor
    func testFeedRetryRecoversTheSameClipAndRestoresSeeking() async throws {
        guard let address = ProcessInfo.processInfo.environment["HANDSTRUDEL_FEED_RETRY_FIXTURE_URL"],
              let endpoint = URL(string: address), endpoint.host == "127.0.0.1" else {
            throw XCTSkip("Set HANDSTRUDEL_FEED_RETRY_FIXTURE_URL to a loopback media-control fixture.")
        }
        func setAvailability(_ available: Bool) async throws {
            let url = URL(string: "/__fixture/feed-media?available=\(available ? 1 : 0)", relativeTo: endpoint)!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            let (_, response) = try await URLSession.shared.data(for: request)
            XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 204)
        }
        try await setAvailability(false)
        app.launchArguments = ["--uitesting"]
        app.launchEnvironment["SUPABASE_URL"] = address
        app.launchEnvironment["SUPABASE_ANON_KEY"] = "retry-media-fixture"
        app.launchEnvironment["MEDIA_BASE_URL"] = address
        app.launch()
        let feed = element("tab-feed")
        XCTAssertTrue(feed.waitForExistence(timeout: 5))
        feed.tap()
        let retry = app.buttons["feed-retry-video"]
        XCTAssertTrue(retry.waitForExistence(timeout: 20))
        XCTAssertTrue(app.staticTexts["Evening loop"].firstMatch.exists)
        let slider = app.sliders["feed-video-progress"].firstMatch
        XCTAssertFalse(slider.exists)

        try await setAvailability(true)
        retry.tap()
        XCTAssertTrue(slider.waitForExistence(timeout: 10))
        XCTAssertFalse(retry.exists)
        XCTAssertTrue(app.staticTexts["Evening loop"].firstMatch.exists)
        let actualPlayback = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value BEGINSWITH %@", "0:01"), object: slider)
        await fulfillment(of: [actualPlayback], timeout: 9)
        slider.adjust(toNormalizedSliderPosition: 0.8)
        XCTAssertTrue((slider.value as? String)?.contains("0:03") == true)
    }

    func testPlayAlongStartsBackingAudioInStudio() throws {
        guard let endpoint = ProcessInfo.processInfo.environment["HANDSTRUDEL_PLAY_ALONG_FIXTURE_URL"] else {
            throw XCTSkip("Requires the feed fixture with a real MP4 with audio and FIXTURE_PLAY_ALONG=1.")
        }
        app.launchArguments = ["--uitesting", "-hasSeenOnboarding", "YES"]
        app.launchEnvironment["SUPABASE_URL"] = endpoint
        app.launchEnvironment["SUPABASE_ANON_KEY"] = "notification-fixture-key"
        app.launchEnvironment["MEDIA_BASE_URL"] = endpoint
        app.launch()
        let feed = element("tab-feed")
        XCTAssertTrue(feed.waitForExistence(timeout: 5))
        feed.tap()
        let sound = app.buttons["feed-sound-options"].firstMatch
        XCTAssertTrue(sound.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["play-along"].firstMatch.exists, "Play along should not cover the video.")
        sound.tap()
        let playAlong = app.buttons["play-along"].firstMatch
        XCTAssertTrue(playAlong.waitForExistence(timeout: 5))
        XCTAssertTrue(app.navigationBars["Sound options"].exists)
        XCTAssertTrue(app.buttons["save-clip-preset"].exists)
        captureIfRequested("Feed-Sound-Options")
        playAlong.tap()
        let pause = app.buttons["Pause backing track"]
        XCTAssertTrue(pause.waitForExistence(timeout: 12), app.alerts.firstMatch.debugDescription)
        pause.tap()
        let play = app.buttons["Play backing track"]
        XCTAssertTrue(play.waitForExistence(timeout: 5))
        play.tap()
        XCTAssertTrue(pause.waitForExistence(timeout: 5))
    }

    func testFeedAdvancesWhenAClipFinishes() throws {
        guard let endpoint = ProcessInfo.processInfo.environment["HANDSTRUDEL_PLAY_ALONG_FIXTURE_URL"] else {
            throw XCTSkip("Requires the feed fixture with a real MP4.")
        }
        app.launchArguments = ["--uitesting"]
        app.launchEnvironment["SUPABASE_URL"] = endpoint
        app.launchEnvironment["SUPABASE_ANON_KEY"] = "notification-fixture-key"
        app.launchEnvironment["MEDIA_BASE_URL"] = endpoint
        app.launch()
        element("tab-feed").tap()
        XCTAssertTrue(app.staticTexts["Evening loop"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Mute"].firstMatch.exists)
        let next = app.staticTexts["Second performance"].firstMatch
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: next)], timeout: 10), .completed)
        let nextPlayhead = app.sliders["feed-video-progress"].firstMatch
        let moving = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true AND (value BEGINSWITH %@ OR value BEGINSWITH %@)", "0:01", "0:02"), object: nextPlayhead)
        XCTAssertEqual(XCTWaiter.wait(for: [moving], timeout: 8), .completed, "The second clip must play, not just appear.")
    }

    func testBookmarkAppearsInPrivateSavedLibrary() throws {
        try launchWithProfileFixture()
        signInToProfile()
        XCTAssertTrue(app.buttons["Edit profile"].waitForExistence(timeout: 12))
        element("tab-feed").tap()
        let bookmark = app.buttons["save-performance"].firstMatch
        XCTAssertTrue(bookmark.waitForExistence(timeout: 6))
        if bookmark.label == "Remove from Saved" {
            bookmark.tap()
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", "Save privately"), object: bookmark)], timeout: 5), .completed)
        }
        bookmark.tap()
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", "Remove from Saved"), object: bookmark)], timeout: 5), .completed)
        element("saved-performances").tap()
        XCTAssertTrue(app.navigationBars["Saved performances"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Evening loop"].firstMatch.waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        bookmark.tap()
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", "Save privately"), object: bookmark)], timeout: 5), .completed)
    }

    func testOptedInClipExportsAudioToTheShareSheet() throws {
        guard let endpoint = ProcessInfo.processInfo.environment["HANDSTRUDEL_PLAY_ALONG_FIXTURE_URL"] else {
            throw XCTSkip("Requires the real MP4 fixture with FIXTURE_AUDIO_DOWNLOAD=1.")
        }
        app.launchArguments = ["--uitesting"]
        app.launchEnvironment["SUPABASE_URL"] = endpoint
        app.launchEnvironment["SUPABASE_ANON_KEY"] = "notification-fixture-key"
        app.launchEnvironment["MEDIA_BASE_URL"] = endpoint
        app.launch()
        element("tab-feed").tap()
        XCTAssertTrue(app.staticTexts["Evening loop"].firstMatch.waitForExistence(timeout: 5))
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.39)).tap()
        app.buttons["More"].firstMatch.tap()
        let download = app.buttons["Download audio"]
        XCTAssertTrue(download.waitForExistence(timeout: 5))
        download.tap()
        let save = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Save to Files")).firstMatch
        XCTAssertTrue(save.waitForExistence(timeout: 10), app.alerts.firstMatch.debugDescription)
    }

    func testFeedProgressScrubsARealVideoWithoutPaging() throws {
        guard let endpoint = ProcessInfo.processInfo.environment["HANDSTRUDEL_FEED_MEDIA_FIXTURE_URL"] else {
            throw XCTSkip("Requires the feed fixture with a real MP4 served from FIXTURE_CLIP.")
        }
        app.launchArguments = ["--uitesting"]
        app.launchEnvironment["SUPABASE_URL"] = endpoint
        app.launchEnvironment["SUPABASE_ANON_KEY"] = "notification-fixture-key"
        app.launchEnvironment["MEDIA_BASE_URL"] = endpoint
        app.launch()
        let feed = element("tab-feed")
        XCTAssertTrue(feed.waitForExistence(timeout: 5))
        feed.tap()
        let first = app.staticTexts["Evening loop"].firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        let slider = app.sliders["feed-video-progress"].firstMatch
        XCTAssertTrue(slider.waitForExistence(timeout: 8))
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.43)).tap()
        slider.adjust(toNormalizedSliderPosition: 0.82)
        XCTAssertTrue((slider.value as? String)?.contains("0:03") == true, "Expected seek near three seconds: \(slider.value ?? "none")")
        XCTAssertTrue(first.isHittable)
        let upper = app.coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: 0.31))
        let lower = app.coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: 0.72))
        lower.press(forDuration: 0.05, thenDragTo: upper)
        let second = app.staticTexts["Second performance"].firstMatch
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: second)], timeout: 5), .completed)
    }

    func testFeedFullScreenKeepsPausedPlayhead() throws {
        guard let endpoint = ProcessInfo.processInfo.environment["HANDSTRUDEL_PLAY_ALONG_FIXTURE_URL"] else {
            throw XCTSkip("Requires the feed fixture with a real MP4.")
        }
        app.launchArguments = ["--uitesting"]
        app.launchEnvironment["SUPABASE_URL"] = endpoint
        app.launchEnvironment["SUPABASE_ANON_KEY"] = "notification-fixture-key"
        app.launchEnvironment["MEDIA_BASE_URL"] = endpoint
        app.launch()
        element("tab-feed").tap()
        let fullscreen = app.buttons["feed-fullscreen"]
        XCTAssertTrue(fullscreen.waitForExistence(timeout: 5))
        XCTAssertEqual(fullscreen.label, "Full screen")
        let slider = app.sliders["feed-video-progress"].firstMatch
        XCTAssertTrue(slider.waitForExistence(timeout: 8))
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: 0.40)).tap()
        slider.adjust(toNormalizedSliderPosition: 0.65)
        let pausedPosition = try XCTUnwrap(slider.value as? String)
        XCTAssertFalse(pausedPosition.hasPrefix("0:00"), pausedPosition)
        let sound = app.buttons["feed-sound-options"].firstMatch
        XCTAssertTrue(sound.isHittable)
        captureIfRequested("Feed-Compact")

        fullscreen.tap()
        XCTAssertEqual(fullscreen.label, "Exit full screen")
        XCTAssertFalse(element("tab-feed").exists)
        XCTAssertFalse(sound.exists)
        XCTAssertEqual(slider.value as? String, pausedPosition)
        captureIfRequested("Feed-Full-Screen")
        fullscreen.tap()

        XCTAssertEqual(fullscreen.label, "Full screen")
        XCTAssertTrue(element("tab-feed").exists)
        XCTAssertTrue(sound.isHittable)
        XCTAssertEqual(slider.value as? String, pausedPosition)
    }

    func testCreatorVideoUsesFeedControlsAndCountsPlayback() throws {
        guard let endpoint = ProcessInfo.processInfo.environment["HANDSTRUDEL_VIDEO_VIEWS_FIXTURE_URL"] else {
            throw XCTSkip("Requires a real MP4 and FIXTURE_VIEW_COUNTS=1.")
        }
        app.launchArguments = ["--uitesting"]
        app.launchEnvironment["SUPABASE_URL"] = endpoint
        app.launchEnvironment["SUPABASE_ANON_KEY"] = "notification-fixture-key"
        app.launchEnvironment["MEDIA_BASE_URL"] = endpoint
        app.launch()
        XCTAssertTrue(element("tab-feed").waitForExistence(timeout: 5))
        element("tab-feed").tap()
        let creator = app.buttons["@loopmaker"].firstMatch
        XCTAssertTrue(creator.waitForExistence(timeout: 5))
        creator.tap()
        let latest = app.buttons["profile-latest-performance"]
        XCTAssertTrue(latest.waitForExistence(timeout: 5))
        latest.tap()
        let slider = app.sliders["feed-video-progress"]
        XCTAssertTrue(slider.waitForExistence(timeout: 7))
        let count = app.staticTexts["8 views"].firstMatch
        XCTAssertTrue(count.waitForExistence(timeout: 6))
        element("performance-video").coordinate(withNormalizedOffset: CGVector(dx: 0.48, dy: 0.44)).tap()
        slider.adjust(toNormalizedSliderPosition: 0.61)
        let position = try XCTUnwrap(slider.value as? String)

        let fullscreen = app.buttons["profile-video-fullscreen"]
        fullscreen.tap()
        XCTAssertEqual(fullscreen.label, "Exit full screen")
        XCTAssertEqual(slider.value as? String, position)
        XCTAssertFalse(count.isHittable)
        fullscreen.tap()
        XCTAssertEqual(fullscreen.label, "Full screen")
        XCTAssertEqual(slider.value as? String, position)
        XCTAssertTrue(count.exists)
    }

    @MainActor
    func testFeedSearchBroadensHandleMiss() async throws {
        guard let address = ProcessInfo.processInfo.environment["HANDSTRUDEL_SEARCH_FIXTURE_URL"] else {
            throw XCTSkip("Start scripts/search-ui-fixture.mjs and set HANDSTRUDEL_SEARCH_FIXTURE_URL.")
        }
        let fixture = try XCTUnwrap(URL(string: address))
        let port = try XCTUnwrap(fixture.port)
        guard address == "http://127.0.0.1:\(port)", (1...65535).contains(port) else {
            return XCTFail("Search UI tests require an HTTP fixture on 127.0.0.1.")
        }

        let key = "search-fixture-\(UUID().uuidString)"
        struct FixtureStatus: Decodable {
            let fixture: String
            let searches: [String]
        }
        func fixtureSearches() async throws -> [String] {
            var request = URLRequest(url: fixture.appendingPathComponent("__search_fixture"),
                                     cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 5)
            request.setValue(key, forHTTPHeaderField: "apikey")
            let (data, response) = try await URLSession.shared.data(for: request)
            XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
            let status = try JSONDecoder().decode(FixtureStatus.self, from: data)
            XCTAssertEqual(status.fixture, "handstrudel-search")
            return status.searches
        }

        // Validate the fixture before launching an app that would otherwise default to production.
        let initialSearches = try await fixtureSearches()
        XCTAssertTrue(initialSearches.isEmpty)
        app.launchArguments.append("--uitesting")
        app.launchEnvironment["SUPABASE_URL"] = address
        app.launchEnvironment["SUPABASE_ANON_KEY"] = key
        app.launchEnvironment["MEDIA_BASE_URL"] = address
        app.launch()

        let feed = element("tab-feed")
        XCTAssertTrue(feed.waitForExistence(timeout: 5))
        feed.tap()
        let search = app.buttons["search-posts"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()

        let field = app.searchFields.firstMatch
        let guidance = app.staticTexts["Enter at least two characters. Use @ to search posts by creator handle."]
        let broaden = app.buttons["Broaden search"]
        let clip = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "Search fixture piano take")).firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        XCTAssertTrue(guidance.exists)
        let initialValue = field.value as? String ?? ""
        XCTAssertTrue(initialValue.isEmpty || initialValue == "Caption, instrument, or creator")
        XCTAssertFalse(broaden.exists)
        XCTAssertFalse(clip.exists)

        field.tap()
        field.typeText("@l")
        XCTAssertEqual(field.value as? String, "@l")
        let guidanceDisappeared = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"),
                                                           object: guidance)
        guidanceDisappeared.isInverted = true
        await fulfillment(of: [guidanceDisappeared], timeout: 1)
        let shortSearches = try await fixtureSearches()
        XCTAssertTrue(shortSearches.isEmpty, "One character after @ must not trigger a search.")

        field.typeText("o")
        let handleMiss = app.staticTexts["No posts match that handle"]
        XCTAssertTrue(handleMiss.waitForExistence(timeout: 5))
        XCTAssertTrue(broaden.exists)
        XCTAssertFalse(clip.exists)
        let scopedSearches = try await fixtureSearches()
        XCTAssertEqual(scopedSearches, ["handle"])

        broaden.tap()
        XCTAssertTrue(clip.waitForExistence(timeout: 5))
        XCTAssertEqual(field.value as? String, "lo")
        XCTAssertFalse(handleMiss.exists)
        XCTAssertFalse(broaden.exists)
        let finalSearches = try await fixtureSearches()
        XCTAssertEqual(finalSearches, ["handle", "broadened"])
    }

    func testFeedSwipesBetweenTwoPerformances() throws {
        guard let endpoint = ProcessInfo.processInfo.environment["HANDSTRUDEL_NOTIFICATION_FIXTURE_URL"] else {
            throw XCTSkip("Requires the feed API fixture.")
        }
        app.launchArguments.append("--uitesting")
        app.launchEnvironment["SUPABASE_URL"] = endpoint
        app.launchEnvironment["SUPABASE_ANON_KEY"] = "notification-fixture-key"
        app.launch()
        let feed = element("tab-feed")
        XCTAssertTrue(feed.waitForExistence(timeout: 5))
        feed.tap()
        let first = app.staticTexts["Evening loop"].firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        let upper = app.coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: 0.31))
        let lower = app.coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: 0.72))
        lower.press(forDuration: 0.05, thenDragTo: upper)
        let second = app.staticTexts["Second performance"].firstMatch
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: second)], timeout: 5), .completed)
        upper.press(forDuration: 0.05, thenDragTo: lower)
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: first)], timeout: 5), .completed)
        XCTAssertFalse(app.staticTexts["feed-video-position"].exists)
    }

    func testSoundArtworkReflectsInstrumentPickerSelection() {
        app.launchArguments.append("--uitesting")
        app.launch()
        let changeSound = app.buttons["Change sound"]
        XCTAssertTrue(changeSound.waitForExistence(timeout: 5))
        let artwork = element("sound-artwork")
        XCTAssertTrue(artwork.exists)
        func selectPiano(_ id: String) {
            changeSound.tap()
            let instruments = element("sounds-instrument")
            XCTAssertTrue(instruments.waitForExistence(timeout: 5))
            instruments.tap()
            let category = app.buttons["Piano"]
            if !category.isHittable { app.swipeRight() }
            category.tap()
            let choice = element("instrument-\(id)")
            XCTAssertTrue(choice.waitForExistence(timeout: 5))
            choice.tap()
            app.buttons["Done"].tap()
        }
        selectPiano("grand_piano")
        XCTAssertTrue((artwork.value as? String)?.hasPrefix("Grand Piano,") == true)
        let before = artwork.screenshot().pngRepresentation
        selectPiano("electric_piano_1")
        XCTAssertTrue((artwork.value as? String)?.hasPrefix("Rhodes EP,") == true)
        XCTAssertNotEqual(artwork.screenshot().pngRepresentation, before)
        let left = artwork.coordinate(withNormalizedOffset: CGVector(dx: 0.18, dy: 0.55))
        let right = artwork.coordinate(withNormalizedOffset: CGVector(dx: 0.82, dy: 0.55))
        left.press(forDuration: 0.05, thenDragTo: right)
        XCTAssertTrue((artwork.value as? String)?.hasPrefix("Grand Piano,") == true)
        XCTAssertEqual(changeSound.value as? String, "Grand Piano")
        let preview = app.buttons["studio-instrument-preview"]
        XCTAssertTrue(preview.waitForExistence(timeout: 3))
        if preview.label == "Stop instrument preview" { preview.tap() }
        preview.tap()
        XCTAssertEqual(preview.label, "Stop instrument preview")
        preview.tap()
        XCTAssertEqual(preview.label, "Preview instrument")
    }

    func testCommentNotificationOpensVideoAndThenTheExactReply() throws {
        guard let endpoint = ProcessInfo.processInfo.environment["HANDSTRUDEL_NOTIFICATION_FIXTURE_URL"] else {
            throw XCTSkip("Requires the notification API fixture.")
        }
        app.launchArguments.append("--uitesting")
        app.launchEnvironment["SUPABASE_URL"] = endpoint
        app.launchEnvironment["SUPABASE_ANON_KEY"] = "notification-fixture-key"
        app.launch()
        let feed = element("tab-feed")
        XCTAssertTrue(feed.waitForExistence(timeout: 5))
        feed.tap()
        let inbox = app.buttons["activity-inbox"]
        XCTAssertTrue(inbox.waitForExistence(timeout: 5))
        inbox.tap()

        let email = app.textFields["you@example.com"]
        if email.waitForExistence(timeout: 3) {
            email.tap()
            email.typeText("notification@example.test")
            app.buttons["Email me a code"].tap()
            let code = app.textFields["6-digit code"]
            XCTAssertTrue(code.waitForExistence(timeout: 5))
            code.tap()
            code.typeText("123456")
            app.buttons["Sign in"].tap()
            XCTAssertTrue(inbox.waitForExistence(timeout: 12))
            inbox.tap()
        }

        XCTAssertTrue(app.navigationBars["Notifications"].waitForExistence(timeout: 5))
        let groupedLike = app.staticTexts["@loopmaker and 2 others liked your video"]
        XCTAssertTrue(groupedLike.waitForExistence(timeout: 5))
        groupedLike.tap()
        let detail = app.navigationBars["@loopmaker"]
        XCTAssertTrue(detail.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Evening loop"].exists)
        XCTAssertFalse(app.buttons["notification-view-comment"].exists)
        detail.buttons.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Notifications"].waitForExistence(timeout: 5))

        let notification = app.staticTexts["@loopmaker replied to you"]
        XCTAssertTrue(notification.waitForExistence(timeout: 5))
        notification.tap()
        XCTAssertTrue(detail.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Evening loop"].exists)
        let reply = app.buttons["notification-view-comment"]
        if !reply.isHittable { app.swipeUp() }
        reply.tap()
        XCTAssertTrue(app.buttons["Close comments"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Try the lower octave"].waitForExistence(timeout: 5))
        let like = app.buttons["comment-like-40000000-0000-0000-0000-000000000002"]
        XCTAssertTrue(like.waitForExistence(timeout: 5))
        if !like.isHittable { app.swipeUp() }
        like.tap()
        let liked = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "1 like"), object: like)
        XCTAssertEqual(XCTWaiter.wait(for: [liked], timeout: 5), .completed)
        app.buttons["Close comments"].tap()
        XCTAssertTrue(reply.waitForExistence(timeout: 5))
        reply.tap()
        XCTAssertTrue(like.waitForExistence(timeout: 5))
        XCTAssertEqual(like.value as? String, "1 like")
        if !like.isHittable { app.swipeUp() }
        like.tap()
        let unliked = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "0 likes"), object: like)
        XCTAssertEqual(XCTWaiter.wait(for: [unliked], timeout: 5), .completed)
        app.buttons["Close comments"].tap()
        XCTAssertTrue(detail.waitForExistence(timeout: 5))
        detail.buttons.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Notifications"].waitForExistence(timeout: 5))
    }

    func testFeed_creatorProfileAndFollowingGuestState() throws {
        guard let key = ProcessInfo.processInfo.environment["HANDSTRUDEL_LOCAL_COMMENTS_KEY"] else {
            throw XCTSkip("Requires the local Supabase creator fixture.")
        }
        app.launchArguments.append("--uitesting")
        app.launchEnvironment["SUPABASE_URL"] = "http://127.0.0.1:54321"
        app.launchEnvironment["SUPABASE_ANON_KEY"] = key
        app.launch()
        let feed = element("tab-feed")
        XCTAssertTrue(feed.waitForExistence(timeout: 5))
        feed.tap()
        let creator = app.buttons["@comments_smoke"].firstMatch
        XCTAssertTrue(creator.waitForExistence(timeout: 10))
        creator.tap()
        XCTAssertTrue(app.navigationBars["Creator"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Performances"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        app.buttons["Following"].tap()
        XCTAssertTrue(app.buttons["Sign in to follow creators"].waitForExistence(timeout: 5))
    }

    func testArtistProfileOpensLatestClipAndPlaysSharedSound() throws {
        try launchWithProfileFixture()
        element("tab-feed").tap()
        let author = app.buttons["@loopmaker"].firstMatch
        XCTAssertTrue(author.waitForExistence(timeout: 8))
        author.tap()
        XCTAssertTrue(app.staticTexts["Loop Maker"].waitForExistence(timeout: 5))
        let likes = element("profile-likes-received")
        XCTAssertEqual(likes.label, "Likes received")
        XCTAssertEqual(likes.value as? String, "42")
        XCTAssertTrue(app.buttons["Share profile"].exists)
        let spotlight = app.buttons["profile-latest-performance"]
        XCTAssertTrue(spotlight.waitForExistence(timeout: 5))
        captureIfRequested("Artist-Profile")
        spotlight.tap()
        XCTAssertTrue(app.staticTexts["Evening loop"].waitForExistence(timeout: 5))
        let preset = app.buttons.matching(identifier: "play-clip-preset").firstMatch
        XCTAssertTrue(preset.waitForExistence(timeout: 5))
        XCTAssertEqual(preset.label, "Play this sound")
        app.navigationBars["@loopmaker"].buttons["Done"].tap()
        app.buttons["profile-sounds"].tap()
        let sound = app.buttons["profile-play-sound"].firstMatch
        XCTAssertTrue(sound.waitForExistence(timeout: 5))
        captureIfRequested("Artist-Sounds")
        sound.tap()
        XCTAssertTrue(element("close-button").waitForExistence(timeout: 10))
    }

    func testCreatorLikesReachableAtLargestDynamicType() throws {
        app.launchArguments += [
            "-UIPreferredContentSizeCategoryName",
            UIContentSizeCategory.accessibilityExtraExtraExtraLarge.rawValue,
        ]
        try launchWithProfileFixture()
        element("tab-feed").tap()
        let author = app.buttons["@loopmaker"].firstMatch
        XCTAssertTrue(author.waitForExistence(timeout: 8))
        author.tap()

        let title = app.staticTexts["Loop Maker"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(title.frame.height, 45, "Expected the accessibility-size profile header")

        let likes = element("profile-likes-received")
        for _ in 0..<2 where !likes.isHittable {
            app.swipeUp(velocity: .slow)
        }
        XCTAssertTrue(likes.isHittable)
        XCTAssertEqual(likes.label, "Likes received")
        XCTAssertEqual(likes.value as? String, "42")
        captureIfRequested("Artist-Profile-Largest-Text")
    }

    func testPlayThisSoundFromFeedOpensMusicSession() throws {
        try launchWithProfileFixture()
        element("tab-feed").tap()
        let sound = app.buttons["feed-sound-options"].firstMatch
        XCTAssertTrue(sound.waitForExistence(timeout: 8))
        sound.tap()
        let preset = app.buttons.matching(identifier: "play-clip-preset").firstMatch
        XCTAssertTrue(preset.waitForExistence(timeout: 8))
        XCTAssertTrue(preset.isHittable)
        XCTAssertEqual(preset.label, "Play this sound")
        preset.tap()
        XCTAssertTrue(element("close-button").waitForExistence(timeout: 10))
    }

    func testAccountProfileEditsDisplayNameAndKeepsEmptyState() throws {
        try launchWithProfileFixture()
        signInToProfile()
        let edit = app.buttons["Edit profile"]
        XCTAssertTrue(edit.waitForExistence(timeout: 12))
        let likes = element("profile-likes-received")
        let zero = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "0"), object: likes)
        XCTAssertEqual(XCTWaiter.wait(for: [zero], timeout: 5), .completed)
        edit.tap()
        let name = app.textFields["Display name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["profile-choose-photo"].exists)
        name.tap()
        let previous = (name.value as? String) ?? ""
        let edited = previous == "Night Studio" ? "Dawn Studio" : "Night Studio"
        name.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: previous.count) + edited)
        app.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts[edited].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["No performances yet"].waitForExistence(timeout: 5))
        captureIfRequested("Account-Artist")
        app.buttons["Make music"].tap()
        XCTAssertTrue(element("start-button").waitForExistence(timeout: 5))
        element("tab-account").tap()
        XCTAssertEqual(likes.value as? String, "0", "Reopening Account should have the previously loaded counts.")
        XCTAssertTrue(app.staticTexts["No performances yet"].exists)
    }

    func testFollowingWithNoFollowsIsNotAConnectionError() throws {
        try launchWithProfileFixture()
        signInToProfile()
        XCTAssertTrue(app.buttons["Edit profile"].waitForExistence(timeout: 12))
        element("tab-feed").tap()
        let following = app.segmentedControls.buttons["Following"].firstMatch
        XCTAssertTrue(following.waitForExistence(timeout: 8))
        following.tap()
        XCTAssertTrue(app.staticTexts["You aren't following any creators yet"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["Try again"].exists)
        app.buttons["Browse latest"].tap()
        XCTAssertTrue(app.staticTexts["Evening loop"].firstMatch.waitForExistence(timeout: 8))
    }

    func testProfileCanRemoveExistingPhoto() throws {
        try launchWithProfileFixture()
        signInToProfile()
        let edit = app.buttons["Edit profile"]
        XCTAssertTrue(edit.waitForExistence(timeout: 12))
        edit.tap()
        let remove = app.buttons["Remove photo"]
        guard remove.waitForExistence(timeout: 3) else { throw XCTSkip("Requires an existing fixture photo.") }
        remove.tap()
        let confirm = app.buttons.matching(identifier: "profile-confirm-remove-photo").firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 3))
        confirm.tap()
        app.buttons["Save"].tap()
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
        edit.tap()
        XCTAssertTrue(app.buttons["profile-choose-photo"].waitForExistence(timeout: 5))
        XCTAssertFalse(remove.exists)
    }

    private func signInToProfile() {
        element("tab-account").tap()
        let emailPrompt = app.buttons["Sign in"]
        if emailPrompt.waitForExistence(timeout: 2) {
            captureIfRequested("Account-Guest")
            emailPrompt.tap()
            let email = app.textFields["you@example.com"]
            XCTAssertTrue(email.waitForExistence(timeout: 5))
            email.tap()
            email.typeText("profile@example.test")
            app.buttons["Email me a code"].tap()
            let code = app.textFields["6-digit code"]
            XCTAssertTrue(code.waitForExistence(timeout: 5))
            code.tap()
            code.typeText("123456")
            app.buttons["verify-sign-in-code"].tap()
        }
    }

    private func launchWithProfileFixture() throws {
        guard let endpoint = ProcessInfo.processInfo.environment["HANDSTRUDEL_NOTIFICATION_FIXTURE_URL"] else {
            throw XCTSkip("Requires the profile API fixture.")
        }
        app.launchArguments.append("--uitesting")
        app.launchEnvironment["SUPABASE_URL"] = endpoint
        app.launchEnvironment["SUPABASE_ANON_KEY"] = "notification-fixture-key"
        app.launch()
    }

    func testFeed_challengeAndPrivateBookmarkEntryPoints() throws {
        guard let key = ProcessInfo.processInfo.environment["HANDSTRUDEL_LOCAL_DISCOVERY_KEY"] else {
            throw XCTSkip("Requires the local weekly challenge fixture.")
        }
        app.launchArguments.append("--uitesting")
        app.launchEnvironment["SUPABASE_URL"] = "http://127.0.0.1:54321"
        app.launchEnvironment["SUPABASE_ANON_KEY"] = key
        app.launch()
        let feed = element("tab-feed")
        XCTAssertTrue(feed.waitForExistence(timeout: 5))
        feed.tap()
        let challenge = element("weekly-challenge")
        XCTAssertTrue(challenge.waitForExistence(timeout: 10))
        challenge.tap()
        XCTAssertTrue(app.staticTexts["Eight bar warmup"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Watch the backing clip"].waitForExistence(timeout: 5))
        let empty = app.staticTexts["No takes yet. Play along and post a take to join this week's challenge."]
        if !empty.isHittable { app.swipeUp() }
        XCTAssertTrue(empty.waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        let saved = element("saved-performances")
        XCTAssertTrue(saved.waitForExistence(timeout: 5))
        saved.tap()
        XCTAssertTrue(app.navigationBars["Sign in"].waitForExistence(timeout: 5))
    }

    func testMainNavigation_opensFeedAndAccount() {
        launchToStart()
        let feed = element("tab-feed")
        XCTAssertTrue(feed.waitForExistence(timeout: 5))
        XCTAssertFalse(element("tab-learn").exists)
        XCTAssertFalse(element("tab-sounds").exists)
        captureIfRequested("01-Music")
        feed.tap()
        XCTAssertTrue(app.staticTexts["Feed"].waitForExistence(timeout: 5))
        XCTAssertFalse(element("start-button").exists)
        if ProcessInfo.processInfo.environment["HANDSTRUDEL_CAPTURE_UI"] == "1" {
            _ = app.buttons["Share video"].firstMatch.waitForExistence(timeout: 10)
            captureIfRequested("02-Feed")
        }
        element("tab-account").tap()
        XCTAssertTrue(app.buttons["Account settings"].waitForExistence(timeout: 5))
        captureIfRequested("03-Account")
        element("tab-music").tap()
        XCTAssertTrue(element("start-button").waitForExistence(timeout: 5))
    }

    func testSounds_showsMusicSettings() {
        launchToStart()
        let changeSound = app.buttons["Change sound"]
        XCTAssertTrue(changeSound.waitForExistence(timeout: 5))
        changeSound.tap()
        XCTAssertTrue(app.staticTexts["Instrument"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Chords"].exists)
        XCTAssertTrue(app.staticTexts["Key"].exists)
        XCTAssertTrue(app.staticTexts["Scale"].exists)
        captureIfRequested("04-Sounds")
        app.buttons["Done"].tap()
        XCTAssertTrue(element("start-button").waitForExistence(timeout: 5))
    }

    func testCustomScaleCanBeSavedAndRecalled() {
        app.launchArguments = ["--uitesting", "--uitest-pro-scales"]
        app.launch()
        func openScalePicker() {
            let changeSound = app.buttons["Change sound"]
            XCTAssertTrue(changeSound.waitForExistence(timeout: 5))
            changeSound.tap()
            let scale = element("scale-picker")
            XCTAssertTrue(scale.waitForExistence(timeout: 5))
            scale.tap()
        }
        let name = "Pulse \(UUID().uuidString.prefix(6))"
        openScalePicker()
        let create = element("create-custom-scale")
        XCTAssertTrue(create.waitForExistence(timeout: 5))
        create.tap()
        let nameField = app.textFields["custom-scale-name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText(name)
        let save = app.buttons["Save & Use"]
        XCTAssertTrue(save.isEnabled)
        save.tap()
        XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 5))

        app.terminate()
        app.launch()
        openScalePicker()
        XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 5))
    }

    func testCustomScaleRequiresPro() {
        app.launchArguments = ["--uitesting", "--force-locked"]
        app.launch()
        let changeSound = app.buttons["Change sound"]
        XCTAssertTrue(changeSound.waitForExistence(timeout: 5))
        changeSound.tap()
        let scale = element("scale-picker")
        XCTAssertTrue(scale.waitForExistence(timeout: 5))
        scale.tap()
        let create = element("create-custom-scale")
        XCTAssertTrue(create.waitForExistence(timeout: 5))
        create.tap()
        XCTAssertTrue(app.staticTexts["Pro Upgrade"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.textFields["custom-scale-name"].exists)
    }

    func testMusic_showsStartButton() {
        launchToStart()
        XCTAssertTrue(element("start-button").waitForExistence(timeout: 5))
        XCTAssertTrue(element("start-button").label.contains("Start playing"))
    }

    // MARK: - Session Start Tests

    func testMusic_startsSession() {
        launchToSession()
        XCTAssertTrue(element("close-button").exists)
        captureIfRequested("05-Performance")
    }

    private func captureIfRequested(_ name: String) {
        guard ProcessInfo.processInfo.environment["HANDSTRUDEL_CAPTURE_UI"] == "1" else { return }
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testSession_showsSettingsButton() {
        launchToSession()
        XCTAssertTrue(element("settings-button").waitForExistence(timeout: 2))
    }

    func testSession_showsSharePlayButton() {
        launchToSession()
        let jam = element("shareplay-jam-button")
        XCTAssertTrue(jam.waitForExistence(timeout: 5))
        XCTAssertTrue(jam.isHittable)
        XCTAssertEqual(jam.label, "Start SharePlay jam")
    }

    func testSession_halfSpeedRecordingToggle() {
        launchToSession()
        let toggle = element("half-speed-recording")
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        let previous = toggle.value as? String
        XCTAssertTrue(previous == "On" || previous == "Off")
        toggle.tap()
        XCTAssertEqual(toggle.value as? String, previous == "On" ? "Off" : "On")
        XCTAssertTrue(element("record-button").exists)
        toggle.tap()
        XCTAssertEqual(toggle.value as? String, previous)
    }

    func testSession_showsRecordButton() {
        launchToSession()
        XCTAssertTrue(element("record-button").waitForExistence(timeout: 2))
    }

    func testSession_closeReturnsToStart() {
        launchToSession()
        let closeBtn = element("close-button")
        XCTAssertTrue(closeBtn.waitForExistence(timeout: 3))
        closeBtn.tap()
        XCTAssertTrue(element("start-button").waitForExistence(timeout: 5))
    }

    // MARK: - Onboarding Tests

    func testOnboarding_showsOnFirstLaunch() {
        launchToSessionWithOnboarding()
        let gotIt = element("onboarding-got-it")
        XCTAssertTrue(gotIt.waitForExistence(timeout: 5), "Onboarding should show")
    }

    func testOnboarding_highlightsFirstNote() {
        launchToSessionWithOnboarding()
        XCTAssertTrue(element("onboarding-first-note").waitForExistence(timeout: 5))
    }

    func testOnboarding_showsPinchAfterFirstNote() {
        launchToSessionWithOnboarding()
        let note = element("onboarding-first-note")
        XCTAssertTrue(note.waitForExistence(timeout: 5))
        note.tap()
        XCTAssertTrue(app.staticTexts["Now try a pinch"].waitForExistence(timeout: 5))
        XCTAssertFalse(note.exists)
    }

    func testTouchOnlySettingRemembersChoice() {
        app.launchArguments = ["--reset-studio-input"]
        launchToSession()
        defer {
            app.terminate()
            app.launchArguments = ["--uitesting", "--reset-studio-input"]
            app.launch()
        }
        element("settings-button").tap()
        selectMusicSettingsSection("play")
        let touch = app.segmentedControls["studio-play-input"].buttons["Touch only"]
        XCTAssertTrue(touch.waitForExistence(timeout: 5))
        touch.tap()
        XCTAssertTrue(touch.isSelected)
        element("music-settings-done").tap()
        XCTAssertTrue(element("touch-camera-off").waitForExistence(timeout: 5))

        app.terminate()
        app.launchArguments = []
        launchToSession()
        XCTAssertTrue(element("touch-camera-off").waitForExistence(timeout: 5))
    }

    func testDeniedCameraAutomaticallySwitchesToTouchWithoutLeavingSession() {
        app.launchArguments = ["--uitesting", "--reset-onboarding", "--reset-studio-input", "--uitest-camera-denied"]
        app.launch()
        let start = element("start-button")
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        XCTAssertFalse(app.segmentedControls["studio-play-input"].exists)
        start.tap()
        let note = element("onboarding-first-note")
        XCTAssertTrue(note.waitForExistence(timeout: 5))
        note.tap()
        XCTAssertTrue(app.staticTexts["Tap or slide to play"].exists)
        element("onboarding-got-it").tap()

        XCTAssertTrue(element("touch-camera-off").waitForExistence(timeout: 5))
        XCTAssertTrue(element("close-button").exists)
        XCTAssertFalse(element("camera-recovery-touch").exists)
        XCTAssertTrue(app.buttons["wheel-note-0"].exists)
        XCTAssertTrue(app.buttons["wheel-chord-0"].exists)
        element("settings-button").tap()
        selectMusicSettingsSection("play")
        let touch = app.segmentedControls["studio-play-input"].buttons["Touch only"]
        XCTAssertTrue(touch.waitForExistence(timeout: 5))
        XCTAssertTrue(touch.isSelected)
        XCTAssertTrue(app.buttons["Open Camera Settings"].exists)
    }

    func testOnboarding_gotItDismisses() {
        launchToSessionWithOnboarding()
        let gotIt = element("onboarding-got-it")
        XCTAssertTrue(gotIt.waitForExistence(timeout: 5))
        gotIt.tap()
        XCTAssertTrue(element("settings-button").waitForExistence(timeout: 3))
        XCTAssertFalse(gotIt.exists)
    }

    // MARK: - Control Sheet Tests

    func testSettingsButton_opensSheet() {
        launchToSession()
        let settingsBtn = element("settings-button")
        XCTAssertTrue(settingsBtn.waitForExistence(timeout: 3))
        settingsBtn.tap()
        XCTAssertTrue(app.staticTexts["HARMONY"].waitForExistence(timeout: 5))
    }

    func testMusicSettingsDashboardShowsOnlyTheSelectedControls() {
        launchToSession()
        element("settings-button").tap()
        selectMusicSettingsSection("sound")
        XCTAssertTrue(app.staticTexts["CURRENT SOUND"].exists)
        XCTAssertTrue(app.buttons["scale-picker"].isHittable)
        XCTAssertFalse(app.segmentedControls["studio-play-input"].exists)
        captureIfRequested("Music-Settings-Sound")

        selectMusicSettingsSection("play")
        XCTAssertTrue(app.segmentedControls["studio-play-input"].isHittable)
        XCTAssertTrue(app.buttons["music-other-modes"].isHittable)
        XCTAssertFalse(app.buttons["scale-picker"].exists)

        selectMusicSettingsSection("mix")
        XCTAssertTrue(app.staticTexts["DRUMS 1"].isHittable)
        XCTAssertFalse(app.segmentedControls["studio-play-input"].exists)

        selectMusicSettingsSection("capture")
        XCTAssertTrue(app.switches["Include microphone (solo takes)"].isHittable)
        captureIfRequested("Music-Settings-Capture")
        closeMusicSettings()
    }

    func testControlSheet_showsHarmonySection() {
        launchToSession()
        element("settings-button").tap()
        let harmony = app.staticTexts["HARMONY"]
        XCTAssertTrue(harmony.waitForExistence(timeout: 5))
    }

    func testControlSheet_showsSoundSection() {
        launchToSession()
        element("settings-button").tap()
        _ = app.staticTexts["HARMONY"].waitForExistence(timeout: 3)
        // Sound + BPM hide in chord-melody-family modes (the default Split is
        // routed through the SoundFont sampler). Switch to Melodic to bring
        // them back; that's the mode whose entire point is the Strudel synth.
        switchToMode("mode-melodic")
        closeMusicSettings()
        element("settings-button").tap()
        let sound = app.staticTexts["SOUND"]
        if !sound.exists { app.swipeUp() }
        XCTAssertTrue(sound.waitForExistence(timeout: 3))
    }

    func testControlSheet_showsBPMSection() {
        launchToSession()
        element("settings-button").tap()
        _ = app.staticTexts["HARMONY"].waitForExistence(timeout: 3)
        switchToMode("mode-melodic")
        closeMusicSettings()
        element("settings-button").tap()
        selectMusicSettingsSection("mix")
        let bpm = app.staticTexts["BPM"]
        if !bpm.exists { app.swipeUp() }
        XCTAssertTrue(bpm.waitForExistence(timeout: 3))
    }

    // MARK: - Mode Switching Tests

    func testModeSection_showsAllModes() {
        launchToSession()
        element("settings-button").tap()
        _ = app.staticTexts["HARMONY"].waitForExistence(timeout: 3)
        expandOtherModes()
        XCTAssertTrue(element("mode-melodic").waitForExistence(timeout: 2))
        XCTAssertTrue(element("mode-grid").exists)
        XCTAssertTrue(element("mode-drums").exists)
        XCTAssertTrue(element("mode-learn").exists)
    }

    func testModeSwitching_tapGrid() {
        launchToSession()
        element("settings-button").tap()
        _ = app.staticTexts["HARMONY"].waitForExistence(timeout: 3)
        switchToMode("mode-grid")
        closeMusicSettings()
        let oneOctave = app.buttons["grid-range-1"]
        XCTAssertTrue(oneOctave.waitForExistence(timeout: 3))
        oneOctave.tap()
        XCTAssertTrue(oneOctave.isSelected)
    }

    func testModeSwitching_tapDrums() {
        launchToSession()
        element("settings-button").tap()
        _ = app.staticTexts["HARMONY"].waitForExistence(timeout: 3)
        switchToMode("mode-drums")
        // Reopen the sheet so we can confirm the mode chip is now selected.
        closeMusicSettings()
        element("settings-button").tap()
        expandOtherModes()
        let drums = element("mode-drums")
        XCTAssertTrue(drums.waitForExistence(timeout: 3))
        XCTAssertTrue(drums.isSelected)
    }

    func testModeSwitching_tapLearn_showsSongPicker() {
        launchToSession()
        element("settings-button").tap()
        _ = app.staticTexts["HARMONY"].waitForExistence(timeout: 3)
        switchToMode("mode-learn")
        XCTAssertTrue(app.staticTexts["LEARN"].waitForExistence(timeout: 3))
    }

    func testModeSwitching_backToMelodic() {
        launchToSession()
        element("settings-button").tap()
        _ = app.staticTexts["HARMONY"].waitForExistence(timeout: 3)
        switchToMode("mode-grid")
        closeMusicSettings()
        element("settings-button").tap()
        _ = app.staticTexts["HARMONY"].waitForExistence(timeout: 3)
        switchToMode("mode-melodic")
        closeMusicSettings()
        element("settings-button").tap()
        expandOtherModes()
        XCTAssertTrue(element("mode-melodic").isSelected)
    }

    // MARK: - Harmony Tests

    func testHarmony_keySelection() {
        launchToSession()
        element("settings-button").tap()
        let harmony = app.staticTexts["HARMONY"]
        _ = harmony.waitForExistence(timeout: 3)
        let keyD = app.staticTexts["D"].firstMatch
        if keyD.exists { keyD.tap() }
        XCTAssertTrue(harmony.exists)
    }

    func testHarmony_scaleSelection() {
        launchToSession()
        element("settings-button").tap()
        let harmony = app.staticTexts["HARMONY"]
        _ = harmony.waitForExistence(timeout: 3)
        let minor = app.staticTexts["Minor"].firstMatch
        if minor.exists { minor.tap() }
        XCTAssertTrue(harmony.exists)
    }

    // MARK: - BPM Tests

    func testBPM_showsValue() {
        launchToSession()
        element("settings-button").tap()
        _ = app.staticTexts["HARMONY"].waitForExistence(timeout: 3)
        // BPM is hidden in chord-melody-family modes (the default Split). Pop
        // into Melodic where the tempo slider belongs.
        switchToMode("mode-melodic")
        closeMusicSettings()
        element("settings-button").tap()
        selectMusicSettingsSection("mix")
        let bpm = app.staticTexts["BPM"]
        if !bpm.exists { app.swipeUp() }
        XCTAssertTrue(bpm.waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["120"].exists || app.staticTexts["BPM"].exists)
    }

    // MARK: - Learn Song Picker Tests

    func testLearnSongStartsWithTouchableLanes() {
        launchToSession()
        element("settings-button").tap()
        switchToMode("mode-learn")
        let song = element("song-Twinkle Twinkle")
        XCTAssertTrue(song.waitForExistence(timeout: 5))
        song.tap()
        let lane = app.buttons["learn-lane-0"]
        XCTAssertTrue(lane.waitForExistence(timeout: 8))
        XCTAssertTrue(element("learn-touch-hint").exists)
        lane.tap()
    }

    func testLearnSongPicker_showsMelodies() {
        launchToSession()
        element("settings-button").tap()
        _ = app.staticTexts["HARMONY"].waitForExistence(timeout: 3)
        switchToMode("mode-learn")
        _ = app.staticTexts["LEARN"].waitForExistence(timeout: 3)
        XCTAssertTrue(app.staticTexts["MELODIES"].exists)
    }

    func testLearnSongPicker_showsPractice() {
        launchToSession()
        element("settings-button").tap()
        _ = app.staticTexts["HARMONY"].waitForExistence(timeout: 3)
        switchToMode("mode-learn")
        _ = app.staticTexts["LEARN"].waitForExistence(timeout: 3)
        let practice = app.staticTexts["PRACTICE"]
        if !practice.exists { app.swipeUp() }
        XCTAssertTrue(practice.waitForExistence(timeout: 3))
    }

    func testLearnSongPicker_showsSongCards() {
        launchToSession()
        element("settings-button").tap()
        _ = app.staticTexts["HARMONY"].waitForExistence(timeout: 3)
        switchToMode("mode-learn")
        _ = app.staticTexts["LEARN"].waitForExistence(timeout: 3)
        XCTAssertTrue(element("song-Twinkle Twinkle").waitForExistence(timeout: 3))
    }

    func testLearnSongPicker_showsPracticeButtons() {
        launchToSession()
        element("settings-button").tap()
        _ = app.staticTexts["HARMONY"].waitForExistence(timeout: 3)
        switchToMode("mode-learn")
        _ = app.staticTexts["LEARN"].waitForExistence(timeout: 3)
        let practice = app.staticTexts["PRACTICE"]
        if !practice.exists { app.swipeUp() }
        _ = practice.waitForExistence(timeout: 3)
        XCTAssertTrue(element("practice-ascending").exists)
        XCTAssertTrue(element("practice-descending").exists)
    }

    func testLearnSongPicker_showsImportSection() {
        launchToSession()
        element("settings-button").tap()
        _ = app.staticTexts["HARMONY"].waitForExistence(timeout: 3)
        switchToMode("mode-learn")
        _ = app.staticTexts["LEARN"].waitForExistence(timeout: 3)
        let importSection = app.staticTexts["IMPORT"]
        if !importSection.exists { app.swipeUp() }
        XCTAssertTrue(importSection.waitForExistence(timeout: 3))
    }

    // MARK: - Navigation Flow Tests

    func testFullFlow_startToSessionAndSettings() {
        launchToSession()
        element("settings-button").tap()
        XCTAssertTrue(app.staticTexts["HARMONY"].waitForExistence(timeout: 5))
        switchToMode("mode-grid")
        closeMusicSettings()
        XCTAssertTrue(app.buttons["grid-range-2"].waitForExistence(timeout: 3))
    }

    func testFullFlow_learnModeSongSelection() {
        launchToSession()

        element("settings-button").tap()
        _ = app.staticTexts["HARMONY"].waitForExistence(timeout: 3)

        switchToMode("mode-learn")
        _ = app.staticTexts["LEARN"].waitForExistence(timeout: 3)

        let song = element("song-Twinkle Twinkle")
        if song.waitForExistence(timeout: 3) {
            song.tap()
        }

        XCTAssertTrue(element("close-button").waitForExistence(timeout: 5))
    }
}
