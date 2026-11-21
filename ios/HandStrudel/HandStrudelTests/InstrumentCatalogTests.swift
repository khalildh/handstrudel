import XCTest
@testable import HandStrudel

/// Downloadable instruments (`public.instrument_catalog`): validation with the
/// bundled loader, version skipping, merge order and caching.
@MainActor
final class InstrumentCatalogTests: XCTestCase {
    private var cacheURL: URL!

    override func setUp() async throws {
        cacheURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("InstrumentCatalogTests-\(UUID().uuidString)")
            .appendingPathComponent("instrument-catalog.json")
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: cacheURL.deletingLastPathComponent())
    }

    private static func body(id: String, name: String = "Remote Wheel", version: Int = 1, radius: Double = 1.0,
                             extra: [String: Any] = [:]) -> String {
        var file: [String: Any] = [
            "format": "handstrudel.instrument", "format_version": version, "id": id, "name": name,
            "surface": ["type": "split_wheel", "radius": radius, "rest_radius": 0.3, "octave_band_radius": 0.75],
            "chords": ["side": "right"],
            "notes": ["source": "scale_one_octave", "octave_band": true],
        ]
        file.merge(extra) { $1 }
        return String(decoding: try! JSONSerialization.data(withJSONObject: file, options: .sortedKeys), as: UTF8.self)
    }

    private static func row(_ id: String, version: Int = 1, body: String? = nil) -> InstrumentCatalogRow {
        InstrumentCatalogRow(id: id, formatVersion: version, body: body ?? Self.body(id: id, version: version), sortOrder: 0)
    }

    private func makeCatalog(enabled: Bool = true, version: String = "1.0.3",
                             fetch: @escaping (String) async throws -> Data = { _ in throw URLError(.timedOut) }) -> InstrumentCatalog {
        InstrumentCatalog(bundled: InstrumentLibrary.all, appVersion: version, cacheURL: cacheURL,
                          fetcher: RemoteFetcher(fetch: fetch), isEnabled: { enabled })
    }

    private static func encode(_ rows: [InstrumentCatalogRow]) -> Data { try! JSONEncoder().encode(rows) }

    private var bundledIDs: Set<String> { Set(InstrumentLibrary.all.map(\.id)) }

    // MARK: Validation

    func testValidFileIsAcceptedAndMergedAfterTheBundledLibrary() {
        let result = InstrumentCatalog.accept([Self.row("community.big-wheel")], bundledIDs: bundledIDs)
        XCTAssertEqual(result.instruments.map(\.id), ["community.big-wheel"])
        XCTAssertTrue(result.skipped.isEmpty)
        XCTAssertEqual(result.instruments.first?.chords.side, .right)

        let merged = InstrumentCatalog.merge(bundled: InstrumentLibrary.all, remote: result.instruments)
        XCTAssertEqual(merged.map(\.id), InstrumentLibrary.all.map(\.id) + ["community.big-wheel"])
    }

    func testMalformedFilesAreRejected() {
        let rows = [
            Self.row("community.truncated", body: "{\"format\":\"handstrudel.instrument\",\"format_version\":1,"),
            Self.row("community.not-instrument", body: "{\"format\":\"something.else\",\"format_version\":1}"),
            Self.row("community.bad-surface", body: Self.body(id: "community.bad-surface",
                                                               extra: ["surface": ["type": "piano", "radius": 1]])),
            Self.row("community.no-name", body: Self.body(id: "community.no-name", name: "   ")),
            Self.row("community.huge", body: Self.body(id: "community.huge",
                                                        extra: ["padding": String(repeating: "x", count: InstrumentSpec.byteLimit)])),
        ]
        let result = InstrumentCatalog.accept(rows, bundledIDs: bundledIDs)
        XCTAssertTrue(result.instruments.isEmpty)
        XCTAssertEqual(result.skipped.map { $0.reason }, [
            .rejected([.malformed]), .rejected([.unsupportedFormat]), .rejected([.malformed]),
            .rejected([.nameMissing]), .rejected([.tooLarge]),
        ])
    }

    func testFutureFormatFilesAreSkipped() {
        let rows = [
            Self.row("community.future", version: 2),
            // A row that claims format 1 but carries a format 2 file.
            Self.row("community.sneaky", version: 1, body: Self.body(id: "community.sneaky", version: 2)),
        ]
        let result = InstrumentCatalog.accept(rows, bundledIDs: bundledIDs)
        XCTAssertTrue(result.instruments.isEmpty)
        XCTAssertEqual(result.skipped.map { $0.reason }, [.newerFormat(2), .rejected([.unsupportedVersion])])
    }

    func testOutOfRangeValuesAreRepairedLikeBundledFiles() throws {
        let result = InstrumentCatalog.accept([Self.row("community.wide", body: Self.body(id: "community.wide", radius: 3))],
                                              bundledIDs: bundledIDs)
        XCTAssertEqual(try XCTUnwrap(result.instruments.first).surface.radius, 1.0)
    }

    func testBundledFilesWinAndReservedIDsAreRefused() {
        let wide = try! String(contentsOf: XCTUnwrap(Bundle.main.url(forResource: "wide-wheel", withExtension: "json", subdirectory: "library")))
        let rows = [
            Self.row("demo.wide-wheel", body: wide.replacingOccurrences(of: "Wide Wheel", with: "Hijacked")),
            Self.row("builtin.scale-wheel", body: Self.body(id: "builtin.scale-wheel")),
            Self.row("community.mismatch", body: Self.body(id: "community.other")),
            Self.row("community.twice"),
            Self.row("community.twice"),
        ]
        let result = InstrumentCatalog.accept(rows, bundledIDs: bundledIDs)
        XCTAssertEqual(result.instruments.map(\.id), ["community.twice"])
        XCTAssertEqual(result.skipped.map { $0.reason }, [.bundledCollision, .reservedID, .idMismatch, .duplicate])

        let merged = InstrumentCatalog.merge(bundled: InstrumentLibrary.all,
                                             remote: [InstrumentLibrary.splitWheel] + result.instruments)
        XCTAssertEqual(merged.filter { $0.id == InstrumentLibrary.splitWheelID }.count, 1)
        XCTAssertEqual(merged.first { $0.id == "demo.wide-wheel" }?.name, "Wide Wheel")
    }

    /// Every shared instrument fixture is accepted or rejected the same way
    /// when it arrives from the catalog as when it's bundled.
    func testSharedFixturesBehaveTheSameWhenDownloaded() throws {
        let folder = RemoteConfigTests.sharedFolder.appendingPathComponent("instruments/fixtures")
        let files = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
        XCTAssertGreaterThanOrEqual(files.count, 10)
        for file in files {
            let fixture = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any])
            let input = try JSONSerialization.data(withJSONObject: XCTUnwrap(fixture["input"]))
            let expect = try XCTUnwrap(fixture["expect"] as? [String: Any])
            let object = try JSONSerialization.jsonObject(with: input) as? [String: Any]
            let id = (object?["id"] as? String).map { "remote.\($0)" } ?? "remote.unknown"
            var body = object ?? [:]
            if body["id"] is String { body["id"] = id }
            let row = InstrumentCatalogRow(id: id, formatVersion: 1,
                                           body: String(decoding: try JSONSerialization.data(withJSONObject: body), as: UTF8.self))
            let result = InstrumentCatalog.accept([row], bundledIDs: [])
            XCTAssertEqual(!result.instruments.isEmpty, expect["accepted"] as? Bool, file.lastPathComponent)
        }
    }

    // MARK: Fetching and caching

    func testDownloadedFilesAreCachedAndRevalidated() async {
        let catalog = makeCatalog { version in
            XCTAssertEqual(version, "1.0.3")
            return Self.encode([Self.row("community.big-wheel"), Self.row("community.future", version: 2)])
        }
        await catalog.refresh()
        XCTAssertEqual(catalog.remote.map(\.id), ["community.big-wheel"])
        XCTAssertEqual(catalog.all.last?.id, "community.big-wheel")

        let offline = makeCatalog()
        XCTAssertEqual(offline.remote.map(\.id), ["community.big-wheel"], "next launch starts from the cache")
        await offline.refresh()
        XCTAssertEqual(offline.remote.map(\.id), ["community.big-wheel"], "a failed fetch keeps it")

        let afterUpdate = makeCatalog(version: "1.0.4")
        XCTAssertTrue(afterUpdate.remote.isEmpty, "a different app version refetches")
    }

    func testUnpublishedFilesDisappearOnTheNextFetch() async {
        var rows = [Self.row("community.a"), Self.row("community.b")]
        let catalog = makeCatalog { _ in Self.encode(rows) }
        await catalog.refresh()
        rows.removeFirst()
        await catalog.refresh()
        XCTAssertEqual(catalog.remote.map(\.id), ["community.b"])
    }

    func testSwitchedOffHidesDownloadsAndSkipsFetching() async {
        var fetches = 0
        let catalog = makeCatalog(enabled: false) { _ in fetches += 1; return Self.encode([Self.row("community.a")]) }
        await catalog.refreshIfNeeded()
        XCTAssertEqual(fetches, 0)
        catalog.apply(rows: [Self.row("community.a")])
        XCTAssertEqual(catalog.all.map(\.id), InstrumentLibrary.all.map(\.id))
    }

    func testMalformedResponseKeepsTheLastGoodSet() async {
        var response = Self.encode([Self.row("community.a")])
        let catalog = makeCatalog { _ in response }
        await catalog.refresh()
        response = Data("not json".utf8)
        await catalog.refresh()
        XCTAssertEqual(catalog.remote.map(\.id), ["community.a"])
    }
}
