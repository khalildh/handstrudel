import XCTest
@testable import HandStrudel

final class InviteRewardsTests: XCTestCase {
    func testNormalizesCodesTheWayTheServerDoes() {
        XCTAssertEqual(InviteCode.normalize("abcd-2345"), "ABCD2345")
        XCTAssertEqual(InviteCode.normalize("  ABCD 2345\n"), "ABCD2345")
        XCTAssertNil(InviteCode.normalize("ABCD234"), "too short")
        XCTAssertNil(InviteCode.normalize("ABCD23450"), "too long")
        XCTAssertNil(InviteCode.normalize("ABCD1234"), "1 and 0 are never in a code")
        XCTAssertNil(InviteCode.normalize(nil))
        XCTAssertEqual(InviteCode.sanitizeTyping("ab-cd 23456"), "ABCD2345")
    }

    func testParsesInviteLinks() throws {
        let invite = try XCTUnwrap(InviteCode.parse(URL(string: "https://handstrudel.com/invite?c=abcd2345")!))
        XCTAssertEqual(invite.code, "ABCD2345")
        XCTAssertTrue(invite.isInviteOnly)

        let watch = try XCTUnwrap(InviteCode.parse(URL(string:
            "https://handstrudel.com/watch?v=0f8fad5b-d9cb-469f-a165-70867728950e&invite=ABCD2345")!))
        XCTAssertEqual(watch.code, "ABCD2345")
        XCTAssertFalse(watch.isInviteOnly, "the post still opens")
        XCTAssertNotNil(PerformanceLink(url: URL(string:
            "https://handstrudel.com/watch?v=0f8fad5b-d9cb-469f-a165-70867728950e&invite=ABCD2345")!))

        XCTAssertEqual(InviteCode.parse(URL(string: "handstrudel://invite/ABCD2345")!)?.code, "ABCD2345")
        XCTAssertNil(InviteCode.parse(URL(string: "handstrudel://watch/ABCD2345")!))
        XCTAssertNil(InviteCode.parse(URL(string: "https://handstrudel.com/watch?v=0f8fad5b-d9cb-469f-a165-70867728950e")!))
        XCTAssertNil(InviteCode.parse(URL(string: "https://evil.example/invite?c=ABCD2345")!))
        XCTAssertNil(InviteCode.parse(URL(string: "http://handstrudel.com/invite?c=ABCD2345")!))
        XCTAssertNil(InviteCode.parse(URL(string: "https://handstrudel.com/invite?c=nope")!))
    }

    func testInviteURLsRoundTrip() throws {
        let url = InviteCode.url(for: "ABCD2345")
        XCTAssertEqual(url.absoluteString, "https://handstrudel.com/invite?c=ABCD2345")
        XCTAssertEqual(InviteCode.parse(url)?.code, "ABCD2345")
    }

    func testSummaryCountsFriends() throws {
        func summary(joined: Int, rewarded: Int = 0) throws -> InviteSummary {
            try JSONDecoder().decode(InviteSummary.self, from: JSONSerialization.data(withJSONObject: [
                "code": "ABCD2345", "friends_joined": joined, "friends_rewarded": rewarded, "reward_limit": 10,
            ]))
        }
        XCTAssertNil(try summary(joined: 0).joinedText)
        XCTAssertEqual(try summary(joined: 1).joinedText, "1 friend joined")
        XCTAssertEqual(try summary(joined: 3).joinedText, "3 friends joined")
        XCTAssertFalse(try summary(joined: 9, rewarded: 9).reachedLimit)
        XCTAssertTrue(try summary(joined: 12, rewarded: 10).reachedLimit)
        let text = try summary(joined: 0).shareText
        XCTAssertTrue(text.hasSuffix(" https://handstrudel.com/invite?c=ABCD2345"), "the shared text always carries the link")
        XCTAssertTrue(text.contains("we both get a week"))
    }

    func testCelebrationNamesTheFriend() {
        let inviter = InviteCelebration(id: UUID(), role: "inviter", friendUsername: "maya", expiresAt: nil)
        XCTAssertEqual(inviter.message, "@maya posted their first take. You both get 7 days of HandStrudel+.")
        let invitee = InviteCelebration(id: UUID(), role: "invitee", friendUsername: nil, expiresAt: nil)
        XCTAssertTrue(invitee.message.contains("the friend who invited you"))
    }

    func testEveryServerReasonHasAnActionableMessage() {
        for reason in ["not_found", "self_invite", "already_redeemed", "already_posted"] {
            XCTAssertNotEqual(InviteRedeemOutcome.message(for: reason), InviteRedeemOutcome.message(for: nil), reason)
        }
    }

    func testIntroTrackerText() throws {
        func stats(_ intros: Int, _ milestone: Int?, _ badge: String?) -> IntroStats {
            IntroStats(intros: intros, milestone: milestone, badge: badge)
        }
        XCTAssertNil(stats(0, nil, nil).badgeText)
        XCTAssertEqual(stats(1, 1, "Spark").badgeText, "Spark · 1 intro")
        XCTAssertEqual(stats(12, 10, "Connector").badgeText, "Connector · 12 intros")
        XCTAssertEqual(stats(1, 1, "Spark").headline, "You've introduced 1 person")
        XCTAssertEqual(stats(7, 5, "Bandleader").headline, "You've introduced 7 people")
        XCTAssertEqual(stats(7, 5, "Bandleader").nextMilestoneText, "3 more for the 10-intro badge")
        XCTAssertNil(stats(30, 25, "Headliner").nextMilestoneText, "no badge past 25")
    }

    func testAcceptedMessageStaysTruePastTheInvitersCap() {
        XCTAssertTrue(InviteManager.acceptedMessage(inviter: "maya", inviterRewarded: true)
            .contains("you each get 7 days"))
        let capped = InviteManager.acceptedMessage(inviter: "maya", inviterRewarded: false)
        XCTAssertFalse(capped.contains("you each"))
        XCTAssertTrue(capped.contains("still count as their intro"))
    }

    func testIntroPersonDecodesFromTheServer() throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let person = try decoder.decode(IntroPerson.self, from: Data("""
            {"user_id":"0f8fad5b-d9cb-469f-a165-70867728950e","username":"maya","display_name":null,
             "avatar_key":null,"joined_at":"2026-11-21T03:00:00Z","posted_first_take":true}
            """.utf8))
        XCTAssertEqual(person.username, "maya")
        XCTAssertEqual(person.status, "Posted their first take")
    }
}
