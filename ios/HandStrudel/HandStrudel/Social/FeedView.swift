import AVFoundation
import AVKit
import SwiftUI
import UIKit

private enum PerformanceStart {
    case backing(Video)
    case preset(SoundSetup)
}

/// Full-screen, vertically paged feed of public posts (newest first).
/// Browsable signed out; liking, following, reporting and blocking need an account.
struct FeedView: View {
    @ObservedObject var auth: AuthManager
    let isActive: Bool
    let onMakeMusic: () -> Void
    let onTrySound: (SoundSetup) -> Void
    let onPlayAlong: (Video) -> Void
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var model = FeedModel()
    @State private var showSignIn = false
    @State private var reporting: Video?
    @State private var commenting: Video?
    @State private var lastCommentVideo: UUID?
    @State private var toast: String?
    @State private var muted = true
    @State private var showActivity = false
    @State private var unreadActivity = false
    @State private var creatorVideo: Video?
    @State private var sourceVideo: Video?
    @State private var showSaved = false
    @State private var challenge: WeeklyChallenge?
    @State private var openChallenge: WeeklyChallenge?
    @State private var pendingStart: PerformanceStart?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            topBar
            if let challenge, !model.followingOnly {
                Button { openChallenge = challenge } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "waveform").foregroundStyle(StudioStyle.accent)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("WEEKLY PLAY-ALONG").font(.caption2.monospaced().weight(.semibold))
                                .foregroundStyle(StudioStyle.accent)
                            Text(verbatim: challenge.title).font(.subheadline.bold()).lineLimit(1)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(StudioStyle.surface, in: RoundedRectangle(cornerRadius: 13))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("weekly-challenge")
            }
            ZStack(alignment: .top) {
                if model.videos.isEmpty {
                    emptyState
                } else {
                    PagedFeed(videos: model.videos, current: $model.current) { video, isCurrent in
                        FeedCell(video: video, isCurrent: isActive && scenePhase == .active && isCurrent
                                 && commenting == nil && !showActivity && creatorVideo == nil && sourceVideo == nil
                                 && !showSaved && openChallenge == nil,
                                 isMine: video.userId == auth.userId,
                                 isFollowing: model.following.contains(video.userId),
                                 isSaved: model.savedIDs.contains(video.id),
                                 muted: muted, toggleMute: { muted.toggle() },
                                 like: { act { try await model.toggleLike(video, user: $0) } },
                                 follow: { act { try await model.toggleFollow(video.userId, user: $0) } },
                                 report: { requireSignIn { _ in reporting = video } },
                                 block: { act { try await model.block(video.userId, user: $0); show("Blocked @\(video.username ?? "user")") } },
                                 delete: { Task { try? await model.delete(video) } }, onTrySound: onTrySound,
                                 comments: { openComments(video) },
                                 creator: { creatorVideo = video },
                                 bookmark: {
                                     act { uid in
                                         let saved = try await model.toggleBookmark(video.id, user: uid)
                                         if let saved { show(saved ? "Saved privately." : "Removed from Saved.") }
                                     }
                                 },
                                 playAlong: { onPlayAlong(video) },
                                 revokeBacking: {
                                     act { _ in
                                         try await FeedService.stopAllowingBacking(video: video.id)
                                         await model.refreshVideoControls(for: video.id)
                                         show("New play-along posts are off.")
                                     }
                                 },
                                 source: { id in Task { await openSource(id) } })
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay { RoundedRectangle(cornerRadius: 20).strokeBorder(StudioStyle.border).allowsHitTesting(false) }
                    .onChange(of: model.current) { i in
                        if i >= model.videos.count - 3 { Task { await model.loadMore() } }
                    }
                }
                if let toast {
                    Text(toast)
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(.ultraThinMaterial, in: Capsule()).padding(12)
                        .transition(.opacity)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 9)
        .padding(.bottom, 10)
        .background(StudioStyle.background.ignoresSafeArea())
        .foregroundStyle(StudioStyle.ink)
        .task(id: FeedRefresh(user: auth.userId, following: model.followingOnly)) {
            await model.refresh(user: auth.userId)
            await refreshBadge()
        }
        .task(id: ChallengeRefresh(user: auth.userId, visible: isActive && scenePhase == .active)) {
            challenge = nil
            guard isActive, scenePhase == .active else { return }
            let featured = try? await FeedService.weeklyChallenge()
            if !Task.isCancelled { challenge = featured }
        }
        .task(id: isActive && scenePhase == .active && auth.isSignedIn && !showActivity) {
            guard isActive, scenePhase == .active, auth.isSignedIn, !showActivity else { return }
            await refreshBadge()
        }
        .onChange(of: auth.userId) { uid in
            unreadActivity = false
            showSaved = false
            openChallenge = nil
            if uid == nil { model.followingOnly = false }
        }
        .sheet(isPresented: $showSignIn) { SignInView(auth: auth, reason: "Sign in to save performances and join the community.") }
        .sheet(isPresented: $showSaved, onDismiss: resumePerformance) {
            PerformanceLibraryView(kind: .saved, auth: auth,
                                   onRemove: { id in model.removedBookmark(id) }) { start in
                pendingStart = start
                showSaved = false
            }
        }
        .sheet(item: $openChallenge, onDismiss: resumePerformance) { challenge in
            PerformanceLibraryView(kind: .challenge(challenge), auth: auth) { start in
                pendingStart = start
                openChallenge = nil
            }
        }
        .sheet(item: $commenting, onDismiss: {
            if let id = lastCommentVideo { Task { await model.refreshVideoControls(for: id) } }
        }) { video in
            CommentsView(video: video, auth: auth) { author in
                model.removeBlockedAuthor(author)
                if author == video.userId { commenting = nil }
            }
        }
        .sheet(isPresented: $showActivity, onDismiss: { Task { await refreshBadge() } }) {
            ActivityInboxView(auth: auth)
        }
        .sheet(item: $creatorVideo, onDismiss: resumePerformance) { video in
            PublicCreatorView(creatorId: video.userId, auth: auth, onFollowChange: {
                Task { await model.refresh(user: auth.userId) }
            }) { start in
                pendingStart = start
                creatorVideo = nil
            }
        }
        .sheet(item: $sourceVideo, onDismiss: resumePerformance) { video in
            CreatorVideoView(video: video, auth: auth, onPlayAlong: { source in
                pendingStart = .backing(source)
                sourceVideo = nil
            }, onTrySound: { sound in
                pendingStart = .preset(sound)
                sourceVideo = nil
            })
        }
        .confirmationDialog("Report this post", isPresented: Binding(
            get: { reporting != nil }, set: { if !$0 { reporting = nil } }), titleVisibility: .visible) {
            ForEach(FeedService.ReportReason.allCases) { reason in
                Button(reason.rawValue) {
                    guard let v = reporting else { return }
                    act { try await model.report(v, reason: reason, user: $0); show("Thanks — we'll review it within 24 hours") }
                }
            }
        } message: { Text("Reports are anonymous. Posts with several reports are hidden while we review them.") }
    }

    private func resumePerformance() {
        guard let start = pendingStart else { return }
        pendingStart = nil
        switch start {
        case .backing(let video): onPlayAlong(video)
        case .preset(let sound): onTrySound(sound)
        }
    }

    private var topBar: some View {
        ViewThatFits(in: .horizontal) {
            HStack { feedTitle; Spacer(minLength: 8); feedPicker; feedActions }
            VStack(spacing: 8) {
                HStack { feedTitle; Spacer(); feedActions }
                feedPicker
            }
        }
        .padding(.horizontal, 9)
    }

    private var feedTitle: some View {
        Text("Feed")
            .font(.system(size: 33, weight: .regular, design: .serif))
            .accessibilityAddTraits(.isHeader)
            .fixedSize(horizontal: true, vertical: false)
    }

    private var feedPicker: some View {
        Picker("Feed", selection: $model.followingOnly) {
            Text("Latest").tag(false)
            Text("Following").tag(true)
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 190)
        .accessibilityIdentifier("feed-filter")
    }

    private var feedActions: some View {
        HStack(spacing: 0) {
            Button {
                requireSignIn { _ in showSaved = true }
            } label: {
                Image(systemName: "bookmark").font(.system(size: 18, weight: .semibold)).frame(width: 44, height: 44)
            }
            .accessibilityLabel("Saved performances")
            .accessibilityIdentifier("saved-performances")
            Button {
                requireSignIn { _ in showActivity = true }
            } label: {
                Image(systemName: "bell").font(.system(size: 19, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .overlay(alignment: .topTrailing) {
                        if unreadActivity { Circle().fill(StudioStyle.accent).frame(width: 7, height: 7).padding(7) }
                    }
            }
            .accessibilityLabel(unreadActivity ? "Activity, unread" : "Activity")
            .accessibilityIdentifier("activity-inbox")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            if model.loading {
                ProgressView("Loading videos")
            } else {
                Image(systemName: "play.rectangle").font(.system(size: 40)).foregroundStyle(StudioStyle.accent)
                Text(model.error ?? (model.followingOnly ? "No performances from creators you follow yet" : "No performances yet"))
                    .font(.title3.bold()).multilineTextAlignment(.center)
                if model.followingOnly {
                    if !auth.isSignedIn {
                        Button("Sign in to follow creators") { showSignIn = true }.buttonStyle(StudioActionStyle())
                    } else {
                        Button("Browse latest") { model.followingOnly = false }.buttonStyle(StudioActionStyle())
                    }
                } else if model.error == nil {
                    Button("Make the first one", action: onMakeMusic).buttonStyle(StudioActionStyle())
                }
                Button(model.error == nil ? "Refresh" : "Try again") { Task { await model.refresh(user: auth.userId) } }
                    .frame(minHeight: 44)
            }
        }
        .padding(24)
        .frame(maxWidth: 360)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func requireSignIn(_ action: @escaping (UUID) -> Void) {
        guard let uid = auth.userId, !auth.needsProfileSetup else { showSignIn = true; return }
        action(uid)
    }

    private func act(_ op: @escaping (UUID) async throws -> Void) {
        requireSignIn { uid in
            Task {
                do { try await op(uid) } catch { show("Couldn't do that — \(error.localizedDescription)") }
            }
        }
    }

    private func show(_ message: String) {
        withAnimation { toast = message }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { withAnimation { if toast == message { toast = nil } } }
    }

    private func openComments(_ video: Video) {
        lastCommentVideo = video.id
        commenting = video
    }

    private func openSource(_ id: UUID) async {
        do {
            guard let video = try await FeedService.video(id: id) else {
                show("The original performance is unavailable.")
                return
            }
            sourceVideo = video
        } catch {
            show("Couldn't open the original performance.")
        }
    }

    private func refreshBadge() async {
        guard let viewer = auth.userId else { unreadActivity = false; return }
        let unread = (try? await FeedService.hasUnreadActivity()) ?? false
        if !Task.isCancelled && auth.userId == viewer { unreadActivity = unread }
    }
}

private struct FeedRefresh: Equatable {
    let user: UUID?
    let following: Bool
}

private struct ChallengeRefresh: Equatable {
    let user: UUID?
    let visible: Bool
}

// MARK: - Model

@MainActor
final class FeedModel: ObservableObject {
    @Published var videos: [Video] = []
    @Published var current = 0
    @Published var following: Set<UUID> = []
    @Published var loading = false
    @Published var error: String?
    @Published var followingOnly = false
    @Published private(set) var savedIDs = Set<UUID>()
    private var reachedEnd = false
    private var generation = 0
    private var viewer: UUID?
    private var pendingLikes = Set<UUID>()
    private var pendingFollows = Set<UUID>()
    private var pendingBookmarks = Set<UUID>()
    private var bookmarkRevision = 0
    private let writeLike: (Bool, UUID, UUID) async throws -> Void

    init(writeLike: @escaping (Bool, UUID, UUID) async throws -> Void = FeedService.setLiked) {
        self.writeLike = writeLike
    }

    func refreshVideoControls(for id: UUID) async {
        guard let fresh = try? await FeedService.video(id: id),
              let index = videos.firstIndex(where: { $0.id == id }) else { return }
        videos[index].commentCount = fresh.commentCount
        videos[index].commentsEnabled = fresh.commentsEnabled
        videos[index].backingEnabled = fresh.backingEnabled
    }

    func refresh(user: UUID?) async {
        generation += 1
        let request = generation
        let followingOnly = self.followingOnly
        if viewer != user { savedIDs = []; bookmarkRevision += 1 }
        viewer = user
        loading = true; error = nil; reachedEnd = false
        videos = []; current = 0; following = []
        defer { if request == generation { loading = false } }
        guard !followingOnly || user != nil else { return }
        do {
            let page = try await FeedService.page(followingOnly: followingOnly)
            guard !Task.isCancelled, request == generation else { return }
            videos = page
            reachedEnd = videos.count < FeedService.pageSize
            await loadBookmarks(in: page, request: request)
            await loadFollowing(in: page, request: request)
        } catch {
            if !Task.isCancelled && request == generation { self.error = "Couldn't load the feed. Check your connection." }
        }
    }

    func loadMore() async {
        guard !loading, !reachedEnd, let last = videos.last else { return }
        let request = generation
        loading = true
        defer { if request == generation { loading = false } }
        if let more = try? await FeedService.page(after: last, followingOnly: followingOnly), request == generation {
            let seen = Set(videos.map(\.id))
            videos += more.filter { !seen.contains($0.id) }
            reachedEnd = more.count < FeedService.pageSize
            await loadBookmarks(in: more, request: request)
            await loadFollowing(in: more, request: request)
        }
    }

    private func loadFollowing(in page: [Video], request: Int) async {
        guard let viewer else { return }
        let authors = Set(page.map(\.userId)).subtracting([viewer])
        let set = followingOnly ? authors : (try? await FeedService.followedAuthors(authors, user: viewer)) ?? []
        if request == generation { following.formUnion(set) }
    }

    private func loadBookmarks(in page: [Video], request: Int) async {
        guard viewer != nil else { return }
        let revision = bookmarkRevision
        let IDs = page.map(\.id)
        guard let saved = try? await FeedService.savedVideoIDs(IDs),
              request == generation, revision == bookmarkRevision else { return }
        savedIDs.subtract(IDs)
        savedIDs.formUnion(saved)
    }

    func toggleBookmark(_ id: UUID, user: UUID) async throws -> Bool? {
        guard user == viewer, pendingBookmarks.insert(id).inserted else { return nil }
        defer { pendingBookmarks.remove(id) }
        bookmarkRevision += 1
        let save = !savedIDs.contains(id)
        try await FeedService.setBookmark(save, video: id, user: user)
        guard viewer == user else { return nil }
        bookmarkRevision += 1
        if save { savedIDs.insert(id) } else { savedIDs.remove(id) }
        return save
    }

    func removedBookmark(_ id: UUID) {
        bookmarkRevision += 1
        savedIDs.remove(id)
    }

    func toggleLike(_ video: Video, user: UUID) async throws {
        guard let i = videos.firstIndex(where: { $0.id == video.id }),
              pendingLikes.insert(video.id).inserted else { return }
        defer { pendingLikes.remove(video.id) }
        let request = generation
        let original = (videos[i].likedByMe, videos[i].likeCount)
        let liked = !(videos[i].likedByMe ?? false)
        videos[i].likedByMe = liked                       // optimistic
        videos[i].likeCount = max(0, original.1 + (liked ? 1 : -1))
        do { try await writeLike(liked, video.id, user) } catch {
            if request == generation, let index = videos.firstIndex(where: { $0.id == video.id }) {
                videos[index].likedByMe = original.0
                videos[index].likeCount = original.1
            }
            throw error
        }
    }

    func toggleFollow(_ author: UUID, user: UUID) async throws {
        guard viewer == user, pendingFollows.insert(author).inserted else { return }
        defer { pendingFollows.remove(author) }
        let request = generation
        let follow = !following.contains(author)
        if follow { following.insert(author) } else { following.remove(author) }
        do { try await FeedService.setFollowing(follow, target: author, user: user) } catch {
            if request == generation {
                if follow { following.remove(author) } else { following.insert(author) }
            }
            throw error
        }
        if viewer == user {
            if follow { following.insert(author) } else { following.remove(author) }
            if followingOnly && !follow { remove { $0.userId == author } }
        }
    }

    func report(_ video: Video, reason: FeedService.ReportReason, user: UUID) async throws {
        try await FeedService.report(video.id, reason: reason, user: user)
        remove { $0.id == video.id }                       // hide it for the reporter right away
    }

    func block(_ author: UUID, user: UUID) async throws {
        try await FeedService.block(author, user: user)
        removeBlockedAuthor(author)
    }

    func removeBlockedAuthor(_ author: UUID) {
        following.remove(author)
        remove { $0.userId == author }
    }

    func delete(_ video: Video) async throws {
        try await FeedService.deleteVideo(video.id)
        remove { $0.id == video.id }
    }

    private func remove(where match: (Video) -> Bool) {
        let currentID = videos.indices.contains(current) ? videos[current].id : nil
        videos.removeAll(where: match)
        current = videos.firstIndex(where: { $0.id == currentID }) ?? min(current, max(videos.count - 1, 0))
    }
}

private struct ActivityInboxView: View {
    @ObservedObject var auth: AuthManager
    @Environment(\.dismiss) private var dismiss
    @State private var items: [CreatorActivity] = []
    @State private var target: Destination?
    @State private var loading = false
    @State private var opening = false
    @State private var more = false
    @State private var error: String?

    struct Destination: Identifiable {
        let video: Video
        let comment: UUID
        var id: UUID { comment }
    }

    var body: some View {
        NavigationStack {
            List {
                if let error {
                    Text(error).font(.footnote).foregroundStyle(.secondary)
                    Button("Try again") { Task { await load() } }
                }
                if items.isEmpty && error == nil {
                    if loading { ProgressView("Loading activity") }
                    else { Text("New comments and replies will show up here.").foregroundStyle(.secondary) }
                }
                ForEach(items) { item in
                    Button { Task { await open(item) } } label: {
                        HStack(spacing: 12) {
                            Image(systemName: item.kind == .reply ? "arrowshape.turn.up.left" : "bubble.left")
                                .foregroundStyle(StudioStyle.accent).frame(width: 28)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.kind == .reply ? "@\(item.username) replied to you" : "@\(item.username) commented on your video")
                                    .font(.subheadline.weight(item.readAt == nil ? .bold : .regular))
                                Text(verbatim: item.body).foregroundStyle(.secondary).lineLimit(2)
                                Text(item.createdAt, style: .relative).font(.caption2).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if item.readAt == nil {
                                Circle().fill(StudioStyle.accent).frame(width: 7, height: 7)
                                    .accessibilityLabel("Unread")
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(opening)
                }
                if more {
                    Button("Load more activity") { Task { await load(append: true) } }.disabled(loading)
                }
            }
            .navigationTitle("Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .refreshable { await load() }
            .task { await load() }
            .sheet(item: $target, onDismiss: { Task { await load() } }) { destination in
                CommentsView(video: destination.video, auth: auth, targetComment: destination.comment) { _ in
                    Task { await load() }
                }
            }
        }
        .tint(StudioStyle.accent)
    }

    private func load(append: Bool = false) async {
        guard !loading else { return }
        loading = true
        error = nil
        defer { loading = false }
        do {
            let page = try await FeedService.activity(after: append ? items.last : nil)
            guard !Task.isCancelled else { return }
            if !append { items = [] }
            items += page
            more = page.count == FeedService.activityPageSize
        } catch {
            if !Task.isCancelled { self.error = "Couldn't load your activity." }
        }
    }

    private func open(_ item: CreatorActivity) async {
        guard !opening else { return }
        opening = true
        defer { opening = false }
        do {
            guard let video = try await FeedService.video(id: item.videoId) else {
                await load()
                error = "This performance is no longer available."
                return
            }
            target = Destination(video: video, comment: item.commentId)
            if item.readAt == nil, (try? await FeedService.markActivityRead(item.id)) != nil,
               let index = items.firstIndex(where: { $0.id == item.id }) {
                items[index].readAt = Date()
            }
        } catch { self.error = "Couldn't open that conversation." }
    }
}

private struct PublicCreatorView: View {
    let creatorId: UUID
    @ObservedObject var auth: AuthManager
    let onFollowChange: () -> Void
    let onStart: (PerformanceStart) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var creator: PublicCreator?
    @State private var videos: [Video] = []
    @State private var opened: Video?
    @State private var afterDismiss: PerformanceStart?
    @State private var following = false
    @State private var loading = true
    @State private var busy = false
    @State private var more = false
    @State private var signIn = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let creator {
                        HStack(spacing: 12) {
                            Text(String(creator.username.prefix(1)).uppercased())
                                .font(.title2.bold()).frame(width: 56, height: 56)
                                .background(StudioStyle.surface, in: Circle())
                            VStack(alignment: .leading) {
                                Text(creator.displayName ?? "@\(creator.username)").font(.title2.bold())
                                if creator.displayName != nil { Text("@\(creator.username)").foregroundStyle(.secondary) }
                            }
                            Spacer()
                            if auth.userId != creatorId {
                                Button(following ? "Following" : "Follow", action: changeFollow)
                                    .buttonStyle(.bordered).disabled(busy)
                            }
                        }
                        Text("Performances").font(.headline)
                        if videos.isEmpty && !loading { Text("No public performances yet.").foregroundStyle(.secondary) }
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
                            ForEach(videos) { video in
                                Button { opened = video } label: {
                                    Rectangle().fill(StudioStyle.surface).aspectRatio(9 / 16, contentMode: .fit)
                                        .overlay {
                                            AsyncImage(url: video.thumbURL) { image in image.resizable().scaledToFill() }
                                                placeholder: { Image(systemName: "play.rectangle") }
                                        }
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(video.caption.isEmpty ? "Play performance" : video.caption)
                            }
                        }
                        if more { Button("More performances") { Task { await loadVideos(append: true) } }.disabled(busy) }
                    } else if loading {
                        ProgressView("Loading creator")
                    } else if error == nil {
                        Text("This profile is unavailable.")
                    }
                    if let error { Text(error).font(.footnote).foregroundStyle(.secondary) }
                }
                .padding(18)
            }
            .background(StudioStyle.background)
            .navigationTitle("Creator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .refreshable { await load() }
            .task(id: auth.userId) { await load() }
            .sheet(item: $opened, onDismiss: {
                if let start = afterDismiss { afterDismiss = nil; onStart(start) }
            }) { video in
                CreatorVideoView(video: video, auth: auth, onPlayAlong: { source in
                    afterDismiss = .backing(source)
                    opened = nil
                }, onTrySound: { sound in
                    afterDismiss = .preset(sound)
                    opened = nil
                })
            }
            .sheet(isPresented: $signIn) { SignInView(auth: auth, reason: "Sign in to follow this creator.") }
        }
        .tint(StudioStyle.accent)
    }

    private func load() async {
        loading = true
        error = nil
        defer { loading = false }
        do {
            creator = try await FeedService.creator(id: creatorId)
            guard creator != nil else { return }
            if let user = auth.userId { following = await FeedService.isFollowing(creatorId, user: user) }
            else { following = false }
            await loadVideos()
        } catch { if !Task.isCancelled { self.error = "Couldn't load this profile. Pull down to refresh." } }
    }

    private func loadVideos(append: Bool = false) async {
        busy = true
        defer { busy = false }
        do {
            let page = try await FeedService.page(after: append ? videos.last : nil, creator: creatorId)
            guard !Task.isCancelled else { return }
            if !append { videos = [] }
            videos += page
            more = page.count == FeedService.pageSize
        } catch { if !Task.isCancelled { self.error = "Couldn't load performances." } }
    }

    private func changeFollow() {
        guard let user = auth.userId, !auth.needsProfileSetup else { signIn = true; return }
        busy = true
        Task {
            defer { busy = false }
            do {
                try await FeedService.setFollowing(!following, target: creatorId, user: user)
                following.toggle()
                onFollowChange()
            } catch { self.error = "Couldn't update your follows." }
        }
    }
}

private struct ClipPresetCard: View {
    let setup: SoundSetup
    let username: String?
    let onPlay: ((SoundSetup) -> Void)?
    @State private var saved = false

    private var title: String { setup.instrumentName ?? "Performance preset" }
    private var savedName: String { username.map { "\(title) by @\($0)" } ?? title }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: "waveform")
                .font(.caption.weight(.bold))
                .foregroundStyle(StudioStyle.accent)
                .lineLimit(1)
            Text(setup.presetDetails)
                .font(.caption)
                .lineLimit(2)
            HStack(spacing: 8) {
                if let onPlay {
                    Button { onPlay(setup) } label: {
                        Label("Play sound", systemImage: "play.fill")
                            .padding(.horizontal, 9)
                            .frame(minHeight: 44)
                            .background(StudioStyle.accent.opacity(0.17), in: RoundedRectangle(cornerRadius: 9))
                    }
                    .accessibilityIdentifier("play-clip-preset")
                }
                Button {
                    PersistenceManager.shared.addPreset(setup, named: savedName)
                    saved = true
                } label: {
                    Image(systemName: saved ? "checkmark" : "bookmark")
                        .frame(width: 44, height: 44)
                        .background(.white.opacity(0.11), in: RoundedRectangle(cornerRadius: 9))
                }
                .disabled(saved)
                .accessibilityLabel(saved ? "Preset saved" : "Save preset privately")
                .accessibilityIdentifier("save-clip-preset")
            }
            .font(.caption.weight(.semibold))
            .buttonStyle(.plain)
        }
        .padding(8)
        .foregroundStyle(StudioStyle.ink)
        .background(.black.opacity(0.70), in: RoundedRectangle(cornerRadius: 12))
        .onAppear {
            saved = PersistenceManager.shared.loadSetups().contains {
                $0.sound == setup && $0.name == String(savedName.prefix(40))
            }
        }
    }
}

struct CreatorVideoView: View {
    let video: Video
    @ObservedObject var auth: AuthManager
    var onPlayAlong: ((Video) -> Void)? = nil
    var onTrySound: ((SoundSetup) -> Void)? = nil
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?
    @State private var showComments = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 10) {
                VideoPlayer(player: player)
                if !video.caption.isEmpty { Text(verbatim: video.caption) }
                if let setup = video.soundSetup {
                    ClipPresetCard(setup: setup, username: video.username, onPlay: onTrySound)
                } else if let instrument = video.instrument {
                    Label(instrument, systemImage: "waveform").font(.caption).foregroundStyle(.secondary)
                }
                if video.backingEnabled == true, let onPlayAlong {
                    Button("Play along", systemImage: "waveform.badge.plus") { onPlayAlong(video) }
                        .buttonStyle(StudioActionStyle())
                }
                if video.commentsEnabled == true {
                    Button("Comments", systemImage: "bubble") { showComments = true; player?.pause() }
                        .frame(minHeight: 44)
                }
            }
            .padding(16)
            .navigationTitle("@\(video.username ?? "creator")")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) { ShareLink(item: video.watchURL) }
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
            }
            .sheet(isPresented: $showComments) { CommentsView(video: video, auth: auth) }
        }
        .task { player = AVPlayer(url: video.videoURL) }
        .onChange(of: scenePhase) { if $0 != .active { player?.pause() } }
        .onDisappear { player?.pause() }
        .tint(StudioStyle.accent)
    }
}

private struct PerformanceLibraryView: View {
    enum Kind {
        case saved, challenge(WeeklyChallenge)

        var title: String {
            switch self {
            case .saved: return "Saved performances"
            case .challenge: return "Weekly play-along"
            }
        }
    }

    let kind: Kind
    @ObservedObject var auth: AuthManager
    var onRemove: (UUID) -> Void = { _ in }
    let onPlay: (PerformanceStart) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var items: [Video] = []
    @State private var source: Video?
    @State private var selected: Video?
    @State private var playAfterDismiss: PerformanceStart?
    @State private var more = false
    @State private var loading = false
    @State private var removing: UUID?
    @State private var error: String?

    var body: some View {
        NavigationStack {
            List {
                if case .challenge(let challenge) = kind {
                    Section {
                        Text(verbatim: challenge.title).font(.system(.title2, design: .serif))
                        Text(verbatim: challenge.prompt)
                        Text("Ends \(challenge.endsAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption).foregroundStyle(.secondary)
                        if let source {
                            Button("Watch the backing clip", systemImage: "play.rectangle") { selected = source }
                            Button("Play along", systemImage: "waveform") { onPlay(.backing(source)) }
                                .fontWeight(.semibold)
                        } else if !loading && error == nil {
                            Text("This challenge is no longer available.").foregroundStyle(.secondary)
                        }
                    }
                }
                Section {
                    if let error {
                        Text(error).foregroundStyle(.secondary)
                        Button("Try again") { Task { await load() } }
                    }
                    if items.isEmpty {
                        if loading { ProgressView("Loading performances") }
                        else if error == nil {
                            Text(emptyMessage).foregroundStyle(.secondary)
                        }
                    }
                    ForEach(items) { video in
                        Button { selected = video } label: {
                            HStack(spacing: 12) {
                                AsyncImage(url: video.thumbURL) { image in image.resizable().scaledToFill() }
                                    placeholder: { Image(systemName: "play.rectangle").foregroundStyle(.secondary) }
                                    .frame(width: 40, height: 56)
                                    .background(StudioStyle.surface)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("@\(video.username ?? "creator")").font(.subheadline.bold())
                                    Text(verbatim: video.caption.isEmpty ? video.instrument ?? "Performance" : video.caption)
                                        .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                        .swipeActions {
                            if case .saved = kind {
                                Button("Remove", role: .destructive) { Task { await remove(video) } }
                                    .disabled(removing != nil)
                            }
                        }
                    }
                    if more { Button("Load more") { Task { await load(append: true) } }.disabled(loading) }
                } header: {
                    if case .challenge = kind { Text("Community takes") }
                }
            }
            .navigationTitle(kind.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .refreshable { await load() }
            .task { await load() }
            .sheet(item: $selected, onDismiss: {
                if let video = playAfterDismiss { playAfterDismiss = nil; onPlay(video) }
            }) { video in
                CreatorVideoView(video: video, auth: auth, onPlayAlong: { video in
                    playAfterDismiss = .backing(video)
                    selected = nil
                }, onTrySound: { sound in
                    playAfterDismiss = .preset(sound)
                    selected = nil
                })
            }
        }
        .tint(StudioStyle.accent)
    }

    private var emptyMessage: String {
        switch kind {
        case .saved: return "Save a performance from its options menu to find it here later. Only you can see this list."
        case .challenge: return "No takes yet. Play along and post a take to join this week's challenge."
        }
    }

    private func load(append: Bool = false) async {
        guard !loading else { return }
        loading = true
        error = nil
        defer { loading = false }
        do {
            let last = append ? items.last : nil
            let page: [Video]
            switch kind {
            case .saved: page = try await FeedService.bookmarks(after: last)
            case .challenge(let challenge):
                if !append {
                    guard let current = try await FeedService.weeklyChallenge(), current.id == challenge.id else {
                        source = nil; items = []; more = false; return
                    }
                    let video = try await FeedService.video(id: challenge.sourceVideoID)
                    source = video?.backingEnabled == true ? video : nil
                }
                page = try await FeedService.page(after: last, challenge: challenge.id)
            }
            guard !Task.isCancelled else { return }
            let previous = append ? items : []
            let seen = Set(previous.map(\.id))
            items = previous + page.filter { !seen.contains($0.id) }
            more = page.count == FeedService.pageSize
        } catch { if !Task.isCancelled { self.error = "Couldn't load performances. Try again." } }
    }

    private func remove(_ video: Video) async {
        guard let uid = auth.userId, removing == nil else { return }
        removing = video.id
        defer { removing = nil }
        do {
            try await FeedService.setBookmark(false, video: video.id, user: uid)
            items.removeAll { $0.id == video.id }
            onRemove(video.id)
        } catch { self.error = "Couldn't remove that performance. Try again." }
    }
}

// MARK: - Cell

private struct FeedCell: View {
    let video: Video
    let isCurrent: Bool
    let isMine: Bool
    let isFollowing: Bool
    let isSaved: Bool
    let muted: Bool
    let toggleMute: () -> Void
    let like: () -> Void
    let follow: () -> Void
    let report: () -> Void
    let block: () -> Void
    let delete: () -> Void
    let onTrySound: (SoundSetup) -> Void
    let comments: () -> Void
    let creator: () -> Void
    let bookmark: () -> Void
    let playAlong: () -> Void
    let revokeBacking: () -> Void
    let source: (UUID) -> Void
    @State private var paused = false
    @State private var confirmDelete = false

    var body: some View {
        ZStack(alignment: .bottom) {
            LoopingPlayer(url: video.videoURL, thumb: video.thumbURL, playing: isCurrent && !paused, muted: muted)
                .onTapGesture { paused.toggle() }
            LinearGradient(colors: [.clear, .black.opacity(0.88)], startPoint: .center, endPoint: .bottom)
                .allowsHitTesting(false)
            if paused {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 54))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            HStack(alignment: .bottom, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 8) { author; followButton }
                        VStack(alignment: .leading, spacing: 4) { author; followButton }
                    }
                    if !video.caption.isEmpty { Text(video.caption).font(.subheadline).lineLimit(3) }
                    if let setup = video.soundSetup {
                        ClipPresetCard(setup: setup, username: video.username, onPlay: onTrySound)
                            .id(video.id)
                    } else if let instrument = video.instrument {
                        Label(instrument, systemImage: "waveform")
                            .font(.caption.monospaced())
                            .foregroundStyle(StudioStyle.accent)
                    }
                    if video.backingEnabled == true {
                        Button(action: playAlong) { Label("Play along", systemImage: "waveform.badge.plus") }
                            .font(.caption.weight(.semibold)).buttonStyle(.borderedProminent)
                            .tint(StudioStyle.accent).foregroundStyle(StudioStyle.background)
                            .accessibilityIdentifier("play-along")
                    }
                    if let id = video.sourceVideoId, let username = video.sourceUsername {
                        Button("Inspired by @\(username)") { source(id) }
                            .font(.caption.weight(.semibold)).foregroundStyle(StudioStyle.accent)
                    }
                }
                Spacer()
                VStack(spacing: 8) {
                    Button(action: like) {
                        VStack(spacing: 4) {
                            actionIcon(video.likedByMe == true ? "heart.fill" : "heart",
                                       tint: video.likedByMe == true ? StudioStyle.recording : .white)
                            Text("\(video.likeCount)").font(.caption.bold())
                        }
                    }
                    .accessibilityLabel(video.likedByMe == true ? "Unlike" : "Like")
                    if let enabled = video.commentsEnabled, enabled || isMine {
                        Button(action: comments) {
                            VStack(spacing: 4) {
                                actionIcon("bubble")
                                if enabled { Text("\(video.commentCount ?? 0)").font(.caption.bold()) }
                            }
                        }
                        .accessibilityLabel(enabled ? "Comments, \(video.commentCount ?? 0)" : "Manage comments")
                        .accessibilityIdentifier("video-comments-button")
                    }
                    Button(action: toggleMute) {
                        actionIcon(muted ? "speaker.slash" : "speaker.wave.2")
                    }
                    .accessibilityLabel(muted ? "Unmute" : "Mute")
                    ShareLink(item: video.watchURL) {
                        actionIcon("square.and.arrow.up")
                    }
                    .accessibilityLabel("Share video")
                    Menu {
                        Button(isSaved ? "Remove from Saved" : "Save privately",
                               systemImage: isSaved ? "bookmark.slash" : "bookmark", action: bookmark)
                        if isMine {
                            if video.backingEnabled == true {
                                Button("Stop allowing play-along", action: revokeBacking)
                            }
                            Button("Delete post", role: .destructive) { confirmDelete = true }
                        } else {
                            Button(action: report) { Label("Report", systemImage: "flag") }
                            Button(role: .destructive, action: block) {
                                Label("Block @\(video.username ?? "user")", systemImage: "hand.raised")
                            }
                        }
                    } label: { actionIcon("ellipsis") }
                    .accessibilityLabel("More")
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 15).padding(.bottom, 16)
        }
        .accessibilityAction(named: Text(paused ? "Play video" : "Pause video")) { paused.toggle() }
        .confirmationDialog("Delete this post?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive, action: delete)
        }
    }

    private var author: some View {
        Button(action: creator) {
            Text("@\(video.username ?? "user")").font(.headline).lineLimit(1)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens creator profile")
    }

    @ViewBuilder
    private var followButton: some View {
        if !isMine {
            Button(action: follow) {
                Text(isFollowing ? "Following" : "Follow")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 11)
                    .padding(.vertical, 6)
                    .foregroundStyle(isFollowing ? .white : StudioStyle.background)
                    .background(isFollowing ? Color.white.opacity(0.16) : StudioStyle.accent, in: Capsule())
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private func actionIcon(_ symbol: String, tint: Color = .white) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: 44, height: 44)
            .background(.black.opacity(0.55), in: Circle())
            .overlay { Circle().strokeBorder(.white.opacity(0.18)) }
    }
}

// MARK: - Paging container (UICollectionView, works on iOS 16)

private struct PagedFeed<Cell: View>: UIViewRepresentable {
    let videos: [Video]
    @Binding var current: Int
    let cell: (Video, Bool) -> Cell

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UICollectionView {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 0
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.isPagingEnabled = true
        cv.showsVerticalScrollIndicator = false
        cv.contentInsetAdjustmentBehavior = .never
        cv.backgroundColor = .black
        cv.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "cell")
        cv.dataSource = context.coordinator
        cv.delegate = context.coordinator
        return cv
    }

    func updateUIView(_ cv: UICollectionView, context: Context) {
        let old = context.coordinator.parent
        context.coordinator.parent = self
        let oldIDs = old.videos.map(\.id)
        let newIDs = videos.map(\.id)
        if oldIDs != newIDs {
            cv.reloadData()
            // Pagination appends pages; a removal can move the active video to a new index.
            if !newIDs.starts(with: oldIDs) {
                cv.layoutIfNeeded()
                cv.setContentOffset(CGPoint(x: 0, y: CGFloat(current) * cv.bounds.height), animated: false)
            }
        } else {
            for case let ip in cv.indexPathsForVisibleItems { context.coordinator.configure(cv.cellForItem(at: ip), at: ip) }
        }
    }

    final class Coordinator: NSObject, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
        var parent: PagedFeed
        init(_ parent: PagedFeed) { self.parent = parent }

        func collectionView(_ cv: UICollectionView, numberOfItemsInSection section: Int) -> Int { parent.videos.count }

        func collectionView(_ cv: UICollectionView, cellForItemAt ip: IndexPath) -> UICollectionViewCell {
            let c = cv.dequeueReusableCell(withReuseIdentifier: "cell", for: ip)
            configure(c, at: ip)
            return c
        }

        func configure(_ c: UICollectionViewCell?, at ip: IndexPath) {
            guard let c, ip.item < parent.videos.count else { return }
            let v = parent.videos[ip.item]
            c.contentConfiguration = UIHostingConfiguration { parent.cell(v, ip.item == parent.current) }
                .margins(.all, 0)
        }

        func collectionView(_ cv: UICollectionView, layout: UICollectionViewLayout,
                            sizeForItemAt ip: IndexPath) -> CGSize { cv.bounds.size }

        func scrollViewDidEndDecelerating(_ sv: UIScrollView) {
            let page = Int((sv.contentOffset.y / max(sv.bounds.height, 1)).rounded())
            if page != parent.current { parent.current = page }
        }

        func scrollViewDidEndDragging(_ sv: UIScrollView, willDecelerate decelerate: Bool) {
            if !decelerate { scrollViewDidEndDecelerating(sv) }
        }
    }
}

// MARK: - Looping video

private struct LoopingPlayer: UIViewRepresentable {
    let url: URL
    let thumb: URL
    let playing: Bool
    let muted: Bool

    func makeUIView(context: Context) -> PlayerView { PlayerView() }

    func updateUIView(_ view: PlayerView, context: Context) {
        view.load(url: url, thumb: thumb)
        view.player?.isMuted = muted
        if playing { view.player?.play() } else { view.player?.pause() }
    }

    static func dismantleUIView(_ view: PlayerView, coordinator: ()) {
        view.player?.pause()
    }

    final class PlayerView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        private var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
        private let thumbView = UIImageView()
        private var looper: AVPlayerLooper?
        private(set) var player: AVQueuePlayer?
        private var loadedURL: URL?

        override init(frame: CGRect) {
            super.init(frame: frame)
            backgroundColor = .black
            playerLayer.videoGravity = .resizeAspectFill
            thumbView.contentMode = .scaleAspectFill
            thumbView.clipsToBounds = true
            addSubview(thumbView)
            // Reveal video once frames are ready, so the thumbnail covers loading.
            playerLayer.addObserver(self, forKeyPath: "readyForDisplay", options: [.new], context: nil)
        }
        required init?(coder: NSCoder) { fatalError() }

        override func layoutSubviews() { super.layoutSubviews(); thumbView.frame = bounds }

        func load(url: URL, thumb: URL) {
            guard url != loadedURL else { return }
            loadedURL = url
            thumbView.image = nil
            thumbView.isHidden = false
            URLSession.shared.dataTask(with: thumb) { [weak self] data, _, _ in
                guard let data, let img = UIImage(data: data) else { return }
                DispatchQueue.main.async { if self?.loadedURL == url { self?.thumbView.image = img } }
            }.resume()
            let item = AVPlayerItem(url: url)
            let q = AVQueuePlayer()
            looper = AVPlayerLooper(player: q, templateItem: item)
            player = q
            playerLayer.player = q
        }

        override func observeValue(forKeyPath keyPath: String?, of object: Any?,
                                   change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
            guard keyPath == "readyForDisplay" else { return }
            DispatchQueue.main.async { self.thumbView.isHidden = self.playerLayer.isReadyForDisplay }
        }

        deinit {
            playerLayer.removeObserver(self, forKeyPath: "readyForDisplay")
        }
    }
}
