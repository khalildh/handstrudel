import XCTest
@testable import HandStrudel

/// Remote config (`shared/remote-config/`, `docs/remote-updates.md`): shared
/// fixtures, defaults, caching, throttling and the update prompt.
@MainActor
final class RemoteConfigTests: XCTestCase {
    static let sharedFolder = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()      // HandStrudelTests
        .deletingLastPathComponent()      // HandStrudel (project)
        .deletingLastPathComponent()      // ios
        .deletingLastPathComponent()      // repo root
        .appendingPathComponent("shared")

    private var cacheURL: URL!

    override func setUp() async throws {
        cacheURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("RemoteConfigTests-\(UUID().uuidString)")
            .appendingPathComponent("remote-config.json")
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: cacheURL.deletingLastPathComponent())
    }

    private func json(_ path: String) throws -> Any {
        try JSONSerialization.jsonObject(with: Data(contentsOf: Self.sharedFolder.appendingPathComponent(path)), options: .fragmentsAllowed)
    }

    private func decode<T: Decodable>(_ type: T.Type, _ object: Any) throws -> T {
        try JSONDecoder().decode(T.self, from: JSONSerialization.data(withJSONObject: object, options: .fragmentsAllowed))
    }

    private func makeConfig(version: String = "1.0.3", install: String = "2F6C9A7E-1B4D-4C11-9E0A-5D2B7C3E8F10",
                            clock: @escaping () -> Date = Date.init,
                            fetch: @escaping (String) async throws -> Data) -> RemoteConfig {
        RemoteConfig(appVersion: version, installID: install, cacheURL: cacheURL, fetcher: RemoteFetcher(fetch: fetch), now: clock)
    }

    private static func rows(_ rows: [[String: Any]]) -> Data {
        try! JSONSerialization.data(withJSONObject: rows.enumerated().map { index, row in
            ["id": index + 1, "rollout_percent": 100, "priority": 0].merging(row) { $1 }
        })
    }

    // MARK: Shared fixtures

    func testDefaultsMatchSharedKeys() throws {
        let file = try XCTUnwrap(json("remote-config/keys.json") as? [String: Any])
        let keys = try XCTUnwrap(file["keys"] as? [String: [String: Any]])
        XCTAssertEqual(Set(keys.keys), Set(RemoteConfigKeys.definitions.keys))
        for (key, definition) in keys {
            let expected = try decode(JSONValue.self, definition["default"] ?? NSNull())
            XCTAssertEqual(RemoteConfigKeys.defaults[key], expected, key)
            let kind = try XCTUnwrap(RemoteConfigKeys.definitions[key]?.kind, key)
            switch definition["type"] as? String {
            case "bool": XCTAssertEqual(kind, .bool, key)
            case "number": XCTAssertEqual(kind, .number(min: definition["min"] as! Double, max: definition["max"] as! Double), key)
            case "string": XCTAssertEqual(kind, .string(maxLength: definition["max_length"] as? Int), key)
            case "string_array":
                XCTAssertEqual(kind, .stringArray(maxItems: definition["max_items"] as! Int, maxLength: definition["max_length"] as! Int), key)
            case "version": XCTAssertEqual(kind, .version, key)
            case let other: XCTFail("\(key): unknown type \(String(describing: other))")
            }
        }
    }

    func testVersionFixtures() throws {
        let file = try XCTUnwrap(json("remote-config/fixtures/versions.json") as? [String: Any])
        for item in try XCTUnwrap(file["parse"] as? [[String: Any]]) {
            let input = try XCTUnwrap(item["input"] as? String)
            XCTAssertEqual(AppVersion(input)?.parts, item["parts"] as? [Int], input)
        }
        for item in try XCTUnwrap(file["compare"] as? [[String: Any]]) {
            let a = try XCTUnwrap(AppVersion(item["a"] as! String)), b = try XCTUnwrap(AppVersion(item["b"] as! String))
            let result = a < b ? -1 : (a == b ? 0 : 1)
            XCTAssertEqual(result, item["result"] as? Int, "\(a.parts) vs \(b.parts)")
        }
    }

    func testBucketFixtures() throws {
        let file = try XCTUnwrap(json("remote-config/fixtures/buckets.json") as? [String: Any])
        let cases = try XCTUnwrap(file["cases"] as? [[String: Any]])
        XCTAssertGreaterThanOrEqual(cases.count, 15)
        for item in cases {
            let key = item["key"] as! String, install = item["install_id"] as! String
            XCTAssertEqual(RemoteRollout.bucket(key: key, installID: install), item["bucket"] as? Int, "\(key) \(install)")
        }
    }

    func testResolveFixtures() throws {
        let file = try XCTUnwrap(json("remote-config/fixtures/resolve.json") as? [String: Any])
        for item in try XCTUnwrap(file["cases"] as? [[String: Any]]) {
            let name = item["name"] as! String
            let rows = try decode([RemoteConfigRow].self, item["rows"] as Any)
            let values = RemoteConfigKeys.resolve(rows: rows, installID: item["install_id"] as! String)
            XCTAssertNil(values["unknown.key"], name)
            for (key, expected) in try XCTUnwrap(item["expect"] as? [String: Any]) {
                XCTAssertEqual(values[key], try decode(JSONValue.self, expected), "\(name): \(key)")
            }
        }
    }

    // MARK: Defaults, fetching and caching

    func testDefaultsWithoutCacheOrNetworkMatchTodaysBehaviour() async {
        let config = makeConfig { _ in throw URLError(.notConnectedToInternet) }
        await config.refresh()
        XCTAssertTrue(config.feedEnabled)
        XCTAssertEqual(config.feedPageSize, 10)
        XCTAssertEqual(config.proTitle, "HandStrudel Pro")
        XCTAssertEqual(config.proFeatures, ["120+ instruments", "Every scale — modes, harmonic minor, exotic",
                                            "Every chord progression", "One-time purchase"])
        XCTAssertNil(config.proNote)
        XCTAssertEqual(config.updateRequirement, .none)
        XCTAssertTrue(config.remoteInstrumentsEnabled)
        XCTAssertEqual(config.appStoreURL, URL(string: "https://apps.apple.com/app/id6764415289"))
        XCTAssertNil(config.lastSuccess)
        XCTAssertFalse(FileManager.default.fileExists(atPath: cacheURL.path))
    }

    func testFetchAppliesValuesAndCachesThem() async {
        let config = makeConfig { version in
            XCTAssertEqual(version, "1.0.3")
            return Self.rows([["key": "feed.enabled", "value": false], ["key": "store.pro_note", "value": " Holiday sale "]])
        }
        await config.refresh()
        XCTAssertFalse(config.feedEnabled)
        XCTAssertEqual(config.proNote, "Holiday sale")

        // Next launch, offline: the last good copy applies before any fetch.
        let offline = makeConfig { _ in throw URLError(.timedOut) }
        XCTAssertFalse(offline.feedEnabled)
        await offline.refresh()
        XCTAssertFalse(offline.feedEnabled, "a failed fetch keeps the cached copy")
        XCTAssertEqual(offline.proNote, "Holiday sale")
    }

    /// `feed.page_size` is read once at launch from the copy the previous launch cached.
    func testLaunchValuesComeFromThePreviousLaunchsCache() async {
        XCTAssertEqual(RemoteConfig.values(cachedAt: cacheURL, appVersion: "1.0.3", installID: "x")[RemoteConfigKeys.feedPageSize],
                       .number(10), "first launch: default")
        let config = makeConfig { _ in Self.rows([["key": "feed.page_size", "value": 15]]) }
        await config.refresh()
        XCTAssertEqual(config.feedPageSize, 15)
        XCTAssertEqual(RemoteConfig.values(cachedAt: cacheURL, appVersion: "1.0.3", installID: "x")[RemoteConfigKeys.feedPageSize],
                       .number(15), "next launch: the fetched value")
        XCTAssertEqual(RemoteConfig.values(cachedAt: cacheURL, appVersion: "1.0.4", installID: "x")[RemoteConfigKeys.feedPageSize],
                       .number(10), "after an app update: default until the next fetch")
    }

    func testMalformedResponseKeepsTheLastGoodCopy() async {
        var response = Self.rows([["key": "feed.enabled", "value": false]])
        let config = makeConfig { _ in response }
        await config.refresh()
        response = Data("{\"message\":\"oops\"}".utf8)
        await config.refresh()
        XCTAssertFalse(config.feedEnabled)
    }

    func testAnEmptySnapshotRollsBackToDefaults() async {
        var response = Self.rows([["key": "feed.enabled", "value": false]])
        let config = makeConfig { _ in response }
        await config.refresh()
        XCTAssertFalse(config.feedEnabled)
        response = Self.rows([])
        await config.refresh()
        XCTAssertTrue(config.feedEnabled, "a deleted or disabled row falls back to the default")
    }

    func testCacheIsDroppedWhenTheAppVersionChanges() async {
        let old = makeConfig(version: "1.0.2") { _ in Self.rows([["key": "feed.enabled", "value": false]]) }
        await old.refresh()
        let updated = makeConfig(version: "1.0.3") { _ in throw URLError(.timedOut) }
        XCTAssertTrue(updated.feedEnabled)
    }

    func testFetchesAreThrottledToOnceEvery15Minutes() async {
        var now = Date(timeIntervalSince1970: 1_000_000)
        var fetches = 0
        let config = makeConfig(clock: { now }) { _ in fetches += 1; return Self.rows([]) }
        await config.refreshIfNeeded()
        await config.refreshIfNeeded()
        XCTAssertEqual(fetches, 1)
        now += 14 * 60
        await config.refreshIfNeeded()
        XCTAssertEqual(fetches, 1)
        now += 2 * 60
        await config.refreshIfNeeded()
        XCTAssertEqual(fetches, 2)
    }

    func testFailedFetchesAreThrottledToo() async {
        var fetches = 0
        let config = makeConfig { _ in fetches += 1; throw URLError(.timedOut) }
        await config.refreshIfNeeded()
        await config.refreshIfNeeded()
        XCTAssertEqual(fetches, 1)
    }

    func testWronglyTypedValuesKeepTheDefault() async {
        let config = makeConfig { _ in
            Self.rows([["key": "feed.enabled", "value": "false"], ["key": "feed.page_size", "value": 3],
                       ["key": "store.pro_features", "value": "one"]])
        }
        await config.refresh()
        XCTAssertTrue(config.feedEnabled)
        XCTAssertEqual(config.feedPageSize, 5, "numbers are clamped")
        XCTAssertEqual(config.proFeatures.count, 4)
    }

    // MARK: Rollout

    func testRaisingARolloutOnlyAddsInstalls() {
        let installs = (0..<500).map { _ in UUID().uuidString }
        var previous = Set<String>()
        for percent in [0, 5, 25, 50, 100] {
            let included = Set(installs.filter { RemoteRollout.includes(key: "feed.enabled", installID: $0, percent: percent) })
            XCTAssertTrue(previous.isSubset(of: included), "\(percent)%")
            previous = included
        }
        XCTAssertEqual(previous.count, 500)
        let tenPercent = installs.filter { RemoteRollout.includes(key: "feed.page_size", installID: $0, percent: 10) }.count
        XCTAssertTrue((20...80).contains(tenPercent), "roughly 10% of 500, got \(tenPercent)")
    }

    func testInstallIDIsRandomAndStable() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "RemoteConfigTests-\(UUID().uuidString)"))
        let first = RemoteInstall.id(defaults: defaults)
        XCTAssertNotNil(UUID(uuidString: first))
        XCTAssertEqual(RemoteInstall.id(defaults: defaults), first)
    }

    // MARK: Update prompt

    func testUpdateRequirement() {
        XCTAssertEqual(UpdateRequirement(current: "1.0.1", minimum: "1.0.2", recommended: "1.0.3"), .required(version: "1.0.2"))
        XCTAssertEqual(UpdateRequirement(current: "1.0.2", minimum: "1.0.2", recommended: "1.0.3"), .recommended(version: "1.0.3"))
        XCTAssertEqual(UpdateRequirement(current: "1.0.3", minimum: "1.0.2", recommended: "1.0.3"), .none)
        XCTAssertEqual(UpdateRequirement(current: "1.0.10", minimum: "1.0.9", recommended: nil), .none)
        XCTAssertEqual(UpdateRequirement(current: "1.0.3", minimum: nil, recommended: nil), .none)
        XCTAssertEqual(UpdateRequirement(current: "1.0.3", minimum: "garbage", recommended: "2"), .recommended(version: "2"))
        XCTAssertEqual(UpdateRequirement(current: "dev", minimum: "9.9.9", recommended: nil), .none,
                       "an unparseable build version is never blocked")
    }

    func testConfigDrivesTheUpdatePrompt() async {
        var response = Self.rows([["key": "update.recommended_version", "value": "1.0.4"],
                                  ["key": "update.message", "value": "New sounds inside."]])
        let config = makeConfig { _ in response }
        await config.refresh()
        XCTAssertEqual(config.updateRequirement, .recommended(version: "1.0.4"))
        XCTAssertEqual(config.updateMessage, "New sounds inside.")

        response = Self.rows([["key": "update.minimum_version", "value": "1.0.4"],
                              ["key": "update.app_store_url", "value": "https://apps.apple.com/us/app/handstrudel/id6764415289"]])
        await config.refresh()
        XCTAssertEqual(config.updateRequirement, .required(version: "1.0.4"))
        XCTAssertEqual(config.appStoreURL.host, "apps.apple.com")
    }
}
