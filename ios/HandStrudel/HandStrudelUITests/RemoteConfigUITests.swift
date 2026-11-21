import XCTest

/// Remote config served by a local fixture (DEBUG builds read
/// `HANDSTRUDEL_REMOTE_CONFIG_FIXTURE` instead of the network): the feed kill
/// switch, the soft update banner and the hard update block.
final class RemoteConfigUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments.append("--uitesting")
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func launch(rows: String) {
        app.launchEnvironment["HANDSTRUDEL_REMOTE_CONFIG_FIXTURE"] = rows
        app.launchEnvironment["HANDSTRUDEL_INSTRUMENT_CATALOG_FIXTURE"] = "[]"
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

        element("tab-feed").tap()
        XCTAssertTrue(element("feed-unavailable").waitForExistence(timeout: 5), "the kill switch replaces the feed")

        element("update-banner-dismiss").tap()
        XCTAssertTrue(banner.waitForNonExistence(timeout: 5), "the banner can be dismissed")
        app.terminate()
        app.launch()
        XCTAssertTrue(element("tab-feed").waitForExistence(timeout: 10))
        XCTAssertFalse(element("update-banner").waitForExistence(timeout: 3), "dismissal sticks for that version")
    }

    func testFixtureBlocksAnUnsupportedVersion() {
        launch(rows: """
        [{"id":1,"key":"update.minimum_version","value":"99.0","rollout_percent":100,"priority":0}]
        """)
        XCTAssertTrue(element("update-required").waitForExistence(timeout: 10), "the hard block appears")
        XCTAssertTrue(element("update-required-open").exists)
        XCTAssertTrue(app.staticTexts["Update required"].exists)
    }

    func testNoConfigLeavesTheAppAsItWas() {
        launch(rows: "[]")
        XCTAssertTrue(element("tab-feed").waitForExistence(timeout: 10))
        XCTAssertTrue(element("update-required").waitForNonExistence(timeout: 5), "a cached block clears once the fetch returns nothing")
        XCTAssertFalse(element("update-banner").exists)
        element("tab-feed").tap()
        XCTAssertTrue(element("feed-unavailable").waitForNonExistence(timeout: 5), "the feed is on by default")
    }
}
