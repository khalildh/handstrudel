import Foundation
import MetricKit

/// Crash, hang and resource-exception reports from Apple's MetricKit, uploaded to our own
/// Supabase table (`public.app_diagnostics`, insert-only for the app). No third-party SDK.
///
/// Only sent when the player opted in to Usage Analytics. MetricKit delivers each payload once
/// (usually on the next launch, at most daily), so payloads received while opted out are dropped,
/// and a failed upload is kept on disk and retried on the next launch.
final class CrashDiagnostics: NSObject, MXMetricManagerSubscriber {
    static let shared = CrashDiagnostics(uploader: DiagnosticsUploader.live)

    let uploader: DiagnosticsUploader

    init(uploader: DiagnosticsUploader) {
        self.uploader = uploader
    }

    func start() {
        guard !ProcessInfo.processInfo.arguments.contains("--uitesting") else { return }
        MXMetricManager.shared.add(self)
        Task { await uploader.flushPending() }
        #if DEBUG
        // MetricKit doesn't deliver payloads in the Simulator. This feeds a recorded sample through
        // the same path: `-simulateDiagnostic` launch argument (or SIMULATE_DIAGNOSTIC=1).
        if ProcessInfo.processInfo.arguments.contains("-simulateDiagnostic")
            || ProcessInfo.processInfo.environment["SIMULATE_DIAGNOSTIC"] == "1" {
            Task { await uploader.receive([DiagnosticReport.sampleCrash, DiagnosticReport.sampleHang]) }
        }
        #endif
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        let reports = payloads.flatMap(DiagnosticReport.reports(from:))
        Task { await uploader.receive(reports) }
    }
}

/// One diagnostic as MetricKit gave it: its kind and its JSON representation.
struct DiagnosticReport: Equatable {
    enum Kind: String, CaseIterable {
        case crash, hang, cpuException = "cpu_exception", diskWriteException = "disk_write_exception"
        case appLaunch = "app_launch"
    }

    let kind: Kind
    let json: Data

    static func reports(from payload: MXDiagnosticPayload) -> [DiagnosticReport] {
        var reports: [DiagnosticReport] = []
        func add(_ kind: Kind, _ diagnostics: [MXDiagnostic]?) {
            reports += (diagnostics ?? []).map { DiagnosticReport(kind: kind, json: $0.jsonRepresentation()) }
        }
        add(.crash, payload.crashDiagnostics)
        add(.hang, payload.hangDiagnostics)
        add(.cpuException, payload.cpuExceptionDiagnostics)
        add(.diskWriteException, payload.diskWriteExceptionDiagnostics)
        if #available(iOS 16.0, *) { add(.appLaunch, payload.appLaunchDiagnostics) }
        return reports
    }
}

/// Turns reports into `app_diagnostics` rows and posts them. An actor so MetricKit's background
/// callbacks and the launch-time retry don't race on the pending file.
actor DiagnosticsUploader {
    typealias Transport = (URLRequest) async throws -> (Data, URLResponse)

    /// Compact-JSON cap per diagnostic. The database allows 64 KB of jsonb text, which spaces out
    /// a little more than compact JSON; this leaves room for that.
    static let maxPayloadBytes = 48_000
    /// At most this many rows wait on the device for a retry.
    static let maxPendingRows = 50

    struct Environment {
        var baseURL: URL
        var anonKey: String
        var appVersion: String
        var build: String
        var osVersion: String
        var deviceModel: String
    }

    private let environment: () -> Environment?
    private let isOptedIn: () -> Bool
    private let transport: Transport
    private let pendingURL: URL?

    init(environment: @escaping () -> Environment?, isOptedIn: @escaping () -> Bool,
         pendingURL: URL?, transport: @escaping Transport) {
        self.environment = environment
        self.isOptedIn = isOptedIn
        self.pendingURL = pendingURL
        self.transport = transport
    }

    static let live = DiagnosticsUploader(
        environment: {
            guard SocialConfig.isConfigured else { return nil }
            let info = Bundle.main.infoDictionary
            return Environment(
                baseURL: SocialConfig.supabaseURL,
                anonKey: SocialConfig.supabaseAnonKey,
                appVersion: info?["CFBundleShortVersionString"] as? String ?? "0",
                build: info?["CFBundleVersion"] as? String ?? "0",
                osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
                deviceModel: DiagnosticsUploader.hardwareModel()
            )
        },
        isOptedIn: { UserDefaults.standard.bool(forKey: AppAnalytics.optInKey) },
        pendingURL: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("pending-diagnostics.json"),
        transport: { request in
            let config = URLSessionConfiguration.ephemeral
            config.httpShouldSetCookies = false
            config.urlCredentialStorage = nil
            return try await URLSession(configuration: config).data(for: request)
        }
    )

    // MARK: Receiving

    func receive(_ reports: [DiagnosticReport]) async {
        guard isOptedIn() else {
            clearPending()
            return
        }
        guard let env = environment() else { return }
        let rows = reports.compactMap { Self.row(for: $0, env: env) }
        guard !rows.isEmpty else { return }
        await upload(loadPending() + rows, env: env)
    }

    func flushPending() async {
        guard isOptedIn() else {
            clearPending()
            return
        }
        let pending = loadPending()
        guard !pending.isEmpty, let env = environment() else { return }
        await upload(pending, env: env)
    }

    private func upload(_ rows: [[String: Any]], env: Environment) async {
        let rows = Array(rows.suffix(Self.maxPendingRows))
        guard let request = Self.request(rows: rows, env: env) else { return }
        do {
            let (_, response) = try await transport(request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            if (200..<300).contains(status) || (400..<500).contains(status) {
                // Accepted, or rejected for good (a retry would fail the same way).
                clearPending()
            } else {
                savePending(rows)
            }
        } catch {
            savePending(rows)
        }
    }

    // MARK: Rows and requests

    static func request(rows: [[String: Any]], env: Environment) -> URLRequest? {
        guard let body = try? JSONSerialization.data(withJSONObject: rows) else { return nil }
        var request = URLRequest(url: env.baseURL.appending(path: "rest/v1/app_diagnostics"), timeoutInterval: 15)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(env.anonKey, forHTTPHeaderField: "apikey")
        // The app has no select grant on the table, so it must not ask for the row back.
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        request.httpBody = body
        return request
    }

    /// The row for one report. Versions come from the report's own metadata (the build that
    /// crashed, which may be older than the one uploading), falling back to the running app.
    static func row(for report: DiagnosticReport, env: Environment) -> [String: Any]? {
        guard let object = try? JSONSerialization.jsonObject(with: report.json) as? [String: Any] else { return nil }
        let (payload, truncated) = cap(object, limit: maxPayloadBytes)
        let meta = payload["diagnosticMetaData"] as? [String: Any] ?? [:]
        var row: [String: Any] = [
            "kind": report.kind.rawValue,
            "platform": "ios",
            "app_version": versionString(meta["appVersion"] as? String) ?? versionString(env.appVersion) ?? "0",
            "build": versionString(meta["appBuildVersion"] as? String) ?? versionString(env.build) ?? "0",
            "os_version": clip(meta["osVersion"] as? String ?? env.osVersion, 64),
            "device_model": clip(meta["deviceType"] as? String ?? env.deviceModel, 64),
            "truncated": truncated,
            "payload": payload,
        ]
        if let summary = summary(meta) { row["summary"] = summary }
        return row
    }

    /// Keeps a diagnostic under `limit` bytes of compact JSON, dropping detail in order of value:
    /// first other threads' stacks, then deep frames of the crashing thread, then the stack itself.
    /// Always removes the region format, which we don't need.
    static func cap(_ object: [String: Any], limit: Int) -> (payload: [String: Any], truncated: Bool) {
        var payload = object
        if var meta = payload["diagnosticMetaData"] as? [String: Any] {
            meta.removeValue(forKey: "regionFormat")
            payload["diagnosticMetaData"] = meta
        }
        if size(payload) <= limit { return (payload, false) }

        if var tree = payload["callStackTree"] as? [String: Any],
           let stacks = tree["callStacks"] as? [[String: Any]] {
            let attributed = stacks.filter { $0["threadAttributed"] as? Bool == true }
            tree["callStacks"] = attributed.isEmpty ? Array(stacks.prefix(1)) : attributed
            payload["callStackTree"] = tree
            if size(payload) <= limit { return (payload, true) }

            for depth in [64, 32, 16] {
                tree["callStacks"] = (tree["callStacks"] as? [[String: Any]] ?? []).map { stack in
                    var stack = stack
                    stack["callStackRootFrames"] = (stack["callStackRootFrames"] as? [[String: Any]] ?? [])
                        .map { prune($0, keeping: depth) }
                    return stack
                }
                payload["callStackTree"] = tree
                if size(payload) <= limit { return (payload, true) }
            }
        }
        payload.removeValue(forKey: "callStackTree")
        if size(payload) <= limit { return (payload, true) }
        return (["diagnosticMetaData": payload["diagnosticMetaData"] ?? [:]], true)
    }

    private static func prune(_ frame: [String: Any], keeping depth: Int) -> [String: Any] {
        var frame = frame
        guard let subFrames = frame["subFrames"] as? [[String: Any]] else { return frame }
        frame["subFrames"] = depth <= 1 ? nil : subFrames.map { prune($0, keeping: depth - 1) }
        return frame
    }

    static func size(_ object: Any) -> Int {
        (try? JSONSerialization.data(withJSONObject: object))?.count ?? .max
    }

    static func summary(_ meta: [String: Any]) -> String? {
        let keys = ["exceptionType", "exceptionCode", "signal", "terminationReason",
                    "hangDuration", "totalCPUTime", "totalSampledTime", "writesCaused", "launchDuration"]
        let parts = keys.compactMap { key -> String? in
            guard let value = meta[key] else { return nil }
            return "\(key)=\(value)"
        }
        return parts.isEmpty ? nil : clip(parts.joined(separator: " "), 200)
    }

    private static func versionString(_ value: String?) -> String? {
        guard let value else { return nil }
        let allowed = value.filter { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "." || $0 == "-") }
        return allowed.isEmpty ? nil : String(allowed.prefix(32))
    }

    private static func clip(_ value: String, _ max: Int) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "unknown" : String(trimmed.prefix(max))
    }

    static func hardwareModel() -> String {
        #if targetEnvironment(simulator)
        if let model = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] { return model }
        #endif
        var info = utsname()
        uname(&info)
        return withUnsafeBytes(of: &info.machine) { raw in
            String(decoding: raw.prefix { $0 != 0 }, as: UTF8.self)
        }
    }

    // MARK: Pending rows

    private func loadPending() -> [[String: Any]] {
        guard let pendingURL, let data = try? Data(contentsOf: pendingURL),
              let rows = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }
        return rows
    }

    private func savePending(_ rows: [[String: Any]]) {
        guard let pendingURL,
              let data = try? JSONSerialization.data(withJSONObject: Array(rows.suffix(Self.maxPendingRows))) else { return }
        try? FileManager.default.createDirectory(at: pendingURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: pendingURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    private func clearPending() {
        guard let pendingURL else { return }
        try? FileManager.default.removeItem(at: pendingURL)
    }

    func pendingCount() -> Int { loadPending().count }
}

#if DEBUG
extension DiagnosticReport {
    /// Shaped like a real `MXCrashDiagnostic.jsonRepresentation()`.
    static let sampleCrash = DiagnosticReport(kind: .crash, json: Data("""
    {"version":"1.0.0","callStackTree":{"callStackPerThread":true,"callStacks":[
      {"threadAttributed":true,"callStackRootFrames":[{"binaryUUID":"70B89F27-1634-3580-A695-57CDB41D7743",
       "offsetIntoBinaryTextSegment":123456,"sampleCount":1,"binaryName":"HandStrudel","address":4295098432,
       "subFrames":[{"binaryUUID":"70B89F27-1634-3580-A695-57CDB41D7743","offsetIntoBinaryTextSegment":120000,
       "sampleCount":1,"binaryName":"HandStrudel","address":4295094976}]}]},
      {"threadAttributed":false,"callStackRootFrames":[{"binaryUUID":"C7E1A1A3-2C5D-3B0E-9E1F-3A2B1C0D9E8F",
       "offsetIntoBinaryTextSegment":4096,"sampleCount":1,"binaryName":"libsystem_kernel.dylib","address":7000000000}]}]},
     "diagnosticMetaData":{"appBuildVersion":"17","appVersion":"1.0.2","osVersion":"iPhone OS 26.1 (23B85)",
      "deviceType":"iPhone17,1","platformArchitecture":"arm64e","regionFormat":"US","bundleIdentifier":"com.handstrudel.app",
      "exceptionType":1,"exceptionCode":0,"signal":11,"terminationReason":"Namespace SIGNAL, Code 11 Segmentation fault: 11",
      "virtualMemoryRegionInfo":"0 is not in any region."}}
    """.utf8))

    static let sampleHang = DiagnosticReport(kind: .hang, json: Data("""
    {"version":"1.0.0","callStackTree":{"callStackPerThread":false,"callStacks":[{"threadAttributed":true,
      "callStackRootFrames":[{"binaryUUID":"70B89F27-1634-3580-A695-57CDB41D7743","offsetIntoBinaryTextSegment":200000,
      "sampleCount":20,"binaryName":"HandStrudel","address":4295175000}]}]},
     "diagnosticMetaData":{"appBuildVersion":"17","appVersion":"1.0.2","osVersion":"iPhone OS 26.1 (23B85)",
      "deviceType":"iPhone17,1","platformArchitecture":"arm64e","regionFormat":"US","bundleIdentifier":"com.handstrudel.app",
      "hangDuration":"2.4 sec"}}
    """.utf8))
}
#endif
