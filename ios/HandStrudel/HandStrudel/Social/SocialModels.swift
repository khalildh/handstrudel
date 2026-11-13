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
    // Joined in the `feed_videos` view only.
    var username: String?
    var likedByMe: Bool?

    enum CodingKeys: String, CodingKey {
        case id, caption, instrument, mode, width, height, hidden, username
        case userId = "user_id"
        case videoKey = "video_key"
        case thumbKey = "thumb_key"
        case durationS = "duration_s"
        case likeCount = "like_count"
        case createdAt = "created_at"
        case likedByMe = "liked_by_me"
    }

    var videoURL: URL { SocialConfig.mediaURL(videoKey) }
    var thumbURL: URL { SocialConfig.mediaURL(thumbKey) }
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

    enum CodingKeys: String, CodingKey {
        case id, caption, instrument, mode, width, height
        case userId = "user_id"
        case videoKey = "video_key"
        case thumbKey = "thumb_key"
        case durationS = "duration_s"
    }
}

struct SignUploadRequest: Encodable {
    let videoBytes: Int
    let thumbBytes: Int
}

struct SignUploadResponse: Decodable {
    let id: UUID
    let videoKey: String
    let thumbKey: String
    let videoUploadUrl: URL
    let thumbUploadUrl: URL
}
