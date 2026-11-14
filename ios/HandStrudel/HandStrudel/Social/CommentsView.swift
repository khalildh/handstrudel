import SwiftUI

struct CommentsView: View {
    @Environment(\.studioPalette) private var palette
    let video: Video
    let targetComment: UUID?
    @ObservedObject var auth: AuthManager
    var onBlock: (UUID) -> Void = { _ in }
    @Environment(\.dismiss) private var dismiss
    @FocusState private var composerFocused: Bool
    @State private var roots: [VideoComment] = []
    @State private var replies: [UUID: [VideoComment]] = [:]
    @State private var replyTarget: VideoComment?
    @State private var draft = ""
    @State private var errorMessage: String?
    @State private var notice: String?
    @State private var showSignIn = false
    @State private var action: CommentAction?
    @State private var busy = false
    @State private var loading = true
    @State private var hasMore = false
    @State private var rootOffset = 0
    @State private var replyOffsets: [UUID: Int] = [:]
    @State private var enabled: Bool
    @State private var pendingLikes: Set<UUID> = []

    init(video: Video, auth: AuthManager, targetComment: UUID? = nil, onBlock: @escaping (UUID) -> Void = { _ in }) {
        self.video = video
        self.targetComment = targetComment
        self.auth = auth
        self.onBlock = onBlock
        _enabled = State(initialValue: video.commentsEnabled ?? false)
    }

    private var canPost: Bool { auth.isSignedIn && !auth.needsProfileSetup }
    private var isOwner: Bool { auth.userId == video.userId }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if let errorMessage {
                HStack {
                    Text(errorMessage)
                    Spacer(minLength: 8)
                    Button("Dismiss", systemImage: "xmark") { self.errorMessage = nil }.labelStyle(.iconOnly)
                }
                .font(.footnote)
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                .background(palette.surface)
            } else if let notice {
                Text(notice).font(.footnote).foregroundStyle(palette.accent).padding(8)
            }
            thread
            if enabled {
                Divider()
                composer
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.background.ignoresSafeArea())
        .foregroundStyle(palette.ink)
        .tint(palette.accent)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(busy)
        .task(id: auth.userId) {
            roots = []
            replies = [:]
            await reload()
            if let targetComment { await reveal(targetComment) }
        }
        .sheet(isPresented: $showSignIn) { SignInView(auth: auth, reason: "Sign in to join the conversation.") }
        .confirmationDialog(action?.title ?? "Comment options", isPresented: Binding(
            get: { action != nil }, set: { if !$0 { action = nil } }), titleVisibility: .visible, presenting: action
        ) { action in
            switch action {
            case let .report(comment):
                ForEach(CommentReportReason.allCases) { reason in
                    Button(reason.title) {
                        perform {
                            try await FeedService.reportComment(comment.id, reason: reason)
                            notice = "Report sent. This comment is hidden for you."
                            await refreshThread(around: comment)
                        }
                    }
                }
            case let .delete(comment):
                Button("Delete", role: .destructive) {
                    perform {
                        try await FeedService.deleteComment(comment.id)
                        await refreshThread(around: comment)
                    }
                }
            case let .block(comment):
                Button("Block @\(comment.username)", role: .destructive) {
                    guard let uid = auth.userId else { return }
                    perform {
                        try await FeedService.block(comment.userId, user: uid)
                        onBlock(comment.userId)
                        notice = "Blocked @\(comment.username)."
                        await reload()
                    }
                }
            }
        } message: { action in
            if case .delete(let comment) = action, comment.replyCount > 0 {
                Text("This also removes the replies to this comment.")
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Comments").font(.system(.title2, design: .serif)).accessibilityAddTraits(.isHeader)
                if let creator = video.username {
                    Text("Performance by @\(creator)").font(.caption).foregroundStyle(palette.muted)
                }
            }
            Spacer()
            if isOwner {
                Menu {
                    Button(enabled ? "Turn off comments" : "Turn on comments",
                           systemImage: enabled ? "bubble.left.and.exclamationmark.bubble.right" : "bubble.left") {
                        guard let uid = auth.userId else { return }
                        perform {
                            try await FeedService.setCommentsEnabled(!enabled, video: video.id, user: uid)
                            enabled.toggle()
                            roots = []
                            replies = [:]
                            await reload()
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis").frame(width: 44, height: 44)
                }
                .accessibilityLabel("Manage comments")
                .disabled(busy)
            }
            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.system(size: 13, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .background(palette.surface, in: Circle())
            }
            .accessibilityLabel("Close comments")
            .disabled(busy)
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 10)
    }

    private var thread: some View {
        ScrollViewReader { proxy in
            threadContent
                .onChange(of: highlightedComment) { id in
                    if let id { withAnimation { proxy.scrollTo(id, anchor: .center) } }
                }
        }
    }

    @State private var highlightedComment: UUID?

    private var threadContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                if !enabled {
                    empty("Comments are off", detail: "The creator has turned off comments for this performance.")
                } else if roots.isEmpty {
                    if loading {
                        ProgressView("Loading comments").frame(maxWidth: .infinity).padding(.vertical, 32)
                    } else if errorMessage == nil {
                        empty("Start the conversation", detail: "Say what you liked, or ask how they made that sound.")
                    }
                }
                ForEach(roots) { comment in
                    commentRow(comment, root: comment)
                        .id(comment.id)
                    if let items = replies[comment.id] {
                        ForEach(items) { reply in
                            commentRow(reply, root: comment).padding(.leading, 38).id(reply.id)
                        }
                    }
                    let loaded = replies[comment.id]?.count ?? 0
                    if comment.replyCount > loaded {
                        Button(loaded == 0 ? "View replies (\(comment.replyCount))" : "More replies") {
                            perform { try await loadReplies(comment.id, append: true) }
                        }
                        .font(.caption.weight(.semibold))
                        .padding(.leading, 47)
                    } else if loaded > 0 {
                        Button("Hide replies") { replies[comment.id] = nil }
                            .font(.caption.weight(.semibold)).padding(.leading, 47)
                    }
                }
                if hasMore {
                    Button("Load more comments") {
                        perform {
                            let more = try await FeedService.comments(video: video.id, offset: rootOffset)
                            rootOffset += more.count
                            hasMore = more.count == FeedService.commentPageSize
                            let seen = Set(roots.map(\.id))
                            roots += more.filter { !seen.contains($0.id) }
                        }
                    }
                    .font(.footnote.weight(.semibold))
                }
            }
            .padding(18)
        }
        .scrollDismissesKeyboard(.interactively)
        .refreshable { if !busy { await reload() } }
        .disabled(busy)
    }

    private func empty(_ title: String, detail: String) -> some View {
        VStack(spacing: 7) {
            Image(systemName: "bubble.left.and.bubble.right").font(.title2).foregroundStyle(palette.accent)
            Text(title).font(.headline)
            Text(detail).font(.subheadline).foregroundStyle(palette.muted)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }

    private func commentRow(_ comment: VideoComment, root: VideoComment) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(String(comment.username.prefix(1)).uppercased())
                .font(.caption.bold())
                .frame(width: 32, height: 32)
                .background(palette.surface, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text("@\(comment.username)").font(.caption.bold())
                    if comment.userId == video.userId {
                        Text("Creator").font(.caption2.weight(.semibold)).foregroundStyle(palette.accent)
                    }
                    Spacer()
                    Text(comment.createdAt, style: .relative).font(.caption2).foregroundStyle(palette.muted)
                }
                Text(verbatim: comment.body).font(.subheadline).frame(maxWidth: .infinity, alignment: .leading)
                Button("Reply") {
                    if !canPost { showSignIn = true }
                    replyTarget = root
                    if canPost { composerFocused = true }
                }
                .font(.caption.weight(.semibold)).foregroundStyle(palette.muted)
                .padding(.vertical, 4)
            }
            VStack(spacing: 0) {
                if let count = comment.likeCount {
                    likeButton(comment, count: count)
                }
                commentMenu(comment)
            }
        }
        .padding(4)
        .background {
            if highlightedComment == comment.id { palette.accent.opacity(0.10) }
        }
    }

    private func commentMenu(_ comment: VideoComment) -> some View {
        Menu {
            if comment.userId == auth.userId || isOwner {
                Button("Delete comment", systemImage: "trash", role: .destructive) { action = .delete(comment) }
            }
            if comment.userId != auth.userId {
                Button("Report comment", systemImage: "flag") {
                    if canPost { action = .report(comment) } else { showSignIn = true }
                }
                Button("Block @\(comment.username)", systemImage: "hand.raised", role: .destructive) {
                    if canPost { action = .block(comment) } else { showSignIn = true }
                }
            }
        } label: {
            Image(systemName: "ellipsis").frame(width: 44, height: 44).foregroundStyle(palette.muted)
        }
        .accessibilityLabel("Options for comment by @\(comment.username)")
    }

    private func likeButton(_ comment: VideoComment, count: Int) -> some View {
        let liked = comment.likedByMe == true
        return Button { toggleLike(comment) } label: {
            VStack(spacing: 2) {
                Image(systemName: liked ? "heart.fill" : "heart").font(.subheadline.weight(.semibold))
                Text(count.formatted(.number.notation(.compactName))).font(.caption2.monospacedDigit())
            }
            .foregroundStyle(liked ? palette.recording : palette.muted)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(pendingLikes.contains(comment.id) || loading)
        .accessibilityLabel(liked ? "Unlike comment by @\(comment.username)" : "Like comment by @\(comment.username)")
        .accessibilityValue(count == 1 ? "1 like" : "\(count) likes")
        .accessibilityIdentifier("comment-like-\(comment.id.uuidString.lowercased())")
    }

    private func toggleLike(_ comment: VideoComment) {
        guard enabled, let viewer = auth.userId else { showSignIn = true; return }
        guard pendingLikes.insert(comment.id).inserted else { return }
        let liked = comment.likedByMe != true
        errorMessage = nil
        Task {
            defer { pendingLikes.remove(comment.id) }
            do {
                try await FeedService.setCommentLiked(liked, comment: comment.id, user: viewer)
                guard auth.userId == viewer else { return }
                // Update the displayed row, which may have refreshed while the request was in flight.
                if let parent = comment.parentId, let index = replies[parent]?.firstIndex(where: { $0.id == comment.id }) {
                    replies[parent]?[index].applyLike(liked)
                } else if let index = roots.firstIndex(where: { $0.id == comment.id }) {
                    roots[index].applyLike(liked)
                }
            } catch {
                guard auth.userId == viewer else { return }
                errorMessage = (error as? SocialError)?.localizedDescription ?? "Couldn't update this like. Try again."
            }
        }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 7) {
            if let replyTarget {
                HStack {
                    Text("Replying to @\(replyTarget.username)").font(.caption)
                    Spacer()
                    Button("Cancel reply", systemImage: "xmark") { self.replyTarget = nil }.labelStyle(.iconOnly)
                }
                .foregroundStyle(palette.muted)
            }
            if canPost {
                HStack(alignment: .bottom, spacing: 9) {
                    TextField(replyTarget == nil ? "Add a comment…" : "Write a reply…", text: $draft, axis: .vertical)
                        .lineLimit(1...4)
                        .padding(11)
                        .background(palette.surface, in: RoundedRectangle(cornerRadius: 16))
                        .focused($composerFocused)
                        .accessibilityIdentifier("comment-text")
                    Button(action: submit) {
                        Image(systemName: "arrow.up")
                            .font(.body.weight(.bold))
                            .frame(width: 44, height: 44)
                            .foregroundStyle(palette.onAccent)
                            .background(palette.accent, in: Circle())
                    }
                    .disabled(busy || !VideoComment.isValidBody(draft))
                    .opacity(VideoComment.isValidBody(draft) ? 1 : 0.45)
                    .accessibilityLabel("Post comment")
                }
                if draft.unicodeScalars.count > 250 {
                    Text("\(draft.unicodeScalars.count)/\(VideoComment.maxLength)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(VideoComment.isValidBody(draft) ? palette.muted : palette.recording)
                }
            } else {
                Button("Sign in to comment", systemImage: "bubble.left") { showSignIn = true }
                    .buttonStyle(StudioActionStyle())
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .disabled(busy)
    }

    private func reload() async {
        loading = true
        defer { loading = false }
        errorMessage = nil
        do {
            let fresh = try await FeedService.video(id: video.id)
            let commentsEnabled = fresh?.commentsEnabled ?? false
            let items = commentsEnabled ? try await FeedService.comments(video: video.id) : []
            guard !Task.isCancelled else { return }
            enabled = commentsEnabled
            roots = items
            rootOffset = items.count
            hasMore = items.count == FeedService.commentPageSize
            replies = [:]
            replyOffsets = [:]
            if let replyTarget, !items.contains(where: { $0.id == replyTarget.id }) { self.replyTarget = nil }
        } catch {
            if !Task.isCancelled { errorMessage = "Couldn't load comments. Pull down to try again." }
        }
    }

    private func loadReplies(_ parent: UUID, append: Bool = false) async throws {
        let prior = append ? replies[parent, default: []] : []
        let offset = append && replies[parent] != nil ? replyOffsets[parent, default: 0] : 0
        let items = try await FeedService.comments(video: video.id, parent: parent, offset: offset)
        replyOffsets[parent] = offset + items.count
        let seen = Set(prior.map(\.id))
        replies[parent] = prior + items.filter { !seen.contains($0.id) }
    }

    private func reveal(_ id: UUID) async {
        do {
            guard let target = try await FeedService.comment(id: id, video: video.id) else {
                notice = "This comment is no longer available."
                return
            }
            if let parent = target.parentId {
                if !roots.contains(where: { $0.id == parent }),
                   let root = try await FeedService.comment(id: parent, video: video.id) {
                    roots.append(root)
                }
                try await loadReplies(parent)
                if replies[parent]?.contains(where: { $0.id == id }) == false {
                    replies[parent, default: []].append(target)
                }
            } else if !roots.contains(where: { $0.id == id }) {
                roots.append(target)
            }
            highlightedComment = id
        } catch {
            notice = "Couldn't open that comment. Pull down to refresh."
        }
    }

    private func refreshThread(around comment: VideoComment) async {
        if let parent = comment.parentId {
            replies[parent]?.removeAll { $0.id == comment.id }
        } else {
            roots.removeAll { $0.id == comment.id }
            replies[comment.id] = nil
            if replyTarget?.id == comment.id { replyTarget = nil }
        }
        await reload()
        if let parent = comment.parentId, roots.contains(where: { $0.id == parent }) {
            try? await loadReplies(parent)
        }
    }

    private func submit() {
        guard canPost, VideoComment.isValidBody(draft) else { return }
        let body = VideoComment.trimmed(draft)
        let target = replyTarget
        perform {
            try await FeedService.addComment(video: video.id, parent: target?.id, text: body)
            draft = ""
            replyTarget = nil
            composerFocused = false
            await reload()
            if let target, roots.contains(where: { $0.id == target.id }) {
                try? await loadReplies(target.id)
            }
        }
    }

    private func perform(_ work: @escaping () async throws -> Void) {
        guard !busy else { return }
        busy = true
        errorMessage = nil
        notice = nil
        Task {
            defer { busy = false }
            do { try await work() }
            catch {
                errorMessage = (error as? SocialError)?.localizedDescription ?? "Couldn't complete that action. Try again."
            }
        }
    }
}

private enum CommentAction {
    case report(VideoComment), delete(VideoComment), block(VideoComment)

    var title: String {
        switch self {
        case .report: return "Report this comment"
        case .delete: return "Delete this comment?"
        case .block(let comment): return "Block @\(comment.username)?"
        }
    }
}
