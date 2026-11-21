import XCTest

/// Runs against a real local Supabase stack seeded by `scripts/moderation-ui-fixture.sh`
/// (email sign-in codes are read from the stack's Mailpit). Skips without it.
final class ModerationUITests: XCTestCase {
    private var app: XCUIApplication!
    private var api = ""
    private var anonKey = ""
    private var mailpit: URL!

    private let targetCaption = "Moderation target clip"
    private let controlCaption = "Moderation control clip"
    private let targetID = "e0000000-0000-0000-0000-000000000001"

    override func setUpWithError() throws {
        continueAfterFailure = false
        let env = ProcessInfo.processInfo.environment
        guard let url = env["HANDSTRUDEL_MODERATION_SUPABASE_URL"], let key = env["HANDSTRUDEL_MODERATION_ANON_KEY"],
              let mail = env["HANDSTRUDEL_MODERATION_MAILPIT_URL"].flatMap(URL.init(string:)) else {
            throw XCTSkip("Run scripts/moderation-ui-fixture.sh against a local stack and pass its TEST_RUNNER_ variables.")
        }
        api = url
        anonKey = key
        mailpit = mail
        app = XCUIApplication()
    }

    private func launch() {
        app.launchArguments = ["--uitesting", "-hasSeenOnboarding", "YES"]
        app.launchEnvironment["SUPABASE_URL"] = api
        app.launchEnvironment["SUPABASE_ANON_KEY"] = anonKey
        // No media server locally: thumbnails and clips fail fast and show placeholders.
        app.launchEnvironment["MEDIA_BASE_URL"] = "http://127.0.0.1:1"
        app.launchEnvironment["CLIP_MEDIA_BASE_URL"] = "http://127.0.0.1:1"
        app.launch()
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    func testAdminHidesReportedPostAndItLeavesTheFeed() throws {
        launch()
        openFeed()
        XCTAssertTrue(app.staticTexts[targetCaption].waitForExistence(timeout: 15), "the reported post starts in the feed")

        signIn(email: "moderator@example.test")
        let entry = openAccountMenu(waitingFor: "Moderation")
        XCTAssertTrue(entry.exists, "admins see Profile → Moderation")
        entry.tap()

        let row = element("moderation-item-\(targetID)")
        XCTAssertTrue(row.waitForExistence(timeout: 10), "the reported post is in the open queue")
        attach("Moderation-Queue")
        row.tap()
        XCTAssertTrue(app.staticTexts["Reports"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Spam"].waitForExistence(timeout: 5), "the detail lists the report reason")
        let hide = element("moderation-hide")
        XCTAssertTrue(hide.waitForExistence(timeout: 5))
        hide.tap()
        let confirm = app.buttons["Hide"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "hiding asks for confirmation")
        attach("Moderation-Confirm")
        confirm.tap()
        XCTAssertTrue(element("moderation-done").waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Hidden by admin"].waitForExistence(timeout: 5), "the detail shows the new state")
        attach("Moderation-Hidden")

        app.navigationBars.buttons.element(boundBy: 0).tap()
        let log = element("moderation-log")
        XCTAssertTrue(log.waitForExistence(timeout: 5))
        log.tap()
        let entryText = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "hid a post by @reported_creator"))
            .firstMatch
        XCTAssertTrue(entryText.waitForExistence(timeout: 10), "the audit log records the hide")
        attach("Moderation-Log")

        // A fresh launch reloads the public feed from the server.
        app.terminate()
        launch()
        openFeed()
        XCTAssertTrue(app.staticTexts[controlCaption].waitForExistence(timeout: 15), "the feed loaded")
        XCTAssertFalse(app.staticTexts[targetCaption].exists, "the hidden post is gone from the feed")
        attach("Feed-After-Hide")
    }

    func testNonAdminDoesNotSeeModeration() throws {
        launch()
        signIn(email: "member@example.test")
        XCTAssertFalse(openAccountMenu(waitingFor: "Moderation").exists, "non-admins don't see Moderation")
        XCTAssertTrue(app.buttons["Sign out"].exists, "the menu is open and signed in")
        attach("Member-Menu")
    }

    // MARK: - Helpers

    /// Opens the gear menu once the profile has loaded. A SwiftUI Menu keeps the items it had when it
    /// opened, so it's reopened a few times while the admin check (one RPC after sign-in) completes.
    private func openAccountMenu(waitingFor item: String) -> XCUIElement {
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "@")).firstMatch
            .waitForExistence(timeout: 15), "the signed-in profile loaded")
        let settings = app.buttons["Account settings"]
        let target = app.buttons[item]
        for attempt in 0..<4 {
            XCTAssertTrue(settings.waitForExistence(timeout: 10))
            settings.tap()
            XCTAssertTrue(app.buttons["Sign out"].waitForExistence(timeout: 5), "the account menu opened")
            if target.waitForExistence(timeout: 2) || attempt == 3 { break }
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08)).tap()  // close the menu
        }
        return target
    }

    private func openFeed() {
        let feed = element("tab-feed")
        XCTAssertTrue(feed.waitForExistence(timeout: 10))
        feed.tap()
    }

    /// Signs out any earlier account, then signs in with an emailed code from Mailpit.
    private func signIn(email: String) {
        let signInButton = app.buttons["Sign in"]
        let settings = app.buttons["Account settings"]
        // The first tab tap can land while the feed is still settling; retry until the account screen shows.
        for _ in 0..<3 where !settings.exists && !signInButton.exists {
            element("tab-account").tap()
            _ = settings.waitForExistence(timeout: 4) || signInButton.waitForExistence(timeout: 1)
        }
        if !signInButton.exists {
            XCTAssertTrue(settings.waitForExistence(timeout: 5))
            settings.tap()
            app.buttons["Sign out"].tap()
            XCTAssertTrue(signInButton.waitForExistence(timeout: 10))
        }
        clearMail()
        signInButton.tap()
        let field = app.textFields["you@example.com"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(email)
        app.buttons["Email me a code"].tap()
        let codeField = app.textFields["6-digit code"]
        XCTAssertTrue(codeField.waitForExistence(timeout: 10))
        let code = signInCode(for: email)
        XCTAssertNotNil(code, "Mailpit received a sign-in code")
        codeField.tap()
        codeField.typeText(code ?? "")
        app.buttons["verify-sign-in-code"].tap()
    }

    private func clearMail() {
        var request = URLRequest(url: mailpit.appendingPathComponent("api/v1/messages"))
        request.httpMethod = "DELETE"
        _ = fetch(request)
    }

    private func signInCode(for email: String) -> String? {
        for _ in 0..<20 {
            if let data = fetch(URLRequest(url: mailpit.appendingPathComponent("api/v1/messages"))),
               let list = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let messages = list["messages"] as? [[String: Any]],
               let message = messages.first(where: { message in
                   (message["To"] as? [[String: Any]])?.contains { ($0["Address"] as? String) == email } == true
               }),
               let id = message["ID"] as? String,
               let body = fetch(URLRequest(url: mailpit.appendingPathComponent("api/v1/message/\(id)"))),
               let detail = try? JSONSerialization.jsonObject(with: body) as? [String: Any] {
                let text = [detail["Text"], detail["HTML"]].compactMap { $0 as? String }.joined(separator: " ")
                if let range = text.range(of: #"\b\d{6}\b"#, options: .regularExpression) { return String(text[range]) }
            }
            Thread.sleep(forTimeInterval: 0.5)
        }
        return nil
    }

    private func fetch(_ request: URLRequest) -> Data? {
        let done = expectation(description: "mailpit")
        var result: Data?
        URLSession.shared.dataTask(with: request) { data, response, _ in
            if let status = (response as? HTTPURLResponse)?.statusCode, (200..<300).contains(status) { result = data }
            done.fulfill()
        }.resume()
        wait(for: [done], timeout: 10)
        return result
    }

    private func attach(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
