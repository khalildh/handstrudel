import XCTest

/// End-to-end push checks against a local Supabase stack. Run with `scripts/push-ui-check.sh`,
/// which seeds the accounts and posts, sends `xcrun simctl push` when the test asks for it,
/// and passes these settings (prefixed TEST_RUNNER_ for xcodebuild). Skipped otherwise.
final class PushNotificationUITests: XCTestCase {
    private struct Settings {
        let api: URL, anonKey: String, serviceKey: String
        let email: String, userID: String
        let signalFile: String, caption: String, commentBody: String
    }

    private var app: XCUIApplication!
    private let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")

    private func settings() throws -> Settings {
        let env = ProcessInfo.processInfo.environment
        guard let api = env["PUSH_UI_SUPABASE_URL"].flatMap(URL.init(string:)), api.host == "127.0.0.1",
              let anon = env["PUSH_UI_ANON_KEY"], let service = env["PUSH_UI_SERVICE_KEY"],
              let email = env["PUSH_UI_EMAIL"], let user = env["PUSH_UI_USER_ID"],
              let signal = env["PUSH_UI_SIGNAL_FILE"], let caption = env["PUSH_UI_CAPTION"],
              let comment = env["PUSH_UI_COMMENT"] else {
            throw XCTSkip("Run through scripts/push-ui-check.sh (local Supabase + simctl push).")
        }
        return Settings(api: api, anonKey: anon, serviceKey: service, email: email, userID: user,
                        signalFile: signal, caption: caption, commentBody: comment)
    }

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func launch(_ s: Settings) {
        app.launchArguments = ["--uitesting"]
        app.launchEnvironment["SUPABASE_URL"] = s.api.absoluteString
        app.launchEnvironment["SUPABASE_ANON_KEY"] = s.anonKey
        app.launch()
        let onboarding = element("onboarding-got-it")
        if onboarding.waitForExistence(timeout: 2) { onboarding.tap() }
    }

    // MARK: Server helpers

    private func request(_ s: Settings, _ path: String, method: String = "GET", body: [String: Any]? = nil) throws -> Any {
        var request = URLRequest(url: URL(string: path, relativeTo: s.api)!)
        request.httpMethod = method
        request.setValue(s.serviceKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(s.serviceKey)", forHTTPHeaderField: "Authorization")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let done = expectation(description: path)
        var result: Result<Data, Error> = .failure(URLError(.unknown))
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error { result = .failure(error) }
            else if let code = (response as? HTTPURLResponse)?.statusCode, !(200..<300).contains(code) {
                result = .failure(NSError(domain: "HTTP \(code)", code: code,
                                          userInfo: [NSLocalizedDescriptionKey: String(decoding: data ?? Data(), as: UTF8.self)]))
            } else { result = .success(data ?? Data()) }
            done.fulfill()
        }.resume()
        wait(for: [done], timeout: 15)
        return try JSONSerialization.jsonObject(with: result.get(), options: [.fragmentsAllowed])
    }

    /// The stored `likes` preference for the test account (nil when no row exists).
    private func storedLikes(_ s: Settings) throws -> Bool? {
        let rows = try request(s, "/rest/v1/notification_preferences?select=likes&user_id=eq.\(s.userID)") as? [[String: Any]]
        return rows?.first?["likes"] as? Bool
    }

    private func signIn(_ s: Settings) throws {
        element("tab-account").tap()
        let signIn = app.buttons["Sign in"].firstMatch
        if !signIn.waitForExistence(timeout: 5) {
            // A session left over from an earlier run (the seed recreates the account): sign out first.
            app.buttons["Account settings"].tap()
            let signOut = app.buttons["Sign out"]
            XCTAssertTrue(signOut.waitForExistence(timeout: 5))
            signOut.tap()
        }
        XCTAssertTrue(signIn.waitForExistence(timeout: 10))
        signIn.tap()
        let email = app.textFields["you@example.com"]
        XCTAssertTrue(email.waitForExistence(timeout: 5))
        email.tap()
        email.typeText(s.email)
        app.buttons["Email me a code"].tap()
        let codeField = app.textFields["6-digit code"]
        XCTAssertTrue(codeField.waitForExistence(timeout: 10))
        // A fresh one-time code for the same address, straight from the local auth server.
        let link = try request(s, "/auth/v1/admin/generate_link", method: "POST",
                               body: ["type": "magiclink", "email": s.email]) as? [String: Any]
        let code = try XCTUnwrap((link?["email_otp"] ?? (link?["properties"] as? [String: Any])?["email_otp"]) as? String)
        codeField.tap()
        codeField.typeText(code)
        element("verify-sign-in-code").tap()
        XCTAssertTrue(codeField.waitForNonExistence(timeout: 15), "Signing in with the code should close the sheet")
    }

    private func openNotificationSettings() {
        element("tab-account").tap()
        let gear = app.buttons["Account settings"]
        XCTAssertTrue(gear.waitForExistence(timeout: 10))
        gear.tap()
        let item = app.buttons["Notifications"]
        XCTAssertTrue(item.waitForExistence(timeout: 5))
        item.tap()
        XCTAssertTrue(app.navigationBars["Notifications"].waitForExistence(timeout: 5))
    }

    private func flip(_ toggle: XCUIElement) {
        let control = toggle.switches.firstMatch.exists ? toggle.switches.firstMatch : toggle
        control.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
    }

    private func waitUntil(_ timeout: TimeInterval, _ condition: () throws -> Bool) rethrows -> Bool {
        let end = Date().addingTimeInterval(timeout)
        while Date() < end {
            if try condition() { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        }
        return try condition()
    }

    // MARK: Tests

    func testTogglingANotificationTypeIsStoredForTheSignedInAccount() throws {
        let s = try settings()
        launch(s)
        try signIn(s)
        XCTAssertNil(try storedLikes(s), "a new account starts with no stored preferences (all on)")

        openNotificationSettings()
        let likes = element("notification-toggle-likes")
        XCTAssertTrue(likes.waitForExistence(timeout: 10))
        XCTAssertTrue(waitUntil(10) { likes.isEnabled }, "toggles enable once preferences load")
        XCTAssertEqual(likes.value as? String, "1")
        flip(likes)
        XCTAssertTrue(try waitUntil(10) { try storedLikes(s) == false }, "turning Likes off is saved to notification_preferences")

        // Reopen: the screen shows what the server stored.
        app.navigationBars["Notifications"].buttons["Done"].tap()
        openNotificationSettings()
        let reloaded = element("notification-toggle-likes")
        XCTAssertTrue(waitUntil(10) { reloaded.isEnabled })
        XCTAssertEqual(reloaded.value as? String, "0")
        XCTAssertEqual(element("notification-toggle-comments").value as? String, "1", "other types are unchanged")

        flip(reloaded)
        XCTAssertTrue(try waitUntil(10) { try storedLikes(s) == true }, "turning Likes back on is saved")
    }

    func testTappingAPushAfterTheAppWasClosedOpensThatPost() throws {
        let s = try settings()
        launch(s)

        // Allow notifications from settings (also checks the permission prompt).
        openNotificationSettings()
        let turnOn = app.buttons["Turn on notifications"]
        if turnOn.waitForExistence(timeout: 3) {
            turnOn.tap()
            let allow = springboard.buttons["Allow"]
            XCTAssertTrue(allow.waitForExistence(timeout: 10), "the system permission prompt appears")
            allow.tap()
        }
        XCTAssertTrue(app.staticTexts["Notifications are on"].waitForExistence(timeout: 10))

        try coldLaunchFromPush(s, kind: "watch", expect: s.caption)
        try coldLaunchFromPush(s, kind: "comments", expect: s.commentBody)
    }

    /// Closes the app, asks the host script to send a push, taps the banner, and checks where it lands.
    private func coldLaunchFromPush(_ s: Settings, kind: String, expect text: String) throws {
        app.terminate()
        XCTAssertTrue(app.wait(for: .notRunning, timeout: 10))
        XCUIDevice.shared.press(.home)
        XCTAssertTrue(FileManager.default.createFile(atPath: s.signalFile, contents: Data(kind.utf8)),
                      "couldn't ask the host for a push")
        let banner = springboard.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "push-check-\(kind)")).firstMatch
        XCTAssertTrue(banner.waitForExistence(timeout: 30), "the \(kind) push banner appears")
        banner.tap()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 20), "tapping the banner launches the app")
        let landed = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", text)).firstMatch
        XCTAssertTrue(landed.waitForExistence(timeout: 20), "the \(kind) push opens the post showing “\(text)”")
    }
}
