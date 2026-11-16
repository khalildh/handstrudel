import AVFoundation
import Combine
import SwiftUI
import UIKit

private enum PerformanceStart {
    case backing(Video)
    case preset(SoundSetup)
}

/// Full-screen, vertically paged feed of public posts.
/// Browsable signed out; liking, following, reporting and blocking need an account.
struct FeedView<Navigation: View>: View {
    @Environment(\.studioPalette) private var palette
    @ObservedObject var auth: AuthManager
    let isActive: Bool
    @Binding var isFullscreen: Bool
    let onMakeMusic: () -> Void
    let onTrySound: (SoundSetup) -> Void
    let onPlayAlong: (Video) -> Void
    let onVideoAvailabilityChanged: (Bool) -> Void
    let navigation: (Bool) -> Navigation
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var model = FeedModel()
    @State private var showSignIn = false
    @State private var reporting: Video?
    @State private var commenting: Video?
    @State private var lastCommentVideo: UUID?
    @State private var toast: String?
    @AppStorage("feedMuted") private var muted = false
    @State private var showActivity = false
    @State private var unreadActivity = false
    @State private var creatorVideo: Video?
    @State private var sourceVideo: Video?
    @State private var soundVideo: Video?
    @State private var remixVideo: Video?
    @State private var showSaved = false
    @State private var showSearch = false
    @State private var challenge: WeeklyChallenge?
    @State private var openChallenge: WeeklyChallenge?
    @State private var pendingStart: PerformanceStart?
    @State private var audioDownload: Video?
    @State private var pendingBookmark: Video?
    @State private var sharing: Video?
    @State private var showsFullscreenControls = true
    @State private var overlayHeights = FeedOverlayHeights(header: 100, navigation: 66)

    private var hasVideos: Bool { !model.videos.isEmpty }

    private var allowsFeedPlayback: Bool {
        isActive && scenePhase == .active && commenting == nil && !showActivity && creatorVideo == nil
            && sourceVideo == nil && soundVideo == nil && remixVideo == nil && sharing == nil
            && !showSaved && !showSearch && openChallenge == nil && !showSignIn
    }

    private var engagementTarget: UUID? { allowsFeedPlayback && !isFullscreen ? model.currentVideoID : nil }

    var body: some View {
        GeometryReader { bounds in
            feedCanvas(safeInsets: bounds.safeAreaInsets)
        }
        .onChange(of: hasVideos, perform: onVideoAvailabilityChanged)
        .onAppear { onVideoAvailabilityChanged(hasVideos) }
    }

    private func feedCanvas(safeInsets: EdgeInsets) -> some View {
        ZStack {
            if hasVideos {
                PagedFeed(videos: model.videos, current: $model.current, isVisible: isActive, allowsPlayback: allowsFeedPlayback, refresh: {
                    await model.refresh(user: auth.userId)
                }) { video, isCurrent, playbackGate in
                    FeedCell(video: video, isCurrent: isCurrent, isFullscreen: isFullscreen, playbackGate: playbackGate,
                             showsFullscreenControls: $showsFullscreenControls,
                             engagement: model.engagement[video.id],
                             overlayHeights: .init(header: overlayHeights.header + safeInsets.top,
                                                   navigation: (isFullscreen ? 0 : overlayHeights.navigation) + safeInsets.bottom),
                             isMine: video.userId == auth.userId,
                             isFollowing: model.following.contains(video.userId),
                             isSaved: model.savedIDs.contains(video.id),
                             canDownloadAudio: model.audioDownloadIDs.contains(video.id),
                             canChangeAudioPermission: video.userId == auth.userId && video.sourceVideoId == nil,
                             muted: muted, toggleMute: { muted.toggle() },
                             like: { act { try await model.toggleLike(video, user: $0) } },
                             follow: { act { try await model.toggleFollow(video.userId, user: $0) } },
                             report: { requireSignIn { _ in reporting = video } },
                             block: { act { try await model.block(video.userId, user: $0); show("Blocked @\(video.username ?? "user")") } },
                             delete: { Task { try? await model.delete(video) } },
                             comments: { openComments(video) },
                             creator: { creatorVideo = video },
                             bookmark: {
                                 toggleBookmark(video)
                             },
                             repost: { toggleRepost(video) },
                             share: { sharing = video },
                             downloadAudio: { audioDownload = video },
                             changeAudioPermission: {
                                 Task {
                                     do {
                                         let allowed = try await model.toggleAudioPermission(video.id)
                                         show(allowed ? "Audio downloads allowed." : "Audio downloads turned off.")
                                     } catch { show("Couldn't change audio downloads. Try again.") }
                                 }
                             },
                             advance: { advanceAfterClip(video.id) },
                             showSound: { soundVideo = video },
                             showRemixes: { remixVideo = video },
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
                        .ignoresSafeArea(.container, edges: [.top, .bottom])
                }
                .onChange(of: model.current) { _ in Task { await model.loadMore() } }
                .accessibilityScrollAction { edge in
                    if edge == .bottom { movePage(by: 1) }
                    if edge == .top { movePage(by: -1) }
                }
                .accessibilityAction(named: Text("Previous video")) { movePage(by: -1) }
                .accessibilityAction(named: Text("Next video")) { movePage(by: 1) }
                .ignoresSafeArea(.container, edges: [.top, .bottom])
            } else {
                emptyState
                    .padding(.top, overlayHeights.header)
                    .padding(.bottom, overlayHeights.navigation)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(hasVideos || isFullscreen ? Color.black : palette.background)
        .foregroundStyle(palette.ink)
        .overlay(alignment: .top) {
            if isActive { overlaidHeader }
        }
        .overlay(alignment: .bottom) {
            if isActive && !isFullscreen {
                navigation(hasVideos)
                    .background {
                        GeometryReader { geometry in
                            Color.clear.preference(key: FeedOverlayHeights.self, value: .init(navigation: geometry.size.height))
                        }
                        .allowsHitTesting(false)
                    }
            }
        }
        .overlay(alignment: .top) {
            if isActive, let toast {
                Text(toast)
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.top, overlayHeights.header + 4)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .onPreferenceChange(FeedOverlayHeights.self) { overlayHeights = $0 }
        .onChange(of: isFullscreen) { if $0 { showsFullscreenControls = true } }
        .accessibilityAction(.escape) { if isFullscreen { isFullscreen = false } }
        .task(id: FeedRefresh(user: auth.userId, mode: model.mode)) {
            await model.refresh(user: auth.userId)
            await refreshBadge()
        }
        .task(id: engagementTarget) {
            if let id = engagementTarget { await model.refreshEngagement(for: id) }
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
            if uid == nil, model.followingOnly { model.mode = .discover }
        }
        .sheet(isPresented: $showSignIn, onDismiss: {
            let video = pendingBookmark
            pendingBookmark = nil
            if let video, let uid = auth.userId, !auth.needsProfileSetup {
                writeBookmark(video, user: uid, explicitlySave: true)
            }
        }) { SignInView(auth: auth, reason: "Sign in to save performances and join the community.") }
        .modifier(PerformanceAudioDownload(video: $audioDownload))
        .sheet(item: $sharing) { video in
            VideoShareSheet(video: video) { await model.refreshEngagement(for: video.id) }
        }
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
        .sheet(item: $remixVideo, onDismiss: resumePerformance) { video in
            PerformanceLibraryView(kind: .remixes(video), auth: auth) { start in
                pendingStart = start
                remixVideo = nil
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
        .sheet(isPresented: $showActivity, onDismiss: {
            resumePerformance()
            Task { await refreshBadge() }
        }) {
            ActivityInboxView(auth: auth) { sound in
                pendingStart = .preset(sound)
                showActivity = false
            }
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
        .sheet(item: $soundVideo, onDismiss: resumePerformance) { video in
            FeedSoundSheet(video: video) { start in
                pendingStart = start
                soundVideo = nil
            }
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

    private func advanceAfterClip(_ id: UUID) -> Bool {
        guard model.videos.indices.contains(model.current), model.videos[model.current].id == id,
              model.videos.indices.contains(model.current + 1) else { return false }
        movePage(by: 1)
        return true
    }

    private func resumePerformance() {
        guard let start = pendingStart else { return }
        pendingStart = nil
        switch start {
        case .backing(let video): onPlayAlong(video)
        case .preset(let sound): onTrySound(sound)
        }
    }

    private var overlaidHeader: some View {
        VStack(spacing: 4) {
            if !isFullscreen {
                HStack(spacing: 6) {
                    feedMenu
                    Spacer(minLength: 0)
                    feedActions
                }
            }
            HStack(spacing: 10) {
                if !isFullscreen, let challenge, !model.followingOnly {
                    Button { openChallenge = challenge } label: {
                        Label(challenge.title, systemImage: "waveform")
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                            .foregroundStyle(hasVideos ? palette.mediaAccent : palette.accent)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(hasVideos ? Color.black.opacity(0.6) : palette.surface, in: Capsule())
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Weekly play-along: \(challenge.title)")
                    .accessibilityIdentifier("weekly-challenge")
                }
                Spacer(minLength: 0)
                if hasVideos || isFullscreen { playbackActions }
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(hasVideos || isFullscreen ? Color.white : palette.ink)
        .padding(.horizontal, 16)
        .padding(.top, 7)
        .background {
            if hasVideos && !isFullscreen {
                LinearGradient(colors: [.black.opacity(0.8), .black.opacity(0.38), .clear], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea(.container, edges: .top)
                    .allowsHitTesting(false)
            }
        }
        .background {
            GeometryReader { geometry in
                Color.clear.preference(key: FeedOverlayHeights.self, value: .init(header: geometry.size.height))
            }
            .allowsHitTesting(false)
        }
    }

    private var playbackActions: some View {
        HStack(spacing: 7) {
            if !isFullscreen {
                Button { muted.toggle() } label: {
                    FeedVideoIcon(symbol: muted ? "speaker.slash" : "speaker.wave.2")
                }
                .accessibilityLabel(muted ? "Unmute" : "Mute")
            }
            Button { isFullscreen.toggle() } label: {
                FeedVideoIcon(symbol: isFullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
            }
            .accessibilityLabel(isFullscreen ? "Exit full screen" : "Full screen")
            .accessibilityIdentifier("feed-fullscreen")
        }
    }

    private var feedMenu: some View {
        Menu {
            Picker("Show", selection: $model.mode) {
                ForEach(FeedMode.allCases, id: \.self) { mode in Text(mode.title).tag(mode) }
            }
            .pickerStyle(.inline)
        } label: {
            HStack(spacing: 7) {
                Text(model.mode == .discover ? "Feed" : model.mode.title)
                    .font(.system(size: 33, weight: .regular, design: .serif))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Image(systemName: "chevron.down").font(.system(size: 11, weight: .semibold))
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .accessibilityLabel("Feed options")
        .accessibilityValue(model.mode.title)
        .accessibilityIdentifier("feed-options")
    }

    private var feedActions: some View {
        HStack(spacing: 0) {
            Button { showSearch = true } label: {
                Image(systemName: "magnifyingglass").font(.system(size: 18, weight: .semibold)).frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Search posts")
            .accessibilityIdentifier("search-posts")
            Button {
                requireSignIn { _ in showSaved = true }
            } label: {
                Image(systemName: "bookmark").font(.system(size: 18, weight: .semibold)).frame(width: 44, height: 44)
                    .contentShape(Rectangle())
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
                    .contentShape(Rectangle())
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
                Text(emptyFeedTitle)
                    .font(.title3.bold()).multilineTextAlignment(.center)
                if model.followingOnly {
                    if !auth.isSignedIn {
                        Button("Sign in to follow creators") { showSignIn = true }.buttonStyle(StudioActionStyle())
                    } else {
                        if model.error == nil {
                            Text(model.confirmedNoFollows
                                 ? "Follow a creator in Discover or Latest to see their posts here."
                                 : "New public posts from creators you follow will appear here.")
                                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        }
                        Button("Browse Discover") { model.mode = .discover }.buttonStyle(StudioActionStyle())
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

    private var emptyFeedTitle: String {
        if let error = model.error { return error }
        guard model.followingOnly else { return "No performances yet" }
        if auth.isSignedIn, model.confirmedNoFollows { return "You aren't following any creators yet" }
        return "No performances from creators you follow yet"
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
        guard let uid = auth.userId, !auth.needsProfileSetup else {
            pendingBookmark = video
            showSignIn = true
            return
        }
        writeBookmark(video, user: uid)
    }

    private func toggleRepost(_ video: Video) {
        requireSignIn { uid in
            Task {
                do {
                    if let reposted = try await model.toggleRepost(video, user: uid) {
                        show(reposted ? "Reposted to your followers." : "Repost removed.")
                    }
                } catch let error as FeedService.Unavailable {
                    show(error.localizedDescription)
                } catch {
                    show("Couldn't update your repost. Try again.")
                }
            }
        }
    }

    private func writeBookmark(_ video: Video, user: UUID, explicitlySave: Bool = false) {
        Task {
            do {
                if let saved = try await model.toggleBookmark(video.id, user: user, explicitlySave: explicitlySave) {
                    show(saved ? "Saved privately." : "Removed from Saved.")
                    await model.refreshEngagement(for: video.id)
                }
            } catch let error as FeedService.Unavailable {
                show(error.localizedDescription)
            } catch {
                show("Couldn't update Saved. Try again.")
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
    let mode: FeedMode
}

enum FeedMode: Hashable, CaseIterable {
    case discover, latest, following

    var title: String {
        switch self {
        case .discover: return "Discover"
        case .latest: return "Latest"
        case .following: return "Following"
        }
    }

    var fetchLimit: Int { self == .discover ? 24 : FeedService.pageSize }
}

private struct FeedOverlayHeights: PreferenceKey, Equatable {
    var header: CGFloat = 0
    var navigation: CGFloat = 0

    static let defaultValue = Self()
    static func reduce(value: inout Self, nextValue: () -> Self) {
        let next = nextValue()
        value.header = max(value.header, next.header)
        value.navigation = max(value.navigation, next.navigation)
    }
}

enum DiscoveryFeedRanking {
    static func order(_ videos: [Video], now: Date, after lastCreator: UUID? = nil) -> [Video] {
        func score(_ video: Video) -> Double {
            let hoursOld = max(0, now.timeIntervalSince(video.createdAt) / 3600)
            let freshness = 3 / (1 + hoursOld / 72)
            let engagement = min(log1p(Double(max(0, video.likeCount))), 4) * 0.65 / (1 + hoursOld / 168)
            return freshness + engagement
        }

        var candidates: [(index: Int, video: Video, score: Double)] = videos.enumerated().map { index, video in
            (index, video, score(video))
        }
        candidates.sort { lhs, rhs in
            if lhs.score == rhs.score { return lhs.index < rhs.index }
            return lhs.score > rhs.score
        }
        var result: [Video] = []
        var last = lastCreator
        while !candidates.isEmpty {
            let pick = candidates.firstIndex { $0.video.userId != last } ?? candidates.startIndex
            let video = candidates.remove(at: pick).video
            result.append(video)
            last = video.userId
        }
        return result
    }
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
    @Published var mode: FeedMode = .discover
    @Published private(set) var confirmedNoFollows = false
    @Published private(set) var savedIDs = Set<UUID>()
    @Published private(set) var audioDownloadIDs = Set<UUID>()
    @Published private(set) var engagement: [UUID: VideoEngagement] = [:]
    private var engagementRequests: [UUID: UUID] = [:]
    private var reachedEnd = false
    private var pageCursor: Video?
    private var seenVideoIDs = Set<UUID>()
    private var loadedMode: FeedMode?
    private var rankingDate = Date()
    private var generation = 0
    private var viewer: UUID?
    private var pendingLikes = Set<UUID>()
    private var pendingFollows = Set<UUID>()
    private var pendingBookmarks = Set<UUID>()
    private var pendingReposts = Set<UUID>()
    private var bookmarkRevision = 0
    private let writeLike: (Bool, UUID, UUID) async throws -> Void
    private let loadPublicPage: (Video?, Int) async throws -> [Video]
    private let loadAudioDownloadIDs: ([UUID]) async throws -> Set<UUID>

    var followingOnly: Bool { mode == .following }
    var currentVideoID: UUID? { videos.indices.contains(current) ? videos[current].id : nil }

    init(writeLike: @escaping (Bool, UUID, UUID) async throws -> Void = FeedService.setLiked,
         loadPublicPage: @escaping (Video?, Int) async throws -> [Video] = {
             try await FeedService.page(after: $0, limit: $1)
         }, loadAudioDownloadIDs: @escaping ([UUID]) async throws -> Set<UUID> = FeedService.audioDownloadsAllowed) {
        self.writeLike = writeLike
        self.loadPublicPage = loadPublicPage
        self.loadAudioDownloadIDs = loadAudioDownloadIDs
    }

    func refreshVideoControls(for id: UUID) async {
        guard let fresh = try? await FeedService.video(id: id),
              let index = videos.firstIndex(where: { $0.id == id }) else { return }
        videos[index].commentCount = fresh.commentCount
        videos[index].commentsEnabled = fresh.commentsEnabled
        videos[index].backingEnabled = fresh.backingEnabled
    }

    func refreshEngagement(for id: UUID) async {
        let request = UUID()
        engagementRequests[id] = request
        defer { if engagementRequests[id] == request { engagementRequests[id] = nil } }
        guard let counts = try? await FeedService.engagement(for: id), !Task.isCancelled,
              engagementRequests[id] == request, videos.contains(where: { $0.id == id }) else { return }
        if engagement[id] != counts { engagement[id] = counts }
    }

    func toggleRepost(_ video: Video, user: UUID) async throws -> Bool? {
        guard viewer == user, video.userId != user, pendingReposts.insert(video.id).inserted else { return nil }
        defer { pendingReposts.remove(video.id) }
        if engagement[video.id]?.repostedByMe == nil { await refreshEngagement(for: video.id) }
        guard viewer == user, let reposted = engagement[video.id]?.repostedByMe else { throw FeedService.Unavailable.reposts }
        guard let updated = try await FeedService.setReposted(!reposted, video: video.id) else { return nil }
        guard viewer == user else { return nil }
        engagementRequests[video.id] = nil
        if videos.contains(where: { $0.id == video.id }) { engagement[video.id] = updated }
        return updated.repostedByMe
    }

    func refresh(user: UUID?, loadFollowingPage: (UUID) async throws -> FeedService.FollowingPage = {
        try await FeedService.followingPage(user: $0)
    }) async {
        generation += 1
        let request = generation
        let selectedMode = mode
        let followingOnly = selectedMode == .following
        if viewer != user { savedIDs = []; bookmarkRevision += 1 }
        viewer = user
        loading = true; error = nil; reachedEnd = false
        pageCursor = nil
        seenVideoIDs.removeAll()
        loadedMode = selectedMode
        rankingDate = Date()
        confirmedNoFollows = false
        audioDownloadIDs = []
        engagement = [:]
        engagementRequests = [:]
        videos = []; current = 0; following = []
        defer { if request == generation { loading = false } }
        guard !followingOnly || user != nil else { return }
        do {
            let page: [Video]
            var noFollows = false
            if followingOnly, let user {
                let result = try await loadFollowingPage(user)
                page = result.videos
                noFollows = result.confirmedNoFollows
            } else {
                page = try await loadPublicPage(nil, selectedMode.fetchLimit)
            }
            guard !Task.isCancelled, request == generation, mode == selectedMode else { return }
            let displayed = appendVisiblePage(page, mode: selectedMode)
            confirmedNoFollows = noFollows
            await loadPageDetails(displayed, request: request)
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
        guard !loading, !reachedEnd, loadedMode == mode, current >= videos.count - 3 else { return }
        let request = generation
        loading = true
        defer { if request == generation { loading = false } }
        while !Task.isCancelled, request == generation, !reachedEnd, current >= videos.count - 3 {
            guard (try? await appendPage(request: request)) == true else { break }
        }
    }

    private func appendPage(request: Int) async throws -> Bool {
        let selectedMode = mode
        guard loadedMode == selectedMode, let last = pageCursor else { return false }
        let page = try await fetchPage(after: last, mode: selectedMode, user: viewer)
        guard !Task.isCancelled, request == generation, mode == selectedMode else { return false }
        let fresh = appendVisiblePage(page, mode: selectedMode)
        await loadPageDetails(fresh, request: request)
        return !fresh.isEmpty
    }

    private func appendVisiblePage(_ page: [Video], mode: FeedMode) -> [Video] {
        let fresh = page.filter { seenVideoIDs.insert($0.id).inserted }
        // The cursor follows the server's order, not the order viewers see.
        pageCursor = page.last
        reachedEnd = page.count < mode.fetchLimit || fresh.isEmpty
        let displayed = mode == .discover
            ? DiscoveryFeedRanking.order(fresh, now: rankingDate, after: videos.last?.userId)
            : fresh
        videos += displayed
        return displayed
    }

    private func loadPageDetails(_ page: [Video], request: Int) async {
        async let bookmarks: Void = loadBookmarks(in: page, request: request)
        async let follows: Void = loadFollowing(in: page, request: request)
        async let downloads: Void = loadAudioPermissions(in: page, request: request)
        _ = await (bookmarks, follows, downloads)
    }

    private func fetchPage(after last: Video, mode: FeedMode, user: UUID?) async throws -> [Video] {
        if mode == .following {
            guard let user else { return [] }
            return try await FeedService.followingPage(user: user, after: last).videos
        }
        return try await loadPublicPage(last, mode.fetchLimit)
    }

    private func loadFollowing(in page: [Video], request: Int) async {
        guard let viewer else { return }
        let authors = Set(page.map(\.userId)).subtracting([viewer])
        let set = (try? await FeedService.followedAuthors(authors, user: viewer)) ?? []
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

    private func loadAudioPermissions(in page: [Video], request: Int) async {
        guard let ids = try? await loadAudioDownloadIDs(page.map(\.id)), request == generation else { return }
        audioDownloadIDs.formUnion(ids)
    }

    func toggleAudioPermission(_ id: UUID) async throws -> Bool {
        let allowed = !audioDownloadIDs.contains(id)
        try await FeedService.setAudioDownloadsAllowed(allowed, video: id)
        if allowed { audioDownloadIDs.insert(id) } else { audioDownloadIDs.remove(id) }
        return allowed
    }

    func toggleBookmark(_ id: UUID, user: UUID, explicitlySave: Bool = false) async throws -> Bool? {
        guard (user == viewer || explicitlySave), pendingBookmarks.insert(id).inserted else { return nil }
        defer { pendingBookmarks.remove(id) }
        bookmarkRevision += 1
        let save = explicitlySave || !savedIDs.contains(id)
        try await FeedService.setBookmark(save, video: id, user: user)
        guard viewer == user else { return explicitlySave ? save : nil }
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
            if followingOnly && !follow {
                remove { ($0.userId == author && $0.repostedByID == nil)
                    || ($0.repostedByID == author && !following.contains($0.userId)) }
                for index in videos.indices where videos[index].repostedByID == author {
                    videos[index].repostedBy = nil
                    videos[index].repostedByID = nil
                }
            }
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
        remove { $0.userId == author || $0.repostedByID == author }
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
    let onTrySound: (SoundSetup) -> Void
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
                        NotificationPerformanceView(item: item, auth: auth, onTrySound: onTrySound) {
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
    let onTrySound: (SoundSetup) -> Void
    let onRead: () -> Void
    @State private var video: Video?
    @State private var failed = false
    @State private var unavailable = false
    @State private var attempt = 0
    @State private var isFullscreen = false
    @State private var showsFullscreenControls = true

    var body: some View {
        if let video {
            PerformanceDetail(video: video, auth: auth, isFullscreen: $isFullscreen,
                              showsFullscreenControls: $showsFullscreenControls,
                              notification: item, onTrySound: onTrySound)
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
                                             likesReceived: creator.likesReceived, viewsReceived: creator.viewsReceived,
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
            .fullScreenCover(item: $opened, onDismiss: {
                if let start = afterDismiss { afterDismiss = nil; onStart(start) }
            }) { video in
                CreatorVideoView(video: video, auth: auth, onPlayAlong: { source in
                    afterDismiss = .backing(source)
                    opened = nil
                }, onTrySound: { sound in
                    afterDismiss = .preset(sound)
                    opened = nil
                }, playlist: videos)
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
                if let search = PostSearch(input) {
                    if results.isEmpty && !busy && !failed {
                        emptyResults(for: search)
                    }
                } else {
                    Text("Enter at least two characters. Use @ to search posts by creator handle.")
                        .foregroundStyle(.secondary)
                }
                ForEach(results) { video in
                    Button { opened = video } label: { PerformanceListRow(video: video) }
                        .buttonStyle(.plain)
                }
                if busy { ProgressView("Searching posts") }
                if failed {
                    Text(cursor == nil ? "Couldn't load search results." : "Couldn't load more results.")
                        .foregroundStyle(.secondary)
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

    @ViewBuilder
    private func emptyResults(for search: PostSearch) -> some View {
        let broaderInput = search.broaderInput
        VStack(alignment: .leading, spacing: 6) {
            Text(search.isHandleSearch ? "No posts match that handle" : "No matching posts")
                .font(.headline)
            if broaderInput != nil {
                Text("Check the handle, or also search captions, instruments, and creator names.")
                    .foregroundStyle(.secondary)
            } else if search.isHandleSearch {
                Text("Check the spelling or try a different handle.")
                    .foregroundStyle(.secondary)
            } else {
                Text("Try a shorter search, a different instrument, or a creator's name.")
                    .foregroundStyle(.secondary)
            }
        }
        if let broaderInput {
            Button("Broaden search") { input = broaderInput }
        }
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
                        Label("Play this sound", systemImage: "play.fill")
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .padding(.horizontal, 11)
                            .frame(minHeight: 44)
                            .foregroundStyle(palette.mediaOnAccent)
                            .background(palette.mediaAccent, in: RoundedRectangle(cornerRadius: 9))
                    }
                    .accessibilityIdentifier("play-clip-preset")
                    .accessibilityHint("Opens this setup in the Music tab")
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
    var playlist: [Video] = []
    @Environment(\.dismiss) private var dismiss
    @State private var playingVideo: Video?
    @State private var isFullscreen = false
    @State private var showsFullscreenControls = true

    var body: some View {
        let current = playingVideo ?? video
        NavigationStack {
            PerformanceDetail(video: current, auth: auth, isFullscreen: $isFullscreen,
                              showsFullscreenControls: $showsFullscreenControls,
                              onPlayAlong: onPlayAlong, onTrySound: onTrySound,
                              allowsSharing: allowsSharing && current.hidden != true, advance: { playNext(after: current) })
                .id(current.id)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                }
        }
        .statusBarHidden(isFullscreen)
    }

    private func playNext(after current: Video) -> Bool {
        let clips = playlist.filter { $0.userId == current.userId && $0.hidden != true }
        guard let first = clips.first else { return false }
        let next = clips.firstIndex(where: { $0.id == current.id })
            .map { clips[($0 + 1) % clips.count] } ?? first
        guard next.id != current.id else { return false }
        playingVideo = next
        return true
    }
}

private struct PerformanceDetail: View {
    @Environment(\.studioPalette) private var palette
    @Environment(\.scenePhase) private var scenePhase
    let video: Video
    @ObservedObject var auth: AuthManager
    @Binding var isFullscreen: Bool
    @Binding var showsFullscreenControls: Bool
    var notification: CreatorActivity? = nil
    var onPlayAlong: ((Video) -> Void)? = nil
    var onTrySound: ((SoundSetup) -> Void)? = nil
    var allowsSharing = true
    var advance: () -> Bool = { false }
    @StateObject private var playback = FeedPlaybackController()
    @State private var playbackGate = FeedPlaybackGate()
    @State private var detailIsVisible = false
    @State private var playerIsOnScreen = true
    @State private var paused = false
    @AppStorage("feedMuted") private var muted = false
    @State private var showComments = false
    @State private var audioDownload: Video?
    @State private var canDownloadAudio = false
    @State private var sharing = false

    private var isCurrent: Bool {
        detailIsVisible && playerIsOnScreen && scenePhase == .active && !showComments && audioDownload == nil && !sharing
    }

    var body: some View {
        GeometryReader { geometry in
            let insets = isFullscreen ? geometry.safeAreaInsets : EdgeInsets()
            let playerHeight = isFullscreen ? geometry.size.height + insets.top + insets.bottom : min(430, geometry.size.width * 1.19)
            ScrollViewReader { scrolling in
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        detailPlayer(safeInsets: insets)
                            .frame(height: playerHeight)
                            .clipShape(RoundedRectangle(cornerRadius: isFullscreen ? 0 : 16))
                            .accessibilityElement(children: .contain)
                            .accessibilityLabel(video.caption.isEmpty ? "Video" : video.caption)
                            .accessibilityIdentifier("performance-video")
                            .background {
                                GeometryReader { playerFrame in
                                    let frame = playerFrame.frame(in: .named("detail-scroll"))
                                    Color.clear.preference(key: ClipIsOnScreen.self,
                                                           value: frame.maxY > 0 && frame.minY < geometry.size.height)
                                }
                            }
                            .id("detail-player")
                        if !isFullscreen { details }
                    }
                    .padding(isFullscreen ? 0 : 16)
                    .frame(maxWidth: isFullscreen ? .infinity : 560)
                    .frame(maxWidth: .infinity)
                }
                .coordinateSpace(name: "detail-scroll")
                .scrollDisabled(isFullscreen)
                .ignoresSafeArea(.container, edges: isFullscreen ? .vertical : [])
                .onChange(of: isFullscreen) { fullscreen in
                    if fullscreen {
                        showsFullscreenControls = true
                        scrolling.scrollTo("detail-player", anchor: .top)
                    }
                }
                .onPreferenceChange(ClipIsOnScreen.self) { playerIsOnScreen = $0 }
            }
        }
        .background((isFullscreen ? Color.black : palette.background).ignoresSafeArea())
        .foregroundStyle(palette.ink)
        .navigationTitle("@\(video.username ?? auth.profile?.username ?? "creator")")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(isFullscreen ? .hidden : .visible, for: .navigationBar)
        .toolbar {
            if allowsSharing {
                ToolbarItem(placement: .primaryAction) {
                    Button("Share video", systemImage: "square.and.arrow.up") { sharing = true }
                }
            }
        }
        .sheet(isPresented: $sharing) { VideoShareSheet(video: video) }
        .sheet(isPresented: $showComments) {
            CommentsView(video: video, auth: auth, targetComment: notification?.commentId)
        }
        .task(id: video.id) {
            canDownloadAudio = (try? await FeedService.audioDownloadsAllowed([video.id]))?.contains(video.id) == true
        }
        .modifier(PerformanceAudioDownload(video: $audioDownload))
        .onAppear { detailIsVisible = true }
        .onDisappear { detailIsVisible = false; playbackGate.select(nil) }
        .accessibilityAction(.escape) { if isFullscreen { isFullscreen = false } }
        .tint(palette.accent)
    }

    private func detailPlayer(safeInsets: EdgeInsets) -> some View {
        ZStack(alignment: .bottom) {
            ClipPlaybackSurface(video: video, playback: playback, playbackGate: playbackGate,
                                isCurrent: isCurrent, paused: $paused, muted: muted, aspectFit: true,
                                selectsPlayback: true, fullscreenControls: isFullscreen ? $showsFullscreenControls : nil,
                                advance: advance)
            if !isFullscreen || showsFullscreenControls {
                ClipPlaybackControls(playback: playback, paused: isFullscreen ? $paused : nil,
                                     muted: muted, toggleMute: { muted.toggle() })
                    .padding(10)
                    .padding(.bottom, safeInsets.bottom)
                    .background(.black.opacity(0.45))
            }
        }
        .overlay(alignment: .topTrailing) {
            Button { isFullscreen.toggle() } label: {
                FeedVideoIcon(symbol: isFullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isFullscreen ? "Exit full screen" : "Full screen")
            .accessibilityIdentifier("profile-video-fullscreen")
            .padding(12)
            .padding(.top, safeInsets.top)
        }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 10) {
            VideoViewLabel(count: playback.displayedViewCount(fetched: video.viewCount))
                .foregroundStyle(palette.muted)
            if let setup = video.soundSetup {
                ClipPresetCard(setup: setup, username: video.username ?? auth.profile?.username, onPlay: onTrySound.map { play in
                    { sound in
                        paused = true
                        play(sound)
                    }
                })
            } else if let instrument = video.instrument {
                Label(instrument, systemImage: "waveform").font(.caption).foregroundStyle(.secondary)
            }
            if !video.caption.isEmpty { Text(verbatim: video.caption) }
            if let notification { notificationCard(notification) }
            if video.backingEnabled == true, let onPlayAlong {
                Button("Play along", systemImage: "waveform.badge.plus") {
                    paused = true
                    onPlayAlong(video)
                }
                .buttonStyle(StudioActionStyle())
            }
            if allowsSharing && canDownloadAudio {
                Button("Download audio", systemImage: "arrow.down.circle") {
                    audioDownload = video
                }
                .frame(minHeight: 44)
            }
            if notification?.commentId == nil && video.commentsEnabled == true {
                Button("Comments", systemImage: "bubble", action: openComments)
                    .frame(minHeight: 44)
            }
        }
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
        showComments = true
    }
}

private struct ClipIsOnScreen: PreferenceKey {
    static let defaultValue = false
    static func reduce(value: inout Bool, nextValue: () -> Bool) { value = value || nextValue() }
}

private struct VideoShareSheet: View {
    let video: Video
    var onRecorded: () async -> Void = {}

    var body: some View {
        ShareSheet(activityItems: [video.watchURL]) {
            Task {
                guard (try? await FeedService.recordShare(for: video.id)) != nil else { return }
                await onRecorded()
            }
        }
    }
}

private struct PerformanceAudioDownload: ViewModifier {
    @Binding var video: Video?
    @State private var audioFile: URL?
    @State private var message: String?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if video != nil {
                    ProgressView("Preparing audio…")
                        .padding(12).background(.regularMaterial, in: Capsule())
                        .padding(.top, 8)
                }
            }
            .task(id: video?.id) {
                guard let selected = video else { return }
                do {
                    guard try await FeedService.audioDownloadsAllowed([selected.id]).contains(selected.id) else {
                        throw SocialError.message("The creator hasn't allowed audio downloads for this clip.")
                    }
                    let file = try await PerformanceAudio.export(selected)
                    if Task.isCancelled { try? FileManager.default.removeItem(at: file); return }
                    audioFile = file
                } catch {
                    if !Task.isCancelled {
                        message = (error as? SocialError)?.localizedDescription ?? "Couldn't prepare the audio. Try again."
                    }
                }
                if !Task.isCancelled { video = nil }
            }
            .sheet(item: $audioFile) { file in
                ShareSheet(activityItems: [file])
                    .onDisappear { try? FileManager.default.removeItem(at: file) }
            }
            .alert("Download audio", isPresented: Binding(
                get: { message != nil }, set: { if !$0 { message = nil } }
            )) { Button("OK", role: .cancel) {} } message: { Text(message ?? "") }
    }
}

private struct PerformanceLibraryView: View {
    @Environment(\.studioPalette) private var palette
    enum Kind {
        case saved, challenge(WeeklyChallenge), remixes(Video)

        var title: String {
            switch self {
            case .saved: return "Saved performances"
            case .challenge: return "Weekly play-along"
            case .remixes: return "Remixes"
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
                } else if case .remixes = kind, let source {
                    Button("Play along", systemImage: "waveform") { onPlay(.backing(source)) }
                        .fontWeight(.semibold)
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
        case .remixes: return "No remixes yet. Published Play Along clips will appear here."
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
            case .remixes(let origin):
                if !append {
                    let visible = try await FeedService.video(id: origin.id)
                    source = visible?.backingEnabled == true ? visible : nil
                }
                page = try await FeedService.remixes(of: origin.id, after: last)
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
    let isFullscreen: Bool
    let playbackGate: FeedPlaybackGate
    @Binding var showsFullscreenControls: Bool
    let engagement: VideoEngagement?
    let overlayHeights: FeedOverlayHeights
    let isMine: Bool
    let isFollowing: Bool
    let isSaved: Bool
    let canDownloadAudio: Bool
    let canChangeAudioPermission: Bool
    let muted: Bool
    let toggleMute: () -> Void
    let like: () -> Void
    let follow: () -> Void
    let report: () -> Void
    let block: () -> Void
    let delete: () -> Void
    let comments: () -> Void
    let creator: () -> Void
    let bookmark: () -> Void
    let repost: () -> Void
    let share: () -> Void
    let downloadAudio: () -> Void
    let changeAudioPermission: () -> Void
    let advance: () -> Bool
    let showSound: () -> Void
    let showRemixes: () -> Void
    let revokeBacking: () -> Void
    let source: (UUID) -> Void
    @State private var paused = false
    @State private var confirmDelete = false
    @StateObject private var playback = FeedPlaybackController()
    @State private var confirmAudioDownloads = false

    var body: some View {
        GeometryReader { bounds in
            ZStack(alignment: .bottom) {
                ClipPlaybackSurface(video: video, playback: playback, playbackGate: playbackGate,
                                    isCurrent: isCurrent, paused: $paused, muted: muted,
                                    aspectFit: isFullscreen, fullscreenControls: isFullscreen ? $showsFullscreenControls : nil,
                                    advance: advance)
                if !isFullscreen || showsFullscreenControls {
                    LinearGradient(colors: [.clear, .black.opacity(isFullscreen ? 0.58 : 0.88)],
                                   startPoint: isFullscreen ? UnitPoint(x: 0.5, y: 0.8) : .center, endPoint: .bottom)
                        .allowsHitTesting(false)
                }
                VStack(spacing: 0) {
                    if isFullscreen {
                        if isCurrent && showsFullscreenControls {
                            ClipPlaybackControls(playback: playback, paused: $paused, muted: muted, toggleMute: toggleMute)
                        }
                    } else {
                        let railHeight = bounds.size.height - overlayHeights.header - overlayHeights.navigation
                            - FeedProgressStrip.height - 12
                        postControls(railHeight: max(44, railHeight))
                        // Reserve the scrubber row even when the player has no duration yet.
                        ZStack {
                            if isCurrent { FeedProgressStrip(playback: playback) }
                        }
                        .frame(height: FeedProgressStrip.height)
                    }
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 15)
                .padding(.bottom, overlayHeights.navigation + 3)
            }
        }
        .confirmationDialog("Delete this post?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive, action: delete)
        }
        .confirmationDialog("Let anyone download this clip's audio?", isPresented: $confirmAudioDownloads, titleVisibility: .visible) {
            Button("Allow audio downloads", action: changeAudioPermission)
        } message: { Text("This includes any voice in the clip. Only allow downloads if you have permission to share all of the audio.") }
    }

    private func postControls(railHeight: CGFloat) -> some View {
        HStack(alignment: .bottom, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                if engagement?.repostedByMe == true {
                    Label("You reposted", systemImage: "arrow.triangle.2.circlepath")
                        .font(.caption.weight(.semibold)).foregroundStyle(palette.mediaAccent)
                } else if let username = video.repostedBy {
                    Label("@\(username) reposted", systemImage: "arrow.triangle.2.circlepath")
                        .font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.9))
                        .lineLimit(1)
                }
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) { author; followButton }
                    VStack(alignment: .leading, spacing: 4) { author; followButton }
                }
                if !video.caption.isEmpty { Text(video.caption).font(.subheadline).lineLimit(3) }
                if video.soundSetup != nil || video.backingEnabled == true {
                    soundButton
                } else if let instrument = video.instrument {
                    Label(instrument, systemImage: "waveform")
                        .font(.caption.monospaced())
                        .foregroundStyle(palette.mediaAccent)
                }
                if let id = video.sourceVideoId, let username = video.sourceUsername {
                    Button("Inspired by @\(username)") { source(id) }
                        .font(.caption.weight(.semibold)).foregroundStyle(palette.mediaAccent)
                }
            }
            Spacer(minLength: 0)
            ViewThatFits(in: .vertical) {
                actionRail
                ScrollView { actionRail }.scrollIndicators(.hidden)
            }
            .frame(width: 52)
            .frame(maxHeight: railHeight, alignment: .bottom)
        }
    }

    private var actionRail: some View {
        VStack(spacing: 3) {
            Button(action: like) {
                railGlyph(video.likedByMe == true ? "heart.fill" : "heart", count: video.likeCount,
                          tint: video.likedByMe == true ? palette.recording : .white)
            }
            .accessibilityLabel(video.likedByMe == true ? "Unlike" : "Like")
            .accessibilityValue("\(video.likeCount.formatted()) likes")

            if let enabled = video.commentsEnabled, enabled || isMine {
                Button(action: comments) {
                    railGlyph("bubble", count: enabled ? video.commentCount ?? 0 : nil)
                }
                .accessibilityLabel(enabled ? "Comments, \(video.commentCount ?? 0)" : "Manage comments")
                .accessibilityIdentifier("video-comments-button")
            }

            Button(action: showRemixes) {
                railGlyph("waveform.badge.plus", count: engagement?.remixes, reserveCount: true)
            }
            .accessibilityLabel("Remixes")
            .accessibilityValue(engagement.map { $0.remixes.formatted() } ?? "")
            .accessibilityHint("Shows published Play Along clips")
            .accessibilityIdentifier("feed-remix-count")

            if !isMine {
                let didRepost = engagement?.repostedByMe == true
                Button(action: repost) {
                    railGlyph("arrow.triangle.2.circlepath", count: engagement?.reposts,
                              tint: didRepost ? palette.mediaAccent : .white, reserveCount: true)
                }
                .accessibilityLabel(didRepost ? "Remove repost" : "Repost")
                .accessibilityValue(engagement?.reposts.map { "\($0.formatted()) reposts" } ?? "")
                .accessibilityIdentifier("feed-repost")
            }

            Button(action: share) { railGlyph("paperplane", count: engagement?.shares, reserveCount: true) }
                .accessibilityLabel("Share video")
                .accessibilityValue(engagement.map { "\($0.shares.formatted()) shares" } ?? "")

            Button(action: bookmark) {
                railGlyph(isSaved ? "bookmark.fill" : "bookmark", count: engagement?.saves,
                          tint: isSaved ? palette.mediaAccent : .white, reserveCount: true)
            }
            .accessibilityLabel(isSaved ? "Remove from Saved" : "Save privately")
            .accessibilityValue(engagement.map { "\($0.saves.formatted()) saves" } ?? "")
            .accessibilityIdentifier("save-performance")

            if let views = playback.displayedViewCount(fetched: video.viewCount) {
                railMetric("eye", label: "Views", count: views)
                    .accessibilityIdentifier("feed-views-count")
            }

            Menu {
                if canDownloadAudio {
                    Button("Download audio", systemImage: "arrow.down.circle", action: downloadAudio)
                }
                if canChangeAudioPermission {
                    Button(canDownloadAudio ? "Turn off audio downloads" : "Allow audio downloads",
                           systemImage: "waveform") {
                        if canDownloadAudio { changeAudioPermission() }
                        else { confirmAudioDownloads = true }
                    }
                }
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
            } label: { railGlyph("ellipsis") }
            .accessibilityLabel("More")
        }
        .buttonStyle(.plain)
    }

    private func railMetric(_ symbol: String, label: String, count: Int) -> some View {
        railGlyph(symbol, count: count)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
            .accessibilityValue(count.formatted())
    }

    private func railGlyph(_ symbol: String, count: Int? = nil, tint: Color = .white, reserveCount: Bool = false) -> some View {
        VStack(spacing: 1) {
            FeedVideoIcon(symbol: symbol, tint: tint, size: 34)
            if count != nil || reserveCount {
                Text((count ?? 0).formatted(.number.notation(.compactName)))
                    .opacity(count == nil ? 0 : 1)
                    .font(.caption2.monospacedDigit().weight(.bold))
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 44)
        .contentShape(Rectangle())
    }

    private var soundButton: some View {
        let title = video.soundSetup?.instrumentName ?? video.instrument ?? "Sound"
        return Button(action: showSound) {
            HStack(spacing: 6) {
                Image(systemName: "waveform")
                Text(title).lineLimit(1)
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
        .accessibilityLabel("Sound options: \(title)")
        .accessibilityIdentifier("feed-sound-options")
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

}

private struct FeedVideoIcon: View {
    let symbol: String
    var tint: Color = .white
    var size: CGFloat = 44

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.41, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(.black.opacity(0.55), in: Circle())
            .overlay { Circle().strokeBorder(.white.opacity(0.18)) }
    }
}

struct VideoViewLabel: View {
    let count: Int?

    var body: some View {
        if let count {
            Label(count == 1 ? "1 view" : "\(count.formatted()) views", systemImage: "eye")
                .font(.caption.weight(.medium))
                .accessibilityIdentifier("video-view-count")
        }
    }
}

private struct ClipPlaybackSurface: View {
    @Environment(\.studioPalette) private var palette
    let video: Video
    @ObservedObject var playback: FeedPlaybackController
    let playbackGate: FeedPlaybackGate
    let isCurrent: Bool
    @Binding var paused: Bool
    let muted: Bool
    let aspectFit: Bool
    var selectsPlayback = false
    var fullscreenControls: Binding<Bool>? = nil
    let advance: () -> Bool
    @State private var attempt = 0

    var body: some View {
        ZStack {
            FeedPlayer(videoID: video.id, url: video.videoURL, thumb: video.thumbURL,
                       playback: playback, playbackGate: playbackGate, isCurrent: isCurrent,
                       playing: !paused && !playback.failed, muted: muted, aspectFit: aspectFit,
                       durationHint: video.durationS, countsViews: video.viewCount != nil && video.hidden != true,
                       selectsPlayback: selectsPlayback, onEnd: advance) {
                playback.failed = true
            }
            .id(attempt)
            .allowsHitTesting(false)
            Color.clear.contentShape(Rectangle()).onTapGesture {
                if let fullscreenControls {
                    fullscreenControls.wrappedValue.toggle()
                } else if !playback.failed {
                    paused.toggle()
                }
            }
            if isCurrent && playback.failed {
                VStack(spacing: 8) {
                    Text("Couldn't play this video.").font(.subheadline.weight(.semibold))
                    Button("Retry video") {
                        playback.failed = false
                        paused = false
                        attempt += 1
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(palette.mediaAccent)
                    .foregroundStyle(palette.mediaOnAccent)
                    .accessibilityIdentifier("feed-retry-video")
                }
                .foregroundStyle(.white)
                .padding(12)
                .background(.black.opacity(0.8), in: RoundedRectangle(cornerRadius: 12))
            } else if paused && !playback.failed && fullscreenControls == nil {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 54))
                    .foregroundStyle(.white)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityActions {
            if let fullscreenControls {
                Button(fullscreenControls.wrappedValue ? "Hide playback controls" : "Show playback controls") {
                    fullscreenControls.wrappedValue.toggle()
                }
            }
            if !playback.failed {
                Button(paused ? "Play video" : "Pause video") { paused.toggle() }
            }
        }
    }
}

private struct ClipPlaybackControls: View {
    @ObservedObject var playback: FeedPlaybackController
    let paused: Binding<Bool>?
    let muted: Bool
    let toggleMute: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            if let paused {
                Button { paused.wrappedValue.toggle() } label: {
                    FeedVideoIcon(symbol: paused.wrappedValue ? "play.fill" : "pause.fill")
                }
                .accessibilityLabel(paused.wrappedValue ? "Play video" : "Pause video")
                .accessibilityIdentifier("fullscreen-playback-toggle")
                .disabled(playback.failed)
            }
            FeedProgressStrip(playback: playback)
            Spacer(minLength: 0)
            Button(action: toggleMute) {
                FeedVideoIcon(symbol: muted ? "speaker.slash" : "speaker.wave.2")
            }
            .accessibilityLabel(muted ? "Unmute" : "Mute")
            .accessibilityIdentifier("video-playback-mute")
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
    }
}

private struct FeedSoundSheet: View {
    @Environment(\.studioPalette) private var palette
    @Environment(\.dismiss) private var dismiss
    let video: Video
    let onStart: (PerformanceStart) -> Void
    @State private var saved = false

    private var title: String { video.soundSetup?.instrumentName ?? video.instrument ?? "Sound" }
    private var savedName: String { video.username.map { "\(title) by @\($0)" } ?? title }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 5) {
                        Label(title, systemImage: "waveform")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(palette.ink)
                        if let setup = video.soundSetup {
                            Text(setup.presetDetails)
                                .font(.subheadline.monospaced())
                                .foregroundStyle(palette.muted)
                        }
                    }
                    if let setup = video.soundSetup {
                        Button("Play this sound", systemImage: "play.fill") { onStart(.preset(setup)) }
                            .buttonStyle(ProfileActionStyle(primary: true))
                            .accessibilityHint("Opens this setup in the Music tab")
                            .accessibilityIdentifier("play-clip-preset")
                    }
                    if video.backingEnabled == true {
                        Button("Play along", systemImage: "waveform.badge.plus") { onStart(.backing(video)) }
                            .buttonStyle(ProfileActionStyle(primary: video.soundSetup == nil))
                            .accessibilityHint("Uses this clip as a backing track")
                            .accessibilityIdentifier("play-along")
                    }
                    if let setup = video.soundSetup {
                        Button(saved ? "Preset saved" : "Save preset privately", systemImage: saved ? "checkmark" : "bookmark") {
                            PersistenceManager.shared.addPreset(setup, named: savedName)
                            saved = true
                        }
                        .buttonStyle(ProfileActionStyle())
                        .disabled(saved)
                        .accessibilityIdentifier("save-clip-preset")
                    }
                }
                .frame(maxWidth: 480, alignment: .leading)
                .padding(22)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .background(palette.background.ignoresSafeArea())
            .navigationTitle("Sound options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .tint(palette.accent)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onAppear {
            guard let setup = video.soundSetup else { return }
            saved = PersistenceManager.shared.loadSetups().contains {
                $0.sound == setup && $0.name == String(savedName.prefix(40))
            }
        }
    }
}

// MARK: - Paging container (UICollectionView, works on iOS 16)

private struct PagedFeed<Cell: View>: UIViewRepresentable {
    let videos: [Video]
    @Binding var current: Int
    let isVisible: Bool
    let allowsPlayback: Bool
    let refresh: () async -> Void
    let cell: (Video, Bool, FeedPlaybackGate) -> Cell

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UICollectionView {
        let layout = PageLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 0
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.accessibilityIdentifier = "feed-video-viewport"
        cv.accessibilityElementsHidden = !isVisible
        cv.decelerationRate = .fast
        cv.alwaysBounceVertical = true
        cv.isDirectionalLockEnabled = true
        cv.delaysContentTouches = false
        cv.allowsSelection = false
        cv.showsVerticalScrollIndicator = false
        cv.contentInsetAdjustmentBehavior = .never
        cv.backgroundColor = .black
        cv.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "cell")
        cv.dataSource = context.coordinator
        cv.delegate = context.coordinator
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(context.coordinator, action: #selector(Coordinator.pullToRefresh(_:)), for: .valueChanged)
        cv.refreshControl = refreshControl
        return cv
    }

    func updateUIView(_ cv: UICollectionView, context: Context) {
        let old = context.coordinator.parent
        context.coordinator.parent = self
        cv.accessibilityElementsHidden = !isVisible
        context.coordinator.selectPage(current)
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

    static func dismantleUIView(_ view: UICollectionView, coordinator: Coordinator) {
        coordinator.playbackGate.select(nil)
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
        let playbackGate = FeedPlaybackGate()
        private var snapPage: Int?
        init(_ parent: PagedFeed) { self.parent = parent }

        func selectPage(_ page: Int) {
            let id = parent.allowsPlayback && parent.videos.indices.contains(page) ? parent.videos[page].id : nil
            playbackGate.select(id)
        }

        @objc func pullToRefresh(_ control: UIRefreshControl) {
            Task {
                await parent.refresh()
                control.endRefreshing()
            }
        }

        func align(_ cv: UICollectionView) {
            guard parent.videos.indices.contains(parent.current), cv.bounds.height > 0 else { return }
            let target = CGFloat(parent.current) * cv.bounds.height
            guard abs(cv.contentOffset.y - target) > 1 else { return }
            cv.layoutIfNeeded()
            cv.setContentOffset(CGPoint(x: 0, y: target), animated: false)
            cv.layoutIfNeeded()
        }

        func collectionView(_ cv: UICollectionView, numberOfItemsInSection section: Int) -> Int { parent.videos.count }

        func collectionView(_ cv: UICollectionView, cellForItemAt ip: IndexPath) -> UICollectionViewCell {
            let c = cv.dequeueReusableCell(withReuseIdentifier: "cell", for: ip)
            configure(c, at: ip)
            return c
        }

        func collectionView(_ cv: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt ip: IndexPath) {
            // A prefetched cell can have been built before auto-advance selected it.
            configure(cell, at: ip)
        }

        func configure(_ c: UICollectionViewCell?, at ip: IndexPath) {
            guard let c, ip.item < parent.videos.count else { return }
            let v = parent.videos[ip.item]
            c.contentConfiguration = UIHostingConfiguration {
                parent.cell(v, parent.allowsPlayback && ip.item == parent.current, playbackGate).id(v.id)
            }
                .margins(.all, 0)
        }

        func collectionView(_ cv: UICollectionView, layout: UICollectionViewLayout,
                            sizeForItemAt ip: IndexPath) -> CGSize {
            CGSize(width: max(1, cv.bounds.width), height: max(1, cv.bounds.height))
        }

        func scrollViewWillBeginDragging(_ sv: UIScrollView) {
            snapPage = nil
        }

        func scrollViewWillEndDragging(_ sv: UIScrollView, withVelocity velocity: CGPoint,
                                       targetContentOffset: UnsafeMutablePointer<CGPoint>) {
            let height = sv.bounds.height
            guard height > 0, parent.videos.indices.contains(parent.current) else { return }
            let offset = sv.contentOffset.y
            let projected = targetContentOffset.pointee.y
            // Leave the overscroll at the top to the native refresh control.
            guard parent.current != 0 || offset >= 0 || projected > 0 else { return }
            let start = CGFloat(parent.current) * height
            let distance = offset - start
            let projectedDistance = projected - start
            let travel = abs(distance) >= abs(projectedDistance) ? distance : projectedDistance
            let threshold = min(120, height / 3)
            let step = travel >= threshold ? 1 : travel <= -threshold ? -1 : 0
            let page = min(parent.videos.count - 1, max(0, parent.current + step))
            snapPage = page
            targetContentOffset.pointee.y = CGFloat(page) * height
        }

        func scrollViewDidEndDecelerating(_ sv: UIScrollView) {
            guard !parent.videos.isEmpty else { return }
            snapPage = nil
            let page = min(parent.videos.count - 1, max(0, Int((sv.contentOffset.y / max(sv.bounds.height, 1)).rounded())))
            if page != parent.current {
                selectPage(page)
                parent.current = page
            }
        }

        func scrollViewDidEndDragging(_ sv: UIScrollView, willDecelerate decelerate: Bool) {
            guard !decelerate else { return }
            if let page = snapPage {
                sv.setContentOffset(CGPoint(x: 0, y: CGFloat(page) * sv.bounds.height), animated: false)
            }
            scrollViewDidEndDecelerating(sv)
        }
    }
}

// MARK: - Looping video

@MainActor
final class FeedPlaybackGate {
    private var selected: UUID?
    private weak var owner: AVPlayer?

    func select(_ videoID: UUID?) {
        guard selected != videoID else { return }
        owner?.pause()
        owner = nil
        selected = videoID
    }

    func owns(_ player: AVPlayer, videoID: UUID) -> Bool { selected == videoID && owner === player }

    func play(_ player: AVPlayer, videoID: UUID) {
        guard selected == videoID else { player.pause(); return }
        // UIKit can keep old cells alive or create two hosts for the same clip during a reload.
        if owner !== player {
            owner?.pause()
            owner = player
        }
        if player.timeControlStatus == .paused { player.play() }
    }
}

struct FeedPlaybackPosition: Equatable {
    let duration: Double
    let seconds: Double

    init?(duration: Double, seconds: Double) {
        guard duration.isFinite, duration > 0, seconds.isFinite else { return nil }
        self.duration = duration
        self.seconds = min(duration, max(0, seconds))
    }

    // Seek just before the end so scrubbing doesn't immediately advance the feed.
    var seekSeconds: Double { min(seconds, max(0, duration - 1.0 / 60)) }

    static func timeLabel(_ seconds: Double) -> String {
        guard seconds.isFinite else { return "0:00" }
        let whole = Int(max(0, min(seconds, 86_399)))
        return "\(whole / 60):\(String(format: "%02d", whole % 60))"
    }
}

struct QualifiedClipWatch {
    private var previous: Double?
    private var watched: Double = 0
    private(set) var qualified = false

    mutating func resetSample() { previous = nil }

    mutating func sample(_ position: FeedPlaybackPosition, playing: Bool) -> Bool {
        guard !qualified else { return false }
        let last = previous
        previous = playing ? position.seconds : nil
        guard let last, playing else { return false }
        let advance = position.seconds - last
        guard advance > 0, advance <= 0.6 else { return false }
        watched += advance
        qualified = watched >= min(2, position.duration / 2)
        return qualified
    }
}

@MainActor
private enum ClipViewReceipt {
    // A different token per clip, shared between feed and detail for this app run.
    private static var receipts: [UUID: UUID] = [:]

    static func forVideo(_ video: UUID) -> UUID {
        if let existing = receipts[video] { return existing }
        let receipt = UUID()
        receipts[video] = receipt
        return receipt
    }
}

@MainActor
private final class FeedPlaybackController: ObservableObject {
    @Published private(set) var position: FeedPlaybackPosition?
    @Published private(set) var viewCount: Int?
    @Published var failed = false
    private var player: AVPlayer?
    private var timeObserver: Any?
    private var isCurrent = false
    private var wantsPlayback = false
    private var isTracking = false
    private var isSeeking = false
    private var seekID = 0
    private var durationHint: Double?
    private var playbackGate: FeedPlaybackGate?
    private var videoID: UUID?
    private var countsViews = false
    private var watch = QualifiedClipWatch()

    func displayedViewCount(fetched: Int?) -> Int? {
        viewCount.map { max($0, fetched ?? 0) } ?? fetched
    }

    func configure(player newPlayer: AVPlayer, videoID: UUID, gate: FeedPlaybackGate,
                   isCurrent: Bool, wantsPlayback: Bool, durationHint: Double?, countsViews: Bool) {
        if player !== newPlayer {
            disconnect()
            player = newPlayer
        }
        self.videoID = videoID
        playbackGate = gate
        self.durationHint = durationHint
        self.countsViews = countsViews
        if !wantsPlayback { watch.resetSample() }
        self.wantsPlayback = wantsPlayback
        if self.isCurrent != isCurrent {
            self.isCurrent = isCurrent
            if isCurrent { observe(newPlayer) }
            else { stopObserving(); cancelSeek() }
        }
        syncPlayback()
    }

    func disconnect(from expectedPlayer: AVPlayer? = nil) {
        if let expectedPlayer, player !== expectedPlayer { return }
        stopObserving()
        cancelSeek()
        player?.pause()
        player = nil
        playbackGate = nil
        videoID = nil
        isCurrent = false
        watch.resetSample()
    }

    func setEditing(_ editing: Bool) {
        guard isCurrent, editing != isTracking else { return }
        if editing {
            cancelSeek()
            isTracking = true
            player?.pause()
        } else {
            isTracking = false
            if let position { seek(to: position) }
            else { syncPlayback() }
        }
    }

    func setSeconds(_ seconds: Double) {
        guard isCurrent, let duration = position?.duration,
              let next = FeedPlaybackPosition(duration: duration, seconds: seconds) else { return }
        position = next
        if !isTracking { seek(to: next) }
    }

    func finished(_ owner: AVPlayer, advance: () -> Bool) {
        guard player === owner, let videoID, playbackGate?.owns(owner, videoID: videoID) == true,
              isCurrent, wantsPlayback, !isTracking, !isSeeking else { return }
        owner.pause()
        if advance() { wantsPlayback = false }
        if let duration = position?.duration, let beginning = FeedPlaybackPosition(duration: duration, seconds: 0) {
            position = beginning
            seek(to: beginning)
        } else {
            owner.seek(to: .zero)
            syncPlayback()
        }
    }

    private func observe(_ owner: AVPlayer) {
        let interval = CMTime(value: 1, timescale: 5)
        timeObserver = owner.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self, weak owner] time in
            MainActor.assumeIsolated {
                guard let owner, let self else { return }
                self.sample(owner, time: time)
            }
        }
        Task { @MainActor [weak self, weak owner] in
            guard let owner else { return }
            self?.sample(owner, time: owner.currentTime())
        }
    }

    private func sample(_ owner: AVPlayer, time: CMTime) {
        guard isCurrent, !isTracking, !isSeeking, player === owner else { return }
        let measured = owner.currentItem?.duration.seconds ?? 0
        let duration = measured.isFinite && measured > 0 ? measured : durationHint ?? 0
        let next = FeedPlaybackPosition(duration: duration, seconds: time.seconds)
        if position != next { position = next }
        if countsViews, let next, let videoID, wantsPlayback,
           watch.sample(next, playing: owner.timeControlStatus == .playing && playbackGate?.owns(owner, videoID: videoID) == true) {
            let receipt = ClipViewReceipt.forVideo(videoID)
            Task { [weak self] in
                guard let total = try? await FeedService.recordView(video: videoID, receipt: receipt),
                      let self, self.videoID == videoID else { return }
                self.viewCount = max(total, self.viewCount ?? 0)
            }
        }
    }

    private func seek(to position: FeedPlaybackPosition) {
        guard let player else { return }
        seekID += 1
        let id = seekID
        isSeeking = true
        watch.resetSample()
        player.pause()
        player.currentItem?.cancelPendingSeeks()
        let time = CMTime(seconds: position.seekSeconds, preferredTimescale: 600)
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self, weak player] _ in
            Task { @MainActor in
                guard let self, let player, self.player === player, self.seekID == id else { return }
                self.isSeeking = false
                self.sample(player, time: player.currentTime())
                self.syncPlayback()
            }
        }
    }

    private func cancelSeek() {
        seekID += 1
        isTracking = false
        isSeeking = false
        watch.resetSample()
        player?.currentItem?.cancelPendingSeeks()
    }

    private func syncPlayback() {
        guard let player, let videoID, let playbackGate else { return }
        if isCurrent && wantsPlayback && !isTracking && !isSeeking {
            playbackGate.play(player, videoID: videoID)
        } else if player.timeControlStatus != .paused {
            player.pause()
        }
    }

    private func stopObserving() {
        if let timeObserver { player?.removeTimeObserver(timeObserver) }
        timeObserver = nil
    }
}

private struct FeedProgressStrip: View {
    static let height: CGFloat = 44
    @Environment(\.studioPalette) private var palette
    @ObservedObject var playback: FeedPlaybackController

    var body: some View {
        if let position = playback.position, !playback.failed {
            let elapsed = FeedPlaybackPosition.timeLabel(position.seconds)
            let duration = FeedPlaybackPosition.timeLabel(position.duration)
            HStack(spacing: 8) {
                Slider(value: Binding(get: { position.seconds }, set: playback.setSeconds),
                       in: 0...position.duration, onEditingChanged: playback.setEditing)
                    .tint(palette.mediaAccent)
                    .frame(minHeight: Self.height)
                    .accessibilityLabel("Video progress")
                    .accessibilityValue("\(elapsed) of \(duration)")
                    .accessibilityIdentifier("feed-video-progress")
                Text("\(elapsed) / \(duration)")
                    .font(.caption2.monospacedDigit().weight(.semibold))
                    .accessibilityHidden(true)
            }
        }
    }
}

@MainActor
final class FeedClipFailureMonitor {
    private let player: AVPlayer
    private var onFailure: (() -> Void)?
    private var observations: [NSKeyValueObservation] = []
    private var itemStatus: NSKeyValueObservation?
    private var itemEndFailure: AnyCancellable?

    init(player: AVPlayer, looper: AVPlayerLooper? = nil, onFailure: @escaping () -> Void) {
        self.player = player
        self.onFailure = onFailure
        // The typed KVO payload can omit these Objective-C enum values.
        observations = [
            player.observe(\.status, options: [.initial]) { @Sendable [weak self] player, _ in
                if player.status == .failed { self?.scheduleFailure() }
            },
            player.observe(\.currentItem) { @Sendable [weak self] _, _ in
                DispatchQueue.main.async { [weak self] in self?.observeCurrentItem() }
            }
        ]
        if let looper {
            observations.append(looper.observe(\.status, options: [.initial]) { @Sendable [weak self] looper, _ in
                if looper.status == .failed { self?.scheduleFailure() }
            })
        }
        observeCurrentItem()
    }

    private func observeCurrentItem() {
        itemStatus = nil
        itemEndFailure = nil
        // The looper plays replicas, not the template item.
        guard onFailure != nil, let item = player.currentItem else { return }
        itemStatus = item.observe(\.status, options: [.initial]) { @Sendable [weak self] item, _ in
            if item.status == .failed { self?.scheduleFailure(for: item) }
        }
        itemEndFailure = NotificationCenter.default
            .publisher(for: AVPlayerItem.failedToPlayToEndTimeNotification, object: item)
            .sink { @Sendable [weak self, weak item] _ in
                if let item { self?.scheduleFailure(for: item) }
            }
    }

    nonisolated private func scheduleFailure(for item: AVPlayerItem? = nil) {
        DispatchQueue.main.async { [weak self] in
            guard let self, let report = self.onFailure else { return }
            if let item, self.player.currentItem !== item { return }
            self.onFailure = nil
            self.observations.removeAll()
            self.itemStatus = nil
            self.itemEndFailure = nil
            report()
        }
    }
}

private struct FeedPlayer: UIViewRepresentable {
    let videoID: UUID
    let url: URL
    let thumb: URL
    let playback: FeedPlaybackController
    let playbackGate: FeedPlaybackGate
    let isCurrent: Bool
    let playing: Bool
    let muted: Bool
    let aspectFit: Bool
    let durationHint: Double?
    let countsViews: Bool
    let selectsPlayback: Bool
    let onEnd: () -> Bool
    let onFailure: () -> Void

    func makeUIView(context: Context) -> PlayerView { PlayerView() }

    func updateUIView(_ view: PlayerView, context: Context) {
        if selectsPlayback { playbackGate.select(isCurrent ? videoID : nil) }
        view.onFailure = onFailure
        view.onEnd = onEnd
        view.setAspectFit(aspectFit)
        view.load(url: url, thumb: thumb)
        if view.playback !== playback { view.playback?.disconnect(from: view.player); view.playback = playback }
        guard let player = view.player else { return }
        player.isMuted = muted
        playback.configure(player: player, videoID: videoID, gate: playbackGate,
                           isCurrent: isCurrent, wantsPlayback: playing, durationHint: durationHint, countsViews: countsViews)
    }

    static func dismantleUIView(_ view: PlayerView, coordinator: ()) {
        view.playback?.disconnect(from: view.player)
        view.playback = nil
        view.stopObservingAndPause()
    }

    final class PlayerView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        private var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
        private let thumbView = UIImageView()
        private var failureMonitor: FeedClipFailureMonitor?
        private var endObservation: AnyCancellable?
        private(set) var player: AVPlayer?
        var playback: FeedPlaybackController?
        private var loadedURL: URL?
        var onFailure: (() -> Void)?
        var onEnd: (() -> Bool)?

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

        func setAspectFit(_ fit: Bool) {
            playerLayer.videoGravity = fit ? .resizeAspect : .resizeAspectFill
            thumbView.contentMode = fit ? .scaleAspectFit : .scaleAspectFill
        }

        func load(url: URL, thumb: URL) {
            guard url != loadedURL else { return }
            stopObservingAndPause()
            loadedURL = url
            thumbView.image = nil
            thumbView.isHidden = false
            URLSession.shared.dataTask(with: thumb) { [weak self] data, _, _ in
                guard let data, let img = UIImage(data: data) else { return }
                DispatchQueue.main.async { if self?.loadedURL == url { self?.thumbView.image = img } }
            }.resume()
            let item = AVPlayerItem(url: url)
            let clipPlayer = AVPlayer(playerItem: item)
            clipPlayer.actionAtItemEnd = .pause
            player = clipPlayer
            playerLayer.player = clipPlayer
            failureMonitor = FeedClipFailureMonitor(player: clipPlayer) { [weak self] in
                self?.player?.pause()
                self?.onFailure?()
            }
            endObservation = NotificationCenter.default.publisher(for: AVPlayerItem.didPlayToEndTimeNotification, object: item)
                .sink { [weak self, weak clipPlayer] _ in
                    DispatchQueue.main.async { [weak self, weak clipPlayer] in
                        guard let self, let clipPlayer, self.player === clipPlayer, let onEnd else { return }
                        playback?.finished(clipPlayer, advance: onEnd)
                    }
                }
        }

        func stopObservingAndPause() {
            failureMonitor = nil
            endObservation = nil
            player?.pause()
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
