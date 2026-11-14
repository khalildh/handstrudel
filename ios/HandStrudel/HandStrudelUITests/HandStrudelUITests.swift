import XCTest

final class HandStrudelUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
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
        app.launchArguments.append(contentsOf: ["--uitesting", "--reset-onboarding"])
        app.launch()
        let start = element("start-button")
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        start.tap()
    }

    /// All modes live behind an "Other modes" disclosure at the bottom of the
    /// settings sheet now. Tests that switch modes need to scroll there and
    /// expand it first. Assumes the sheet is already open.
    private func expandOtherModes() {
        // SwiftUI's DisclosureGroup label can show up as either a static text
        // or a button depending on iOS version — match both.
        var attempts = 0
        while attempts < 8 {
            let asText = app.staticTexts["Other modes"]
            let asButton = app.buttons["Other modes"]
            if asText.isHittable { asText.tap(); return }
            if asButton.isHittable { asButton.tap(); return }
            app.swipeUp()
            attempts += 1
        }
    }

    /// Switch to a mode that's hidden behind the "Other modes" disclosure.
    /// Returns the mode element after expansion + tapping.
    @discardableResult
    private func switchToMode(_ identifier: String) -> XCUIElement {
        expandOtherModes()
        let mode = element(identifier)
        if mode.waitForExistence(timeout: 2), mode.isHittable {
            mode.tap()
        }
        return mode
    }

    // MARK: - Start Overlay Tests

    func testLaunch_showsStartOverlay() {
        launchToStart()
        XCTAssertTrue(app.staticTexts["handstrudel"].waitForExistence(timeout: 5))
    }

    func testStartOverlay_showsSubtitle() {
        launchToStart()
        XCTAssertTrue(app.staticTexts["Move your hands to make music."].waitForExistence(timeout: 5))
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
        XCTAssertTrue(app.staticTexts["feed-video-position"].exists)
        app.buttons["Next video"].tap()
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: second)], timeout: 5), .completed)
        app.buttons["Previous video"].tap()
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: first)], timeout: 5), .completed)
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
        // HARMONY is the first section header that's always present (the
        // top-of-sheet MODE header was removed when the mode picker moved
        // into the bottom-of-sheet "Other modes" disclosure).
        XCTAssertTrue(app.staticTexts["HARMONY"].waitForExistence(timeout: 5))
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
        app.swipeDown()   // dismiss + reopen so the sheet redraws past hidden sections
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
        app.swipeDown()
        element("settings-button").tap()
        let bpm = app.staticTexts["BPM"]
        if !bpm.exists { app.swipeUp() }
        XCTAssertTrue(bpm.waitForExistence(timeout: 3))
    }

    // MARK: - Mode Switching Tests

    func testModeSection_showsAllModes() {
        launchToSession()
        element("settings-button").tap()
        _ = app.staticTexts["HARMONY"].waitForExistence(timeout: 3)
        // All modes live in the bottom-of-sheet "Other modes" disclosure now.
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
        app.swipeDown()
        XCTAssertTrue(app.staticTexts["Range"].waitForExistence(timeout: 3))
    }

    func testModeSwitching_tapDrums() {
        launchToSession()
        element("settings-button").tap()
        _ = app.staticTexts["HARMONY"].waitForExistence(timeout: 3)
        switchToMode("mode-drums")
        // Reopen the sheet so we can confirm the mode chip is now selected.
        app.swipeDown()
        element("settings-button").tap()
        expandOtherModes()
        XCTAssertTrue(element("mode-drums").waitForExistence(timeout: 2))
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
        sleep(1)
        element("settings-button").tap()
        _ = app.staticTexts["HARMONY"].waitForExistence(timeout: 3)
        switchToMode("mode-melodic")
        sleep(1)
        element("settings-button").tap()
        expandOtherModes()
        XCTAssertTrue(element("mode-melodic").waitForExistence(timeout: 2))
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
        app.swipeDown()
        element("settings-button").tap()
        let bpm = app.staticTexts["BPM"]
        if !bpm.exists { app.swipeUp() }
        XCTAssertTrue(bpm.waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["120"].exists || app.staticTexts["BPM"].exists)
    }

    // MARK: - Learn Song Picker Tests

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
        app.swipeDown()
        XCTAssertTrue(app.staticTexts["Range"].waitForExistence(timeout: 2))
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
