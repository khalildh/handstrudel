import XCTest
@testable import HandStrudel

/// Funnel events: names and details match the database allow-list, and opt-in is respected.
@MainActor
final class AppAnalyticsFunnelTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suite = ""
    private var hits: [AppAnalytics.Hit] = []
    private var analytics: AppAnalytics!

    override func setUp() async throws {
        suite = "funnel-\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        hits = []
        analytics = AppAnalytics(defaults: defaults, hits: { [unowned self] in self.hits.append($0) })
        Funnel.analytics = analytics
    }

    override func tearDown() async throws {
        Funnel.analytics = .shared
        defaults.removePersistentDomain(forName: suite)
    }

    /// The latest migration that defines `record_app_usage_event`, read from the repository.
    private func migrationSQL() throws -> String {
        let repo = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: repo.appendingPathComponent(
            "supabase/migrations/20261121070000_crash_diagnostics_funnel.sql"), encoding: .utf8)
    }

    /// Quoted words inside the SQL span that starts at `start` and ends at the next `end`.
    private func quoted(in sql: String, from start: String, to end: String) throws -> Set<String> {
        let begin = try XCTUnwrap(sql.range(of: start), "missing \(start)")
        let finish = try XCTUnwrap(sql.range(of: end, range: begin.upperBound..<sql.endIndex), "missing \(end)")
        let span = String(sql[begin.upperBound..<finish.lowerBound])
        let regex = try NSRegularExpression(pattern: "'([a-z_]+)'")
        return Set(regex.matches(in: span, range: NSRange(span.startIndex..., in: span)).map {
            String(span[Range($0.range(at: 1), in: span)!])
        })
    }

    func testEveryEventNameIsOnTheDatabaseAllowList() throws {
        let sql = try migrationSQL()
        let appNames = Set(AppAnalytics.Event.allCases.map(\.rawValue))
        let tableCheck = try quoted(in: sql, from: "add constraint app_usage_daily_event_check check (event in (", to: "));")
        let functionCheck = try quoted(in: sql, from: "if p_event is null or p_event not in (", to: ") then")
        XCTAssertEqual(appNames, tableCheck, "AppAnalytics.Event and the table's check constraint differ")
        XCTAssertEqual(appNames, functionCheck, "AppAnalytics.Event and record_app_usage_event differ")
        for name in ["store_viewed", "purchase_started", "purchase_completed", "restore_tapped",
                     "invite_link_shared", "invite_code_redeemed", "invited_first_post",
                     "reply_started", "reply_posted", "challenge_link_shared", "challenge_link_opened",
                     "daily_sound_opened", "daily_take_posted", "streak_extended",
                     "sound_page_opened", "play_this_sound_tapped", "notification_opened",
                     "first_note", "first_post_published"] {
            XCTAssertTrue(appNames.contains(name), name)
        }
    }

    func testEveryDetailIsOnTheDatabaseAllowList() throws {
        let sql = try migrationSQL()
        let products = try quoted(in: sql, from: "then p_detail in (", to: ")")
        XCTAssertEqual(Set(AppAnalytics.PurchaseProduct.allCases.map(\.rawValue)), products)
        let notification = try quoted(in: sql, from: "when p_event = 'notification_opened'\n      then p_detail in (", to: "\n      )")
        XCTAssertEqual(Set(AppAnalytics.NotificationKind.allCases.map(\.rawValue)), notification)
        XCTAssertEqual(Set(AppAnalytics.Event.allowedDetails.keys),
                       [.purchaseStarted, .purchaseCompleted, .notificationOpened])
    }

    func testNothingIsSentWhenOptedOut() {
        Funnel.storeViewed()
        Funnel.purchaseStarted(productId: StoreManager.pro)
        Funnel.notificationOpened(pushType: "like")
        Funnel.playThisSoundTapped()
        Funnel.postPublished()
        XCTAssertEqual(hits, [])
    }

    func testFunnelEventsAreSentWhenOptedIn() {
        defaults.set(true, forKey: AppAnalytics.optInKey)
        Funnel.storeViewed()
        Funnel.purchaseStarted(productId: StoreManager.plusYearly)
        Funnel.purchaseCompleted(productId: StoreManager.plusMonthly)
        Funnel.purchaseCompleted(productId: "com.handstrudel.pack.studio") // not sold: ignored
        Funnel.restoreTapped()
        Funnel.notificationOpened(pushType: "take_reply")
        Funnel.notificationOpened(pushType: "something_new")
        Funnel.playThisSoundTapped()
        XCTAssertEqual(hits, [
            .init(event: .storeViewed),
            .init(event: .purchaseStarted, detail: "plus_yearly"),
            .init(event: .purchaseCompleted, detail: "plus_monthly"),
            .init(event: .restoreTapped),
            .init(event: .notificationOpened, detail: "take_reply"),
            .init(event: .notificationOpened, detail: "other"),
            .init(event: .playThisSoundTapped),
        ])
    }

    func testFirstPostCountsOnceAndInvitedFirstPostNeedsARedeemedCode() {
        defaults.set(true, forKey: AppAnalytics.optInKey)
        Funnel.postPublished()
        Funnel.postPublished()
        XCTAssertEqual(hits, [.init(event: .firstPostPublished)])

        // A fresh install that redeemed an invite.
        let other = "funnel-invited-\(UUID().uuidString)"
        let invited = UserDefaults(suiteName: other)!
        defer { invited.removePersistentDomain(forName: other) }
        invited.set(true, forKey: AppAnalytics.optInKey)
        hits = []
        Funnel.analytics = AppAnalytics(defaults: invited, hits: { [unowned self] in self.hits.append($0) })
        Funnel.inviteCodeRedeemed()
        Funnel.postPublished()
        Funnel.postPublished()
        XCTAssertEqual(hits, [.init(event: .inviteCodeRedeemed), .init(event: .firstPostPublished),
                              .init(event: .invitedFirstPost)])
    }

    func testAPostWhileOptedOutIsStillTheFirstPost() {
        Funnel.postPublished()
        defaults.set(true, forKey: AppAnalytics.optInKey)
        Funnel.postPublished()
        XCTAssertEqual(hits, [], "Opting in later must not count a second post as the first")
    }

    func testEventRequestNamesTheEventAndOnlyAddsADetailWhenThereIsOne() throws {
        let base = URL(string: "http://127.0.0.1:54321")!
        let plain = AppAnalytics.request(for: .init(event: .storeViewed), baseURL: base, anonKey: "anon")
        XCTAssertEqual(plain.url?.absoluteString, "http://127.0.0.1:54321/rest/v1/rpc/record_app_usage_event")
        XCTAssertEqual(plain.httpMethod, "POST")
        XCTAssertEqual(plain.value(forHTTPHeaderField: "apikey"), "anon")
        let plainBody = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(plain.httpBody)) as? [String: String])
        XCTAssertEqual(plainBody, ["p_event": "store_viewed"])

        let detailed = AppAnalytics.request(for: .init(event: .purchaseCompleted, detail: "pro"), baseURL: base, anonKey: "anon")
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(detailed.httpBody)) as? [String: String])
        XCTAssertEqual(body, ["p_event": "purchase_completed", "p_detail": "pro"])
    }
}

/// MetricKit diagnostics: capping, request building, opt-in and retry, with a mock network.
final class CrashDiagnosticsTests: XCTestCase {
    private let env = DiagnosticsUploader.Environment(
        baseURL: URL(string: "http://127.0.0.1:54321")!, anonKey: "anon-key",
        appVersion: "1.0.2", build: "18", osVersion: "Version 26.1 (Build 23B85)", deviceModel: "iPhone18,1")

    private final class Box: @unchecked Sendable {
        var requests: [URLRequest] = []
        var status = 201
        var fail = false
        var optedIn = true
    }

    private func makeUploader(_ box: Box, pending: URL?) -> DiagnosticsUploader {
        let env = env
        return DiagnosticsUploader(environment: { env }, isOptedIn: { box.optedIn }, pendingURL: pending) { request in
            box.requests.append(request)
            if box.fail { throw URLError(.notConnectedToInternet) }
            return (Data(), HTTPURLResponse(url: request.url!, statusCode: box.status, httpVersion: nil, headerFields: nil)! as URLResponse)
        }
    }

    private func pendingFile() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("diag-\(UUID().uuidString).json")
    }

    private func rows(_ request: URLRequest) throws -> [[String: Any]] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as? [[String: Any]])
    }

    func testRowUsesTheCrashedBuildsMetadataAndDropsRegion() throws {
        let row = try XCTUnwrap(DiagnosticsUploader.row(for: .sampleCrash, env: env))
        XCTAssertEqual(row["kind"] as? String, "crash")
        XCTAssertEqual(row["app_version"] as? String, "1.0.2")
        XCTAssertEqual(row["build"] as? String, "17", "the build that crashed, not the one uploading")
        XCTAssertEqual(row["os_version"] as? String, "iPhone OS 26.1 (23B85)")
        XCTAssertEqual(row["device_model"] as? String, "iPhone17,1")
        XCTAssertEqual(row["truncated"] as? Bool, false)
        XCTAssertEqual(row["summary"] as? String,
                       "exceptionType=1 exceptionCode=0 signal=11 terminationReason=Namespace SIGNAL, Code 11 Segmentation fault: 11")
        let meta = try XCTUnwrap((row["payload"] as? [String: Any])?["diagnosticMetaData"] as? [String: Any])
        XCTAssertNil(meta["regionFormat"])
        XCTAssertEqual(meta["signal"] as? Int, 11)
    }

    func testOversizedPayloadKeepsTheCrashingThreadThenTrimsDepthThenDropsTheStack() throws {
        func frame(_ depth: Int) -> [String: Any] {
            var f: [String: Any] = ["binaryName": "HandStrudel", "binaryUUID": UUID().uuidString,
                                    "offsetIntoBinaryTextSegment": depth, "address": 4_295_000_000 + depth, "sampleCount": 1]
            if depth < 200 { f["subFrames"] = [frame(depth + 1)] }
            return f
        }
        let otherThreads = (0..<40).map { _ in ["threadAttributed": false, "callStackRootFrames": [frame(150)]] as [String: Any] }
        let big: [String: Any] = [
            "diagnosticMetaData": ["appVersion": "1.0.2", "regionFormat": "US", "signal": 6],
            "callStackTree": ["callStacks": [["threadAttributed": true, "callStackRootFrames": [frame(0)]]] + otherThreads],
        ]
        XCTAssertGreaterThan(DiagnosticsUploader.size(big), DiagnosticsUploader.maxPayloadBytes)

        let (capped, truncated) = DiagnosticsUploader.cap(big, limit: DiagnosticsUploader.maxPayloadBytes)
        XCTAssertTrue(truncated)
        XCTAssertLessThanOrEqual(DiagnosticsUploader.size(capped), DiagnosticsUploader.maxPayloadBytes)
        let stacks = try XCTUnwrap((capped["callStackTree"] as? [String: Any])?["callStacks"] as? [[String: Any]])
        XCTAssertEqual(stacks.count, 1)
        XCTAssertEqual(stacks.first?["threadAttributed"] as? Bool, true)
        XCTAssertNil((capped["diagnosticMetaData"] as? [String: Any])?["regionFormat"])

        let (tiny, tinyTruncated) = DiagnosticsUploader.cap(big, limit: 200)
        XCTAssertTrue(tinyTruncated)
        XCTAssertNil(tiny["callStackTree"])
        XCTAssertEqual((tiny["diagnosticMetaData"] as? [String: Any])?["signal"] as? Int, 6)

        let (small, smallTruncated) = DiagnosticsUploader.cap(["diagnosticMetaData": ["signal": 6]], limit: 1000)
        XCTAssertFalse(smallTruncated)
        XCTAssertEqual(DiagnosticsUploader.size(small), DiagnosticsUploader.size(["diagnosticMetaData": ["signal": 6]]))
    }

    func testUploadRequestIsAMinimalInsertIntoAppDiagnostics() async throws {
        let box = Box()
        let uploader = makeUploader(box, pending: pendingFile())
        await uploader.receive([.sampleCrash, .sampleHang])
        XCTAssertEqual(box.requests.count, 1, "one batched insert")
        let request = try XCTUnwrap(box.requests.first)
        XCTAssertEqual(request.url?.absoluteString, "http://127.0.0.1:54321/rest/v1/app_diagnostics")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "apikey"), "anon-key")
        XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"), "no account is attached")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Prefer"), "return=minimal")
        let sent = try rows(request)
        XCTAssertEqual(sent.map { $0["kind"] as? String }, ["crash", "hang"])
        XCTAssertEqual(Set(sent[0].keys), ["kind", "platform", "app_version", "build", "os_version",
                                           "device_model", "truncated", "payload", "summary"])
        XCTAssertEqual(sent[1]["summary"] as? String, "hangDuration=2.4 sec")
    }

    func testNothingIsSentWhenOptedOut() async {
        let box = Box()
        box.optedIn = false
        let uploader = makeUploader(box, pending: pendingFile())
        await uploader.receive([.sampleCrash])
        await uploader.flushPending()
        XCTAssertEqual(box.requests.count, 0)
        let pending = await uploader.pendingCount()
        XCTAssertEqual(pending, 0, "nothing is kept for later either")
    }

    func testFailedUploadIsRetriedOnNextLaunchAndDroppedIfOptedOut() async throws {
        let file = pendingFile()
        defer { try? FileManager.default.removeItem(at: file) }
        let box = Box()
        box.fail = true
        let uploader = makeUploader(box, pending: file)
        await uploader.receive([.sampleCrash])
        var pending = await uploader.pendingCount()
        XCTAssertEqual(pending, 1)

        box.fail = false
        box.status = 503
        await uploader.flushPending()
        pending = await uploader.pendingCount()
        XCTAssertEqual(pending, 1, "server errors keep the row")

        box.status = 201
        let relaunched = makeUploader(box, pending: file)
        await relaunched.flushPending()
        XCTAssertEqual(try rows(XCTUnwrap(box.requests.last)).count, 1)
        pending = await relaunched.pendingCount()
        XCTAssertEqual(pending, 0)

        box.fail = true
        await relaunched.receive([.sampleHang])
        box.optedIn = false
        let before = box.requests.count
        await relaunched.flushPending()
        XCTAssertEqual(box.requests.count, before)
        pending = await relaunched.pendingCount()
        XCTAssertEqual(pending, 0, "turning analytics off discards waiting reports")
    }
}
