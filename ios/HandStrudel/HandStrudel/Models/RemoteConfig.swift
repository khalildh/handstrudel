import CryptoKit
import Foundation

/// Server-driven config and feature flags (`docs/remote-updates.md`).
///
/// The app ships with a default for every key (`shared/remote-config/keys.json`)
/// equal to its behaviour without config, so first launch, offline use and a
/// dead backend all work. At launch it reads the last good copy from disk, then
/// fetches `app_config_for(platform, version)` in the background — never
/// blocking UI — and again on foreground at most every 15 minutes.
///
/// Values are plain JSON that pick between behaviours already in the binary.
/// Nothing fetched here is ever executed (App Store Review Guideline 2.5.2).
@MainActor
final class RemoteConfig: ObservableObject {
    static let shared = RemoteConfig()

    nonisolated static let platform = "ios"
    nonisolated static let minimumFetchInterval: TimeInterval = 15 * 60

    /// The resolved value for each known key (defaults overlaid with server rows).
    @Published private(set) var values: [String: JSONValue]
    private(set) var lastFetchAttempt: Date?
    private(set) var lastSuccess: Date?

    let appVersion: String
    let installID: String
    private let cacheURL: URL?
    private let fetcher: RemoteFetcher
    private let now: () -> Date
    private var inFlight: Task<Void, Never>?

    init(appVersion: String = RemoteConfig.bundleVersion,
         installID: String = RemoteInstall.id(),
         cacheURL: URL? = RemoteCache.url("remote-config.json"),
         fetcher: RemoteFetcher = .configRows,
         now: @escaping () -> Date = Date.init) {
        self.appVersion = appVersion
        self.installID = installID
        self.cacheURL = cacheURL
        self.fetcher = fetcher
        self.now = now
        values = RemoteConfigKeys.defaults
        if let cached = Self.readCache(cacheURL, appVersion: appVersion) {
            values = RemoteConfigKeys.resolve(rows: cached.rows, installID: installID)
            lastSuccess = cached.fetchedAt
        }
    }

    // MARK: Fetching

    /// Fetch unless one ran in the last 15 minutes (or one is running).
    func refreshIfNeeded() async {
        if let lastFetchAttempt, now().timeIntervalSince(lastFetchAttempt) < Self.minimumFetchInterval { return }
        await refresh()
    }

    func refresh() async {
        if let inFlight { return await inFlight.value }
        lastFetchAttempt = now()
        let task = Task { @MainActor in
            defer { inFlight = nil }
            guard let data = try? await fetcher.fetch(appVersion),
                  let rows = try? JSONDecoder().decode([RemoteConfigRow].self, from: data) else { return }
            apply(rows: rows)
        }
        inFlight = task
        await task.value
    }

    /// Replace the whole snapshot (a missing row means "back to default") and cache it.
    func apply(rows: [RemoteConfigRow]) {
        let resolved = RemoteConfigKeys.resolve(rows: rows, installID: installID)
        if resolved != values { values = resolved }
        lastSuccess = now()
        Self.writeCache(cacheURL, Snapshot(appVersion: appVersion, fetchedAt: now(), rows: rows))
    }

    // MARK: Typed accessors

    var feedEnabled: Bool { bool(RemoteConfigKeys.feedEnabled) }
    var feedPageSize: Int { Int(number(RemoteConfigKeys.feedPageSize)) }
    var proTitle: String { string(RemoteConfigKeys.proTitle) }
    var proFeatures: [String] { strings(RemoteConfigKeys.proFeatures) }
    var proNote: String? { string(RemoteConfigKeys.proNote).nilIfEmpty }
    var minimumVersion: String? { values[RemoteConfigKeys.minimumVersion]?.stringValue }
    var recommendedVersion: String? { values[RemoteConfigKeys.recommendedVersion]?.stringValue }
    var updateMessage: String? { string(RemoteConfigKeys.updateMessage).nilIfEmpty }
    var appStoreURL: URL { URL(string: string(RemoteConfigKeys.appStoreURL)) ?? RemoteConfigKeys.defaultAppStoreURL }
    var remoteInstrumentsEnabled: Bool { bool(RemoteConfigKeys.remoteInstruments) }

    /// "Make an instrument" (AI). Off by default; DEBUG builds can force it on
    /// with the `--force-ai-instruments` launch argument or the
    /// `forceAIInstruments` user default (the Debug menu toggle).
    var aiInstrumentsEnabled: Bool {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--force-ai-instruments")
            || UserDefaults.standard.bool(forKey: "forceAIInstruments") { return true }
        #endif
        return bool(RemoteConfigKeys.aiInstruments)
    }

    var updateRequirement: UpdateRequirement {
        UpdateRequirement(current: appVersion, minimum: minimumVersion, recommended: recommendedVersion)
    }

    func bool(_ key: String) -> Bool {
        values[key]?.boolValue ?? RemoteConfigKeys.defaults[key]?.boolValue ?? false
    }

    func number(_ key: String) -> Double {
        values[key]?.numberValue ?? RemoteConfigKeys.defaults[key]?.numberValue ?? 0
    }

    func string(_ key: String) -> String {
        values[key]?.stringValue ?? RemoteConfigKeys.defaults[key]?.stringValue ?? ""
    }

    func strings(_ key: String) -> [String] {
        values[key]?.stringArray ?? RemoteConfigKeys.defaults[key]?.stringArray ?? []
    }

    // MARK: Cache

    struct Snapshot: Codable, Sendable {
        var appVersion: String
        var fetchedAt: Date
        var rows: [RemoteConfigRow]
    }

    /// The last good snapshot, unless it was fetched for another app version
    /// (the server filtered it by version).
    nonisolated static func readCache(_ url: URL?, appVersion: String) -> Snapshot? {
        guard let url, let data = try? Data(contentsOf: url),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data),
              snapshot.appVersion == appVersion else { return nil }
        return snapshot
    }

    nonisolated static func writeCache(_ url: URL?, _ snapshot: Snapshot) {
        guard let url, let data = try? JSONEncoder().encode(snapshot) else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }

    /// Values from the last good copy on disk at launch, for settings that
    /// must stay fixed for the whole session (and be read off the main actor).
    nonisolated static let launchValues: [String: JSONValue] = {
        guard let snapshot = readCache(RemoteCache.url("remote-config.json"), appVersion: bundleVersion) else {
            return RemoteConfigKeys.defaults
        }
        return RemoteConfigKeys.resolve(rows: snapshot.rows, installID: RemoteInstall.id())
    }()

    /// `feed.page_size` as of launch.
    nonisolated static var launchFeedPageSize: Int {
        Int(launchValues[RemoteConfigKeys.feedPageSize]?.numberValue ?? 10)
    }

    nonisolated static var bundleVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }
}

// MARK: - Keys, defaults and resolution

/// One row from `app_config_for()`: already filtered by platform and version.
struct RemoteConfigRow: Codable, Equatable, Sendable {
    var id: Int
    var key: String
    var value: JSONValue
    var rolloutPercent: Int
    var priority: Int

    enum CodingKeys: String, CodingKey {
        case id, key, value, rolloutPercent = "rollout_percent", priority
    }
}

/// The keys this build reads, mirroring `shared/remote-config/keys.json`.
enum RemoteConfigKeys {
    static let feedEnabled = "feed.enabled"
    static let feedPageSize = "feed.page_size"
    static let proTitle = "store.pro_title"
    static let proFeatures = "store.pro_features"
    static let proNote = "store.pro_note"
    static let minimumVersion = "update.minimum_version"
    static let recommendedVersion = "update.recommended_version"
    static let updateMessage = "update.message"
    static let appStoreURL = "update.app_store_url"
    static let remoteInstruments = "instruments.remote_enabled"
    static let aiInstruments = "ai_instruments.enabled"
    static let aiDailyLimitFree = "ai_instruments.daily_limit_free"
    static let aiDailyLimitPro = "ai_instruments.daily_limit_pro"
    static let aiDailyLimitPlus = "ai_instruments.daily_limit_plus"

    static let defaultAppStoreURL = URL(string: "https://apps.apple.com/app/id6764415289")!

    enum Kind: Equatable {
        case bool
        case number(min: Double, max: Double)
        case string(maxLength: Int?)
        case stringArray(maxItems: Int, maxLength: Int)
        case version
    }

    struct Definition {
        let kind: Kind
        let defaultValue: JSONValue
    }

    static let definitions: [String: Definition] = [
        feedEnabled: .init(kind: .bool, defaultValue: .bool(true)),
        feedPageSize: .init(kind: .number(min: 5, max: 30), defaultValue: .number(10)),
        proTitle: .init(kind: .string(maxLength: 40), defaultValue: .string("HandStrudel Pro")),
        proFeatures: .init(kind: .stringArray(maxItems: 6, maxLength: 80), defaultValue: .array([
            .string("120+ instruments"),
            .string("Every scale — modes, harmonic minor, exotic"),
            .string("Every chord progression"),
            .string("One-time purchase"),
        ])),
        proNote: .init(kind: .string(maxLength: 80), defaultValue: .string("")),
        minimumVersion: .init(kind: .version, defaultValue: .null),
        recommendedVersion: .init(kind: .version, defaultValue: .null),
        updateMessage: .init(kind: .string(maxLength: 200), defaultValue: .string("")),
        appStoreURL: .init(kind: .string(maxLength: nil), defaultValue: .string(defaultAppStoreURL.absoluteString)),
        remoteInstruments: .init(kind: .bool, defaultValue: .bool(true)),
        aiInstruments: .init(kind: .bool, defaultValue: .bool(false)),
        // Read by the generate-instrument function; listed so the app knows every key.
        aiDailyLimitFree: .init(kind: .number(min: 0, max: 1000), defaultValue: .number(5)),
        aiDailyLimitPro: .init(kind: .number(min: 0, max: 1000), defaultValue: .number(25)),
        aiDailyLimitPlus: .init(kind: .number(min: 0, max: 1000), defaultValue: .number(50)),
    ]

    static let defaults: [String: JSONValue] = definitions.mapValues(\.defaultValue)

    /// Per key: rows by priority, then newest; skip wrong types and rollouts
    /// that exclude this install; first one left wins, else the default.
    /// (`shared/remote-config/fixtures/resolve.json`.)
    static func resolve(rows: [RemoteConfigRow], installID: String) -> [String: JSONValue] {
        var values = defaults
        let byKey = Dictionary(grouping: rows, by: \.key)
        for (key, candidates) in byKey {
            guard let definition = definitions[key] else { continue }
            let ordered = candidates.sorted { ($0.priority, $0.id) > ($1.priority, $1.id) }
            for row in ordered {
                guard RemoteRollout.includes(key: key, installID: installID, percent: row.rolloutPercent),
                      let value = normalize(row.value, key: key, kind: definition.kind) else { continue }
                values[key] = value
                break
            }
        }
        return values
    }

    /// The value made valid for its key, or nil when it has the wrong type.
    static func normalize(_ value: JSONValue, key: String, kind: Kind) -> JSONValue? {
        switch (kind, value) {
        case (.bool, .bool):
            return value
        case (.number(let lower, let upper), .number(let number)) where number.isFinite:
            return .number(min(upper, max(lower, number.rounded())))
        case (.string(let limit), .string(let text)):
            if key == appStoreURL, !text.hasPrefix("https://apps.apple.com/") { return nil }
            return .string(limit.map { String(text.prefix($0)) } ?? text)
        case (.stringArray(let maxItems, let maxLength), .array(let items)):
            let strings = items.compactMap(\.stringValue)
            guard strings.count == items.count else { return nil }
            return .array(strings.prefix(maxItems).map { .string(String($0.prefix(maxLength))) })
        case (.version, .string(let text)) where AppVersion(text) != nil:
            return value
        case (.version, .null):
            return value
        default:
            return nil
        }
    }
}

// MARK: - Versions and rollout

/// `major.minor.patch`, up to three numeric parts, missing parts 0
/// (`shared/remote-config/fixtures/versions.json`).
struct AppVersion: Comparable, Equatable {
    let parts: [Int]

    init?(_ text: String) {
        let pieces = text.split(separator: ".", omittingEmptySubsequences: false)
        guard (1...3).contains(pieces.count) else { return nil }
        var parts: [Int] = []
        for piece in pieces {
            guard (1...6).contains(piece.count), piece.allSatisfy({ $0.isASCII && $0.isNumber }), let number = Int(piece) else { return nil }
            parts.append(number)
        }
        self.parts = parts + Array(repeating: 0, count: 3 - parts.count)
    }

    static func < (lhs: AppVersion, rhs: AppVersion) -> Bool { lhs.parts.lexicographicallyPrecedes(rhs.parts) }
}

enum UpdateRequirement: Equatable {
    case none
    /// A newer version is recommended: dismissible banner.
    case recommended(version: String)
    /// This version is no longer supported: blocking screen.
    case required(version: String)

    init(current: String, minimum: String?, recommended: String?) {
        guard let currentVersion = AppVersion(current) else { self = .none; return }
        if let minimum, let version = AppVersion(minimum), currentVersion < version {
            self = .required(version: minimum)
        } else if let recommended, let version = AppVersion(recommended), currentVersion < version {
            self = .recommended(version: recommended)
        } else {
            self = .none
        }
    }
}

/// Percentage rollouts bucketed by a per-install random id. The id stays on
/// the device: the server never sees it.
enum RemoteRollout {
    /// uint32 of the first 4 bytes of SHA-256("<key>:<install id>") mod 100.
    static func bucket(key: String, installID: String) -> Int {
        let digest = SHA256.hash(data: Data("\(key):\(installID)".utf8))
        let word = digest.prefix(4).reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
        return Int(word % 100)
    }

    static func includes(key: String, installID: String, percent: Int) -> Bool {
        bucket(key: key, installID: installID) < percent
    }
}

/// A random id created on first launch. Not the IDFA or IDFV, not tied to an
/// account, never sent anywhere; reinstalling resets it.
enum RemoteInstall {
    static let defaultsKey = "remoteConfigInstallID"

    static func id(defaults: UserDefaults = .standard) -> String {
        if let existing = defaults.string(forKey: defaultsKey), !existing.isEmpty { return existing }
        let fresh = UUID().uuidString
        defaults.set(fresh, forKey: defaultsKey)
        return fresh
    }
}

// MARK: - Networking and cache locations

enum RemoteCache {
    static func url(_ name: String) -> URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("RemoteContent", isDirectory: true)
            .appendingPathComponent(name)
    }
}

/// Where remote rows come from: a Supabase RPC, or in DEBUG a local fixture.
struct RemoteFetcher {
    let fetch: (_ appVersion: String) async throws -> Data

    static let configRows = rpc("app_config_for", fixtureVariable: "HANDSTRUDEL_REMOTE_CONFIG_FIXTURE") { version in
        ["p_platform": RemoteConfig.platform, "p_app_version": version]
    }

    static let instrumentRows = rpc("instrument_catalog_for", fixtureVariable: "HANDSTRUDEL_INSTRUMENT_CATALOG_FIXTURE") { version in
        ["p_platform": RemoteConfig.platform, "p_app_version": version, "p_max_format_version": InstrumentSpec.formatVersion]
    }

    static func rpc(_ name: String, fixtureVariable: String, parameters: @escaping (String) -> [String: Any]) -> RemoteFetcher {
        RemoteFetcher { version in
            #if DEBUG
            if let fixture = ProcessInfo.processInfo.environment[fixtureVariable], !fixture.isEmpty {
                let trimmed = fixture.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("[") { return Data(trimmed.utf8) }
                return try Data(contentsOf: URL(fileURLWithPath: trimmed))
            }
            #endif
            guard SocialConfig.isConfigured else { throw URLError(.unsupportedURL) }
            var request = URLRequest(url: SocialConfig.supabaseURL.appendingPathComponent("rest/v1/rpc/\(name)"),
                                     cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(SocialConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(SocialConfig.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters(version))
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw URLError(.badServerResponse)
            }
            return data
        }
    }
}

// MARK: - JSON values

/// Any JSON value, for config values whose type depends on the key.
enum JSONValue: Codable, Equatable, Sendable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null }
        else if let value = try? container.decode(Bool.self) { self = .bool(value) }
        else if let value = try? container.decode(Double.self) { self = .number(value) }
        else if let value = try? container.decode(String.self) { self = .string(value) }
        else if let value = try? container.decode([JSONValue].self) { self = .array(value) }
        else { self = .object(try container.decode([String: JSONValue].self)) }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null: try container.encodeNil()
        case .bool(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        }
    }

    var boolValue: Bool? { if case .bool(let value) = self { return value }; return nil }
    var numberValue: Double? { if case .number(let value) = self { return value }; return nil }
    var stringValue: String? { if case .string(let value) = self { return value }; return nil }
    var stringArray: [String]? {
        guard case .array(let items) = self else { return nil }
        let strings = items.compactMap(\.stringValue)
        return strings.count == items.count ? strings : nil
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
