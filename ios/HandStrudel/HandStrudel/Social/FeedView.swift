import AVFoundation
import SwiftUI
import UIKit

/// Full-screen, vertically paged feed of public posts (newest first).
/// Browsable signed out; liking, following, reporting and blocking need an account.
struct FeedView: View {
    @ObservedObject var auth: AuthManager
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model = FeedModel()
    @State private var showSignIn = false
    @State private var reporting: Video?
    @State private var toast: String?

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()
            if model.videos.isEmpty {
                emptyState
            } else {
                PagedFeed(videos: model.videos, current: $model.current) { video, isCurrent in
                    FeedCell(video: video, isCurrent: isCurrent, isMine: video.userId == auth.userId,
                             isFollowing: model.following.contains(video.userId),
                             like: { act { try await model.toggleLike(video, user: $0) } },
                             follow: { act { try await model.toggleFollow(video.userId, user: $0) } },
                             report: { requireSignIn { _ in reporting = video } },
                             block: { act { try await model.block(video.userId, user: $0); show("Blocked @\(video.username ?? "user")") } },
                             delete: { Task { try? await model.delete(video) } })
                }
                .ignoresSafeArea()
                .onChange(of: model.current) { i in
                    if i >= model.videos.count - 3 { Task { await model.loadMore() } }
                }
            }
            topBar
            if let toast {
                Text(toast).font(.subheadline.bold()).padding(.horizontal, 16).padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule()).padding(.top, 72)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .task { await model.refresh(user: auth.userId) }
        .onChange(of: auth.userId) { uid in Task { await model.refresh(user: uid) } }
        .sheet(isPresented: $showSignIn) { SignInView(auth: auth, reason: "Sign in to like, follow and report posts.") }
        .confirmationDialog("Report this post", isPresented: Binding(
            get: { reporting != nil }, set: { if !$0 { reporting = nil } }), titleVisibility: .visible) {
            ForEach(FeedService.ReportReason.allCases) { reason in
                Button(reason.rawValue) {
                    guard let v = reporting else { return }
                    act { try await model.report(v, reason: reason, user: $0); show("Thanks — we'll review it within 24 hours") }
                }
            }
        } message: { Text("Reports are anonymous. Posts with several reports are hidden while we review them.") }
        .statusBarHidden()
    }

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.headline).padding(12).background(.ultraThinMaterial, in: Circle())
            }
            .accessibilityLabel("Close feed")
            Spacer()
            Text("Feed").font(.headline).shadow(radius: 4)
            Spacer()
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 16).padding(.top, 8)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            if model.loading { ProgressView() } else {
                Image(systemName: "hand.raised.fingers.spread").font(.system(size: 48)).foregroundStyle(.secondary)
                Text(model.error ?? "No posts yet. Record a clip and be the first!")
                    .multilineTextAlignment(.center).foregroundStyle(.secondary).padding(.horizontal, 40)
                Button("Refresh") { Task { await model.refresh(user: auth.userId) } }
            }
        }
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
}

// MARK: - Model

@MainActor
final class FeedModel: ObservableObject {
    @Published var videos: [Video] = []
    @Published var current = 0
    @Published var following: Set<UUID> = []
    @Published var loading = false
    @Published var error: String?
    private var reachedEnd = false

    func refresh(user: UUID?) async {
        loading = true; error = nil; reachedEnd = false
        do {
            videos = try await FeedService.page()
            current = 0
            reachedEnd = videos.count < FeedService.pageSize
            await loadFollowing(user: user)
        } catch {
            self.error = "Couldn't load the feed. Check your connection."
        }
        loading = false
    }

    func loadMore() async {
        guard !loading, !reachedEnd, let last = videos.last else { return }
        loading = true
        if let more = try? await FeedService.page(after: last) {
            let seen = Set(videos.map(\.id))
            videos += more.filter { !seen.contains($0.id) }
            reachedEnd = more.count < FeedService.pageSize
        }
        loading = false
    }

    private func loadFollowing(user: UUID?) async {
        guard let user else { following = []; return }
        var set = Set<UUID>()
        for author in Set(videos.map(\.userId)) where author != user {
            if await FeedService.isFollowing(author, user: user) { set.insert(author) }
        }
        following = set
    }

    func toggleLike(_ video: Video, user: UUID) async throws {
        guard let i = videos.firstIndex(where: { $0.id == video.id }) else { return }
        let liked = !(videos[i].likedByMe ?? false)
        videos[i].likedByMe = liked                       // optimistic
        videos[i].likeCount += liked ? 1 : -1
        do { try await FeedService.setLiked(liked, video: video.id, user: user) } catch {
            videos[i].likedByMe = !liked; videos[i].likeCount -= liked ? 1 : -1
            throw error
        }
    }

    func toggleFollow(_ author: UUID, user: UUID) async throws {
        let follow = !following.contains(author)
        if follow { following.insert(author) } else { following.remove(author) }
        do { try await FeedService.setFollowing(follow, target: author, user: user) } catch {
            if follow { following.remove(author) } else { following.insert(author) }
            throw error
        }
    }

    func report(_ video: Video, reason: FeedService.ReportReason, user: UUID) async throws {
        try await FeedService.report(video.id, reason: reason, user: user)
        remove { $0.id == video.id }                       // hide it for the reporter right away
    }

    func block(_ author: UUID, user: UUID) async throws {
        try await FeedService.block(author, user: user)
        following.remove(author)
        remove { $0.userId == author }
    }

    func delete(_ video: Video) async throws {
        try await FeedService.deleteVideo(video.id)
        remove { $0.id == video.id }
    }

    private func remove(where match: (Video) -> Bool) {
        videos.removeAll(where: match)
        current = min(current, max(videos.count - 1, 0))
    }
}

// MARK: - Cell

private struct FeedCell: View {
    let video: Video
    let isCurrent: Bool
    let isMine: Bool
    let isFollowing: Bool
    let like: () -> Void
    let follow: () -> Void
    let report: () -> Void
    let block: () -> Void
    let delete: () -> Void
    @State private var muted = false
    @State private var confirmDelete = false

    var body: some View {
        ZStack(alignment: .bottom) {
            LoopingPlayer(url: video.videoURL, thumb: video.thumbURL, playing: isCurrent, muted: muted)
                .onTapGesture { muted.toggle() }
            LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .center, endPoint: .bottom)
                .allowsHitTesting(false)
            HStack(alignment: .bottom, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text("@\(video.username ?? "user")").font(.headline)
                        if !isMine {
                            Button(isFollowing ? "Following" : "Follow", action: follow)
                                .font(.caption.bold()).padding(.horizontal, 10).padding(.vertical, 4)
                                .background(isFollowing ? Color.white.opacity(0.2) : Color.green, in: Capsule())
                                .foregroundStyle(isFollowing ? .white : .black)
                        }
                    }
                    if !video.caption.isEmpty { Text(video.caption).font(.subheadline).lineLimit(3) }
                    if let instrument = video.instrument {
                        Label(instrument, systemImage: "music.note").font(.caption).foregroundStyle(.white.opacity(0.8))
                    }
                }
                Spacer()
                VStack(spacing: 20) {
                    Button(action: like) {
                        VStack(spacing: 4) {
                            Image(systemName: video.likedByMe == true ? "heart.fill" : "heart")
                                .font(.title).foregroundStyle(video.likedByMe == true ? .pink : .white)
                            Text("\(video.likeCount)").font(.caption.bold())
                        }
                    }
                    .accessibilityLabel(video.likedByMe == true ? "Unlike" : "Like")
                    ShareLink(item: video.videoURL) { Image(systemName: "arrowshape.turn.up.right.fill").font(.title2) }
                    Menu {
                        if isMine {
                            Button("Delete post", role: .destructive) { confirmDelete = true }
                        } else {
                            Button(action: report) { Label("Report", systemImage: "flag") }
                            Button(role: .destructive, action: block) {
                                Label("Block @\(video.username ?? "user")", systemImage: "hand.raised")
                            }
                        }
                    } label: { Image(systemName: "ellipsis").font(.title2).frame(width: 44, height: 44) }
                    .accessibilityLabel("More")
                    if muted { Image(systemName: "speaker.slash.fill").font(.caption) }
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16).padding(.bottom, 40)
        }
        .ignoresSafeArea()
        .confirmationDialog("Delete this post?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive, action: delete)
        }
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
        if old.videos.map(\.id) != videos.map(\.id) {
            cv.reloadData()
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
