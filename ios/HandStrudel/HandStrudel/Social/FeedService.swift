import Foundation
import Supabase

/// Reads the public feed and performs the social actions on it.
/// All writes are protected by RLS (callers can only act as themselves).
enum FeedService {
    static let pageSize = 10
    static let commentPageSize = 20
    static let activityPageSize = 25

    static func activity(after last: CreatorActivity? = nil) async throws -> [CreatorActivity] {
        let query = supabase.from("activity_inbox").select()
        if let last {
            let date = ISO8601DateFormatter.feed.string(from: last.createdAt)
            _ = query.or("created_at.lt.\(date),and(created_at.eq.\(date),id.lt.\(last.id.uuidString.lowercased()))")
        }
        return try await query.order("created_at", ascending: false).order("id", ascending: false)
            .limit(activityPageSize).execute().value
    }

    static func hasUnreadActivity() async throws -> Bool {
        struct Item: Decodable { let id: UUID }
        let items: [Item] = try await supabase.from("activity_inbox").select("id")
            .is("read_at", value: nil).limit(1).execute().value
        return !items.isEmpty
    }

    static func markActivityRead(_ id: UUID) async throws {
        struct Parameters: Encodable { let target_item: UUID }
        try await supabase.rpc("mark_creator_activity_read", params: Parameters(target_item: id)).execute()
    }

    static func creator(id: UUID) async throws -> PublicCreator? {
        let profiles: [PublicCreator] = try await supabase.from("public_creators").select()
            .eq("id", value: id).limit(1).execute().value
        return profiles.first
    }

    static func comment(id: UUID, video: UUID) async throws -> VideoComment? {
        let rows: [VideoComment] = try await supabase.from("video_comments").select()
            .eq("id", value: id).eq("video_id", value: video).limit(1).execute().value
        return rows.first
    }

    static func video(id: UUID) async throws -> Video? {
        let rows: [Video] = try await supabase.from("feed_videos").select()
            .eq("id", value: id).limit(1).execute().value
        return rows.first
    }

    static func bookmarks(after last: Video? = nil) async throws -> [Video] {
        let query = supabase.from("saved_videos").select()
        if let last, let date = last.savedAt {
            let ts = ISO8601DateFormatter.feed.string(from: date)
            _ = query.or("saved_at.lt.\(ts),and(saved_at.eq.\(ts),id.lt.\(last.id.uuidString.lowercased()))")
        }
        return try await query.order("saved_at", ascending: false).order("id", ascending: false)
            .limit(pageSize).execute().value
    }

    static func savedVideoIDs(_ ids: [UUID]) async throws -> Set<UUID> {
        guard !ids.isEmpty else { return [] }
        struct Row: Decodable { let video_id: UUID }
        let rows: [Row] = try await supabase.from("video_bookmarks").select("video_id")
            .in("video_id", values: ids.map { $0.uuidString.lowercased() }).execute().value
        return Set(rows.map(\.video_id))
    }

    static func setBookmark(_ saved: Bool, video: UUID, user: UUID) async throws {
        if saved {
            struct Row: Encodable { let video_id: UUID }
            do {
                try await supabase.from("video_bookmarks").insert(Row(video_id: video), returning: .minimal).execute()
            } catch let error as PostgrestError where error.code == "23505" {}
        } else {
            try await supabase.from("video_bookmarks").delete()
                .eq("user_id", value: user).eq("video_id", value: video).execute()
        }
    }

    static func weeklyChallenge() async throws -> WeeklyChallenge? {
        let rows: [WeeklyChallenge] = try await supabase.from("weekly_challenges").select()
            .limit(1).execute().value
        return rows.first
    }

    static func comments(video: UUID, parent: UUID? = nil, offset: Int = 0) async throws -> [VideoComment] {
        let thread = supabase.from("video_comments").select().eq("video_id", value: video)
        let query = parent.map { thread.eq("parent_id", value: $0) } ?? thread.is("parent_id", value: nil)
        return try await query.order("created_at", ascending: parent != nil)
            .order("id", ascending: parent != nil)
            .range(from: offset, to: offset + commentPageSize - 1).execute().value
    }

    static func addComment(video: UUID, parent: UUID?, text: String) async throws {
        struct Row: Encodable { let video_id: UUID; let parent_id: UUID?; let body: String }
        do {
            try await supabase.from("comments")
                .insert(Row(video_id: video, parent_id: parent, body: text), returning: .minimal).execute()
        } catch let error as PostgrestError {
            switch error.message {
            case "COMMENT_FILTERED": throw SocialError.message("This comment was filtered. Remove links or harmful language and try again.")
            case "COMMENT_RATE_LIMITED": throw SocialError.message("You're commenting quickly. Wait a minute and try again.")
            case "COMMENT_THREAD_UNAVAILABLE": throw SocialError.message("This reply thread is no longer available.")
            default:
                if error.code == "42501" { throw SocialError.message("You can't comment on this video right now.") }
                throw error
            }
        }
    }

    static func deleteComment(_ id: UUID) async throws {
        struct Params: Encodable { let target_comment: UUID }
        try await supabase.rpc("delete_video_comment", params: Params(target_comment: id)).execute()
    }

    static func reportComment(_ id: UUID, reason: CommentReportReason) async throws {
        struct Row: Encodable { let comment_id: UUID; let reason: String }
        do {
            try await supabase.from("comment_reports")
                .insert(Row(comment_id: id, reason: reason.rawValue), returning: .minimal).execute()
        } catch let error as PostgrestError where error.code == "23505" {}
    }

    static func setCommentsEnabled(_ enabled: Bool, video: UUID, user: UUID) async throws {
        struct Update: Encodable { let comments_enabled: Bool }
        try await supabase.from("videos").update(Update(comments_enabled: enabled))
            .eq("id", value: video).eq("user_id", value: user).execute()
    }

    static func stopAllowingBacking(video: UUID) async throws {
        struct Update: Encodable { let backing_enabled = false }
        try await supabase.from("videos").update(Update()).eq("id", value: video).execute()
    }

    /// Newest-first page of `feed_videos` (hidden posts and blocked users are
    /// already excluded by the view). Pass the last item of the previous page.
    static func page(after last: Video? = nil, followingOnly: Bool = false, creator: UUID? = nil,
                     challenge: UUID? = nil) async throws -> [Video] {
        let table = challenge != nil ? "weekly_challenge_entries" : followingOnly ? "following_videos" : "feed_videos"
        var query = supabase.from(table).select()
        if let creator { query = query.eq("user_id", value: creator) }
        if let challenge { query = query.eq("challenge_id", value: challenge) }
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

    static func followedAuthors(_ authors: Set<UUID>, user: UUID) async throws -> Set<UUID> {
        guard !authors.isEmpty else { return [] }
        struct Follow: Decodable { let followee_id: UUID }
        let rows: [Follow] = try await supabase.from("follows").select("followee_id")
            .eq("follower_id", value: user)
            .in("followee_id", values: authors.map { $0.uuidString.lowercased() }).execute().value
        return Set(rows.map(\.followee_id))
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
