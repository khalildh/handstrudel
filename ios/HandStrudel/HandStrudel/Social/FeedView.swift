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
    @Environment(\.studioPalette) private var palette
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
    @State private var showSearch = false
    @State private var challenge: WeeklyChallenge?
    @State private var openChallenge: WeeklyChallenge?
    @State private var pendingStart: PerformanceStart?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            topBar
            if let challenge, !model.followingOnly {
                Button { openChallenge = challenge } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "waveform").foregroundStyle(palette.accent)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("WEEKLY PLAY-ALONG").font(.caption2.monospaced().weight(.semibold))
                                .foregroundStyle(palette.accent)
                            Text(verbatim: challenge.title).font(.subheadline.bold()).lineLimit(1)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(palette.surface, in: RoundedRectangle(cornerRadius: 13))
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
                                 && !showSaved && !showSearch && openChallenge == nil,
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
                                     toggleBookmark(video)
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
                            .environment(\.studioPalette, palette)
                            .environment(\.colorScheme, .dark)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay { RoundedRectangle(cornerRadius: 20).strokeBorder(palette.border).allowsHitTesting(false) }
                    .overlay(alignment: .topTrailing) { pageControls.padding(10) }
                    .onChange(of: model.current) { _ in Task { await model.loadMore() } }
                    .accessibilityScrollAction { edge in
                        if edge == .bottom { movePage(by: 1) }
                        if edge == .top { movePage(by: -1) }
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
        .background(palette.background.ignoresSafeArea())
        .foregroundStyle(palette.ink)
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
        .sheet(isPresented: $showSearch, onDismiss: resumePerformance) {
            PostSearchView(auth: auth) { start in
                pendingStart = start
                showSearch = false
            }
        }
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

    private func movePage(by amount: Int) {
        let target = model.current + amount
        if model.videos.indices.contains(target) { model.current = target }
    }

    private var pageControls: some View {
        HStack(spacing: 0) {
            if model.videos.count > 1 {
                pageButton("Previous video", icon: "chevron.up", offset: -1)
            }
            Text("\(model.current + 1) / \(model.videos.count)")
                .font(.caption2.monospacedDigit().weight(.semibold))
                .padding(.horizontal, 8)
                .frame(minHeight: 28)
                .accessibilityLabel("Video \(model.current + 1) of \(model.videos.count) loaded")
                .accessibilityIdentifier("feed-video-position")
            if model.videos.count > 1 {
                pageButton("Next video", icon: "chevron.down", offset: 1)
            }
        }
        .foregroundStyle(.white)
        .background(.black.opacity(0.74), in: Capsule())
    }

    private func pageButton(_ title: String, icon: String, offset: Int) -> some View {
        let available = model.videos.indices.contains(model.current + offset)
        return Button { movePage(by: offset) } label: {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
                .opacity(available ? 1 : 0.35)
        }
        .buttonStyle(.plain)
        .disabled(!available)
        .accessibilityLabel(title)
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
            Button { showSearch = true } label: {
                Image(systemName: "magnifyingglass").font(.system(size: 18, weight: .semibold)).frame(width: 44, height: 44)
            }
            .accessibilityLabel("Search posts")
            .accessibilityIdentifier("search-posts")
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
                        if unreadActivity { Circle().fill(palette.accent).frame(width: 7, height: 7).padding(7) }
                    }
            }
            .accessibilityLabel(unreadActivity ? "Notifications, unread" : "Notifications")
            .accessibilityIdentifier("activity-inbox")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            if model.loading {
                ProgressView("Loading videos")
            } else {
                Image(systemName: "play.rectangle").font(.system(size: 40)).foregroundStyle(palette.accent)
                Text(model.error ?? (model.followingOnly ? "No performances from creators you follow yet" : "No performances yet"))
                    .font(.title3.bold()).multilineTextAlignment(.center)
                if model.followingOnly {
                    if !auth.isSignedIn {
                        Button("Sign in to follow creators") { showSignIn = true }.buttonStyle(StudioActionStyle())
                    } else {
                        if model.error == nil {
                            Text("Follow a creator from Latest to see their posts here.")
                                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        }
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

    private func toggleBookmark(_ video: Video) {
        requireSignIn { uid in
            Task {
                do {
                    if let saved = try await model.toggleBookmark(video.id, user: uid) {
                        show(saved ? "Saved privately." : "Removed from Saved.")
                    }
                } catch let error as FeedService.Unavailable {
                    show(error.localizedDescription)
                } catch {
                    show("Couldn't update Saved. Try again.")
                }
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
            let page = try await fetchPage(followingOnly: followingOnly, user: user)
            guard !Task.isCancelled, request == generation else { return }
            videos = page
            reachedEnd = videos.count < FeedService.pageSize
            await loadPageDetails(page, request: request)
            while !Task.isCancelled, request == generation, !reachedEnd, current >= videos.count - 3 {
                guard (try? await appendPage(request: request)) == true else { break }
            }
        } catch {
            if !Task.isCancelled && request == generation {
                self.error = followingOnly ? "Couldn't load posts from creators you follow." : "Couldn't load the feed. Try again."
            }
        }
    }

    func loadMore() async {
        guard !loading, !reachedEnd, current >= videos.count - 3 else { return }
        let request = generation
        loading = true
        defer { if request == generation { loading = false } }
        while !Task.isCancelled, request == generation, !reachedEnd, current >= videos.count - 3 {
            guard (try? await appendPage(request: request)) == true else { break }
        }
    }

    private func appendPage(request: Int) async throws -> Bool {
        guard let last = videos.last else { return false }
        let page = try await fetchPage(after: last, followingOnly: followingOnly, user: viewer)
        guard !Task.isCancelled, request == generation else { return false }
        let seen = Set(videos.map(\.id))
        let fresh = page.filter { !seen.contains($0.id) }
        reachedEnd = page.count < FeedService.pageSize || fresh.isEmpty
        videos += fresh
        await loadPageDetails(fresh, request: request)
        return !fresh.isEmpty
    }

    private func loadPageDetails(_ page: [Video], request: Int) async {
        async let bookmarks: Void = loadBookmarks(in: page, request: request)
        async let follows: Void = loadFollowing(in: page, request: request)
        _ = await (bookmarks, follows)
    }

    private func fetchPage(after last: Video? = nil, followingOnly: Bool, user: UUID?) async throws -> [Video] {
        if followingOnly {
            guard let user else { return [] }
            return try await FeedService.followingPage(user: user, after: last)
        }
        return try await FeedService.page(after: last)
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
    @Environment(\.studioPalette) private var palette
    @ObservedObject var auth: AuthManager
    @Environment(\.dismiss) private var dismiss
    @State private var items: [CreatorActivity] = []
    @State private var cursor: CreatorActivity?
    @State private var loading = false
    @State private var more = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            List {
                if let error {
                    Text(error).font(.footnote).foregroundStyle(.secondary)
                    Button("Try again") { Task { await load() } }
                }
                if items.isEmpty && error == nil {
                    if loading { ProgressView("Loading activity") }
                    else { Text("New likes, comments, and replies will show up here.").foregroundStyle(.secondary) }
                }
                ForEach(items) { item in
                    NavigationLink {
                        NotificationPerformanceView(item: item, auth: auth) {
                            if let index = items.firstIndex(where: { $0.id == item.id && $0.timestamp == item.timestamp }) {
                                items[index].readAt = Date()
                            }
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: item.kind.icon)
                                .foregroundStyle(item.kind.isLike ? palette.recording : palette.accent).frame(width: 28)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title)
                                    .font(.subheadline.weight(item.readAt == nil ? .bold : .regular))
                                if !item.body.isEmpty { Text(verbatim: item.body).foregroundStyle(.secondary).lineLimit(2) }
                                Text(item.createdAt, style: .relative).font(.caption2).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if item.readAt == nil {
                                Circle().fill(palette.accent).frame(width: 7, height: 7)
                                    .accessibilityLabel("Unread")
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .accessibilityHint(item.commentId == nil ? "Opens the video" : "Opens the video and its comment thread")
                    .accessibilityIdentifier("notification-performance-row")
                }
                if more {
                    Button("Load more activity") { Task { await load(append: true) } }.disabled(loading)
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .refreshable { await load() }
            .task { await load() }
        }
        .tint(palette.accent)
    }

    private func load(append: Bool = false) async {
        guard !loading else { return }
        loading = true
        error = nil
        defer { loading = false }
        do {
            let page = try await FeedService.activity(after: append ? cursor : nil)
            guard !Task.isCancelled else { return }
            if !append { items = [] }
            let existing = Set(items.map(\.id))
            items += page.filter { !existing.contains($0.id) }
            cursor = page.last
            more = page.count == FeedService.activityPageSize
        } catch let error as FeedService.Unavailable {
            if !Task.isCancelled { self.error = error.localizedDescription }
        } catch {
            if !Task.isCancelled { self.error = "Couldn't load notifications. Try again." }
        }
    }
}

private struct NotificationPerformanceView: View {
    let item: CreatorActivity
    @ObservedObject var auth: AuthManager
    let onRead: () -> Void
    @State private var video: Video?
    @State private var failed = false
    @State private var unavailable = false
    @State private var attempt = 0

    var body: some View {
        if let video {
            PerformanceDetail(video: video, auth: auth, notification: item)
                .task { await markRead() }
        } else {
            VStack(spacing: 14) {
                if unavailable {
                    Label("This video is no longer available.", systemImage: "play.slash")
                } else if failed {
                    Text("Couldn't open the video.")
                    Button("Try again") { attempt += 1 }
                } else {
                    ProgressView("Opening video")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Performance")
            .navigationBarTitleDisplayMode(.inline)
            .task(id: attempt) { await load() }
        }
    }

    private func load() async {
        failed = false
        do {
            let resolved = try await FeedService.video(id: item.videoId)
            guard !Task.isCancelled else { return }
            guard let resolved else { unavailable = true; return }
            video = resolved
        } catch {
            if !Task.isCancelled { failed = true }
        }
    }

    private func markRead() async {
        if item.readAt == nil, (try? await FeedService.markActivityRead(item)) != nil {
            onRead()
        }
    }
}

private struct PublicCreatorView: View {
    @Environment(\.studioPalette) private var palette
    let creatorId: UUID
    @ObservedObject var auth: AuthManager
    let onFollowChange: () -> Void
    let onStart: (PerformanceStart) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var creator: PublicCreator?
    @State private var videos: [Video] = []
    @State private var counts: FeedService.ProfileCounts?
    @State private var opened: Video?
    @State private var afterDismiss: PerformanceStart?
    @State private var following = false
    @State private var loading = true
    @State private var busy = false
    @State private var changingFollow = false
    @State private var more = false
    @State private var signIn = false
    @State private var error: String?
    @State private var postsFailed = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let creator {
                        CreatorProfileHeader(username: creator.username, displayName: creator.displayName,
                                             avatarKey: creator.avatarKey ?? videos.first?.avatarKey, counts: counts,
                                             isOwner: auth.userId == creatorId) {
                            if auth.userId != creatorId {
                                Button(action: changeFollow) {
                                    Label(following ? "Following" : "Follow",
                                          systemImage: following ? "checkmark" : "plus")
                                }
                                .buttonStyle(ProfileActionStyle(primary: !following))
                                .disabled(changingFollow || loading)
                                .accessibilityIdentifier("profile-follow")
                            }
                        }
                        CreatorPortfolio(videos: videos, loading: loading || busy, failed: postsFailed, more: more,
                                         isOwner: false, open: { opened = $0 }, trySound: { onStart(.preset($0)) },
                                         retry: { Task { await loadVideos(append: more) } },
                                         loadMore: { Task { await loadVideos(append: true) } })
                    } else if loading {
                        ProgressView("Loading creator").frame(maxWidth: .infinity).padding(.vertical, 40)
                    } else if error == nil {
                        Text("This profile is unavailable.").foregroundStyle(palette.muted)
                    }
                    if let error {
                        Text(error).font(.footnote).foregroundStyle(palette.muted)
                        Button("Try again") { Task { await load() } }
                            .buttonStyle(ProfileActionStyle()).disabled(loading || changingFollow)
                    }
                }
                .padding(.horizontal, 21)
                .padding(.vertical, 12)
                .frame(maxWidth: 650)
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .background(palette.background.ignoresSafeArea())
            .foregroundStyle(palette.ink)
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
        .tint(palette.accent)
    }

    private func load() async {
        loading = true
        error = nil
        defer { if !Task.isCancelled { loading = false } }
        let viewer = auth.userId
        do {
            let profile = try await FeedService.creator(id: creatorId)
            guard !Task.isCancelled, viewer == auth.userId else { return }
            creator = profile
            guard profile != nil else { videos = []; counts = nil; return }
            async let metrics = FeedService.profileCounts(for: creatorId)
            if let viewer {
                let result = await FeedService.isFollowing(creatorId, user: viewer)
                guard !Task.isCancelled, viewer == auth.userId else { return }
                if !changingFollow { following = result }
            } else { following = false }
            await loadVideos()
            let result = await metrics
            if !Task.isCancelled, viewer == auth.userId { counts = result }
        } catch { if !Task.isCancelled { self.error = "Couldn't load this profile. Pull down to refresh." } }
    }

    private func loadVideos(append: Bool = false) async {
        guard !busy else { return }
        busy = true
        postsFailed = false
        defer { busy = false }
        do {
            let page = try await FeedService.page(after: append ? videos.last : nil, creator: creatorId)
            guard !Task.isCancelled else { return }
            if append {
                let loaded = Set(videos.map(\.id))
                videos += page.filter { !loaded.contains($0.id) }
            } else { videos = page }
            more = page.count == FeedService.pageSize
        } catch { if !Task.isCancelled { postsFailed = true } }
    }

    private func changeFollow() {
        guard let user = auth.userId, !auth.needsProfileSetup else { signIn = true; return }
        changingFollow = true
        error = nil
        Task {
            defer { changingFollow = false }
            do {
                try await FeedService.setFollowing(!following, target: creatorId, user: user)
                guard auth.userId == user else { return }
                following.toggle()
                onFollowChange()
                counts = await FeedService.profileCounts(for: creatorId)
            } catch { self.error = "Couldn't update your follows." }
        }
    }
}

private struct PostSearchView: View {
    @Environment(\.studioPalette) private var palette
    @ObservedObject var auth: AuthManager
    let onStart: (PerformanceStart) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var input = ""
    @State private var requestID = UUID()
    @State private var results: [Video] = []
    @State private var cursor: Video?
    @State private var busy = false
    @State private var more = false
    @State private var failed = false
    @State private var opened: Video?
    @State private var afterDismiss: PerformanceStart?

    var body: some View {
        NavigationStack {
            List {
                if PostSearch(input) == nil {
                    Text("Search captions, instruments, or creators. Use @ to search by handle.")
                        .foregroundStyle(.secondary)
                } else if results.isEmpty && !busy && !failed {
                    Text("No matching posts.").foregroundStyle(.secondary)
                }
                ForEach(results) { video in
                    Button { opened = video } label: { PerformanceListRow(video: video) }
                        .buttonStyle(.plain)
                }
                if busy { ProgressView("Searching posts") }
                if failed {
                    Text("Couldn't load search results.").foregroundStyle(.secondary)
                    Button("Try again") { loadNextPage() }
                } else if more && !busy {
                    Button("Load more") { loadNextPage() }
                }
            }
            .navigationTitle("Search posts")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $input, placement: .navigationBarDrawer(displayMode: .always), prompt: "Caption, instrument, or creator")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .onChange(of: input) { _ in reset() }
            .onChange(of: auth.userId) { _ in reset() }
            .task(id: requestID) {
                let id = requestID
                guard let search = PostSearch(input) else { return }
                do { try await Task.sleep(for: .milliseconds(300)) } catch { return }
                await load(search, id: id, after: nil)
            }
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
        }
        .tint(palette.accent)
    }

    private func reset() {
        results = []
        cursor = nil
        more = false
        failed = false
        busy = PostSearch(input) != nil
        requestID = UUID()
    }

    private func loadNextPage() {
        guard !busy, let search = PostSearch(input) else { return }
        busy = true
        let id = requestID
        let after = cursor
        Task { await load(search, id: id, after: after) }
    }

    private func load(_ search: PostSearch, id: UUID, after: Video?) async {
        guard requestID == id, !Task.isCancelled else { return }
        defer { if requestID == id { busy = false } }
        failed = false
        do {
            let page = try await FeedService.page(after: after, search: search)
            guard requestID == id, !Task.isCancelled else { return }
            let loaded = Set(results.map(\.id))
            results += page.filter { !loaded.contains($0.id) }
            cursor = page.last ?? after
            more = page.count == FeedService.pageSize
        } catch {
            if requestID == id && !Task.isCancelled { failed = true }
        }
    }
}

private struct PerformanceListRow: View {
    @Environment(\.studioPalette) private var palette
    let video: Video

    var body: some View {
        HStack(spacing: 12) {
            Rectangle().fill(palette.surface)
                .frame(width: 40, height: 56)
                .overlay {
                    AsyncImage(url: video.thumbURL) { image in image.resizable().scaledToFill() }
                        placeholder: { Image(systemName: "play.rectangle").foregroundStyle(.secondary) }
                }
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text("@\(video.username ?? "creator")").font(.subheadline.bold())
                Text(verbatim: video.caption.isEmpty ? video.instrument ?? "Performance" : video.caption)
                    .font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
    }
}

private struct ClipPresetCard: View {
    @Environment(\.studioPalette) private var palette
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
                .foregroundStyle(palette.mediaAccent)
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
                            .background(palette.mediaAccent.opacity(0.17), in: RoundedRectangle(cornerRadius: 9))
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
        .foregroundStyle(.white)
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
    var allowsSharing = true
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            PerformanceDetail(video: video, auth: auth, onPlayAlong: onPlayAlong, onTrySound: onTrySound,
                              allowsSharing: allowsSharing)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                }
        }
    }
}

private struct PerformanceDetail: View {
    @Environment(\.studioPalette) private var palette
    @Environment(\.scenePhase) private var scenePhase
    let video: Video
    @ObservedObject var auth: AuthManager
    var notification: CreatorActivity? = nil
    var onPlayAlong: ((Video) -> Void)? = nil
    var onTrySound: ((SoundSetup) -> Void)? = nil
    var allowsSharing = true
    @State private var player: AVPlayer?
    @State private var showComments = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                VideoPlayer(player: player)
                    .aspectRatio(4 / 5, contentMode: .fit)
                    .frame(maxHeight: 430)
                    .frame(maxWidth: .infinity)
                    .background(.black, in: RoundedRectangle(cornerRadius: 16))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .accessibilityIdentifier("performance-video")
                if !video.caption.isEmpty { Text(verbatim: video.caption) }
                if let notification { notificationCard(notification) }
                if let setup = video.soundSetup {
                    ClipPresetCard(setup: setup, username: video.username ?? auth.profile?.username, onPlay: onTrySound)
                } else if let instrument = video.instrument {
                    Label(instrument, systemImage: "waveform").font(.caption).foregroundStyle(.secondary)
                }
                if video.backingEnabled == true, let onPlayAlong {
                    Button("Play along", systemImage: "waveform.badge.plus") { onPlayAlong(video) }
                        .buttonStyle(StudioActionStyle())
                }
                if notification?.commentId == nil && video.commentsEnabled == true {
                    Button("Comments", systemImage: "bubble", action: openComments)
                        .frame(minHeight: 44)
                }
            }
            .padding(16)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .background(palette.background.ignoresSafeArea())
        .foregroundStyle(palette.ink)
        .navigationTitle("@\(video.username ?? auth.profile?.username ?? "creator")")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if allowsSharing { ToolbarItem(placement: .primaryAction) { ShareLink(item: video.watchURL) } }
        }
        .sheet(isPresented: $showComments) {
            CommentsView(video: video, auth: auth, targetComment: notification?.commentId)
        }
        .task { player = AVPlayer(url: video.videoURL) }
        .onChange(of: scenePhase) { if $0 != .active { player?.pause() } }
        .onDisappear { player?.pause() }
        .tint(palette.accent)
    }

    private func notificationCard(_ item: CreatorActivity) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(item.title, systemImage: item.kind.icon).font(.subheadline.weight(.semibold))
            if item.commentId != nil {
                Text(verbatim: item.body).font(.subheadline).foregroundStyle(palette.muted).lineLimit(3)
                Button(item.kind.commentAction, systemImage: "bubble", action: openComments)
                    .font(.subheadline.bold())
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("notification-view-comment")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 14))
    }

    private func openComments() {
        player?.pause()
        showComments = true
    }
}

private struct PerformanceLibraryView: View {
    @Environment(\.studioPalette) private var palette
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
                        Button { selected = video } label: { PerformanceListRow(video: video) }
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
        .tint(palette.accent)
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
        } catch let error as FeedService.Unavailable {
            if !Task.isCancelled { self.error = error.localizedDescription }
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
        } catch let error as FeedService.Unavailable {
            self.error = error.localizedDescription
        } catch { self.error = "Couldn't remove that performance. Try again." }
    }
}

// MARK: - Cell

private struct FeedCell: View {
    @Environment(\.studioPalette) private var palette
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
                .allowsHitTesting(false)
            Color.clear.contentShape(Rectangle()).onTapGesture { paused.toggle() }
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
                            .foregroundStyle(palette.mediaAccent)
                    }
                    if video.backingEnabled == true {
                        Button(action: playAlong) { Label("Play along", systemImage: "waveform.badge.plus") }
                            .font(.caption.weight(.semibold)).buttonStyle(.borderedProminent)
                            .tint(palette.mediaAccent).foregroundStyle(palette.mediaOnAccent)
                            .accessibilityIdentifier("play-along")
                    }
                    if let id = video.sourceVideoId, let username = video.sourceUsername {
                        Button("Inspired by @\(username)") { source(id) }
                            .font(.caption.weight(.semibold)).foregroundStyle(palette.mediaAccent)
                    }
                }
                Spacer()
                VStack(spacing: 8) {
                    Button(action: like) {
                        VStack(spacing: 4) {
                            actionIcon(video.likedByMe == true ? "heart.fill" : "heart",
                                       tint: video.likedByMe == true ? palette.recording : .white)
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
                    .foregroundStyle(isFollowing ? .white : palette.mediaOnAccent)
                    .background(isFollowing ? Color.white.opacity(0.16) : palette.mediaAccent, in: Capsule())
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
        let layout = PageLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 0
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.isPagingEnabled = true
        cv.isDirectionalLockEnabled = true
        cv.delaysContentTouches = false
        cv.allowsSelection = false
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
            if !newIDs.starts(with: oldIDs) { context.coordinator.align(cv) }
        } else {
            if !cv.isDragging && !cv.isDecelerating { context.coordinator.align(cv) }
            for case let ip in cv.indexPathsForVisibleItems { context.coordinator.configure(cv.cellForItem(at: ip), at: ip) }
        }
    }

    private final class PageLayout: UICollectionViewFlowLayout {
        override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
            newBounds.size != collectionView?.bounds.size
        }

        override func invalidationContext(forBoundsChange newBounds: CGRect) -> UICollectionViewLayoutInvalidationContext {
            let context = super.invalidationContext(forBoundsChange: newBounds)
            if let cv = collectionView, cv.bounds.height > 0, newBounds.size != cv.bounds.size {
                let page = (cv.contentOffset.y / cv.bounds.height).rounded()
                context.contentOffsetAdjustment.y = page * newBounds.height - cv.contentOffset.y
                (context as? UICollectionViewFlowLayoutInvalidationContext)?.invalidateFlowLayoutDelegateMetrics = true
            }
            return context
        }
    }

    final class Coordinator: NSObject, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
        var parent: PagedFeed
        init(_ parent: PagedFeed) { self.parent = parent }

        func align(_ cv: UICollectionView) {
            guard parent.videos.indices.contains(parent.current), cv.bounds.height > 0 else { return }
            let target = CGFloat(parent.current) * cv.bounds.height
            guard abs(cv.contentOffset.y - target) > 1 else { return }
            cv.layoutIfNeeded()
            cv.setContentOffset(CGPoint(x: 0, y: target), animated: false)
        }

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
                            sizeForItemAt ip: IndexPath) -> CGSize {
            CGSize(width: max(1, cv.bounds.width), height: max(1, cv.bounds.height))
        }

        func scrollViewDidEndDecelerating(_ sv: UIScrollView) {
            guard !parent.videos.isEmpty else { return }
            let page = min(parent.videos.count - 1, max(0, Int((sv.contentOffset.y / max(sv.bounds.height, 1)).rounded())))
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
