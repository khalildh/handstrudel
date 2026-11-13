import AVKit
import Supabase
import SwiftUI

/// The signed-in user's profile: their posts, plus account settings
/// (sign out, delete account).
struct ProfileView: View {
    @ObservedObject var auth: AuthManager
    @Environment(\.dismiss) private var dismiss

    @State private var videos: [Video] = []
    @State private var loading = false
    @State private var playing: Video?
    @State private var confirmDeleteVideo: Video?
    @State private var confirmDeleteAccount = false
    @State private var showSignIn = false
    @State private var showBlocked = false

    private let columns = [GridItem(.flexible(), spacing: 2), GridItem(.flexible(), spacing: 2),
                           GridItem(.flexible(), spacing: 2)]

    var body: some View {
        NavigationStack {
            Group {
                if !auth.isSignedIn || auth.needsProfileSetup {
                    VStack(spacing: 16) {
                        Image(systemName: "person.crop.circle").font(.system(size: 56)).foregroundStyle(.secondary)
                        Text("Sign in to post your performances and keep them in one place.")
                            .multilineTextAlignment(.center).foregroundStyle(.secondary)
                        Button("Sign in") { showSignIn = true }.buttonStyle(.borderedProminent)
                    }
                    .padding(32)
                } else {
                    content
                }
            }
            .navigationTitle(auth.profile?.username.map { "@\($0)" } ?? "Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                if auth.isSignedIn {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Button("Blocked users") { showBlocked = true }
                            Link("Community Guidelines", destination: SocialConfig.guidelinesURL)
                            Button("Sign out") { Task { await auth.signOut() } }
                            Button("Delete account…", role: .destructive) { confirmDeleteAccount = true }
                        } label: { Image(systemName: "ellipsis.circle") }
                    }
                }
            }
        }
        .task(id: auth.userId) { await load() }
        .sheet(isPresented: $showSignIn) { SignInView(auth: auth) }
        .sheet(isPresented: $showBlocked) { BlockedUsersView(auth: auth) }
        .fullScreenCover(item: $playing) { v in
            ZStack(alignment: .topTrailing) {
                VideoPlayer(player: AVPlayer(url: v.videoURL)).ignoresSafeArea()
                Button { playing = nil } label: {
                    Image(systemName: "xmark.circle.fill").font(.title).padding()
                }
            }
        }
        .confirmationDialog("Delete this post?", isPresented: Binding(
            get: { confirmDeleteVideo != nil }, set: { if !$0 { confirmDeleteVideo = nil } }),
                            titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let v = confirmDeleteVideo { Task { await delete(v) } }
            }
        }
        .alert("Delete your account?", isPresented: $confirmDeleteAccount) {
            Button("Delete forever", role: .destructive) { Task { if await auth.deleteAccount() { dismiss() } } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes your profile and every video you've posted. It can't be undone.")
        }
    }

    private var content: some View {
        ScrollView {
            if videos.isEmpty && !loading {
                Text("No posts yet. Record a clip and choose “Post to HandStrudel”.")
                    .foregroundStyle(.secondary).multilineTextAlignment(.center).padding(40)
            }
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(videos) { v in
                    Button { playing = v } label: {
                        Color.white.opacity(0.06)
                            .aspectRatio(9 / 16, contentMode: .fit)
                            .overlay {
                                AsyncImage(url: v.thumbURL) { img in img.resizable().scaledToFill() }
                                    placeholder: { Color.clear }
                            }
                            .clipped()
                            .overlay(alignment: .bottomLeading) {
                                Label("\(v.likeCount)", systemImage: "heart.fill")
                                    .font(.caption2.bold()).padding(6)
                            }
                            .overlay(alignment: .topTrailing) {
                                if v.hidden == true {
                                    Image(systemName: "eye.slash.fill").font(.caption).padding(6)
                                }
                            }
                    }
                    .contextMenu {
                        Button("Delete post", role: .destructive) { confirmDeleteVideo = v }
                    }
                }
            }
        }
        .refreshable { await load() }
    }

    private func load() async {
        guard let uid = auth.userId else { videos = []; return }
        loading = true
        videos = (try? await supabase.from("videos").select()
            .eq("user_id", value: uid).order("created_at", ascending: false)
            .execute().value) ?? []
        loading = false
    }

    private func delete(_ v: Video) async {
        do {
            struct Body: Encodable { let videoId: UUID }
            try await supabase.functions.invoke("delete-video", options: FunctionInvokeOptions(body: Body(videoId: v.id)))
            videos.removeAll { $0.id == v.id }
        } catch {
            auth.errorMessage = error.localizedDescription
        }
    }
}

/// People you've blocked, with unblock.
struct BlockedUsersView: View {
    @ObservedObject var auth: AuthManager
    @Environment(\.dismiss) private var dismiss
    @State private var blocked: [FeedService.BlockedUser] = []
    @State private var loaded = false

    var body: some View {
        NavigationStack {
            List {
                if loaded && blocked.isEmpty {
                    Text("You haven't blocked anyone.").foregroundStyle(.secondary)
                }
                ForEach(blocked) { b in
                    HStack {
                        Text("@\(b.profile?.username ?? "user")")
                        Spacer()
                        Button("Unblock") {
                            guard let uid = auth.userId else { return }
                            Task {
                                try? await FeedService.unblock(b.blockedId, user: uid)
                                blocked.removeAll { $0.id == b.id }
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .navigationTitle("Blocked users")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .task {
                if let uid = auth.userId { blocked = (try? await FeedService.blockedUsers(user: uid)) ?? [] }
                loaded = true
            }
        }
    }
}
