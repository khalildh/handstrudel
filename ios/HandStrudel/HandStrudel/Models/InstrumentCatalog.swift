import Foundation

/// Instrument files published after release (`public.instrument_catalog`),
/// merged with the bundled library. See `docs/remote-updates.md`.
///
/// Every downloaded file goes through `InstrumentSpec.load`, exactly like a
/// bundled one: rejected files are dropped and out-of-range values repaired.
/// Files in a newer format are skipped, the `builtin.` prefix is reserved, and
/// bundled files win on id collisions. Instruments are data the shipped
/// renderer draws; nothing downloaded is executed (Guideline 2.5.2).
@MainActor
final class InstrumentCatalog: ObservableObject {
    static let shared = InstrumentCatalog()

    /// Accepted downloaded instruments, in catalog order (bundled ids removed).
    @Published private(set) var remote: [InstrumentSpec] = []
    private(set) var lastFetchAttempt: Date?

    private let bundled: [InstrumentSpec]
    private let appVersion: String
    private let cacheURL: URL?
    private let fetcher: RemoteFetcher
    private let isEnabled: @MainActor () -> Bool
    private let now: () -> Date
    private var inFlight: Task<Void, Never>?

    init(bundled: [InstrumentSpec] = InstrumentLibrary.all,
         appVersion: String = RemoteConfig.bundleVersion,
         cacheURL: URL? = RemoteCache.url("instrument-catalog.json"),
         fetcher: RemoteFetcher = .instrumentRows,
         isEnabled: @escaping @MainActor () -> Bool = { @MainActor in RemoteConfig.shared.remoteInstrumentsEnabled },
         now: @escaping () -> Date = Date.init) {
        self.bundled = bundled
        self.appVersion = appVersion
        self.cacheURL = cacheURL
        self.fetcher = fetcher
        self.isEnabled = isEnabled
        self.now = now
        // Cached files are validated again: the rules may be newer than the cache.
        if let cached = Self.readCache(cacheURL, appVersion: appVersion) {
            remote = Self.accept(cached, bundledIDs: Set(bundled.map(\.id))).instruments
        }
    }

    /// Bundled instruments first, then downloaded ones (when switched on).
    var all: [InstrumentSpec] {
        isEnabled() ? Self.merge(bundled: bundled, remote: remote) : bundled
    }

    // MARK: Fetching

    func refreshIfNeeded() async {
        guard isEnabled() else { return }
        if let lastFetchAttempt, now().timeIntervalSince(lastFetchAttempt) < RemoteConfig.minimumFetchInterval { return }
        await refresh()
    }

    func refresh() async {
        if let inFlight { return await inFlight.value }
        lastFetchAttempt = now()
        let task = Task { @MainActor in
            defer { inFlight = nil }
            guard let data = try? await fetcher.fetch(appVersion),
                  let rows = try? JSONDecoder().decode([InstrumentCatalogRow].self, from: data) else { return }
            apply(rows: rows)
        }
        inFlight = task
        await task.value
    }

    /// Replace the downloaded set and cache the accepted files.
    @discardableResult
    func apply(rows: [InstrumentCatalogRow]) -> Acceptance {
        let result = Self.accept(rows, bundledIDs: Set(bundled.map(\.id)))
        #if DEBUG
        for skip in result.skipped { print("[InstrumentCatalog] skipped \(skip.id): \(skip.reason)") }
        #endif
        if result.instruments != remote { remote = result.instruments }
        Self.writeCache(cacheURL, CachedCatalog(appVersion: appVersion, fetchedAt: now(), rows: result.acceptedRows))
        return result
    }

    // MARK: Validation and merge

    enum SkipReason: Equatable {
        /// Needs a newer app (format version above `InstrumentSpec.formatVersion`).
        case newerFormat(Int)
        /// `InstrumentSpec.load` rejected it.
        case rejected([InstrumentIssue])
        /// Used the `builtin.` prefix, reserved for bundled files.
        case reservedID
        /// The file's id doesn't match the catalog row.
        case idMismatch
        /// A bundled instrument has this id; bundled files win.
        case bundledCollision
        /// An earlier catalog row had this id.
        case duplicate
    }

    struct Acceptance: Equatable {
        var instruments: [InstrumentSpec] = []
        var acceptedRows: [InstrumentCatalogRow] = []
        var skipped: [(id: String, reason: SkipReason)] = []

        static func == (lhs: Acceptance, rhs: Acceptance) -> Bool {
            lhs.instruments == rhs.instruments && lhs.acceptedRows == rhs.acceptedRows
                && lhs.skipped.map { $0.id } == rhs.skipped.map { $0.id } && lhs.skipped.map { $0.reason } == rhs.skipped.map { $0.reason }
        }
    }

    /// Check every catalog row the way bundled files are checked. Pure.
    static func accept(_ rows: [InstrumentCatalogRow], bundledIDs: Set<String>,
                       supportedFormat: Int = InstrumentSpec.formatVersion) -> Acceptance {
        var result = Acceptance()
        var seen = Set<String>()
        for row in rows {
            func skip(_ reason: SkipReason) { result.skipped.append((row.id, reason)) }
            if row.formatVersion > supportedFormat { skip(.newerFormat(row.formatVersion)); continue }
            let loaded = InstrumentSpec.load(Data(row.body.utf8))
            guard let spec = loaded.spec else { skip(.rejected(loaded.issues)); continue }
            if spec.isBuiltIn || row.id.hasPrefix("builtin.") { skip(.reservedID); continue }
            if spec.id != row.id { skip(.idMismatch); continue }
            if bundledIDs.contains(spec.id) { skip(.bundledCollision); continue }
            if !seen.insert(spec.id).inserted { skip(.duplicate); continue }
            result.instruments.append(spec)
            result.acceptedRows.append(row)
        }
        return result
    }

    /// Bundled instruments, then remote ones whose ids aren't bundled.
    static func merge(bundled: [InstrumentSpec], remote: [InstrumentSpec]) -> [InstrumentSpec] {
        let bundledIDs = Set(bundled.map(\.id))
        return bundled + remote.filter { !bundledIDs.contains($0.id) }
    }

    // MARK: Cache

    private struct CachedCatalog: Codable {
        var appVersion: String
        var fetchedAt: Date
        var rows: [InstrumentCatalogRow]
    }

    /// The last accepted files, unless they were fetched for another app version.
    static func readCache(_ url: URL?, appVersion: String) -> [InstrumentCatalogRow]? {
        guard let url, let data = try? Data(contentsOf: url),
              let cached = try? JSONDecoder().decode(CachedCatalog.self, from: data),
              cached.appVersion == appVersion else { return nil }
        return cached.rows
    }

    private static func writeCache(_ url: URL?, _ cached: CachedCatalog) {
        guard let url, let data = try? JSONEncoder().encode(cached) else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }
}

/// One row from `instrument_catalog_for()`: an instrument file and its metadata.
struct InstrumentCatalogRow: Codable, Equatable {
    var id: String
    var formatVersion: Int
    /// The instrument file, as JSON text.
    var body: String
    var sortOrder: Int?

    enum CodingKeys: String, CodingKey {
        case id, formatVersion = "format_version", body, sortOrder = "sort_order"
    }
}
