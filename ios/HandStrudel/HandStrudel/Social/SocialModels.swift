import Foundation

struct Profile: Codable, Equatable, Identifiable {
    let id: UUID
    var username: String?
    var displayName: String?
    var avatarKey: String?
    var acceptedTermsAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, username
        case displayName = "display_name"
        case avatarKey = "avatar_key"
        case acceptedTermsAt = "accepted_terms_at"
    }

    /// Lowercase letters, digits and underscores, 3–20 characters (matches the DB check).
    static func isValidUsername(_ s: String) -> Bool {
        s.range(of: "^[a-z0-9_]{3,20}$", options: .regularExpression) != nil
    }

    /// Normalizes what the user typed into a candidate username.
    static func normalizeUsername(_ s: String) -> String {
        String(s.lowercased().filter { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_") }.prefix(20))
    }
}

struct Video: Codable, Equatable, Identifiable {
    let id: UUID
    let userId: UUID
    let videoKey: String
    let thumbKey: String
    var caption: String
    var instrument: String?
    var mode: String?
    var durationS: Double?
    var width: Int?
    var height: Int?
    var likeCount: Int
    var hidden: Bool?
    let createdAt: Date
    private var rawCreatedAt: String?
    // Joined in the `feed_videos` view only.
    var username: String?
    var displayName: String?
    var likedByMe: Bool?
    var soundSetup: SoundSetup?
    var commentsEnabled: Bool?
    var commentCount: Int?
    var backingEnabled: Bool?
    var sourceVideoId: UUID?
    var sourceUsername: String?
    var savedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, caption, instrument, mode, width, height, hidden, username
        case userId = "user_id"
        case videoKey = "video_key"
        case thumbKey = "thumb_key"
        case durationS = "duration_s"
        case likeCount = "like_count"
        case createdAt = "created_at"
        case likedByMe = "liked_by_me"
        case displayName = "display_name"
        case soundSetup = "sound_setup"
        case commentsEnabled = "comments_enabled"
        case commentCount = "comment_count"
        case backingEnabled = "backing_enabled"
        case sourceVideoId = "source_video_id"
        case sourceUsername = "source_username"
        case savedAt = "saved_at"
    }

    init(from decoder: Decoder) throws {
        let row = try decoder.container(keyedBy: CodingKeys.self)
        id = try row.decode(UUID.self, forKey: .id)
        userId = try row.decode(UUID.self, forKey: .userId)
        videoKey = try row.decode(String.self, forKey: .videoKey)
        thumbKey = try row.decode(String.self, forKey: .thumbKey)
        caption = try row.decode(String.self, forKey: .caption)
        instrument = try row.decodeIfPresent(String.self, forKey: .instrument)
        mode = try row.decodeIfPresent(String.self, forKey: .mode)
        durationS = try row.decodeIfPresent(Double.self, forKey: .durationS)
        width = try row.decodeIfPresent(Int.self, forKey: .width)
        height = try row.decodeIfPresent(Int.self, forKey: .height)
        likeCount = try row.decode(Int.self, forKey: .likeCount)
        hidden = try row.decodeIfPresent(Bool.self, forKey: .hidden)
        createdAt = try row.decode(Date.self, forKey: .createdAt)
        rawCreatedAt = try? row.decode(String.self, forKey: .createdAt)
        username = try row.decodeIfPresent(String.self, forKey: .username)
        displayName = try row.decodeIfPresent(String.self, forKey: .displayName)
        likedByMe = try row.decodeIfPresent(Bool.self, forKey: .likedByMe)
        let setup = try? row.decode(SoundSetup.self, forKey: .soundSetup)
        soundSetup = setup?.isValid == true ? setup : nil
        commentsEnabled = try row.decodeIfPresent(Bool.self, forKey: .commentsEnabled)
        commentCount = try row.decodeIfPresent(Int.self, forKey: .commentCount)
        backingEnabled = try row.decodeIfPresent(Bool.self, forKey: .backingEnabled)
        sourceVideoId = try row.decodeIfPresent(UUID.self, forKey: .sourceVideoId)
        sourceUsername = try row.decodeIfPresent(String.self, forKey: .sourceUsername)
        savedAt = try row.decodeIfPresent(Date.self, forKey: .savedAt)
    }

    var videoURL: URL { SocialConfig.mediaURL(videoKey) }
    var feedCursorTimestamp: String { rawCreatedAt ?? ISO8601DateFormatter.feed.string(from: createdAt) }
    var thumbURL: URL { SocialConfig.mediaURL(thumbKey) }
    var watchURL: URL {
        var url = URLComponents(url: SocialConfig.watchURL, resolvingAgainstBaseURL: false)!
        url.queryItems = [URLQueryItem(name: "v", value: id.uuidString.lowercased())]
        return url.url ?? videoURL
    }
}

/// Row the app inserts after uploading the files.
struct NewVideo: Encodable {
    let id: UUID
    let userId: UUID
    let videoKey: String
    let thumbKey: String
    let caption: String
    let instrument: String?
    let mode: String?
    let durationS: Double
    let width: Int
    let height: Int
    var soundSetup: SoundSetup? = nil
    var commentsEnabled: Bool? = nil
    var backingEnabled: Bool? = nil
    var sourceVideoId: UUID? = nil

    enum CodingKeys: String, CodingKey {
        case id, caption, instrument, mode, width, height
        case userId = "user_id"
        case videoKey = "video_key"
        case thumbKey = "thumb_key"
        case durationS = "duration_s"
        case soundSetup = "sound_setup"
        case commentsEnabled = "comments_enabled"
        case backingEnabled = "backing_enabled"
        case sourceVideoId = "source_video_id"
    }
}

struct SignUploadRequest: Encodable {
    let videoBytes: Int
    let thumbBytes: Int
}

struct VideoComment: Codable, Equatable, Identifiable {
    let id: UUID
    let videoId: UUID
    let userId: UUID
    let parentId: UUID?
    let body: String
    let createdAt: Date
    let username: String
    let replyCount: Int
    var likeCount: Int?
    var likedByMe: Bool?

    static let maxLength = 300

    mutating func applyLike(_ liked: Bool) {
        guard let count = likeCount, (likedByMe == true) != liked else { return }
        likeCount = max(0, count + (liked ? 1 : -1))
        likedByMe = liked
    }

    static func trimmed(_ input: String) -> String {
        input.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func isValidBody(_ input: String) -> Bool {
        (1...maxLength).contains(trimmed(input).unicodeScalars.count)
    }

    enum CodingKeys: String, CodingKey {
        case id, body, username
        case videoId = "video_id"
        case userId = "user_id"
        case parentId = "parent_id"
        case createdAt = "created_at"
        case replyCount = "reply_count"
        case likeCount = "like_count"
        case likedByMe = "liked_by_me"
    }
}

enum CommentReportReason: String, CaseIterable, Identifiable {
    case harassment, sexual, violence, spam, other
    var id: Self { self }

    var title: String {
        switch self {
        case .harassment: return "Hate or harassment"
        case .sexual: return "Sexual content"
        case .violence: return "Violence or self-harm"
        case .spam: return "Spam or scam"
        case .other: return "Something else"
        }
    }
}

struct CreatorActivity: Decodable, Identifiable {
    let id: UUID
    let videoId: UUID
    let commentId: UUID?
    let kind: Kind
    let createdAt: Date
    let timestamp: String
    var readAt: Date?
    let username: String
    let body: String
    let likeCount: Int?

    enum Kind: String, Decodable {
        case comment, reply
        case videoLike = "video_like"
        case commentLike = "comment_like"
        case replyLike = "reply_like"

        var isLike: Bool { self != .comment && self != .reply }

        var icon: String {
            switch self {
            case .comment: return "bubble.left"
            case .reply: return "arrowshape.turn.up.left"
            default: return "heart.fill"
            }
        }

        var commentAction: String {
            self == .reply || self == .replyLike ? "View reply" : "View comment"
        }
    }

    var title: String {
        let actor = "@\(username)"
        let others = max(0, (likeCount ?? 1) - 1)
        let who = others == 0 ? actor : "\(actor) and \(others) \(others == 1 ? "other" : "others")"
        switch kind {
        case .comment: return "\(actor) commented on your video"
        case .reply: return "\(actor) replied to you"
        case .videoLike: return "\(who) liked your video"
        case .commentLike: return "\(who) liked your comment"
        case .replyLike: return "\(who) liked your reply"
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, kind, username, body
        case videoId = "video_id"
        case commentId = "comment_id"
        case createdAt = "created_at"
        case readAt = "read_at"
        case likeCount = "like_count"
    }

    init(from decoder: Decoder) throws {
        let row = try decoder.container(keyedBy: CodingKeys.self)
        id = try row.decode(UUID.self, forKey: .id)
        videoId = try row.decode(UUID.self, forKey: .videoId)
        commentId = try row.decodeIfPresent(UUID.self, forKey: .commentId)
        kind = try row.decode(Kind.self, forKey: .kind)
        createdAt = try row.decode(Date.self, forKey: .createdAt)
        timestamp = (try? row.decode(String.self, forKey: .createdAt)) ?? ISO8601DateFormatter.feed.string(from: createdAt)
        readAt = try row.decodeIfPresent(Date.self, forKey: .readAt)
        username = try row.decode(String.self, forKey: .username)
        body = try row.decode(String.self, forKey: .body)
        likeCount = try row.decodeIfPresent(Int.self, forKey: .likeCount)
    }
}

struct PublicCreator: Decodable, Identifiable {
    let id: UUID
    let username: String
    let displayName: String?
    enum CodingKeys: String, CodingKey {
        case id, username
        case displayName = "display_name"
    }

    init?(visibleVideo: Video) {
        guard let username = visibleVideo.username else { return nil }
        id = visibleVideo.userId
        self.username = username
        displayName = visibleVideo.displayName
    }
}

struct PostSearch: Equatable {
    let text: String
    let filter: String

    init?(_ input: String) {
        let cleaned = input.replacingOccurrences(of: "\0", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        let byHandle = cleaned.hasPrefix("@")
        let text = String((byHandle ? cleaned.dropFirst() : cleaned[...]).prefix(80))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count >= 2 else { return nil }
        self.text = text

        // Escape the literal pattern first, then quote it for PostgREST's logic grammar.
        let metacharacters = "\\.^$|?*+()[]{}"
        let pattern = text.map { metacharacters.contains($0) ? "\\\($0)" : String($0) }.joined()
        let quoted = pattern.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let columns = byHandle ? ["username"] : ["caption", "instrument", "username", "display_name"]
        filter = columns.map { "\($0).imatch.\"\(quoted)\"" }.joined(separator: ",")
    }

    func filter(after cursor: String?) -> String {
        guard let cursor else { return filter }
        return "and(or(\(filter)),or(\(cursor)))"
    }
}

struct BackingCredit: Codable, Equatable {
    let videoId: UUID
    let username: String
}

struct WeeklyChallenge: Decodable, Identifiable {
    let id: UUID
    let sourceVideoID: UUID
    let title: String
    let prompt: String
    let endsAt: Date

    enum CodingKeys: String, CodingKey {
        case id, title, prompt
        case sourceVideoID = "source_video_id"
        case endsAt = "ends_at"
    }
}

enum PerformanceLink: Equatable {
    case watch(UUID), comments(UUID), sound(UUID), playAlong(UUID)

    init?(url: URL) {
        guard let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              parts.user == nil, parts.password == nil, parts.port == nil else { return nil }
        if parts.scheme == "https", parts.host == SocialConfig.watchURL.host,
           ["/watch", "/watch/"].contains(parts.path) {
            let IDs = parts.queryItems?.filter { $0.name == "v" } ?? []
            guard IDs.count == 1, let value = IDs.first?.value, let id = UUID(uuidString: value) else { return nil }
            self = .watch(id)
            return
        }
        guard parts.scheme == "handstrudel", let kind = parts.host, url.pathComponents.count == 2,
              let id = UUID(uuidString: url.lastPathComponent) else { return nil }
        switch kind {
        case "watch": self = .watch(id)
        case "comments": self = .comments(id)
        case "sound": self = .sound(id)
        case "play": self = .playAlong(id)
        default: return nil
        }
    }

    var videoID: UUID {
        switch self {
        case .watch(let id), .comments(let id), .sound(let id), .playAlong(let id): return id
        }
    }
}

struct SignUploadResponse: Decodable {
    let id: UUID
    let videoKey: String
    let thumbKey: String
    let videoUploadUrl: URL
    let thumbUploadUrl: URL
}
