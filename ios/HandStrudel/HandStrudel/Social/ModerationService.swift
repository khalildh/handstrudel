import Foundation
import Supabase

/// One reported or moderated post or comment in the admin queue (`moderation_queue`).
struct ModerationItem: Decodable, Equatable, Identifiable {
    enum Kind: String, Decodable { case post, comment }
    enum State: String, Decodable {
        case visible
        case autoHidden = "auto_hidden"
        case adminHidden = "admin_hidden"
        case banned

        var title: String {
            switch self {
            case .visible: "Visible"
            case .autoHidden: "Auto-hidden"
            case .adminHidden: "Hidden by admin"
            case .banned: "Hidden by ban"
            }
        }
        var isHidden: Bool { self != .visible }
    }

    let kind: Kind
    let targetId: UUID
    let videoId: UUID
    let authorId: UUID
    let authorUsername: String?
    let authorBanned: Bool
    let body: String
    let thumbKey: String
    let videoKey: String
    let createdAt: Date
    let openReports: Int
    let totalReports: Int
    let reasons: [String]
    let lastReportedAt: Date?
    let state: State

    var id: String { "\(kind.rawValue)-\(targetId)" }
    var author: String { authorUsername.map { "@\($0)" } ?? "Deleted account" }

    enum CodingKeys: String, CodingKey {
        case kind = "target_kind", targetId = "target_id", videoId = "video_id", authorId = "author_id"
        case authorUsername = "author_username", authorBanned = "author_banned", body
        case thumbKey = "thumb_key", videoKey = "video_key", createdAt = "created_at"
        case openReports = "open_reports", totalReports = "total_reports", reasons
        case lastReportedAt = "last_reported_at", state
    }
}

struct ModerationReport: Decodable, Equatable, Identifiable {
    let reporterUsername: String?
    let reason: String
    let createdAt: Date
    let reviewedAt: Date?
    var id: String { "\(reporterUsername ?? "?")-\(reason)-\(createdAt.timeIntervalSince1970)" }

    enum CodingKeys: String, CodingKey {
        case reporterUsername = "reporter_username", reason
        case createdAt = "created_at", reviewedAt = "reviewed_at"
    }
}

struct ModerationLogEntry: Decodable, Equatable, Identifiable {
    let id: Int
    let adminUsername: String?
    let action: String
    let targetKind: String
    let targetId: UUID
    let targetUsername: String?
    let note: String?
    let createdAt: Date

    /// "hid a post by @someone"
    var summary: String {
        let verb = switch action {
        case "hide": "hid"
        case "restore": "restored"
        case "dismiss": "dismissed reports on"
        case "ban": "banned"
        case "unban": "unbanned"
        default: action
        }
        let who = targetUsername.map { "@\($0)" } ?? "a deleted account"
        return targetKind == "user" ? "\(verb) \(who)" : "\(verb) a \(targetKind) by \(who)"
    }

    enum CodingKeys: String, CodingKey {
        case id, action, note
        case adminUsername = "admin_username", targetKind = "target_kind", targetId = "target_id"
        case targetUsername = "target_username", createdAt = "created_at"
    }
}

/// Admin-only moderation RPCs. The database refuses every call from a non-admin.
enum ModerationService {
    enum Filter: String, CaseIterable, Identifiable {
        case open, hidden, all
        var id: String { rawValue }
        var title: String { rawValue.capitalized }
    }
    enum Sort: String, CaseIterable, Identifiable {
        case newest, most
        var id: String { rawValue }
        var title: String { self == .newest ? "Newest reports" : "Most reported" }
    }
    enum Action: String {
        case hide, restore, dismiss, ban, unban
    }

    static let pageSize = 50

    static func isModerator() async -> Bool {
        (try? await supabase.rpc("is_moderator").execute().value as Bool) ?? false
    }

    static func queue(filter: Filter, sort: Sort, offset: Int = 0) async throws -> [ModerationItem] {
        struct Params: Encodable { let queue_filter: String; let sort_by: String; let page_size: Int; let page_offset: Int }
        return try await supabase.rpc("moderation_queue", params: Params(
            queue_filter: filter.rawValue, sort_by: sort.rawValue, page_size: pageSize, page_offset: offset))
            .execute().value
    }

    static func reports(for item: ModerationItem) async throws -> [ModerationReport] {
        struct Params: Encodable { let target_kind: String; let target_id: UUID }
        return try await supabase.rpc("moderation_item_reports",
                                      params: Params(target_kind: item.kind.rawValue, target_id: item.targetId))
            .execute().value
    }

    static func log(offset: Int = 0) async throws -> [ModerationLogEntry] {
        struct Params: Encodable { let page_size: Int; let page_offset: Int }
        return try await supabase.rpc("moderation_log", params: Params(page_size: pageSize, page_offset: offset))
            .execute().value
    }

    static func perform(_ action: Action, on item: ModerationItem, note: String) async throws {
        let note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            switch action {
            case .hide, .restore, .dismiss:
                struct Params: Encodable { let target_kind: String; let target_id: UUID; let note: String? }
                let name = action == .dismiss ? "moderation_dismiss_reports" : "moderation_\(action.rawValue)"
                try await supabase.rpc(name, params: Params(
                    target_kind: item.kind.rawValue, target_id: item.targetId, note: note.isEmpty ? nil : note)).execute()
            case .ban, .unban:
                struct Params: Encodable { let target_user: UUID; let note: String? }
                try await supabase.rpc("moderation_\(action.rawValue)_user", params: Params(
                    target_user: item.authorId, note: note.isEmpty ? nil : note)).execute()
            }
        } catch let error as PostgrestError {
            throw SocialError.message(message(for: error))
        }
    }

    static func message(for error: PostgrestError) -> String {
        switch error.message {
        case "NOT_ADMIN": "This account isn't a moderator."
        case "AUTHOR_BANNED": "The author is banned. Unban them to bring their posts back."
        case "CANNOT_BAN_ADMIN": "Moderators can't be banned."
        case "NOT_BANNED": "This account isn't banned."
        case "MODERATION_TARGET_NOT_FOUND": "This item was deleted."
        default: "Couldn't complete that. Check your connection and try again."
        }
    }

    struct Media: Decodable, Equatable { let video: URL; let thumb: URL }

    /// Signed URLs that play posts even while hidden (Edge Function `moderation-media`).
    static func media(for videos: [UUID]) async throws -> [UUID: Media] {
        guard !videos.isEmpty else { return [:] }
        struct Body: Encodable { let videoIds: [UUID] }
        struct Response: Decodable { let media: [String: Media] }
        let response: Response = try await supabase.functions.invoke(
            "moderation-media", options: FunctionInvokeOptions(body: Body(videoIds: Array(Set(videos)).prefix(50).map { $0 })))
        return Dictionary(uniqueKeysWithValues: response.media.compactMap { key, value in
            UUID(uuidString: key).map { ($0, value) }
        })
    }
}

/// Whether the signed-in account may see Profile → Moderation.
@MainActor
final class ModerationAccess: ObservableObject {
    static let shared = ModerationAccess()
    @Published private(set) var isModerator = false

    func refresh(signedIn: Bool) async {
        guard signedIn else { isModerator = false; return }
        isModerator = await ModerationService.isModerator()
    }
}
