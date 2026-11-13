import Foundation
import Supabase

/// Reads the public feed and performs the social actions on it.
/// All writes are protected by RLS (callers can only act as themselves).
enum FeedService {
    static let pageSize = 10

    /// Newest-first page of `feed_videos` (hidden posts and blocked users are
    /// already excluded by the view). Pass the last item of the previous page.
    static func page(after last: Video? = nil) async throws -> [Video] {
        var query = supabase.from("feed_videos").select()
        if let last {
            // Keyset pagination on (created_at, id), matching videos_feed_idx.
            let ts = ISO8601DateFormatter.feed.string(from: last.createdAt)
            query = query.or("created_at.lt.\(ts),and(created_at.eq.\(ts),id.lt.\(last.id.uuidString.lowercased()))")
        }
        return try await query
            .order("created_at", ascending: false)
            .order("id", ascending: false)
            .limit(pageSize)
            .execute().value
    }

    static func setLiked(_ liked: Bool, video: UUID, user: UUID) async throws {
        struct Row: Encodable { let user_id: UUID; let video_id: UUID }
        if liked {
            try await supabase.from("likes").insert(Row(user_id: user, video_id: video)).execute()
        } else {
            try await supabase.from("likes").delete()
                .eq("user_id", value: user).eq("video_id", value: video).execute()
        }
    }

    static func isFollowing(_ target: UUID, user: UUID) async -> Bool {
        let rows: [[String: UUID]] = (try? await supabase.from("follows").select("followee_id")
            .eq("follower_id", value: user).eq("followee_id", value: target)
            .execute().value) ?? []
        return !rows.isEmpty
    }

    static func setFollowing(_ follow: Bool, target: UUID, user: UUID) async throws {
        struct Row: Encodable { let follower_id: UUID; let followee_id: UUID }
        if follow {
            try await supabase.from("follows").insert(Row(follower_id: user, followee_id: target)).execute()
        } else {
            try await supabase.from("follows").delete()
                .eq("follower_id", value: user).eq("followee_id", value: target).execute()
        }
    }

    enum ReportReason: String, CaseIterable, Identifiable {
        case sexual = "Nudity or sexual content"
        case hate = "Hate or harassment"
        case violence = "Violence or self-harm"
        case spam = "Spam or scam"
        case stolen = "Not their content"
        case other = "Something else"
        var id: String { rawValue }
    }

    /// Reports a post. Three reports hide it automatically (DB trigger).
    static func report(_ video: UUID, reason: ReportReason, user: UUID) async throws {
        struct Row: Encodable { let reporter_id: UUID; let video_id: UUID; let reason: String }
        do {
            try await supabase.from("reports")
                .insert(Row(reporter_id: user, video_id: video, reason: reason.rawValue)).execute()
        } catch let e as PostgrestError where e.code == "23505" {
            // Already reported by this user; treat as success.
        }
    }

    /// Blocks a user: neither side sees the other's posts afterwards.
    static func block(_ target: UUID, user: UUID) async throws {
        struct Row: Encodable { let blocker_id: UUID; let blocked_id: UUID }
        do {
            try await supabase.from("blocks").insert(Row(blocker_id: user, blocked_id: target)).execute()
        } catch let e as PostgrestError where e.code == "23505" {}
        try? await setFollowing(false, target: target, user: user)
    }

    static func unblock(_ target: UUID, user: UUID) async throws {
        try await supabase.from("blocks").delete()
            .eq("blocker_id", value: user).eq("blocked_id", value: target).execute()
    }

    struct BlockedUser: Decodable, Identifiable {
        let blockedId: UUID
        let profile: Profile?
        var id: UUID { blockedId }
        enum CodingKeys: String, CodingKey { case blockedId = "blocked_id"; case profile = "profiles" }
    }

    static func blockedUsers(user: UUID) async throws -> [BlockedUser] {
        try await supabase.from("blocks")
            .select("blocked_id, profiles!blocks_blocked_id_fkey(id, username)")
            .eq("blocker_id", value: user).execute().value
    }

    static func deleteVideo(_ video: UUID) async throws {
        struct Body: Encodable { let videoId: UUID }
        try await supabase.functions.invoke("delete-video", options: FunctionInvokeOptions(body: Body(videoId: video)))
    }
}

extension ISO8601DateFormatter {
    /// Postgres timestamptz with fractional seconds, for keyset cursors.
    static let feed: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
}
