import Foundation

/// A player's saved instruments ("My instruments"): kept on the device and,
/// when signed in, in `public.my_instruments` so they survive a reinstall.
///
/// Files are stored exactly as received and every one goes through
/// `InstrumentSpec.load` whenever it is read back, from disk or the account.
@MainActor
final class MyInstruments: ObservableObject {
    static let shared = MyInstruments()
    static let limit = 200

    struct Saved: Codable, Equatable, Identifiable {
        var id: String
        /// The instrument file (JSON text).
        var body: String
        var prompt: String?
        var savedAt: Date

        var spec: InstrumentSpec? { InstrumentSpec.load(Data(body.utf8)).spec }
    }

    @Published private(set) var saved: [Saved] = []
    /// Set when the last account sync failed; local saves still work.
    @Published private(set) var syncError: String?

    private let fileURL: URL?
    private let endpoint: () -> SupabaseEndpoint
    private let send: (URLRequest) async throws -> (Data, URLResponse)

    init(fileURL: URL? = RemoteCache.url("my-instruments.json"),
         endpoint: @escaping () -> SupabaseEndpoint = { .live },
         send: @escaping (URLRequest) async throws -> (Data, URLResponse) = { try await URLSession.shared.data(for: $0) }) {
        self.fileURL = fileURL
        self.endpoint = endpoint
        self.send = send
        if let fileURL, let data = try? Data(contentsOf: fileURL),
           let items = try? JSONDecoder().decode([Saved].self, from: data) {
            saved = items.filter { $0.spec != nil }
        }
    }

    /// Playable saved instruments, newest first.
    var instruments: [InstrumentSpec] { saved.compactMap(\.spec) }

    func contains(_ id: String) -> Bool { saved.contains { $0.id == id } }

    /// Save locally, then to the account. Returns false if the file doesn't load.
    @discardableResult
    func save(body: Data, prompt: String?) async -> Bool {
        guard let spec = InstrumentSpec.load(body).spec, !spec.isBuiltIn,
              let text = String(data: body, encoding: .utf8) else { return false }
        let item = Saved(id: spec.id, body: text, prompt: prompt, savedAt: Date())
        saved.removeAll { $0.id == item.id }
        saved.insert(item, at: 0)
        if saved.count > Self.limit { saved.removeLast(saved.count - Self.limit) }
        persist()
        await upload(item)
        return true
    }

    func delete(_ id: String) async {
        saved.removeAll { $0.id == id }
        persist()
        do {
            let request = try await endpoint().request("rest/v1/my_instruments", method: "DELETE",
                                                       query: [URLQueryItem(name: "id", value: "eq.\(id)")])
            _ = try await checked(send(request))
        } catch AIInstrumentError.signInRequired {
        } catch {
            syncError = "Couldn't remove it from your account."
        }
    }

    /// Merge the account's instruments into the local list (after sign-in or a reinstall).
    func pullFromAccount() async {
        do {
            let request = try await endpoint().request("rest/v1/my_instruments", method: "GET", query: [
                URLQueryItem(name: "select", value: "id,body,prompt,created_at"),
                URLQueryItem(name: "order", value: "created_at.desc"),
            ])
            let (data, _) = try await checked(send(request))
            guard let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return }
            var merged = saved
            for row in rows.reversed() {
                guard let id = row["id"] as? String, !merged.contains(where: { $0.id == id }),
                      let object = row["body"],
                      let body = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
                      InstrumentSpec.load(body).spec != nil else { continue }
                merged.append(Saved(id: id, body: String(decoding: body, as: UTF8.self),
                                    prompt: row["prompt"] as? String, savedAt: Date()))
            }
            if merged != saved { saved = merged; persist() }
            syncError = nil
        } catch AIInstrumentError.signInRequired {
        } catch {
            syncError = "Couldn't load your saved instruments."
        }
    }

    private func upload(_ item: Saved) async {
        do {
            guard let object = try JSONSerialization.jsonObject(with: Data(item.body.utf8)) as? [String: Any] else { return }
            var row: [String: Any] = ["id": item.id, "body": object]
            if let prompt = item.prompt { row["prompt"] = String(prompt.prefix(600)) }
            var request = try await endpoint().request("rest/v1/my_instruments", method: "POST",
                                                       body: try JSONSerialization.data(withJSONObject: row),
                                                       query: [URLQueryItem(name: "on_conflict", value: "user_id,id")])
            request.setValue("resolution=merge-duplicates,return=minimal", forHTTPHeaderField: "Prefer")
            _ = try await checked(send(request))
            syncError = nil
        } catch AIInstrumentError.signInRequired {
        } catch {
            syncError = "Saved on this iPhone. It'll sync to your account next time."
        }
    }

    private func checked(_ result: (Data, URLResponse)) throws -> (Data, URLResponse) {
        let status = (result.1 as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else { throw AIInstrumentError.server("HTTP \(status)") }
        return result
    }

    private func persist() {
        guard let fileURL, let data = try? JSONEncoder().encode(saved) else { return }
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: fileURL, options: .atomic)
    }
}
