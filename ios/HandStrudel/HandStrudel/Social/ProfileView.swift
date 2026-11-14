import AVKit
import Supabase
import SwiftUI

/// The signed-in user's profile: their posts, plus account settings
/// (sign out, delete account).
struct ProfileView: View {
    @Environment(\.studioPalette) private var palette
    @ObservedObject var auth: AuthManager
    @State private var videos: [Video] = []
    @State private var loading = false
    @State private var playing: Video?
    @State private var confirmDeleteVideo: Video?
    @State private var confirmDeleteAccount = false
    @State private var showSignIn = false
    @State private var showBlocked = false
    @State private var showAppearance = false

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 6)]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
                .padding(.horizontal, 21)
                .padding(.top, 9)
            if !auth.isSignedIn || auth.needsProfileSetup {
                signedOut
            } else {
                content
            }
        }
        .frame(maxWidth: 650)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(palette.background.ignoresSafeArea())
        .foregroundStyle(palette.ink)
        .tint(palette.accent)
        .task(id: auth.userId) { await load() }
        .sheet(isPresented: $showSignIn) { SignInView(auth: auth) }
        .sheet(isPresented: $showBlocked) { BlockedUsersView(auth: auth) }
        .sheet(isPresented: $showAppearance) { StudioThemePicker() }
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
            Button("Delete forever", role: .destructive) { Task { _ = await auth.deleteAccount() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes your profile, videos, and comments. It can't be undone.")
        }
    }

    private var header: some View {
        HStack {
            Text("Account")
                .font(.system(size: 33, weight: .regular, design: .serif))
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Menu {
                Button("Appearance", systemImage: "paintpalette") { showAppearance = true }
                if auth.isSignedIn {
                    Button("Blocked users") { showBlocked = true }
                    Button("Sign out") { Task { await auth.signOut() } }
                    Button("Delete account…", role: .destructive) { confirmDeleteAccount = true }
                }
                Link("Community Guidelines", destination: SocialConfig.guidelinesURL)
                Link("Terms of Use", destination: SocialConfig.termsURL)
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(palette.ink)
                    .frame(width: 44, height: 44)
                    .background(palette.surface, in: Circle())
                    .overlay { Circle().strokeBorder(palette.border) }
            }
            .accessibilityLabel("Account settings")
        }
    }

    private var signedOut: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 17) {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(palette.accent)
                    .frame(width: 58, height: 58)
                    .background(palette.accent.opacity(0.10), in: Circle())
                    .accessibilityHidden(true)
                Text("Your performances")
                    .font(.system(.largeTitle, design: .serif))
                    .accessibilityAddTraits(.isHeader)
                Text("Sign in to publish your clips and see them together on your profile.")
                    .font(.subheadline)
                    .foregroundStyle(palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Sign in") { showSignIn = true }
                    .buttonStyle(StudioActionStyle())
                    .padding(.top, 6)
            }
            .padding(21)
            .frame(maxWidth: 480, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 22)
                    .fill(LinearGradient(colors: [palette.accent.opacity(0.09), palette.surface],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
            }
            .overlay { RoundedRectangle(cornerRadius: 22).strokeBorder(palette.border).allowsHitTesting(false) }
            .padding(.horizontal, 21)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 9) {
                if let username = auth.profile?.username {
                    Text("@\(username)").font(.title2.weight(.semibold))
                }
                Text("Performances").font(.headline)
                if loading {
                    ProgressView().tint(palette.accent)
                } else if videos.isEmpty {
                    Text("No posts yet. Record a clip and choose “Post to HandStrudel”.")
                        .font(.subheadline)
                        .foregroundStyle(palette.muted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 12)

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(videos) { v in
                    Button { playing = v } label: {
                        palette.surface
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
                            .clipShape(RoundedRectangle(cornerRadius: 9))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(v.caption.isEmpty ? "Play performance" : "Play \(v.caption)")
                    .contextMenu {
                        Button("Delete post", role: .destructive) { confirmDeleteVideo = v }
                    }
                }
            }
        }
        .padding(.horizontal, 21)
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
