import XCTest
@testable import HandStrudel

final class PushNotificationTests: XCTestCase {
    func testTapLinksUseExistingRoutes() {
        let id = "11111111-1111-1111-1111-111111111111"
        XCTAssertEqual(PushSupport.link(from: ["link": "handstrudel://watch/\(id)"]),
                       URL(string: "handstrudel://watch/\(id)"))
        XCTAssertEqual(PushSupport.link(from: ["link": "handstrudel://comments/\(id)"])
            .flatMap(PerformanceLink.init(url:)), .comments(UUID(uuidString: id)!))
        XCTAssertNil(PushSupport.link(from: ["link": "https://example.com/watch?v=\(id)"]))
        XCTAssertNil(PushSupport.link(from: ["link": "handstrudel://watch/not-a-uuid"]))
        XCTAssertNil(PushSupport.link(from: [:]))
    }

    func testTokenHexMatchesAPNsFormat() {
        XCTAssertEqual(PushSupport.hex(Data([0x00, 0xab, 0x10, 0xff])), "00ab10ff")
    }

    func testEnvironmentComesFromTheProvisioningProfile() {
        func profile(_ value: String) -> Data {
            Data("garbage<plist><dict><key>Entitlements</key><dict><key>aps-environment</key>\n\t\t<string>\(value)</string></dict></dict>".utf8)
        }
        XCTAssertEqual(PushSupport.apsEnvironment(provisioningProfile: profile("development")), "sandbox")
        XCTAssertEqual(PushSupport.apsEnvironment(provisioningProfile: profile("production")), "production")
        XCTAssertEqual(PushSupport.apsEnvironment(provisioningProfile: nil), "production")
        XCTAssertEqual(PushSupport.apsEnvironment(provisioningProfile: Data("<key>other</key>".utf8)), "production")
    }

    func testPreferencesUseServerColumnNames() throws {
        var preferences = NotificationPreferences()
        preferences.takeReplies = false
        let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(preferences)) as? [String: Bool]
        XCTAssertEqual(json, ["remixes": true, "take_replies": false, "likes": true, "comments": true,
                              "following_posts": true, "challenges": true])
        XCTAssertEqual(NotificationPreferences.toggles.count, 6)
    }
}
