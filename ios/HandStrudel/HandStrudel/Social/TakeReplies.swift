import SwiftUI

/// The post a take answers. Kept with a private draft so the reply link survives until posting.
struct ReplyTarget: Codable, Equatable, Hashable {
    let videoId: UUID
    let username: String
}

/// Asks the Music tab to open a post's sound and record the next take as a reply to it.
/// Mirrors `LearnToPlayRequest`: the caller sends it, then opens `setup` like "Play this sound".
struct ReplyTakeRequest {
    let target: ReplyTarget
    let setup: SoundSetup

    init?(video: Video) {
        guard let setup = video.soundSetup, let username = video.username, !username.isEmpty else { return nil }
        target = ReplyTarget(videoId: video.id, username: username)
        self.setup = setup
    }

    func send() { NotificationCenter.default.post(name: .replyWithTake, object: self) }
}

extension Notification.Name {
    static let replyWithTake = Notification.Name("replyWithTake")
}

/// "Challenge a friend": the post's universal link plus a marker that opens the reply recorder.
enum ChallengeLink {
    static let marker = URLQueryItem(name: "reply", value: "1")

    static func url(for videoID: UUID) -> URL {
        var url = URLComponents(url: SocialConfig.watchURL, resolvingAgainstBaseURL: false)!
        url.queryItems = [URLQueryItem(name: "v", value: videoID.uuidString.lowercased()), marker]
        return url.url!
    }

    static func message(for video: Video) -> String {
        let sound = video.soundSetup?.instrumentName.map { " on \($0)" } ?? ""
        return "I challenge you to answer this\(sound) with your own take on HandStrudel"
    }
}

extension FeedService {
    /// Visible replies to a post, newest first. The view already hides moderated, blocked
    /// and reported clips and drops links to unavailable originals.
    static func replies(to video: UUID, limit: Int = 30) async throws -> [Video] {
        try await supabase.from("feed_videos").select()
            .eq("reply_to_id", value: video)
            .order("created_at", ascending: false).order("id", ascending: false)
            .limit(limit).execute().value
    }
}

struct ChallengeShareSheet: View {
    let video: Video

    var body: some View {
        ShareSheet(activityItems: [ChallengeLink.message(for: video), ChallengeLink.url(for: video.id)]) {
            Task { _ = try? await FeedService.recordShare(for: video.id) }
        }
    }
}

/// "Reply to @handle" credit shown on a reply wherever a post's details appear.
struct ReplyCreditButton: View {
    let username: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("Reply to @\(username)", systemImage: "arrowshape.turn.up.left")
                .lineLimit(1)
        }
        .accessibilityIdentifier("reply-credit")
        .accessibilityHint("Opens the post this take answers")
    }
}

/// Shown on a post opened from a challenge link, with the reply recorder one tap away.
struct ChallengeCard: View {
    @Environment(\.studioPalette) private var palette
    let video: Video
    let reply: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("You've been challenged", systemImage: "flag.checkered")
                .font(.headline)
            Text(reply == nil
                 ? "This post doesn't share a playable sound, so it can't be answered with a take."
                 : "Play @\(video.username ?? "this creator")'s sound and post your take as a reply.")
                .font(.subheadline)
                .foregroundStyle(palette.muted)
            if let reply {
                Button("Reply with a take", systemImage: "arrowshape.turn.up.left.fill", action: reply)
                    .buttonStyle(StudioActionStyle())
                    .accessibilityIdentifier("challenge-reply-with-take")
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("challenge-card")
    }
}

/// Horizontal strip of the takes that answered a post. Tapping one asks the host to play it,
/// so the host can pause its own clip first.
struct ReplyStrip: View {
    @Environment(\.studioPalette) private var palette
    let video: Video
    let open: (Video) -> Void
    @State private var replies: [Video] = []
    @State private var loaded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .accessibilityIdentifier("reply-count")
            ScrollView(.horizontal) {
                LazyHStack(spacing: 8) {
                    ForEach(replies) { reply in
                        Button { open(reply) } label: { tile(reply) }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Take by @\(reply.username ?? "creator")")
                            .accessibilityIdentifier("reply-clip")
                    }
                    if !loaded {
                        ProgressView().frame(width: 72, height: 112)
                    }
                }
            }
            .scrollIndicators(.hidden)
            .frame(height: 132)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("reply-strip")
        .task(id: video.id) {
            let rows = (try? await FeedService.replies(to: video.id)) ?? []
            guard !Task.isCancelled else { return }
            replies = rows
            loaded = true
        }
    }

    private var title: String {
        let count = max(video.replyCount ?? 0, replies.count)
        return count == 1 ? "1 take in reply" : "\(count.formatted()) takes in reply"
    }

    private func tile(_ reply: Video) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            AsyncImage(url: reply.thumbURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                palette.surface.overlay { Image(systemName: "waveform").foregroundStyle(palette.accent) }
            }
            .frame(width: 72, height: 108)
            .clipShape(RoundedRectangle(cornerRadius: 9))
            Text("@\(reply.username ?? "creator")")
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
                .frame(width: 72, alignment: .leading)
        }
    }
}

/// Pill in the Music tab while the next take will be posted as a reply.
struct ReplyingToPill: View {
    let target: ReplyTarget
    let cancel: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Label("Replying to @\(target.username)", systemImage: "arrowshape.turn.up.left.fill")
                .lineLimit(1)
                .padding(.leading, 12)
                .padding(.trailing, 4)
                .frame(minHeight: 44)
            Button(action: cancel) {
                Image(systemName: "xmark").frame(width: 44, height: 44)
            }
            .accessibilityLabel("Stop replying")
            .accessibilityIdentifier("cancel-reply")
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.white)
        .background(.black.opacity(0.62), in: Capsule())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("replying-to")
    }
}
