import Supabase
import SwiftUI

struct ProfileView: View {
    @Environment(\.studioPalette) private var palette
    @ObservedObject var auth: AuthManager
    @State private var videos: [Video] = []
    @State private var counts: FeedService.ProfileCounts?
    @State private var loading = true
    @State private var more = false
    @State private var failed = false
    @State private var loadedUser: UUID?
    @State private var loadID = UUID()
    @State private var playing: Video?
    @State private var pendingAction: (() -> Void)?
    @State private var confirmDeleteVideo: Video?
    @State private var confirmDeleteAccount = false
    @State private var showSignIn = false
    @State private var showBlocked = false
    @State private var showAppearance = false
    @State private var showEdit = false
    @State private var deleteError = false

    let onMakeMusic: () -> Void
    let onTrySound: (SoundSetup) -> Void
    let onPlayAlong: (Video) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
                .padding(.horizontal, 21)
                .padding(.top, 9)
            if let profile = auth.profile, let username = profile.username, !auth.needsProfileSetup {
                content(profile, username: username)
                    .id(profile.id)
            } else {
                signedOut
            }
        }
        .frame(maxWidth: 650)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(palette.background.ignoresSafeArea())
        .foregroundStyle(palette.ink)
        .tint(palette.accent)
        .sheet(isPresented: $showSignIn) { SignInView(auth: auth) }
        .sheet(isPresented: $showBlocked) { BlockedUsersView(auth: auth) }
        .sheet(isPresented: $showAppearance) { StudioThemePicker() }
        .sheet(isPresented: $showEdit) { EditCreatorNameView(auth: auth) }
        .sheet(item: $playing, onDismiss: {
            let action = pendingAction
            pendingAction = nil
            action?()
        }) { video in
            CreatorVideoView(video: video, auth: auth, onPlayAlong: { source in
                pendingAction = { onPlayAlong(source) }
                playing = nil
            }, onTrySound: { sound in
                pendingAction = { onTrySound(sound) }
                playing = nil
            }, allowsSharing: video.hidden != true)
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
        .alert("Couldn't delete this post", isPresented: $deleteError) {
            Button("OK", role: .cancel) {}
        }
    }

    private var header: some View {
        HStack {
            Text("Account")
                .font(.system(.title, design: .serif))
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
                Section {
                    Link(destination: SocialConfig.reviewURL) { Label("Write an App Store review", systemImage: "star") }
                    Link(destination: SocialConfig.supportURL) { Label("Get help", systemImage: "questionmark.circle") }
                }
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
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 12) {
                    ProfileEyebrow(title: "HANDSTRUDEL / BACKSTAGE")
                    Text("Your music.\nYour stage.")
                        .font(.system(.largeTitle, design: .serif))
                        .accessibilityAddTraits(.isHeader)
                    Text("Give your performances a home. Share what you play and let others try your sounds.")
                        .font(.subheadline)
                        .foregroundStyle(palette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background { ProfileArtwork().clipShape(RoundedRectangle(cornerRadius: 24)) }
                .overlay { RoundedRectangle(cornerRadius: 24).strokeBorder(palette.border).allowsHitTesting(false) }
                Button(auth.needsProfileSetup ? "Finish setting up" : "Sign in") { showSignIn = true }
                    .buttonStyle(StudioActionStyle())
                Button("Make music as a guest", action: onMakeMusic)
                    .buttonStyle(ProfileActionStyle())
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 21)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
        }
    }

    private func content(_ profile: Profile, username: String) -> some View {
        ScrollView {
            let current = loadedUser == profile.id
            VStack(alignment: .leading, spacing: 20) {
                CreatorProfileHeader(username: username, displayName: profile.displayName,
                                     avatarKey: profile.avatarKey, counts: current ? counts : nil, isOwner: true) {
                    Button("Edit profile", systemImage: "pencil") { showEdit = true }
                        .buttonStyle(ProfileActionStyle())
                }
                CreatorPortfolio(videos: current ? videos : [], loading: !current || loading, failed: current && failed,
                                 more: current && more, isOwner: true, open: { playing = $0 },
                                 trySound: onTrySound, retry: { Task { await load() } },
                                 loadMore: { Task { await load(append: true) } },
                                 makeMusic: onMakeMusic, delete: { confirmDeleteVideo = $0 })
            }
            .padding(.horizontal, 21)
            .padding(.bottom, 24)
        }
        .refreshable { await load() }
        .task(id: profile.id) {
            loadedUser = profile.id
            videos = []
            counts = nil
            more = false
            await load()
        }
    }

    private func load(append: Bool = false) async {
        guard let uid = auth.userId, uid == loadedUser, !append || !loading else { return }
        let request = UUID()
        loadID = request
        loading = true
        failed = false
        defer { if request == loadID { loading = false } }
        async let metrics = append ? nil : FeedService.profileCounts(for: uid, owner: true)
        do {
            let page = try await FeedService.ownerPage(user: uid, after: append ? videos.last : nil)
            guard !Task.isCancelled, auth.userId == uid, request == loadID else { return }
            if append {
                let ids = Set(videos.map(\.id))
                videos += page.filter { !ids.contains($0.id) }
            } else { videos = page }
            more = page.count == FeedService.pageSize
        } catch {
            if !Task.isCancelled && request == loadID { failed = true }
        }
        if let result = await metrics, !Task.isCancelled, auth.userId == uid, request == loadID {
            counts = result
        }
    }

    private func delete(_ v: Video) async {
        do {
            struct Body: Encodable { let videoId: UUID }
            try await supabase.functions.invoke("delete-video", options: FunctionInvokeOptions(body: Body(videoId: v.id)))
            videos.removeAll { $0.id == v.id }
            await load()
        } catch {
            deleteError = true
        }
    }
}

struct CreatorProfileHeader<Actions: View>: View {
    @Environment(\.studioPalette) private var palette
    @Environment(\.dynamicTypeSize) private var typeSize
    let username: String
    let displayName: String?
    let avatarKey: String?
    let counts: FeedService.ProfileCounts?
    let isOwner: Bool
    @ViewBuilder var actions: () -> Actions

    private var artistName: String {
        let name = displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? username : name
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            ProfileEyebrow(title: isOwner ? "YOUR ARTIST PROFILE" : "HANDSTRUDEL ARTIST")
            let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 13))
                : AnyLayout(HStackLayout(spacing: 13))
            layout {
                avatar
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: artistName)
                        .font(.system(.largeTitle, design: .serif))
                        .accessibilityAddTraits(.isHeader)
                    Text(verbatim: "@\(username)")
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundStyle(palette.muted)
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            stats
            HStack(spacing: 8) {
                actions()
                    .frame(maxWidth: .infinity)
                ShareLink(item: SocialConfig.creatorURL(username)) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.body.weight(.semibold))
                        .frame(width: 46, height: 46)
                        .background(palette.background.opacity(0.65), in: RoundedRectangle(cornerRadius: 13))
                        .overlay { RoundedRectangle(cornerRadius: 13).strokeBorder(palette.border) }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Share profile")
            }
        }
        .padding(17)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { ProfileArtwork().clipShape(RoundedRectangle(cornerRadius: 23)) }
        .overlay { RoundedRectangle(cornerRadius: 23).strokeBorder(palette.border).allowsHitTesting(false) }
    }

    private var avatar: some View {
        ZStack {
            Circle().fill(palette.background)
            Text(artistName.prefix(1).uppercased())
                .font(.system(size: 30, weight: .regular, design: .serif))
                .foregroundStyle(palette.accent)
            if let avatarKey, !avatarKey.isEmpty {
                AsyncImage(url: SocialConfig.mediaURL(avatarKey)) { image in
                    image.resizable().scaledToFill()
                } placeholder: { Color.clear }
            }
        }
        .frame(width: 62, height: 62)
        .clipShape(Circle())
        .padding(3)
        .overlay { Circle().strokeBorder(palette.accent.opacity(0.45)) }
        .accessibilityHidden(true)
    }

    private var stats: some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 10))
        return layout {
            stat("Posts", counts?.posts)
            stat("Followers", counts?.followers)
            stat("Following", counts?.following)
        }
    }

    private func stat(_ name: String, _ count: Int?) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(count?.formatted(.number.notation(.compactName)) ?? "–")
                .font(.system(.title3, design: .monospaced).weight(.semibold))
            Text(name).font(.caption).foregroundStyle(palette.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(name)
        .accessibilityValue(count?.formatted() ?? "Unavailable")
    }
}

private struct ProfileArtwork: View {
    @Environment(\.studioPalette) private var palette

    var body: some View {
        ZStack {
            palette.surface
            RadialGradient(colors: [palette.glow, palette.surface.opacity(0.2), .clear],
                           center: .topTrailing, startRadius: 3, endRadius: 265)
            Canvas { context, size in
                let center = CGPoint(x: size.width * 0.85, y: size.height * 0.12)
                for index in 0..<15 {
                    let radius = 15 + Double(index) * 11
                    let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
                    context.stroke(Path(ellipseIn: rect), with: .color(palette.overtone.opacity(index.isMultiple(of: 4) ? 0.24 : 0.10)),
                                   lineWidth: 0.75)
                }
            }
            .mask { LinearGradient(colors: [.clear, .black], startPoint: .leading, endPoint: .trailing) }
        }
        .accessibilityHidden(true)
    }
}

struct ProfileActionStyle: ButtonStyle {
    @Environment(\.studioPalette) private var palette
    var primary = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: 46)
            .foregroundStyle(primary ? palette.onAccent : palette.ink)
            .background(primary ? palette.accent : palette.background.opacity(0.6), in: RoundedRectangle(cornerRadius: 13))
            .overlay { RoundedRectangle(cornerRadius: 13).strokeBorder(primary ? .clear : palette.border) }
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

private struct ProfileEyebrow: View {
    @Environment(\.studioPalette) private var palette
    let title: String

    var body: some View {
        Label(title, systemImage: "waveform")
            .font(.system(.caption2, design: .monospaced).weight(.semibold))
            .tracking(1.35)
            .foregroundStyle(palette.accent)
    }
}

struct CreatorPortfolio: View {
    @Environment(\.studioPalette) private var palette
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var tab: Tab = .clips

    let videos: [Video]
    let loading: Bool
    let failed: Bool
    let more: Bool
    let isOwner: Bool
    let open: (Video) -> Void
    let trySound: (SoundSetup) -> Void
    let retry: () -> Void
    let loadMore: () -> Void
    var makeMusic: (() -> Void)? = nil
    var delete: ((Video) -> Void)? = nil

    private enum Tab: String, CaseIterable {
        case clips = "Performances", sounds = "Sounds"
        var icon: String { self == .clips ? "rectangle.grid.3x2" : "waveform" }
    }

    private var sharedSounds: [Video] {
        var seen: [SoundSetup] = []
        return videos.filter { video in
            guard video.hidden != true, let sound = video.soundSetup, !seen.contains(sound) else { return false }
            seen.append(sound)
            return true
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if tab == .clips, let latest = videos.first(where: { $0.hidden != true }) {
                spotlight(latest)
            }
            tabs
            if tab == .clips { gallery }
            else { sounds }
            if failed {
                Text("Couldn't load performances.").font(.footnote).foregroundStyle(palette.muted)
                Button("Try again", action: retry).buttonStyle(ProfileActionStyle())
            } else if loading {
                ProgressView("Loading performances")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            } else if more {
                Button("Load more performances", action: loadMore).buttonStyle(ProfileActionStyle())
            }
        }
    }

    private var tabs: some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 3)) : AnyLayout(HStackLayout(spacing: 4))
        return layout {
            ForEach(Tab.allCases, id: \.self) { option in
                Button { tab = option } label: {
                    Label(option.rawValue, systemImage: option.icon)
                        .font(.subheadline.weight(.semibold))
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .foregroundStyle(tab == option ? palette.ink : palette.muted)
                        .background(tab == option ? palette.surface : .clear, in: RoundedRectangle(cornerRadius: 10))
                        .overlay { RoundedRectangle(cornerRadius: 10).strokeBorder(tab == option ? palette.border : .clear) }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(option == .clips ? "profile-performances" : "profile-sounds")
                .accessibilityAddTraits(tab == option ? .isSelected : [])
            }
        }
        .padding(3)
        .background(palette.surface.opacity(0.42), in: RoundedRectangle(cornerRadius: 13))
    }

    private func spotlight(_ video: Video) -> some View {
        Button { open(video) } label: {
            HStack(spacing: 13) {
                ProfileThumbnail(video: video)
                    .frame(width: 60, height: 69)
                    .clipShape(RoundedRectangle(cornerRadius: 9))
                VStack(alignment: .leading, spacing: 4) {
                    ProfileEyebrow(title: "LATEST PERFORMANCE")
                    Text(verbatim: clipTitle(video))
                        .font(.system(.title3, design: .serif))
                        .lineLimit(2)
                    if let instrument = video.soundSetup?.instrumentName ?? video.instrument, !instrument.isEmpty {
                        Text(instrument).font(.caption).foregroundStyle(palette.muted).lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "play.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.accent)
                    .frame(width: 36, height: 36)
                    .background(palette.accent.opacity(0.12), in: Circle())
                    .accessibilityHidden(true)
            }
            .padding(10)
            .background(palette.surface, in: RoundedRectangle(cornerRadius: 16))
            .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(palette.border) }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("profile-latest-performance")
        .accessibilityLabel("Watch latest performance: \(clipTitle(video))")
    }

    @ViewBuilder private var gallery: some View {
        if videos.isEmpty && !loading && !failed {
            empty(icon: "play.rectangle", title: "No performances yet",
                  subtitle: isOwner ? "Record a clip and post it to give people a first listen." : "Check back when this artist shares a clip.")
            if let makeMusic { Button("Make music", action: makeMusic).buttonStyle(ProfileActionStyle(primary: true)) }
        } else {
            let columns = Array(repeating: GridItem(.flexible(), spacing: 5), count: typeSize.isAccessibilitySize ? 2 : 3)
            LazyVGrid(columns: columns, spacing: 5) {
                ForEach(videos) { video in
                    if let delete {
                        tile(video).contextMenu {
                            Button("Delete post", systemImage: "trash", role: .destructive) { delete(video) }
                        }
                    } else {
                        tile(video)
                    }
                }
            }
        }
    }

    private func tile(_ video: Video) -> some View {
        Button { open(video) } label: {
            Color.clear.aspectRatio(3 / 4, contentMode: .fit)
                .overlay { ProfileThumbnail(video: video) }
                .overlay(alignment: .topTrailing) {
                    if video.hidden == true {
                        Image(systemName: "eye.slash.fill").font(.caption2).foregroundStyle(.white)
                            .padding(6).background(.black.opacity(0.65), in: Capsule()).padding(5)
                    }
                }
                .overlay(alignment: .bottomLeading) {
                    Label(video.likeCount.formatted(.number.notation(.compactName)), systemImage: "heart.fill")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(5)
                        .background(.black.opacity(0.65), in: Capsule())
                        .padding(5)
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Watch \(clipTitle(video))")
        .accessibilityValue(video.hidden == true ? "Hidden, \(video.likeCount) likes" : "\(video.likeCount) likes")
    }

    @ViewBuilder private var sounds: some View {
        let clips = sharedSounds
        if clips.isEmpty && !loading && !failed {
            empty(icon: "waveform", title: "No playable sounds yet",
                  subtitle: "When a performance includes a sound setup, you can play it here.")
        }
        ForEach(clips) { video in
            if let sound = video.soundSetup {
                Button { trySound(sound) } label: {
                    HStack(spacing: 11) {
                        Image(systemName: "waveform")
                            .foregroundStyle(palette.accent)
                            .frame(width: 42, height: 42)
                            .background(palette.accent.opacity(0.09), in: RoundedRectangle(cornerRadius: 10))
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(sound.instrumentName ?? "Performance sound").font(.headline)
                            Text(sound.presetDetails).font(.caption).foregroundStyle(palette.muted)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: "play.fill").font(.caption.weight(.semibold)).foregroundStyle(palette.accent)
                            .accessibilityHidden(true)
                    }
                    .padding(11)
                    .background(palette.surface, in: RoundedRectangle(cornerRadius: 13))
                    .overlay { RoundedRectangle(cornerRadius: 13).strokeBorder(palette.border) }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("profile-play-sound")
                .accessibilityHint("Opens this setup in the instrument")
            }
        }
    }

    private func empty(icon: String, title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Label(title, systemImage: icon).font(.headline)
            Text(subtitle).font(.subheadline).foregroundStyle(palette.muted)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 14))
    }

    private func clipTitle(_ video: Video) -> String {
        let caption = video.caption.trimmingCharacters(in: .whitespacesAndNewlines)
        return caption.isEmpty ? video.instrument ?? "Performance" : caption
    }
}

private struct ProfileThumbnail: View {
    @Environment(\.studioPalette) private var palette
    let video: Video

    var body: some View {
        ProfileArtwork()
            .overlay { Image(systemName: "waveform").foregroundStyle(palette.accent.opacity(0.8)) }
            .overlay {
                GeometryReader { proxy in
                    AsyncImage(url: video.thumbURL) { image in
                        image.resizable().scaledToFill()
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .clipped()
                    } placeholder: { Color.clear }
                }
            }
            .clipped()
            .accessibilityHidden(true)
    }
}

private struct EditCreatorNameView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.studioPalette) private var palette
    @ObservedObject var auth: AuthManager
    @State private var name = ""
    @State private var saving = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Display name", text: $name).textContentType(.nickname)
                } footer: {
                    Text("Leave blank to show your username instead.")
                }
                if let error { Text(error).foregroundStyle(palette.muted) }
            }
            .navigationTitle("Edit profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(saving) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                        .disabled(saving || name.trimmingCharacters(in: .whitespacesAndNewlines).unicodeScalars.count >
                                  AuthManager.displayNameLimit)
                }
            }
            .onAppear { name = auth.profile?.displayName ?? "" }
            .interactiveDismissDisabled(saving)
        }
        .tint(palette.accent)
    }

    private func save() async {
        saving = true
        error = nil
        defer { saving = false }
        do {
            try await auth.updateDisplayName(name)
            dismiss()
        } catch {
            self.error = "Couldn't save your display name. Try again."
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
