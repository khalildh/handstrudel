import Foundation
import Supabase

/// An instrument the player keeps: saved from a post, created (generated), remixed or imported.
struct MyInstrument: Codable, Identifiable, Equatable {
    enum Kind: String, Codable { case saved, created, remixed, imported }

    let id: UUID
    var document: InstrumentDocument
    let kind: Kind
    /// The post it was saved or remixed from, credited when it's played in a new take.
    let sourceVideoID: UUID?
    /// Shown as "from @creator"; local only, since usernames can change.
    var sourceUsername: String?
    let createdAt: Date
    var updatedAt: Date

    var name: String { document.name }
    var isEditable: Bool { kind != .saved }

    var origin: String {
        switch kind {
        case .saved: return sourceUsername.map { "Saved from @\($0)" } ?? "Saved from a post"
        case .remixed: return sourceUsername.map { "Remix of @\($0)'s instrument" } ?? "Remix"
        case .created: return "Created by you"
        case .imported: return "Imported file"
        }
    }
}

/// The account's instruments (`public.my_instruments`). Reads and writes go through the
/// signed-in client, so row-level security applies: a player only ever sees their own rows, and
/// saving or remixing a post's instrument needs its creator's "Allow remixes".
struct MyInstrumentsRemote {
    struct Row: Codable {
        let id: UUID
        let spec: InstrumentJSON
        let kind: String
        let sourceVideoID: UUID?
        var createdAt: Date? = nil
        var updatedAt: Date? = nil

        enum CodingKeys: String, CodingKey {
            case id, spec, kind
            case sourceVideoID = "source_video_id"
            case createdAt = "created_at"
            case updatedAt = "updated_at"
        }
    }

    /// Insert outcomes the store handles: row-level security said no (for example the creator
    /// turned remixes off since), or the row is already there.
    enum InsertError: Error { case refused, duplicate }

    var fetch: () async throws -> [Row]
    var insert: (Row) async throws -> Void
    var update: (UUID, InstrumentJSON) async throws -> Void
    var delete: (UUID) async throws -> Void

    static let live = MyInstrumentsRemote(
        fetch: {
            try await supabase.from("my_instruments").select("id, spec, kind, source_video_id, created_at, updated_at")
                .order("created_at", ascending: false).limit(500).execute().value
        },
        insert: { row in
            do {
                try await supabase.from("my_instruments")
                    .insert(Row(id: row.id, spec: row.spec, kind: row.kind, sourceVideoID: row.sourceVideoID)).execute()
            } catch let error as PostgrestError where error.code == "42501" {
                throw InsertError.refused
            } catch let error as PostgrestError where error.code == "23505" {
                throw InsertError.duplicate
            }
        },
        update: { id, spec in
            struct Patch: Encodable { let spec: InstrumentJSON }
            try await supabase.from("my_instruments").update(Patch(spec: spec)).eq("id", value: id).execute()
        },
        delete: { id in
            try await supabase.from("my_instruments").delete().eq("id", value: id).execute()
        })
}

/// My instruments, cached on the device per account and synced to the account when signed in.
/// Instruments kept while signed out move into the account at the next sign-in.
@MainActor
final class MyInstrumentsStore: ObservableObject {
    static let shared = MyInstrumentsStore()
    static let limit = 500

    @Published private(set) var items: [MyInstrument] = []
    @Published private(set) var isSyncing = false
    @Published private(set) var syncError: String?

    private struct Cache: Codable {
        var items: [MyInstrument] = []
        /// On the server already.
        var uploaded: Set<UUID> = []
        /// Changed here since the last upload.
        var edited: Set<UUID> = []
        /// Deleted here, still to delete on the server.
        var deleted: Set<UUID> = []
        /// The server refused them (for example the creator turned remixes off). Kept on this device.
        var refused: Set<UUID> = []

        init() {}

        /// Every cached file is validated again; one that no longer loads is dropped, not the cache.
        init(from decoder: Decoder) throws {
            struct Lossy: Decodable {
                let item: MyInstrument?
                init(from decoder: Decoder) throws { item = try? MyInstrument(from: decoder) }
            }
            let values = try decoder.container(keyedBy: CodingKeys.self)
            items = try values.decode([Lossy].self, forKey: .items).compactMap(\.item)
            uploaded = try values.decode(Set<UUID>.self, forKey: .uploaded)
            edited = try values.decode(Set<UUID>.self, forKey: .edited)
            deleted = try values.decode(Set<UUID>.self, forKey: .deleted)
            refused = try values.decode(Set<UUID>.self, forKey: .refused)
        }
    }

    private var cache = Cache()
    private(set) var accountID: UUID?
    private let directory: URL?
    private let remote: MyInstrumentsRemote
    private let now: () -> Date

    static let defaultDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
        .appendingPathComponent("MyInstruments", isDirectory: true)

    init(directory: URL? = MyInstrumentsStore.defaultDirectory,
         remote: MyInstrumentsRemote = .live, now: @escaping () -> Date = Date.init) {
        self.directory = directory
        self.remote = remote
        self.now = now
        #if DEBUG
        if ProcessInfo.processInfo.environment["HANDSTRUDEL_TEST_RESET_INSTRUMENTS"] == "1", directory == Self.defaultDirectory,
           let directory {
            try? FileManager.default.removeItem(at: directory)
        }
        #endif
        cache = read(account: nil)
        items = cache.items
    }

    // MARK: Account

    /// Switch to an account's instruments (nil: signed out). Signed-out instruments join the account.
    func setAccount(_ id: UUID?) {
        guard id != accountID else { return }
        accountID = id
        var next = read(account: id)
        if id != nil {
            let device = read(account: nil)
            for item in device.items where !next.items.contains(where: { $0.id == item.id }) {
                next.items.append(item)
            }
            if !device.items.isEmpty { write(Cache(), account: nil) }
        }
        cache = next
        publish()
    }

    // MARK: Keeping instruments

    func item(id: UUID) -> MyInstrument? { items.first { $0.id == id } }

    /// Whether this post's instrument is already kept unchanged.
    func hasSaved(post: UUID) -> Bool {
        items.contains { $0.kind == .saved && $0.sourceVideoID == post }
    }

    @discardableResult
    func save(_ document: InstrumentDocument, fromPost post: UUID, by username: String?) throws -> MyInstrument {
        if let existing = items.first(where: { $0.kind == .saved && $0.sourceVideoID == post && $0.document == document }) {
            return existing
        }
        return try add(document, kind: .saved, source: post, username: username)
    }

    /// An editable copy with its own id and name, credited to the post it came from.
    @discardableResult
    func remix(_ document: InstrumentDocument, fromPost post: UUID?, by username: String?) throws -> MyInstrument {
        try add(document.remixCopy(), kind: .remixed, source: post, username: username)
    }

    /// For generated instruments and other instruments the player made.
    @discardableResult
    func addCreated(_ document: InstrumentDocument) throws -> MyInstrument {
        try add(document, kind: .created, source: nil, username: nil)
    }

    /// Import a `.handstrudel-instrument` file. The loader validates it first; an identical file
    /// already kept is returned instead of a duplicate.
    @discardableResult
    func importFile(at url: URL) throws -> MyInstrument {
        let document = try InstrumentDocument.importFile(at: url)
        if let existing = items.first(where: { $0.document == document }) { return existing }
        return try add(document, kind: .imported, source: nil, username: nil)
    }

    func update(_ id: UUID, document: InstrumentDocument) {
        guard let index = cache.items.firstIndex(where: { $0.id == id }), cache.items[index].isEditable,
              cache.items[index].document != document else { return }
        cache.items[index].document = document
        cache.items[index].updatedAt = now()
        cache.edited.insert(id)
        save()
    }

    func delete(_ id: UUID) {
        guard let index = cache.items.firstIndex(where: { $0.id == id }) else { return }
        cache.items.remove(at: index)
        cache.edited.remove(id)
        cache.refused.remove(id)
        if cache.uploaded.remove(id) != nil { cache.deleted.insert(id) }
        save()
    }

    private func add(_ document: InstrumentDocument, kind: MyInstrument.Kind, source: UUID?, username: String?) throws -> MyInstrument {
        guard cache.items.count < Self.limit else {
            throw SocialError.message("You have \(Self.limit) instruments. Delete some to keep more.")
        }
        let date = now()
        let item = MyInstrument(id: UUID(), document: document, kind: kind, sourceVideoID: source,
                                sourceUsername: username, createdAt: date, updatedAt: date)
        cache.items.insert(item, at: 0)
        save()
        return item
    }

    // MARK: Sync

    /// Push local changes, then pull the account's instruments from other devices.
    func sync() async {
        guard let account = accountID, !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }
        do {
            for id in cache.deleted {
                try await remote.delete(id)
                guard accountID == account else { return }
                cache.deleted.remove(id)
            }
            for item in cache.items where !cache.uploaded.contains(item.id) && !cache.refused.contains(item.id) {
                do {
                    try await remote.insert(.init(id: item.id, spec: item.document.json, kind: item.kind.rawValue,
                                                  sourceVideoID: item.sourceVideoID))
                    guard accountID == account else { return }
                    cache.uploaded.insert(item.id)
                    cache.edited.remove(item.id)
                } catch MyInstrumentsRemote.InsertError.refused {
                    guard accountID == account else { return }
                    cache.refused.insert(item.id)
                } catch MyInstrumentsRemote.InsertError.duplicate {
                    guard accountID == account else { return }
                    cache.uploaded.insert(item.id)
                }
            }
            for id in cache.edited where cache.uploaded.contains(id) {
                guard let item = cache.items.first(where: { $0.id == id }) else { continue }
                try await remote.update(id, item.document.json)
                guard accountID == account else { return }
                cache.edited.remove(id)
            }
            let rows = try await remote.fetch()
            guard accountID == account else { return }
            merge(rows)
            syncError = nil
        } catch {
            if accountID == account { syncError = "Couldn't sync your instruments. They're safe on this device." }
        }
        if accountID == account { save() }
    }

    private func merge(_ rows: [MyInstrumentsRemote.Row]) {
        let remoteIDs = Set(rows.map(\.id))
        // Deleted on another device: drop what was uploaded and isn't on the server any more.
        let uploaded = cache.uploaded, edited = cache.edited
        cache.items.removeAll { uploaded.contains($0.id) && !remoteIDs.contains($0.id) && !edited.contains($0.id) }
        cache.uploaded.formIntersection(remoteIDs.union(cache.edited))
        for row in rows where !cache.deleted.contains(row.id) {
            // Files are validated like any received instrument; ones this version can't load stay on the server.
            guard let document = try? InstrumentDocument(json: row.spec),
                  let kind = MyInstrument.Kind(rawValue: row.kind) else { continue }
            cache.uploaded.insert(row.id)
            if let index = cache.items.firstIndex(where: { $0.id == row.id }) {
                if !cache.edited.contains(row.id), let updated = row.updatedAt, updated > cache.items[index].updatedAt {
                    cache.items[index].document = document
                    cache.items[index].updatedAt = updated
                }
            } else {
                cache.items.append(MyInstrument(id: row.id, document: document, kind: kind, sourceVideoID: row.sourceVideoID,
                                                sourceUsername: nil, createdAt: row.createdAt ?? now(),
                                                updatedAt: row.updatedAt ?? now()))
            }
        }
        cache.items.sort { $0.createdAt > $1.createdAt }
    }

    /// Whether the server refused this one (it stays on this device only).
    func isDeviceOnly(_ id: UUID) -> Bool { accountID == nil || cache.refused.contains(id) }

    // MARK: Storage

    private func save() {
        write(cache, account: accountID)
        publish()
    }

    private func publish() { items = cache.items }

    private func fileURL(account: UUID?) -> URL? {
        directory?.appendingPathComponent("instruments-\(account?.uuidString.lowercased() ?? "device").json")
    }

    private func read(account: UUID?) -> Cache {
        guard let url = fileURL(account: account), let data = try? Data(contentsOf: url),
              let cache = try? JSONDecoder().decode(Cache.self, from: data) else { return Cache() }
        return cache
    }

    private func write(_ cache: Cache, account: UUID?) {
        guard let directory, let url = fileURL(account: account) else { return }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? JSONEncoder().encode(cache).write(to: url, options: .atomic)
    }
}
