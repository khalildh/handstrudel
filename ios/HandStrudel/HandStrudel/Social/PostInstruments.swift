import Foundation
import Supabase

/// What a feed row says about the instrument a take was played on (`feed_videos`).
struct PostInstrumentSummary: Decodable, Equatable {
    enum Kind: String, Decodable {
        /// The poster made it.
        case own
        /// Played unchanged from another post (`sourceVideoID` made it).
        case copy
        /// An edited copy of `sourceVideoID`'s instrument.
        case remix
    }

    let name: String
    let kind: Kind
    let remixesAllowed: Bool
    let aiGenerated: Bool
    /// Nil when the source is gone, hidden or blocked; credit is then left out, never moved.
    let sourceVideoID: UUID?
    let sourceUsername: String?
    let remixCount: Int?

    private enum CodingKeys: String, CodingKey {
        case hasInstrument = "has_instrument"
        case name = "instrument_spec_name"
        case kind = "instrument_kind"
        case remixesAllowed = "instrument_remixes_allowed"
        case aiGenerated = "instrument_ai_generated"
        case sourceVideoID = "instrument_source_id"
        case sourceUsername = "instrument_source_username"
        case remixCount = "instrument_remix_count"
    }

    private struct Absent: Error {}

    init(name: String, kind: Kind, remixesAllowed: Bool = true, aiGenerated: Bool = false,
         sourceVideoID: UUID? = nil, sourceUsername: String? = nil, remixCount: Int? = nil) {
        self.name = name
        self.kind = kind
        self.remixesAllowed = remixesAllowed
        self.aiGenerated = aiGenerated
        self.sourceVideoID = sourceVideoID
        self.sourceUsername = sourceUsername
        self.remixCount = remixCount
    }

    init(from decoder: Decoder) throws {
        let row = try decoder.container(keyedBy: CodingKeys.self)
        guard try row.decodeIfPresent(Bool.self, forKey: .hasInstrument) == true else { throw Absent() }
        name = try row.decodeIfPresent(String.self, forKey: .name) ?? "Instrument"
        kind = (try? row.decode(Kind.self, forKey: .kind)) ?? .copy
        remixesAllowed = try row.decodeIfPresent(Bool.self, forKey: .remixesAllowed) ?? false
        aiGenerated = try row.decodeIfPresent(Bool.self, forKey: .aiGenerated) ?? false
        sourceVideoID = try row.decodeIfPresent(UUID.self, forKey: .sourceVideoID)
        sourceUsername = try row.decodeIfPresent(String.self, forKey: .sourceUsername)
        remixCount = try row.decodeIfPresent(Int.self, forKey: .remixCount)
    }

    /// "Instrument by @creator" (or "Remix by @poster"), when the creator can be shown.
    func credit(poster: String?) -> String? {
        switch kind {
        case .own: return poster.map { "Instrument by @\($0)" }
        case .copy: return sourceUsername.map { "Instrument by @\($0)" }
        case .remix: return poster.map { "Remix by @\($0)" }
        }
    }

    var remixLine: String? {
        guard kind == .remix, let sourceUsername else { return nil }
        return "Remix of @\(sourceUsername)'s instrument"
    }

    var remixCountLine: String? {
        guard let remixCount, remixCount > 0 else { return nil }
        return remixCount == 1 ? "1 remix" : "\(remixCount) remixes"
    }
}

/// One step of an instrument's remix chain, newest first (depth 0 is the post itself).
struct InstrumentChainLink: Decodable, Equatable, Identifiable {
    let depth: Int
    let videoID: UUID
    let username: String?
    let instrumentName: String?
    let kind: PostInstrumentSummary.Kind?
    var id: UUID { videoID }

    enum CodingKeys: String, CodingKey {
        case depth, username
        case videoID = "video_id"
        case instrumentName = "instrument_name"
        case kind = "instrument_kind"
    }
}

/// Asks the Music tab to play a post's instrument. With `sound`, the post's sound too
/// ("Play this exactly"); without it the player's own sound stays.
struct PlayInstrumentRequest {
    let document: InstrumentDocument
    let sourceVideoID: UUID?
    let sound: SoundSetup?

    func send() { NotificationCenter.default.post(name: .playPostInstrument, object: self) }
}

extension Notification.Name {
    static let playPostInstrument = Notification.Name("playPostInstrument")
}

extension FeedService {
    /// A post's instrument file, read when a viewer plays, saves or remixes it, and validated by
    /// the loader before anything uses it.
    static func instrument(for video: UUID) async throws -> InstrumentDocument {
        struct Row: Decodable { let instrument_spec: InstrumentJSON? }
        let rows: [Row] = try await supabase.from("videos").select("instrument_spec")
            .eq("id", value: video).limit(1).execute().value
        guard let json = rows.first?.instrument_spec, json != .null else {
            throw SocialError.message("This post's instrument is no longer available.")
        }
        return try InstrumentDocument(json: json)
    }

    static func instrumentChain(for video: UUID) async throws -> [InstrumentChainLink] {
        struct Parameters: Encodable { let target_video: UUID }
        return try await supabase.rpc("instrument_remix_chain", params: Parameters(target_video: video)).execute().value
    }
}
