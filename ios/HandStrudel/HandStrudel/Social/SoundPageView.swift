import Supabase
import SwiftUI

// MARK: - Model

/// Header facts for a sound page: which sound a post belongs to, how many visible takes
/// it has, and its original post when the viewer can still see it.
struct SoundSummary: Decodable, Equatable {
    let soundID: UUID
    let takeCount: Int
    let originalVideoID: UUID?

    enum CodingKeys: String, CodingKey {
        case soundID = "sound_id"
        case takeCount = "take_count"
        case originalVideoID = "original_video_id"
    }
}

struct SoundTakeCount: Decodable, Equatable {
    let videoID: UUID
    let takeCount: Int

    enum CodingKeys: String, CodingKey {
        case videoID = "video_id"
        case takeCount = "take_count"
    }
}

enum SoundTakeOrder: String, CaseIterable, Identifiable {
    case top, recent
    var id: Self { self }
    var title: String { self == .top ? "Top" : "Recent" }
}

enum SoundPageText {
    /// "1 take", "23 takes", "1.2K takes".
    static func takes(_ count: Int) -> String {
        count == 1 ? "1 take" : "\(count.formatted(.number.notation(.compactName))) takes"
    }

    /// The feed's sound row, e.g. "Rhodes · C Minor · 23 takes". The count shows once a
    /// sound has more than one take.
    static func row(title: String, keyAndScale: String?, takes count: Int?) -> String {
        var parts = [title]
        if let keyAndScale { parts.append(keyAndScale) }
        if let count, count > 1 { parts.append(takes(count)) }
        return parts.joined(separator: " · ")
    }

    /// Cursor for the next page of a sound's takes, matching the view's sort order.
    static func cursor(after last: Video, order: SoundTakeOrder) -> String {
        let id = last.id.uuidString.lowercased()
        switch order {
        case .top:
            return "like_count.lt.\(last.likeCount),and(like_count.eq.\(last.likeCount),id.lt.\(id))"
        case .recent:
            let ts = last.feedCursorTimestamp
            return "created_at.lt.\(ts),and(created_at.eq.\(ts),id.lt.\(id))"
        }
    }
}

extension FeedService {
    static let soundPageSize = 24

    static func soundSummary(for video: UUID) async throws -> SoundSummary? {
        struct Parameters: Encodable { let target_video: UUID }
        let rows: [SoundSummary] = try await supabase.rpc("sound_summary", params: Parameters(target_video: video))
            .execute().value
        return rows.first
    }

    static func soundTakeCounts(for videos: [UUID]) async throws -> [SoundTakeCount] {
        struct Parameters: Encodable { let target_videos: [UUID] }
        return try await supabase.rpc("sound_take_counts", params: Parameters(target_videos: videos)).execute().value
    }

    /// One page of a sound's visible takes, keyset-paged (no OFFSET).
    static func soundTakes(sound: UUID, order: SoundTakeOrder, after last: Video?) async throws -> [Video] {
        var query = supabase.from("sound_takes").select().eq("sound_id", value: sound)
        if let last { query = query.or(SoundPageText.cursor(after: last, order: order)) }
        let sorted = order == .top
            ? query.order("like_count", ascending: false).order("id", ascending: false)
            : query.order("created_at", ascending: false).order("id", ascending: false)
        return try await sorted.limit(soundPageSize).execute().value
    }
}

/// Take counts for the feed's sound rows. Rows ask for their post's count as they appear;
/// requests made together are sent as one batch.
@MainActor
final class SoundTakeCounts: ObservableObject {
    static let shared = SoundTakeCounts()

    @Published private(set) var counts: [UUID: Int] = [:]
    private var requested = Set<UUID>()
    private var pending: [UUID] = []
    private var flush: Task<Void, Never>?

    func request(_ video: UUID) {
        guard SocialConfig.isConfigured, requested.insert(video).inserted else { return }
        pending.append(video)
        guard flush == nil else { return }
        flush = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 80_000_000)
            await self?.send()
        }
    }

    func record(_ count: Int, for video: UUID) { counts[video] = count }

    private func send() async {
        flush = nil
        let batch = Array(pending.prefix(50))
        pending.removeFirst(batch.count)
        if !pending.isEmpty, flush == nil {
            flush = Task { [weak self] in await self?.send() }
        }
        guard !batch.isEmpty, let rows = try? await FeedService.soundTakeCounts(for: batch) else { return }
        for row in rows { counts[row.videoID] = row.takeCount }
    }
}

// MARK: - Feed row

/// The sound chip on a feed post: instrument, key and, once a sound has company, its take count.
struct FeedSoundRow: View {
    @Environment(\.studioPalette) private var palette
    @ObservedObject private var counts = SoundTakeCounts.shared
    let video: Video
    let action: () -> Void

    private var text: String {
        SoundPageText.row(title: video.soundSetup?.instrumentName ?? video.instrument ?? "Sound",
                          keyAndScale: video.soundSetup?.keyAndScale, takes: counts.counts[video.id])
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "waveform")
                Text(text).lineLimit(1)
                Image(systemName: "chevron.up").font(.system(size: 9, weight: .bold))
            }
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .foregroundStyle(palette.mediaAccent)
            .background(.black.opacity(0.66), in: Capsule())
            .overlay { Capsule().strokeBorder(.white.opacity(0.18)) }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Sound: \(text)")
        .accessibilityHint("Opens the sound page")
        .accessibilityIdentifier("feed-sound-options")
        .task(id: video.id) { counts.request(video.id) }
    }
}

// MARK: - Sound page

/// Everyone's takes on one sound, with a big "Play this sound" to make your own.
struct SoundPageView: View {
    @Environment(\.studioPalette) private var palette
    @Environment(\.isSoundLocked) private var isSoundLocked
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.dismiss) private var dismiss
    /// The post the page was opened from.
    let video: Video
    @ObservedObject var auth: AuthManager
    let onStart: (PerformanceStart) -> Void

    @State private var summary: SoundSummary?
    @State private var summaryLoaded = false
    @State private var original: Video?
    @State private var order: SoundTakeOrder = .top
    @State private var takes: [Video] = []
    @State private var more = false
    @State private var loading = false
    @State private var generation = 0
    @State private var failed = false
    @State private var selected: Video?
    @State private var saved = false

    /// Whose setup the page describes: the original when visible, else the post it was opened from.
    private var reference: Video {
        if let original { return original }
        if video.soundSetup == nil, let take = takes.first(where: { $0.soundSetup != nil }) { return take }
        return video
    }
    private var setup: SoundSetup? { reference.soundSetup }
    private var title: String { setup?.instrumentName ?? reference.instrument ?? "Sound" }
    private var savedName: String { reference.username.map { "\(title) by @\($0)" } ?? title }
    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 5), count: typeSize.isAccessibilitySize ? 2 : 3)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    actions
                    takesSection
                }
                .frame(maxWidth: 560, alignment: .leading)
                .padding(.horizontal, 18)
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity)
            }
            .background(palette.background.ignoresSafeArea())
            .navigationTitle("Sound")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    ShareLink(item: reference.watchURL, subject: Text(title),
                              message: Text("Play this sound on HandStrudel")) {
                        Label("Share sound", systemImage: "square.and.arrow.up")
                    }
                    .accessibilityValue(reference.watchURL.absoluteString)
                    .accessibilityIdentifier("sound-page-share")
                }
            }
        }
        .tint(palette.accent)
        .foregroundStyle(palette.ink)
        .presentationDragIndicator(.visible)
        .task(id: order) { await load(reset: true) }
        .sheet(item: $selected) { take in
            CreatorVideoView(video: take, auth: auth, onPlayAlong: { source in
                selected = nil
                onStart(.backing(source))
            }, onTrySound: { sound in
                selected = nil
                onStart(.preset(sound))
            }, playlist: takes)
        }
        .onAppear {
            guard let setup else { return }
            saved = PersistenceManager.shared.loadSetups().contains {
                $0.sound == setup && $0.name == String(savedName.prefix(40))
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            RoundedRectangle(cornerRadius: 16)
                .fill(palette.surface)
                .overlay { Image(systemName: "waveform").font(.title).foregroundStyle(palette.accent) }
                .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(palette.border) }
                .frame(width: 84, height: 84)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text(verbatim: title)
                    .font(.system(.title2, design: .serif).weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("sound-page-title")
                if let setup {
                    Text(setup.presetDetails)
                        .font(.subheadline.monospaced())
                        .foregroundStyle(palette.muted)
                }
                attribution
                if let summary {
                    Text(SoundPageText.takes(summary.takeCount))
                        .font(.subheadline.weight(.semibold))
                        .accessibilityIdentifier("sound-page-take-count")
                }
                if let setup, isSoundLocked(setup) { ProSoundBadge() }
            }
        }
    }

    @ViewBuilder private var attribution: some View {
        if let original, let username = original.username {
            Button { selected = original } label: {
                Text("Original sound by ") + Text("@\(username)").fontWeight(.semibold)
            }
            .buttonStyle(.plain)
            .font(.subheadline)
            .foregroundStyle(palette.accent)
            .accessibilityHint("Plays the original post")
            .accessibilityIdentifier("sound-page-original")
        } else if summaryLoaded, summary != nil {
            Text("The original post isn't available")
                .font(.subheadline)
                .foregroundStyle(palette.muted)
        }
    }

    private var actions: some View {
        VStack(spacing: 10) {
            if let setup {
                let locked = isSoundLocked(setup)
                Button(locked ? "Unlock & play" : "Play this sound",
                       systemImage: locked ? "lock.open.fill" : "play.fill") {
                    Funnel.playThisSoundTapped()
                    onStart(.preset(setup))
                }
                    .buttonStyle(ProfileActionStyle(primary: true))
                    .accessibilityHint(locked ? "Unlock Pro, then open this setup in the Music tab" : "Opens this setup in the Music tab")
                    .accessibilityIdentifier("play-clip-preset")
            }
            if let reply = ReplyTakeRequest(video: reference) {
                Button("Reply with a take", systemImage: "arrowshape.turn.up.left") { onStart(.reply(reply)) }
                    .buttonStyle(ProfileActionStyle())
                    .accessibilityHint("Opens this sound and posts your next take as a reply")
                    .accessibilityIdentifier("reply-with-take")
            }
            if let learn = LearnToPlayRequest(video: reference) {
                Button("Learn to play", systemImage: "graduationcap") { onStart(.learn(learn)) }
                    .buttonStyle(ProfileActionStyle())
                    .accessibilityHint("Teaches the notes from this performance in Learn mode")
                    .accessibilityIdentifier("learn-clip-notes")
            }
            if reference.backingEnabled == true {
                Button("Play along", systemImage: "waveform.badge.plus") { onStart(.backing(reference)) }
                    .buttonStyle(ProfileActionStyle(primary: setup == nil))
                    .accessibilityHint("Uses this clip as a backing track")
                    .accessibilityIdentifier("play-along")
            }
            if let setup {
                Button(saved ? "Preset saved" : "Save preset privately", systemImage: saved ? "checkmark" : "bookmark") {
                    PersistenceManager.shared.addPreset(setup, named: savedName)
                    saved = true
                }
                .buttonStyle(ProfileActionStyle())
                .disabled(saved)
                .accessibilityIdentifier("save-clip-preset")
            }
        }
    }

    @ViewBuilder private var takesSection: some View {
        Picker("Sort takes", selection: $order) {
            ForEach(SoundTakeOrder.allCases) { Text($0.title).tag($0) }
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("sound-take-order")

        if takes.isEmpty && !loading {
            Text(failed ? "Couldn't load takes." : "No takes to show yet.")
                .font(.footnote)
                .foregroundStyle(palette.muted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            if failed {
                Button("Try again") { Task { await load(reset: true) } }.buttonStyle(ProfileActionStyle())
            }
        } else {
            LazyVGrid(columns: columns, spacing: 5) {
                ForEach(takes) { take in
                    SoundTakeTile(video: take, isOriginal: take.id == summary?.soundID) { selected = take }
                        .onAppear {
                            if take.id == takes.last?.id { Task { await load(reset: false) } }
                        }
                }
            }
            .accessibilityIdentifier("sound-page-takes")
        }
        if loading { ProgressView().frame(maxWidth: .infinity).padding(.vertical, 12) }
    }

    /// Loads the first page (reset) or the next one. A reset starts a new generation, so a
    /// page still in flight for the previous sort order is dropped instead of appended.
    private func load(reset: Bool) async {
        if reset {
            generation += 1
            takes = []
            more = false
        } else if loading || !more {
            return
        }
        let request = generation
        let requestOrder = order
        let after = reset ? nil : takes.last
        loading = true
        defer { if request == generation { loading = false } }
        do {
            if !summaryLoaded {
                let loaded = try await FeedService.soundSummary(for: video.id)
                if !summaryLoaded {
                    summary = loaded
                    summaryLoaded = true
                    if let loaded {
                        SoundTakeCounts.shared.record(loaded.takeCount, for: video.id)
                        if let id = loaded.originalVideoID {
                            original = id == video.id ? video : try await FeedService.video(id: id)
                        }
                    }
                }
            }
            guard request == generation else { return }
            guard let sound = summary?.soundID else { return }
            let page = try await FeedService.soundTakes(sound: sound, order: requestOrder, after: after)
            guard request == generation, !Task.isCancelled else { return }
            let known = Set(takes.map(\.id))
            takes += page.filter { !known.contains($0.id) }
            more = page.count == FeedService.soundPageSize
            failed = false
        } catch {
            if request == generation, !Task.isCancelled { failed = true }
        }
    }
}

private struct SoundTakeTile: View {
    @Environment(\.studioPalette) private var palette
    let video: Video
    let isOriginal: Bool
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            Rectangle()
                .fill(palette.surface)
                .aspectRatio(9 / 16, contentMode: .fit)
                .overlay { Image(systemName: "waveform").foregroundStyle(palette.accent.opacity(0.8)) }
                .overlay {
                    GeometryReader { proxy in
                        ProfileImage(resource: .init(url: video.thumbURL, kind: .thumbnail)) { image in
                            image.resizable().scaledToFill()
                                .frame(width: proxy.size.width, height: proxy.size.height)
                                .clipped()
                        }
                    }
                }
                .overlay(alignment: .topLeading) {
                    if isOriginal {
                        Text("Original")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(palette.mediaAccent, in: Capsule())
                            .foregroundStyle(palette.mediaOnAccent)
                            .padding(6)
                    }
                }
                .overlay(alignment: .bottomLeading) {
                    VStack(alignment: .leading, spacing: 1) {
                        Label(video.likeCount.formatted(.number.notation(.compactName)), systemImage: "heart.fill")
                        Text("@\(video.username ?? "user")").lineLimit(1)
                    }
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.7), radius: 3)
                    .padding(6)
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("sound-take")
    }

    private var accessibilityText: String {
        var parts = [isOriginal ? "Original by @\(video.username ?? "user")" : "Take by @\(video.username ?? "user")"]
        parts.append(video.likeCount == 1 ? "1 like" : "\(video.likeCount) likes")
        if !video.caption.isEmpty { parts.append(video.caption) }
        return parts.joined(separator: ", ")
    }
}
