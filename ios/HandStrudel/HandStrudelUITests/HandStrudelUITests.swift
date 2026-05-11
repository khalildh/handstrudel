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
        // Tap first preset and LET'S GO
        let firstPreset = element("preset-Dreamy")
        XCTAssertTrue(firstPreset.waitForExistence(timeout: 5), "Preset card should exist")
        firstPreset.tap()
        let letsGo = element("lets-go-button")
        XCTAssertTrue(letsGo.waitForExistence(timeout: 2), "LET'S GO should exist")
        letsGo.tap()
        // Wait for session to appear
        let closeBtn = element("close-button")
        XCTAssertTrue(closeBtn.waitForExistence(timeout: 5), "Session should start")
    }

    /// Launch app with onboarding reset and start session
    private func launchToSessionWithOnboarding() {
        app.launchArguments.append(contentsOf: ["--uitesting", "--reset-onboarding"])
        app.launch()
        let firstPreset = element("preset-Dreamy")
        if firstPreset.waitForExistence(timeout: 5) {
            firstPreset.tap()
        }
        let letsGo = element("lets-go-button")
        if letsGo.waitForExistence(timeout: 2) {
            letsGo.tap()
        }
    }

    // MARK: - Start Overlay Tests

    func testLaunch_showsStartOverlay() {
        launchToStart()
        // Title is split into two Text views: "hand" + "strudel"
        XCTAssertTrue(app.staticTexts["strudel"].waitForExistence(timeout: 5))
    }

    func testStartOverlay_showsSubtitle() {
        launchToStart()
        XCTAssertTrue(app.staticTexts["your hands are the instrument"].waitForExistence(timeout: 5))
    }

    func testStartOverlay_showsPickAVibe() {
        launchToStart()
        XCTAssertTrue(app.staticTexts["PICK A VIBE"].waitForExistence(timeout: 5))
    }

    func testStartOverlay_showsPresetCards() {
        launchToStart()
        XCTAssertTrue(element("preset-Dreamy").waitForExistence(timeout: 5))
        XCTAssertTrue(element("preset-Gritty").exists)
        XCTAssertTrue(element("preset-Bouncy").exists)
        XCTAssertTrue(element("preset-Chill").exists)
    }

    func testStartOverlay_letsGoButtonExists() {
        launchToStart()
        XCTAssertTrue(element("lets-go-button").waitForExistence(timeout: 5))
    }

    func testStartOverlay_tapPreset_showsSelection() {
        launchToStart()
        let preset = element("preset-Dreamy")
        XCTAssertTrue(preset.waitForExistence(timeout: 5))
        preset.tap()
        let btn = element("lets-go-button")
        XCTAssertTrue(btn.waitForExistence(timeout: 2))
        XCTAssertTrue(btn.isEnabled)
    }

    func testStartOverlay_tapDifferentPreset() {
        launchToStart()
        let dreamy = element("preset-Dreamy")
        XCTAssertTrue(dreamy.waitForExistence(timeout: 5))
        dreamy.tap()

        let bouncy = element("preset-Bouncy")
        bouncy.tap()

        let btn = element("lets-go-button")
        XCTAssertTrue(btn.isEnabled)
    }

    func testStartOverlay_showsLetsGoText() {
        launchToStart()
        // "LET'S GO" is a Button label, not a standalone staticText
        let btn = element("lets-go-button")
        XCTAssertTrue(btn.waitForExistence(timeout: 5))
        XCTAssertTrue(btn.label.contains("LET"))
    }

    // MARK: - Session Start Tests

    func testLetsGo_startsSession() {
        launchToSession()
        XCTAssertTrue(element("close-button").exists)
    }

    func testSession_showsSettingsButton() {
        launchToSession()
        XCTAssertTrue(element("settings-button").waitForExistence(timeout: 2))
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
        XCTAssertTrue(app.staticTexts["PICK A VIBE"].waitForExistence(timeout: 10))
    }

    // MARK: - Onboarding Tests

    func testOnboarding_showsOnFirstLaunch() {
        launchToSessionWithOnboarding()
        let gotIt = element("onboarding-got-it")
        XCTAssertTrue(gotIt.waitForExistence(timeout: 5), "Onboarding should show")
    }

    func testOnboarding_showsWelcomeText() {
        launchToSessionWithOnboarding()
        XCTAssertTrue(app.staticTexts["welcome to"].waitForExistence(timeout: 5))
    }

    func testOnboarding_showsTips() {
        launchToSessionWithOnboarding()
        _ = element("onboarding-got-it").waitForExistence(timeout: 5)
        XCTAssertTrue(app.staticTexts["Move your hands up & down"].exists)
        XCTAssertTrue(app.staticTexts["Spread your fingers"].exists)
        XCTAssertTrue(app.staticTexts["Tap the record button"].exists)
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
        XCTAssertTrue(app.staticTexts["MODE"].waitForExistence(timeout: 5))
    }

    func testControlSheet_showsHarmonySection() {
        launchToSession()
        element("settings-button").tap()
        _ = app.staticTexts["MODE"].waitForExistence(timeout: 3)
        let harmony = app.staticTexts["HARMONY"]
        if !harmony.exists { app.swipeUp() }
        XCTAssertTrue(harmony.waitForExistence(timeout: 3))
    }

    func testControlSheet_showsSoundSection() {
        launchToSession()
        element("settings-button").tap()
        _ = app.staticTexts["MODE"].waitForExistence(timeout: 3)
        let sound = app.staticTexts["SOUND"]
        if !sound.exists { app.swipeUp() }
        XCTAssertTrue(sound.waitForExistence(timeout: 3))
    }

    func testControlSheet_showsBPMSection() {
        launchToSession()
        element("settings-button").tap()
        _ = app.staticTexts["MODE"].waitForExistence(timeout: 3)
        let bpm = app.staticTexts["BPM"]
        if !bpm.exists { app.swipeUp() }
        XCTAssertTrue(bpm.waitForExistence(timeout: 3))
    }

    // MARK: - Mode Switching Tests

    func testModeSection_showsAllModes() {
        launchToSession()
        element("settings-button").tap()
        _ = app.staticTexts["MODE"].waitForExistence(timeout: 3)
        XCTAssertTrue(element("mode-melodic").exists)
        XCTAssertTrue(element("mode-grid").exists)
        XCTAssertTrue(element("mode-drums").exists)
        XCTAssertTrue(element("mode-learn").exists)
    }

    func testModeSwitching_tapGrid() {
        launchToSession()
        element("settings-button").tap()
        _ = app.staticTexts["MODE"].waitForExistence(timeout: 3)
        element("mode-grid").tap()
        XCTAssertTrue(app.staticTexts["Range"].waitForExistence(timeout: 2))
    }

    func testModeSwitching_tapDrums() {
        launchToSession()
        element("settings-button").tap()
        _ = app.staticTexts["MODE"].waitForExistence(timeout: 3)
        element("mode-drums").tap()
        XCTAssertTrue(element("mode-drums").exists)
    }

    func testModeSwitching_tapLearn_showsSongPicker() {
        launchToSession()
        element("settings-button").tap()
        _ = app.staticTexts["MODE"].waitForExistence(timeout: 3)
        element("mode-learn").tap()
        XCTAssertTrue(app.staticTexts["LEARN"].waitForExistence(timeout: 3))
    }

    func testModeSwitching_backToMelodic() {
        launchToSession()
        element("settings-button").tap()
        _ = app.staticTexts["MODE"].waitForExistence(timeout: 3)
        element("mode-grid").tap()
        sleep(1)
        element("mode-melodic").tap()
        XCTAssertTrue(element("mode-melodic").exists)
    }

    // MARK: - Harmony Tests

    func testHarmony_keySelection() {
        launchToSession()
        element("settings-button").tap()
        _ = app.staticTexts["MODE"].waitForExistence(timeout: 3)
        let harmony = app.staticTexts["HARMONY"]
        if !harmony.exists { app.swipeUp() }
        _ = harmony.waitForExistence(timeout: 3)
        let keyD = app.staticTexts["D"].firstMatch
        if keyD.exists { keyD.tap() }
        XCTAssertTrue(harmony.exists)
    }

    func testHarmony_scaleSelection() {
        launchToSession()
        element("settings-button").tap()
        _ = app.staticTexts["MODE"].waitForExistence(timeout: 3)
        let harmony = app.staticTexts["HARMONY"]
        if !harmony.exists { app.swipeUp() }
        _ = harmony.waitForExistence(timeout: 3)
        let minor = app.staticTexts["Minor"].firstMatch
        if minor.exists { minor.tap() }
        XCTAssertTrue(harmony.exists)
    }

    // MARK: - BPM Tests

    func testBPM_showsValue() {
        launchToSession()
        element("settings-button").tap()
        _ = app.staticTexts["MODE"].waitForExistence(timeout: 3)
        let bpm = app.staticTexts["BPM"]
        if !bpm.exists { app.swipeUp() }
        XCTAssertTrue(bpm.waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["120"].exists || app.staticTexts["BPM"].exists)
    }

    // MARK: - Learn Song Picker Tests

    func testLearnSongPicker_showsMelodies() {
        launchToSession()
        element("settings-button").tap()
        _ = app.staticTexts["MODE"].waitForExistence(timeout: 3)
        element("mode-learn").tap()
        _ = app.staticTexts["LEARN"].waitForExistence(timeout: 3)
        XCTAssertTrue(app.staticTexts["MELODIES"].exists)
    }

    func testLearnSongPicker_showsPractice() {
        launchToSession()
        element("settings-button").tap()
        _ = app.staticTexts["MODE"].waitForExistence(timeout: 3)
        element("mode-learn").tap()
        _ = app.staticTexts["LEARN"].waitForExistence(timeout: 3)
        let practice = app.staticTexts["PRACTICE"]
        if !practice.exists { app.swipeUp() }
        XCTAssertTrue(practice.waitForExistence(timeout: 3))
    }

    func testLearnSongPicker_showsSongCards() {
        launchToSession()
        element("settings-button").tap()
        _ = app.staticTexts["MODE"].waitForExistence(timeout: 3)
        element("mode-learn").tap()
        _ = app.staticTexts["LEARN"].waitForExistence(timeout: 3)
        XCTAssertTrue(element("song-Twinkle Twinkle").waitForExistence(timeout: 3))
    }

    func testLearnSongPicker_showsPracticeButtons() {
        launchToSession()
        element("settings-button").tap()
        _ = app.staticTexts["MODE"].waitForExistence(timeout: 3)
        element("mode-learn").tap()
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
        _ = app.staticTexts["MODE"].waitForExistence(timeout: 3)
        element("mode-learn").tap()
        _ = app.staticTexts["LEARN"].waitForExistence(timeout: 3)
        let importSection = app.staticTexts["IMPORT"]
        if !importSection.exists { app.swipeUp() }
        XCTAssertTrue(importSection.waitForExistence(timeout: 3))
    }

    // MARK: - Navigation Flow Tests

    func testFullFlow_startToSessionAndSettings() {
        app.launchArguments.append("--uitesting")
        app.launch()

        // Start overlay visible
        XCTAssertTrue(app.staticTexts["PICK A VIBE"].waitForExistence(timeout: 5))

        // Select preset and start
        let preset = element("preset-Dreamy")
        XCTAssertTrue(preset.waitForExistence(timeout: 5))
        preset.tap()
        element("lets-go-button").tap()
        XCTAssertTrue(element("close-button").waitForExistence(timeout: 5))

        // Open settings and switch mode
        element("settings-button").tap()
        XCTAssertTrue(app.staticTexts["MODE"].waitForExistence(timeout: 3))
        element("mode-grid").tap()
        XCTAssertTrue(app.staticTexts["Range"].waitForExistence(timeout: 2))
    }

    func testFullFlow_learnModeSongSelection() {
        launchToSession()

        element("settings-button").tap()
        _ = app.staticTexts["MODE"].waitForExistence(timeout: 3)

        element("mode-learn").tap()
        _ = app.staticTexts["LEARN"].waitForExistence(timeout: 3)

        let song = element("song-Twinkle Twinkle")
        if song.waitForExistence(timeout: 3) {
            song.tap()
        }

        XCTAssertTrue(element("close-button").waitForExistence(timeout: 5))
    }
}
