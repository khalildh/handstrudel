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

    @MainActor
    func testPostingReturnsToTheWheelWhileScreeningContinues() async throws {
        guard let address = ProcessInfo.processInfo.environment["HANDSTRUDEL_DRAFT_POST_FIXTURE_URL"],
              let endpoint = URL(string: address), endpoint.host == "127.0.0.1",
              let file = ProcessInfo.processInfo.environment["HANDSTRUDEL_DRAFT_TEST_CLIP"] else {
            throw XCTSkip("Requires a loopback draft posting fixture and a simulator-readable MP4.")
        }
        app.launchArguments = ["--uitesting", "--uitest-draft-after-start", "-hasSeenOnboarding", "YES"]
        app.launchEnvironment["HANDSTRUDEL_TEST_CLIP"] = file
        app.launchEnvironment["SUPABASE_URL"] = address
        app.launchEnvironment["SUPABASE_ANON_KEY"] = "draft-post-fixture-key"
        app.launch()
        signInToProfile()
        XCTAssertTrue(app.buttons["Edit profile"].waitForExistence(timeout: 10))
        element("tab-music").tap()
        element("start-button").tap()

        let review = app.navigationBars["Review take"]
        XCTAssertTrue(review.waitForExistence(timeout: 8))
        let compose = app.buttons["Post to HandStrudel"]
        if !compose.isHittable { app.swipeUp() }
        compose.tap()
        let composer = app.navigationBars["New post"]
        XCTAssertTrue(composer.waitForExistence(timeout: 8))
        let post = app.buttons["Post publicly"]
        if !post.isHittable { app.swipeUp() }
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true AND hittable == true"), object: post)
        await fulfillment(of: [ready], timeout: 8)
        post.tap()

        let wheel = element("close-button")
        let resumed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: wheel)
        await fulfillment(of: [resumed], timeout: 25)
        XCTAssertFalse(composer.exists)
        XCTAssertFalse(review.exists)
        XCTAssertFalse(app.staticTexts["Video posted."].exists)

        let resultURL = try XCTUnwrap(URL(string: "/__fixture/draft-upload-result?status=published", relativeTo: endpoint))
        var request = URLRequest(url: resultURL)
        request.httpMethod = "POST"
        let (_, response) = try await URLSession.shared.data(for: request)
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 204)
        XCTAssertTrue(app.staticTexts["Video posted."].waitForExistence(timeout: 8))
        XCTAssertTrue(wheel.isHittable)
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
        if let endpoint = ProcessInfo.processInfo.environment["HANDSTRUDEL_NOTIFICATION_FIXTURE_URL"] {
            app.launchEnvironment["SUPABASE_URL"] = endpoint
            app.launchEnvironment["SUPABASE_ANON_KEY"] = "notification-fixture-key"
            app.launchEnvironment["MEDIA_BASE_URL"] = endpoint
        }
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
            throw XCTSkip("Set HANDSTRUDEL_FEED_RETRY_FIXTURE_URL to a loopback fixture with FIXTURE_CONTROL_MEDIA=1 and FIXTURE_SINGLE_CLIP=1.")
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
        let clip = app.collectionViews["feed-video-viewport"].cells.containing(.staticText, identifier: "Evening loop").firstMatch
        let caption = clip.staticTexts["Evening loop"]
        let share = app.buttons["Share video"].firstMatch
        XCTAssertTrue(caption.exists)
        XCTAssertTrue(share.exists)
        let captionY = caption.frame.midY
        let shareY = share.frame.midY
        let slider = app.sliders["feed-video-progress"].firstMatch
        XCTAssertTrue(slider.exists)
        XCTAssertEqual(slider.value as? String, "Playback unavailable")
        let scrubberY = slider.frame.midY

        try await setAvailability(true)
        retry.tap()
        XCTAssertTrue(slider.waitForExistence(timeout: 10))
        XCTAssertFalse(retry.exists)
        XCTAssertTrue(caption.exists)
        XCTAssertEqual(caption.frame.midY, captionY, accuracy: 1, "The scrubber must not move the caption.")
        XCTAssertEqual(share.frame.midY, shareY, accuracy: 1, "The scrubber must not move the action rail.")
        XCTAssertEqual(slider.frame.midY, scrubberY, accuracy: 1, "Retry must not insert or move the shared scrubber.")
        let playing = NSPredicate(format: "value MATCHES %@", "0:0[1-3] of 0:04")
        let actualPlayback = XCTNSPredicateExpectation(predicate: playing, object: slider)
        await fulfillment(of: [actualPlayback], timeout: 9)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: 0.40)).tap()
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
        let first = app.staticTexts["Evening loop"].firstMatch
        let continued = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: first)
        XCTAssertEqual(XCTWaiter.wait(for: [continued], timeout: 10), .completed,
                       "The last clip must advance to a different clip instead of replaying itself.")
        let restarted = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value BEGINSWITH %@ OR value BEGINSWITH %@", "0:01", "0:02"),
                                                  object: nextPlayhead)
        XCTAssertEqual(XCTWaiter.wait(for: [restarted], timeout: 8), .completed, "The selected clip must play after crossing the end of the feed.")
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

    func testFeedVideoFillsScreenBehindNavigationAndUsesOptionsMenu() throws {
        guard let endpoint = ProcessInfo.processInfo.environment["HANDSTRUDEL_PLAY_ALONG_FIXTURE_URL"] else {
            throw XCTSkip("Requires the feed fixture with a real MP4.")
        }
        app.launchArguments = ["--uitesting", "-studioTheme", "paper"]
        app.launchEnvironment["SUPABASE_URL"] = endpoint
        app.launchEnvironment["SUPABASE_ANON_KEY"] = "notification-fixture-key"
        app.launchEnvironment["MEDIA_BASE_URL"] = endpoint
        app.launch()
        let feed = element("tab-feed")
        feed.tap()
        let menu = app.buttons["feed-options"]
        XCTAssertTrue(menu.waitForExistence(timeout: 5))
        let viewport = app.collectionViews["feed-video-viewport"]
        XCTAssertTrue(viewport.waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["feed-fullscreen"].isHittable)
        XCTAssertTrue(app.sliders["feed-video-progress"].firstMatch.isHittable)
        XCTAssertEqual(viewport.frame.width, app.frame.width, accuracy: 1)
        XCTAssertEqual(viewport.frame.minY, app.frame.minY, accuracy: 1)
        XCTAssertEqual(viewport.frame.maxY, app.frame.maxY, accuracy: 1)
        XCTAssertLessThan(viewport.frame.minY, menu.frame.midY)
        XCTAssertGreaterThan(viewport.frame.maxY, feed.frame.midY)
        XCTAssertFalse(app.segmentedControls["feed-filter"].exists)
        XCTAssertEqual(menu.value as? String, "Discover")
        captureIfRequested("Feed-Full-Bleed")

        selectFeedMode("Latest")
        XCTAssertEqual(menu.value as? String, "Latest")
        selectFeedMode("Following")
        XCTAssertTrue(app.buttons["Sign in to follow creators"].waitForExistence(timeout: 5))
        selectFeedMode("Discover")
        XCTAssertTrue(viewport.waitForExistence(timeout: 8))
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
        checkPlaybackControlsToggle(at: app.coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: 0.40)),
                                    slider: slider, exit: fullscreen, pausedAt: pausedPosition)
        fullscreen.tap()

        XCTAssertEqual(fullscreen.label, "Full screen")
        XCTAssertTrue(element("tab-feed").exists)
        XCTAssertTrue(sound.isHittable)
        XCTAssertEqual(slider.value as? String, pausedPosition)
    }

    private func checkPlaybackControlsToggle(at video: XCUICoordinate, slider: XCUIElement,
                                             exit: XCUIElement, pausedAt: String) {
        let mute = app.buttons["video-playback-mute"].firstMatch
        let play = app.buttons["fullscreen-playback-toggle"].firstMatch
        XCTAssertTrue(mute.isHittable)
        XCTAssertEqual(play.label, "Play video")
        video.tap()
        XCTAssertFalse(slider.exists)
        XCTAssertFalse(mute.exists)
        XCTAssertFalse(play.exists)
        XCTAssertTrue(exit.isHittable)
        video.tap()
        XCTAssertTrue(slider.waitForExistence(timeout: 5))
        XCTAssertTrue(mute.isHittable)
        XCTAssertEqual(play.label, "Play video")
        XCTAssertEqual(slider.value as? String, pausedAt)
    }

    func testFeedRepostUpdatesTheCountAndCanBeRemoved() throws {
        guard let endpoint = ProcessInfo.processInfo.environment["HANDSTRUDEL_REPOST_FIXTURE_URL"] else {
            throw XCTSkip("Requires the repost-enabled feed fixture.")
        }
        app.launchArguments = ["--uitesting"]
        app.launchEnvironment["SUPABASE_URL"] = endpoint
        app.launchEnvironment["SUPABASE_ANON_KEY"] = "repost-fixture-key"
        app.launchEnvironment["MEDIA_BASE_URL"] = endpoint
        app.launch()
        signInToProfile()
        XCTAssertTrue(app.buttons["Edit profile"].waitForExistence(timeout: 10))
        element("tab-feed").tap()
        let clip = app.collectionViews["feed-video-viewport"].cells.containing(.staticText, identifier: "Evening loop").firstMatch
        let repost = app.buttons["feed-repost"].firstMatch
        func expect(_ label: String, value: String) {
            let state = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@ AND value == %@", label, value), object: repost)
            XCTAssertEqual(XCTWaiter.wait(for: [state], timeout: 6), .completed)
        }
        expect("Repost", value: "2 reposts")
        repost.tap()
        expect("Remove repost", value: "3 reposts")
        XCTAssertTrue(clip.staticTexts["You reposted"].exists)
        repost.tap()
        expect("Repost", value: "2 reposts")
        XCTAssertFalse(clip.staticTexts["You reposted"].exists)
        selectFeedMode("Following")
        XCTAssertTrue(app.staticTexts["@secondartist reposted"].firstMatch.waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["@loopmaker"].firstMatch.exists)
    }

    func testFeedEngagementRailShowsCountsAndRecordsCompletedShare() throws {
        guard let endpoint = ProcessInfo.processInfo.environment["HANDSTRUDEL_ENGAGEMENT_FIXTURE_URL"] else {
            throw XCTSkip("Requires the feed fixture with view counts and engagement.")
        }
        app.launchArguments = ["--uitesting"]
        app.launchEnvironment["SUPABASE_URL"] = endpoint
        app.launchEnvironment["SUPABASE_ANON_KEY"] = "notification-fixture-key"
        app.launchEnvironment["MEDIA_BASE_URL"] = endpoint
        app.launch()
        let feed = element("tab-feed")
        XCTAssertTrue(feed.waitForExistence(timeout: 5))
        feed.tap()
        let views = element("feed-views-count")
        let remixes = app.buttons["feed-remix-count"].firstMatch
        let share = app.buttons["Share video"].firstMatch
        let save = app.buttons["save-performance"].firstMatch
        XCTAssertTrue(remixes.waitForExistence(timeout: 5))
        XCTAssertEqual(remixes.label, "Remixes")
        let countLoaded = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "3"), object: remixes)
        XCTAssertEqual(XCTWaiter.wait(for: [countLoaded], timeout: 5), .completed)
        XCTAssertTrue(views.isHittable)
        XCTAssertEqual(save.value as? String, "5 saves")
        XCTAssertEqual(share.value as? String, "4 shares")
        XCTAssertEqual(app.buttons["Like"].firstMatch.value as? String, "42 likes")
        XCTAssertTrue(app.buttons["video-comments-button"].firstMatch.isHittable)
        captureIfRequested("Feed-Engagement-Rail")

        share.tap()
        let close = app.buttons["header.closeButton"].firstMatch
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        close.tap()
        let cancelled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true AND value == %@", "4 shares"), object: share)
        XCTAssertEqual(XCTWaiter.wait(for: [cancelled], timeout: 5), .completed)

        share.tap()
        let copy = app.cells.matching(NSPredicate(format: "label == %@", "Copy")).firstMatch
        XCTAssertTrue(copy.waitForExistence(timeout: 5))
        copy.tap()
        let recorded = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "5 shares"), object: share)
        XCTAssertEqual(XCTWaiter.wait(for: [recorded], timeout: 7), .completed)
    }

    func testFeedRemixesOpensPublishedPlayAlongClips() throws {
        guard let endpoint = ProcessInfo.processInfo.environment["HANDSTRUDEL_REMIX_FIXTURE_URL"] else {
            throw XCTSkip("Requires FIXTURE_REMIXES=1 and FIXTURE_PLAY_ALONG=1.")
        }
        app.launchArguments = ["--uitesting"]
        app.launchEnvironment["SUPABASE_URL"] = endpoint
        app.launchEnvironment["SUPABASE_ANON_KEY"] = "remix-fixture-key"
        app.launchEnvironment["MEDIA_BASE_URL"] = endpoint
        app.launch()
        element("tab-feed").tap()
        let clip = app.collectionViews["feed-video-viewport"].cells.containing(.staticText, identifier: "Evening loop").firstMatch
        let remixes = app.buttons["feed-remix-count"].firstMatch
        XCTAssertTrue(remixes.waitForExistence(timeout: 5))
        remixes.tap()
        XCTAssertTrue(app.navigationBars["Remixes"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Second performance"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Play along"].isHittable)
    }

    func testRepostedClipAppearsOnOwnProfileAndCanBeRemoved() throws {
        guard let endpoint = ProcessInfo.processInfo.environment["HANDSTRUDEL_REPOST_FIXTURE_URL"] else {
            throw XCTSkip("Requires the repost-enabled feed fixture.")
        }
        app.launchArguments = ["--uitesting"]
        app.launchEnvironment["SUPABASE_URL"] = endpoint
        app.launchEnvironment["SUPABASE_ANON_KEY"] = "repost-fixture-key"
        app.launchEnvironment["MEDIA_BASE_URL"] = endpoint
        app.launch()
        signInToProfile()
        XCTAssertTrue(app.buttons["Edit profile"].waitForExistence(timeout: 10))
        element("tab-feed").tap()
        let clip = app.collectionViews["feed-video-viewport"].cells.containing(.staticText, identifier: "Evening loop").firstMatch
        let repost = app.buttons["feed-repost"].firstMatch
        XCTAssertTrue(repost.waitForExistence(timeout: 8))
        repost.tap()
        let reposted = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", "Remove repost"), object: repost)
        XCTAssertEqual(XCTWaiter.wait(for: [reposted], timeout: 6), .completed)
        element("tab-account").tap()
        let repostTab = app.buttons["profile-reposts"]
        XCTAssertTrue(repostTab.waitForExistence(timeout: 5))
        repostTab.tap()
        let tile = app.buttons["Watch Evening loop by @loopmaker"]
        XCTAssertTrue(tile.waitForExistence(timeout: 8))
        XCTAssertTrue((tile.value as? String)?.hasSuffix(" views") == true)
        XCTAssertEqual(element("profile-views-received").value as? String, "0")
        captureIfRequested("Account-Reposts")

        let performances = app.buttons["profile-performances"]
        performances.tap()
        XCTAssertTrue(performances.isSelected)
        XCTAssertFalse(element("performance-video").exists, "Selecting Performances must not open a video.")
        repostTab.tap()
        XCTAssertTrue(tile.waitForExistence(timeout: 5))

        tile.press(forDuration: 1)
        let remove = app.buttons.matching(NSPredicate(format: "label == %@ AND identifier != %@", "Remove repost", "feed-repost")).firstMatch
        XCTAssertTrue(remove.waitForExistence(timeout: 5))
        remove.tap()
        XCTAssertTrue(app.staticTexts["No reposts yet"].waitForExistence(timeout: 8))
        XCTAssertFalse(tile.exists)
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
        let tile = app.buttons["Watch Evening loop"]
        XCTAssertTrue(tile.waitForExistence(timeout: 5))
        XCTAssertTrue((tile.value as? String)?.hasSuffix(" views") == true)
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
        checkPlaybackControlsToggle(at: element("performance-video").coordinate(withNormalizedOffset: CGVector(dx: 0.48, dy: 0.44)),
                                    slider: slider, exit: fullscreen, pausedAt: position)
        fullscreen.tap()
        XCTAssertEqual(fullscreen.label, "Full screen")
        XCTAssertEqual(slider.value as? String, position)
        XCTAssertTrue(count.exists)
    }

    func testAccountVideoFillsScreenAndAutoplaysNextClip() throws {
        guard let endpoint = ProcessInfo.processInfo.environment["HANDSTRUDEL_ACCOUNT_PLAYBACK_FIXTURE_URL"] else {
            throw XCTSkip("Requires a real MP4 and FIXTURE_ACCOUNT_CLIPS=1.")
        }
        app.launchArguments = ["--uitesting"]
        app.launchEnvironment["SUPABASE_URL"] = endpoint
        app.launchEnvironment["SUPABASE_ANON_KEY"] = "account-playback-fixture-key"
        app.launchEnvironment["MEDIA_BASE_URL"] = endpoint
        app.launch()
        signInToProfile()
        let latest = app.buttons["profile-latest-performance"]
        XCTAssertTrue(latest.waitForExistence(timeout: 10))
        if !latest.isHittable { app.swipeUp() }
        latest.tap()
        let video = element("performance-video")
        XCTAssertTrue(video.waitForExistence(timeout: 5))
        XCTAssertEqual(video.label, "Evening loop")

        let fullscreen = app.buttons["profile-video-fullscreen"]
        fullscreen.tap()
        XCTAssertEqual(fullscreen.label, "Exit full screen")
        XCTAssertEqual(video.frame.minY, app.frame.minY, accuracy: 1)
        XCTAssertEqual(video.frame.maxY, app.frame.maxY, accuracy: 1)
        XCTAssertEqual(video.frame.width, app.frame.width, accuracy: 1)

        let advanced = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", "Second performance"), object: video)
        XCTAssertEqual(XCTWaiter.wait(for: [advanced], timeout: 15), .completed)
        XCTAssertEqual(fullscreen.label, "Exit full screen")
        let slider = app.sliders["feed-video-progress"]
        let playing = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true AND NOT (value BEGINSWITH %@)", "0:00"), object: slider)
        XCTAssertEqual(XCTWaiter.wait(for: [playing], timeout: 5), .completed)

        fullscreen.tap()
        let done = app.navigationBars["@viewer"].buttons["Done"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        done.tap()
        let sounds = app.buttons["profile-sounds"]
        XCTAssertTrue(sounds.waitForExistence(timeout: 5))
        if !sounds.isHittable { app.swipeUp() }
        sounds.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.15)).tap()
        XCTAssertTrue(sounds.isSelected, "The full Sounds tab frame should respond after closing the player.")
        XCTAssertTrue(app.buttons["profile-play-sound"].firstMatch.waitForExistence(timeout: 5))

        let reposts = app.buttons["profile-reposts"]
        reposts.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.15)).tap()
        XCTAssertTrue(reposts.isSelected, "The full Reposts tab frame should respond after closing the player.")
        XCTAssertTrue(app.staticTexts["No reposts yet"].waitForExistence(timeout: 5))
    }

    func testAccountVideoSwipesBetweenPerformances() throws {
        guard let endpoint = ProcessInfo.processInfo.environment["HANDSTRUDEL_ACCOUNT_SWIPE_FIXTURE_URL"] else {
            throw XCTSkip("Requires FIXTURE_ACCOUNT_CLIPS=1 with a clip long enough to swipe before autoplay.")
        }
        app.launchArguments = ["--uitesting"]
        app.launchEnvironment["SUPABASE_URL"] = endpoint
        app.launchEnvironment["SUPABASE_ANON_KEY"] = "account-swipe-fixture-key"
        app.launchEnvironment["MEDIA_BASE_URL"] = endpoint
        app.launch()
        signInToProfile()
        let latest = app.buttons["profile-latest-performance"]
        XCTAssertTrue(latest.waitForExistence(timeout: 10))
        if !latest.isHittable { app.swipeUp() }
        latest.tap()
        let video = element("performance-video")
        XCTAssertTrue(video.waitForExistence(timeout: 5))
        XCTAssertEqual(video.label, "Evening loop")

        func swipeVideo(from start: CGFloat, to end: CGFloat) {
            video.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: start))
                .press(forDuration: 0.05, thenDragTo: video.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: end)))
        }
        func expectClip(_ title: String) {
            let changed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", title), object: video)
            XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 4), .completed)
        }

        swipeVideo(from: 0.25, to: 0.65)
        expectClip("Second performance")

        let fullscreen = app.buttons["profile-video-fullscreen"]
        fullscreen.tap()
        XCTAssertEqual(fullscreen.label, "Exit full screen")
        swipeVideo(from: 0.65, to: 0.25)
        expectClip("Evening loop")
        XCTAssertEqual(fullscreen.label, "Exit full screen")
        let slider = app.sliders["feed-video-progress"]
        let playing = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true AND NOT (value BEGINSWITH %@)", "0:00"), object: slider)
        XCTAssertEqual(XCTWaiter.wait(for: [playing], timeout: 5), .completed)
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
        app.launchEnvironment["MEDIA_BASE_URL"] = endpoint
        app.launch()
        let feed = element("tab-feed")
        XCTAssertTrue(feed.waitForExistence(timeout: 5))
        feed.tap()
        let first = app.staticTexts["Evening loop"].firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        let upper = app.coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: 0.35))
        let lower = app.coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: 0.65))
        lower.press(forDuration: 0.05, thenDragTo: upper)
        let second = app.staticTexts["Second performance"].firstMatch
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: second)], timeout: 5), .completed)
        upper.press(forDuration: 0.05, thenDragTo: lower)
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: first)], timeout: 5), .completed)
        XCTAssertFalse(app.staticTexts["feed-video-position"].exists)
    }

    func testFeedSwipesFromTheScrubberBeforeMediaLoads() throws {
        guard let endpoint = ProcessInfo.processInfo.environment["HANDSTRUDEL_DELAYED_FEED_FIXTURE_URL"] else {
            throw XCTSkip("Requires the real MP4 fixture with FIXTURE_MEDIA_DELAY_MS=6000, FIXTURE_NO_DURATION=1 and delayed engagement.")
        }
        app.launchArguments = ["--uitesting"]
        app.launchEnvironment["SUPABASE_URL"] = endpoint
        app.launchEnvironment["SUPABASE_ANON_KEY"] = "delayed-feed-fixture"
        app.launchEnvironment["MEDIA_BASE_URL"] = endpoint + "/cold-" + UUID().uuidString
        app.launch()
        element("tab-feed").tap()
        let first = app.staticTexts["Evening loop"].firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        let slider = app.sliders["feed-video-progress"].firstMatch
        XCTAssertTrue(slider.exists, "The scrubber's view must exist before duration metadata arrives.")
        XCTAssertEqual(slider.value as? String, "0:00 of --:--", "This test must swipe before the duration has loaded.")
        let upper = app.coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: 0.35))
        let thumb = slider.coordinate(withNormalizedOffset: CGVector(dx: 0.03, dy: 0.5))
        thumb.press(forDuration: 0.05, thenDragTo: upper)
        let second = app.staticTexts["Second performance"].firstMatch
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: second)], timeout: 5), .completed)
        let lower = app.coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: 0.75))
        upper.press(forDuration: 0.05, thenDragTo: lower)
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: first)], timeout: 5), .completed)
    }

    @MainActor
    func testFeedWarmsItsFirstVideoOnMusicHomeBeforeOpening() async throws {
        guard let address = ProcessInfo.processInfo.environment["HANDSTRUDEL_STARTUP_FEED_FIXTURE_URL"],
              let endpoint = URL(string: address), endpoint.host == "127.0.0.1" else {
            throw XCTSkip("Requires a loopback fixture with a solid blue 20-second clip and FIXTURE_VIEW_COUNTS=1.")
        }
        app.terminate()
        let countURL = URL(string: "/rest/v1/feed_videos?id=eq.30000000-0000-0000-0000-000000000001", relativeTo: endpoint)!
        let (before, _) = try await URLSession.shared.data(from: countURL)
        let initial = try XCTUnwrap((JSONSerialization.jsonObject(with: before) as? [[String: Any]])?.first?["view_count"] as? Int)
        let prefix = "/cold-" + UUID().uuidString
        app.launchArguments = ["--uitesting"]
        app.launchEnvironment["SUPABASE_URL"] = address
        app.launchEnvironment["SUPABASE_ANON_KEY"] = "startup-feed-fixture"
        app.launchEnvironment["MEDIA_BASE_URL"] = address + prefix
        app.launch()
        let start = element("start-button")
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        let requestsURL = URL(string: "/__fixture/media-requests", relativeTo: endpoint)!
        var paths: [String] = []
        for _ in 0..<30 {
            let (data, _) = try await URLSession.shared.data(from: requestsURL)
            paths = try JSONDecoder().decode([String].self, from: data)
                .filter { $0.hasPrefix(prefix) }.map { String($0.dropFirst(prefix.count)) }
            if !paths.isEmpty { break }
            try await Task.sleep(for: .milliseconds(100))
        }
        XCTAssertEqual(Set(paths), ["/test/clip.mp4"], "Warm only the selected clip before the user has opened Feed.")
        try await Task.sleep(for: .seconds(3))
        XCTAssertTrue(start.isHittable, "Preloading must leave the Music home screen selected.")
        let (after, _) = try await URLSession.shared.data(from: countURL)
        let warmed = try XCTUnwrap((JSONSerialization.jsonObject(with: after) as? [[String: Any]])?.first?["view_count"] as? Int)
        XCTAssertEqual(warmed, initial, "Background preparation must not count as watching a video.")
        element("tab-feed").tap()
        XCTAssertTrue(app.staticTexts["Evening loop"].firstMatch.waitForExistence(timeout: 5))
        let screenshot = try XCTUnwrap(app.screenshot().image.cgImage)
        let sample = try XCTUnwrap(screenshot.cropping(to: CGRect(x: Double(screenshot.width) * 0.5, y: Double(screenshot.height) * 0.42,
                                                                 width: 12, height: 12)))
        var pixel = [UInt8](repeating: 0, count: 4)
        try pixel.withUnsafeMutableBytes { bytes in
            let context = try XCTUnwrap(CGContext(data: bytes.baseAddress, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                                 space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(sample, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        }
        XCTAssertGreaterThan(Int(pixel[2]), Int(pixel[0]) + 60, "The warmed video should be visible immediately, not an empty black player.")
        captureIfRequested("Feed-Startup-Warmed")
        let playing = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value MATCHES %@", "0:(0[1-9]|1[0-9]) of 0:20"),
                                                object: app.sliders["feed-video-progress"].firstMatch)
        await fulfillment(of: [playing], timeout: 8)
    }

    @MainActor
    func testFeedPlaybackUsesVideoFramesInsteadOfDownloadingUploadedThumbnails() async throws {
        guard let address = ProcessInfo.processInfo.environment["HANDSTRUDEL_OPENING_FRAME_FIXTURE_URL"],
              let endpoint = URL(string: address), endpoint.host == "127.0.0.1" else {
            throw XCTSkip("Requires a loopback fixture with clips at least 20 seconds long and thumbnail request tracking.")
        }
        app.launchArguments = ["--uitesting"]
        app.launchEnvironment["SUPABASE_URL"] = address
        app.launchEnvironment["SUPABASE_ANON_KEY"] = "opening-frame-fixture"
        let prefix = "/cold-" + UUID().uuidString
        app.launchEnvironment["MEDIA_BASE_URL"] = address + prefix
        app.launch()
        element("tab-feed").tap()
        selectFeedMode("Latest")
        let first = app.staticTexts["Evening loop"].firstMatch
        await fulfillment(of: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: first)], timeout: 6)
        let slider = app.sliders["feed-video-progress"].firstMatch
        let moving = NSPredicate(format: "value MATCHES %@", "0:(0[1-9]|1[0-9]) of 0:20")
        await fulfillment(of: [XCTNSPredicateExpectation(predicate: moving, object: slider)], timeout: 12)
        let viewport = app.collectionViews["feed-video-viewport"]
        viewport.coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: 0.7))
            .press(forDuration: 0.05, thenDragTo: viewport.coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: 0.3)))
        let next = app.staticTexts["Second performance"].firstMatch
        await fulfillment(of: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: next)], timeout: 5)
        await fulfillment(of: [XCTNSPredicateExpectation(predicate: moving, object: slider)], timeout: 12)
        let requestURL = URL(string: "/__fixture/thumbnail-requests", relativeTo: endpoint)!
        let (data, _) = try await URLSession.shared.data(from: requestURL)
        let requests = try JSONDecoder().decode([String].self, from: data).filter { $0.hasPrefix(prefix + "/thumbs/") }
        XCTAssertTrue(requests.isEmpty, "Playback should render actual video frames, not fetch uploaded posters: \(requests)")
    }

    @MainActor
    func testFeedPreloadsTheNextClipWithoutSwiping() async throws {
        guard let address = ProcessInfo.processInfo.environment["HANDSTRUDEL_DELAYED_FEED_FIXTURE_URL"],
              let endpoint = URL(string: address), endpoint.host == "127.0.0.1" else {
            throw XCTSkip("Requires the delayed loopback MP4 fixture.")
        }
        app.launchArguments = ["--uitesting"]
        app.launchEnvironment["SUPABASE_URL"] = address
        app.launchEnvironment["SUPABASE_ANON_KEY"] = "prefetch-feed-fixture"
        let prefix = "/cold-" + UUID().uuidString
        app.launchEnvironment["MEDIA_BASE_URL"] = address + prefix
        app.launch()
        element("tab-feed").tap()
        XCTAssertTrue(app.staticTexts["Evening loop"].firstMatch.waitForExistence(timeout: 5))
        let url = URL(string: "/__fixture/media-requests", relativeTo: endpoint)!
        var paths: [String] = []
        for _ in 0..<20 {
            let (data, _) = try await URLSession.shared.data(from: url)
            paths = try JSONDecoder().decode([String].self, from: data)
                .filter { $0.hasPrefix(prefix) }.map { String($0.dropFirst(prefix.count)) }
            if Set(paths).count == 2 { break }
            try await Task.sleep(for: .milliseconds(100))
        }
        XCTAssertEqual(Set(paths), ["/test/clip.mp4", "/test/next-clip.mp4"])
        XCTAssertTrue(app.staticTexts["Evening loop"].firstMatch.isHittable, "Preloading must not navigate to the next video.")
    }

    func testVerticalSwipeStartingOnTheLoadedScrubberChangesVideo() throws {
        guard let endpoint = ProcessInfo.processInfo.environment["HANDSTRUDEL_FEED_MEDIA_FIXTURE_URL"] else {
            throw XCTSkip("Requires the feed fixture with a real MP4.")
        }
        app.launchArguments = ["--uitesting"]
        app.launchEnvironment["SUPABASE_URL"] = endpoint
        app.launchEnvironment["SUPABASE_ANON_KEY"] = "scrubber-swipe-fixture"
        app.launchEnvironment["MEDIA_BASE_URL"] = endpoint
        app.launch()
        element("tab-feed").tap()
        let slider = app.sliders["feed-video-progress"].firstMatch
        XCTAssertTrue(slider.waitForExistence(timeout: 8))
        let thumb = slider.coordinate(withNormalizedOffset: CGVector(dx: 0.03, dy: 0.5))
        let upper = app.coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: 0.35))
        thumb.press(forDuration: 0.05, thenDragTo: upper)
        let second = app.staticTexts["Second performance"].firstMatch
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: second)], timeout: 5), .completed)
    }

    func testFeedSwipesContinuePastBothEdges() throws {
        guard let endpoint = ProcessInfo.processInfo.environment["HANDSTRUDEL_FEED_BOUNDARY_FIXTURE_URL"] else {
            throw XCTSkip("Requires a two-video feed fixture with clips at least 20 seconds long.")
        }
        app.launchArguments = ["--uitesting"]
        app.launchEnvironment["SUPABASE_URL"] = endpoint
        app.launchEnvironment["SUPABASE_ANON_KEY"] = "feed-boundary-fixture"
        app.launchEnvironment["MEDIA_BASE_URL"] = endpoint + "/cold-" + UUID().uuidString
        app.launch()
        element("tab-feed").tap()
        selectFeedMode("Latest")
        let viewport = app.collectionViews["feed-video-viewport"]
        XCTAssertTrue(viewport.waitForExistence(timeout: 5))
        let upper = viewport.coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: 0.27))
        let lower = viewport.coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: 0.73))
        let shortStart = viewport.coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: 0.43))
        let shortEnd = viewport.coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: 0.57))
        func expectClip(_ caption: String) {
            let selected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"),
                                                      object: app.staticTexts[caption].firstMatch)
            XCTAssertEqual(XCTWaiter.wait(for: [selected], timeout: 5), .completed)
        }
        expectClip("Evening loop")
        let slider = app.sliders["feed-video-progress"].firstMatch
        let barY = slider.frame.midY
        shortStart.press(forDuration: 0.05, thenDragTo: shortEnd)
        expectClip("Second performance")
        XCTAssertEqual(slider.frame.midY, barY, accuracy: 1)
        shortEnd.press(forDuration: 0.05, thenDragTo: shortStart)
        expectClip("Evening loop")
        XCTAssertEqual(slider.frame.midY, barY, accuracy: 1)
        // Normal adjacent navigation must still work after both edge jumps.
        lower.press(forDuration: 0.05, thenDragTo: upper)
        expectClip("Second performance")
        upper.press(forDuration: 0.05, thenDragTo: lower)
        expectClip("Evening loop")
        element("feed-options").tap()
        XCTAssertTrue(app.buttons["Refresh feed"].waitForExistence(timeout: 3), "Refresh stays available without claiming the backward swipe.")
    }

    func testFeedKeepsTheScrubberAndPlaybackAcrossConsecutiveVideoSwipes() throws {
        guard let endpoint = ProcessInfo.processInfo.environment["HANDSTRUDEL_SEQUENCE_FEED_FIXTURE_URL"] else {
            throw XCTSkip("Requires FIXTURE_SEQUENCE_CLIPS=1, delayed engagement/media, and a real clip at least 20 seconds long.")
        }
        app.launchArguments = ["--uitesting"]
        app.launchEnvironment["SUPABASE_URL"] = endpoint
        app.launchEnvironment["SUPABASE_ANON_KEY"] = "sequence-feed-fixture"
        app.launchEnvironment["MEDIA_BASE_URL"] = endpoint + "/cold-" + UUID().uuidString
        app.launch()
        element("tab-feed").tap()
        selectFeedMode("Latest")
        let viewport = app.collectionViews["feed-video-viewport"]
        XCTAssertTrue(viewport.waitForExistence(timeout: 5))
        let captions = ["Evening loop", "Second performance", "Third performance",
                        "Fourth performance, with a longer caption that wraps over several lines."]
        let upper = viewport.coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: 0.3))
        let lower = viewport.coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: 0.7))
        let pages = [0, 1, 2, 3, 2, 1, 0]
        var sharedRailFrame: CGRect?
        var sharedScrubberFrame: CGRect?
        for (step, page) in pages.enumerated() {
            let clip = viewport.cells.containing(.staticText, identifier: captions[page]).firstMatch
            let caption = clip.staticTexts[captions[page]]
            let selected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: caption)
            XCTAssertEqual(XCTWaiter.wait(for: [selected], timeout: 4), .completed)
            let slider = app.sliders["feed-video-progress"].firstMatch
            XCTAssertTrue(slider.isHittable, "Every selected clip must already have its scrubber, including pages \(page + 1) and later.")
            let rail = element("feed-action-rail")
            XCTAssertTrue(rail.isHittable)
            XCTAssertFalse(clip.sliders["feed-video-progress"].exists, "The scrubber must not scroll with a video cell.")
            XCTAssertFalse(clip.buttons["Share video"].exists, "The action rail must not scroll with a video cell.")
            if let sharedRailFrame, let sharedScrubberFrame {
                XCTAssertEqual(rail.frame.minY, sharedRailFrame.minY, accuracy: 1)
                XCTAssertEqual(rail.frame.maxY, sharedRailFrame.maxY, accuracy: 1)
                XCTAssertEqual(slider.frame.midY, sharedScrubberFrame.midY, accuracy: 1)
            } else {
                sharedRailFrame = rail.frame
                sharedScrubberFrame = slider.frame
            }
            XCTAssertEqual(app.buttons["Like"].firstMatch.value as? String, page == 0 ? "42 likes" : "0 likes")
            if page == 3 {
                let playing = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value MATCHES %@", "0:(0[1-9]|1[0-9]) of 0:20"), object: slider)
                XCTAssertEqual(XCTWaiter.wait(for: [playing], timeout: 12), .completed,
                               "The fourth video must actually start playing: \(slider.value ?? "missing playhead")")
            }
            if step + 1 < pages.count {
                if pages[step + 1] > page { lower.press(forDuration: 0.05, thenDragTo: upper) }
                else { upper.press(forDuration: 0.05, thenDragTo: lower) }
            }
        }
    }

    @MainActor
    func testFeedViewCountDoesNotRevertWhenReturningToAVideo() async throws {
        guard let endpoint = ProcessInfo.processInfo.environment["HANDSTRUDEL_SEQUENCE_FEED_FIXTURE_URL"],
              let fixture = URL(string: endpoint), fixture.host == "127.0.0.1" else {
            throw XCTSkip("Requires the sequence fixture with FIXTURE_VIEW_COUNTS=1 and a real clip at least 20 seconds long.")
        }
        app.terminate()
        let countURL = URL(string: "/rest/v1/feed_videos?id=eq.30000000-0000-0000-0000-000000000001", relativeTo: fixture)!
        let (data, _) = try await URLSession.shared.data(from: countURL)
        let rows = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [[String: Any]])
        let initial = try XCTUnwrap(rows.first?["view_count"] as? Int)
        app.launchArguments = ["--uitesting"]
        app.launchEnvironment["SUPABASE_URL"] = endpoint
        app.launchEnvironment["SUPABASE_ANON_KEY"] = "view-count-return-fixture"
        app.launchEnvironment["MEDIA_BASE_URL"] = endpoint + "/cold-" + UUID().uuidString
        app.launch()
        element("tab-feed").tap()
        selectFeedMode("Latest")
        XCTAssertTrue(app.staticTexts["Evening loop"].firstMatch.waitForExistence(timeout: 5))
        let views = element("feed-views-count")
        XCTAssertTrue(views.waitForExistence(timeout: 5))
        let counted = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", String(initial + 1)), object: views)
        await fulfillment(of: [counted], timeout: 15)
        let viewport = app.collectionViews["feed-video-viewport"]
        let upper = viewport.coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: 0.3))
        let lower = viewport.coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: 0.7))
        lower.press(forDuration: 0.05, thenDragTo: upper)
        let second = app.staticTexts["Second performance"].firstMatch
        await fulfillment(of: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: second)], timeout: 4)
        upper.press(forDuration: 0.05, thenDragTo: lower)
        let first = app.staticTexts["Evening loop"].firstMatch
        await fulfillment(of: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: first)], timeout: 4)
        XCTAssertEqual(views.value as? String, String(initial + 1), "Returning must immediately show the updated count, not the feed's older snapshot.")
    }

    func testInstrumentCarouselWrapsAcrossTheFreeInstruments() {
        app.launchArguments = ["--uitesting", "--force-locked", "-lastSoundFont", "grand_piano"]
        app.launch()
        let artwork = element("sound-artwork")
        XCTAssertTrue(artwork.waitForExistence(timeout: 5))
        let changeSound = app.buttons["Change sound"]
        func expectInstrument(_ name: String) {
            let selected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", name), object: changeSound)
            XCTAssertEqual(XCTWaiter.wait(for: [selected], timeout: 5), .completed)
        }
        let left = artwork.coordinate(withNormalizedOffset: CGVector(dx: 0.18, dy: 0.55))
        let right = artwork.coordinate(withNormalizedOffset: CGVector(dx: 0.82, dy: 0.55))
        expectInstrument("Grand Piano")
        left.press(forDuration: 0.05, thenDragTo: right)
        expectInstrument("Choir Aahs")
        right.press(forDuration: 0.05, thenDragTo: left)
        expectInstrument("Grand Piano")
        right.press(forDuration: 0.05, thenDragTo: left)
        expectInstrument("Rhodes EP")
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
        selectFeedMode("Following")
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
        let views = element("profile-views-received")
        XCTAssertEqual(views.label, "Total video views")
        XCTAssertEqual(views.value as? String, 1234.formatted())
        XCTAssertFalse(app.buttons["profile-reposts"].exists)
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
        let sounds = app.buttons["profile-sounds"]
        XCTAssertTrue(sounds.waitForExistence(timeout: 5))
        sounds.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.15)).tap()
        XCTAssertTrue(sounds.isSelected)
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
        let views = element("profile-views-received")
        for _ in 0..<2 where !views.isHittable {
            app.swipeUp(velocity: .slow)
        }
        XCTAssertTrue(views.isHittable)
        XCTAssertEqual(views.value as? String, 1234.formatted())
        captureIfRequested("Artist-Profile-Largest-Text")
    }

    func testPlayThisSoundFromFeedOpensMusicSession() throws {
        app.launchEnvironment["MEDIA_BASE_URL"] = ProcessInfo.processInfo.environment["HANDSTRUDEL_NOTIFICATION_FIXTURE_URL"]
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
        selectFeedMode("Following")
        XCTAssertTrue(app.staticTexts["You aren't following any creators yet"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["Try again"].exists)
        app.buttons["Browse Discover"].tap()
        XCTAssertTrue(app.staticTexts["Evening loop"].firstMatch.waitForExistence(timeout: 8))
    }

    private func selectFeedMode(_ title: String) {
        let menu = app.buttons["feed-options"]
        XCTAssertTrue(menu.waitForExistence(timeout: 5))
        menu.tap()
        let option = app.buttons[title].firstMatch
        XCTAssertTrue(option.waitForExistence(timeout: 5))
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: option)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 5), .completed)
        option.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let selected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", title), object: menu)
        XCTAssertEqual(XCTWaiter.wait(for: [selected], timeout: 5), .completed)
        let dismissed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: option)
        XCTAssertEqual(XCTWaiter.wait(for: [dismissed], timeout: 5), .completed)
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
        XCTAssertTrue(app.buttons["feed-options"].waitForExistence(timeout: 5))
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
        XCTAssertTrue(element("store-headline").waitForExistence(timeout: 5))
        XCTAssertTrue(element("store-buy-pro").exists)
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

    /// The store sells only Pro and HandStrudel+, and a Pro owner can subscribe.
    func testStoreSellsProAndPlusForEachKindOfPlayer() {
        for state in ["none", "pro", "plus"] {
            app.terminate()
            app.launchArguments = ["--uitesting", "--uitest-store-state=\(state)", "--uitest-camera-denied", "-hasSeenOnboarding", "YES"]
            app.launch()
            let start = element("start-button")
            XCTAssertTrue(start.waitForExistence(timeout: 5), state)
            start.tap()
            XCTAssertTrue(element("settings-button").waitForExistence(timeout: 5), state)
            element("settings-button").tap()
            let bag = app.buttons["Store"]
            XCTAssertTrue(bag.waitForExistence(timeout: 5), state)
            bag.tap()
            XCTAssertTrue(element("store-headline").waitForExistence(timeout: 5), state)
            XCTAssertFalse(app.staticTexts["808 Kit"].exists, "Old packs are no longer sold")
            XCTAssertFalse(app.staticTexts["Studio Pack"].exists)
            switch state {
            case "none":
                XCTAssertTrue(element("store-buy-pro").exists)
                XCTAssertTrue(element("store-subscribe").exists)
            case "pro":
                XCTAssertTrue(element("store-pro-owned").exists)
                XCTAssertTrue(element("store-plus-pro-note").exists)
                let subscribe = element("store-subscribe")
                XCTAssertTrue(subscribe.exists, "A Pro owner can subscribe to HandStrudel+")
                let yearly = element("store-plan-yearly")
                let monthly = element("store-plan-monthly")
                XCTAssertTrue(yearly.exists && monthly.exists)
                if subscribe.isEnabled {
                    XCTAssertTrue(app.staticTexts["Save 44%"].exists, "Yearly shows its saving over monthly")
                }
                if subscribe.isEnabled { monthly.tap() }
            default:
                XCTAssertTrue(element("store-plus-member").exists)
                XCTAssertTrue(element("store-manage-subscription").exists)
                XCTAssertTrue(element("store-pro-included").exists)
            }
            add(screenshotAttachment("store-\(state)"))
            app.swipeUp()
            add(screenshotAttachment("store-\(state)-bottom"))
            element("store-done").tap()
        }
    }

    private func screenshotAttachment(_ name: String) -> XCTAttachment {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        return attachment
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

    func testChordVoicingCanBeSwitchedFromMusicSettings() {
        launchToSession()
        element("settings-button").tap()
        selectMusicSettingsSection("sound")
        let picker = app.buttons["chord-voicing-picker"].firstMatch
        revealInMusicSettings(picker)
        let initial = picker.label.contains("7ths") ? "7ths" : "Triads"
        let other = initial == "7ths" ? "Triads" : "7ths"
        picker.tap()
        let option = app.buttons[other].firstMatch
        XCTAssertTrue(option.waitForExistence(timeout: 3))
        option.tap()
        XCTAssertTrue(picker.label.contains(other), picker.label)
        picker.tap()
        app.buttons[initial].firstMatch.tap()
        XCTAssertTrue(picker.label.contains(initial), picker.label)
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

// MARK: - Daily sound

extension HandStrudelUITests {
    /// Needs `node scripts/daily-sound-ui-fixture.mjs` and HANDSTRUDEL_DAILY_FIXTURE_URL.
    func testDailySoundCardShowsTodaysSoundStreakAndPlaysIt() throws {
        guard let endpoint = ProcessInfo.processInfo.environment["HANDSTRUDEL_DAILY_FIXTURE_URL"] else {
            throw XCTSkip("Requires the daily sound fixture.")
        }
        app.launchArguments.append("--uitesting")
        for key in ["SUPABASE_URL", "MEDIA_BASE_URL", "CLIP_MEDIA_BASE_URL"] { app.launchEnvironment[key] = endpoint }
        app.launchEnvironment["SUPABASE_ANON_KEY"] = "daily-fixture-key"
        app.launch()
        signOutOfDailyFixture()

        let card = element("daily-sound-card")
        XCTAssertTrue(card.waitForExistence(timeout: 10), "Today's sound sits at the top of the Music home")
        XCTAssertTrue(app.staticTexts["Night Drive"].exists)
        XCTAssertTrue(app.buttons["daily-sound-creator"].exists)
        XCTAssertEqual(element("daily-take-count").label, "3 takes today")
        XCTAssertTrue((element("daily-time-left").label).hasPrefix("New sound in"))
        XCTAssertTrue(app.buttons["daily-streak-sign-in"].exists, "Signed out, the card invites a sign-in")
        captureIfRequested("Daily-Sound-Guest")

        signInToProfile()
        XCTAssertTrue(app.buttons["Edit profile"].waitForExistence(timeout: 12))
        let profileStreak = element("profile-daily-streak")
        XCTAssertTrue(profileStreak.waitForExistence(timeout: 5), "The profile shows the streak and badges")
        element("tab-music").tap()

        let current = element("daily-streak-current")
        XCTAssertTrue(current.waitForExistence(timeout: 10))
        XCTAssertEqual(current.label, "7-day streak")
        XCTAssertEqual(element("daily-streak-best").label, "Best 12")
        let freeze = element("daily-streak-freeze").label
        XCTAssertTrue(freeze.contains("freeze covered"), freeze)
        let loan = element("daily-theme-loan")
        XCTAssertTrue(loan.exists, "A 7-day streak shows the lent hand theme")
        XCTAssertTrue(loan.label.contains("Royal hand theme unlocked"), loan.label)
        XCTAssertEqual(element("daily-streak-badges").label, "Streak badges: 3 days, 7 days")
        app.swipeUp(velocity: .slow)
        captureIfRequested("Daily-Sound-Streak")
        app.swipeDown(velocity: .slow)

        let play = app.buttons["daily-play-sound"]
        XCTAssertEqual(play.label, "Play today's sound")
        play.tap()
        let close = element("close-button")
        XCTAssertTrue(close.waitForExistence(timeout: 10), "Play today's sound opens the studio")
        close.tap()
        signOutOfDailyFixture()
    }

    /// Leaves the fixture account so the next run starts signed out.
    private func signOutOfDailyFixture() {
        let account = element("tab-account")
        XCTAssertTrue(account.waitForExistence(timeout: 10))
        account.tap()
        if app.buttons["Edit profile"].waitForExistence(timeout: 4) {
            app.buttons["Account settings"].tap()
            app.buttons["Sign out"].tap()
            XCTAssertTrue(app.buttons["Sign in"].waitForExistence(timeout: 8))
        }
        element("tab-music").tap()
    }
}
