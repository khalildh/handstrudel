import Foundation
import RevenueCat
import Supabase
import SwiftUI

// MARK: - Codes and links

enum InviteCode {
    /// Matches the server: 8 characters from A–Z and 2–9, without lookalikes.
    static let length = 8

    /// Uppercases and strips spaces, dashes and other separators. Returns nil unless it's a full code.
    static func normalize(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let cleaned = String(raw.uppercased().unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) && $0.isASCII })
        guard cleaned.count == length, cleaned.allSatisfy({ ("A"..."Z").contains($0) || ("2"..."9").contains($0) }) else {
            return nil
        }
        return cleaned
    }

    /// Typing-friendly version for the text field: uppercase, at most 8 letters/digits.
    static func sanitizeTyping(_ raw: String) -> String {
        String(raw.uppercased().filter { $0.isASCII && ($0.isLetter || $0.isNumber) }.prefix(length))
    }

    static func url(for code: String) -> URL {
        var url = URLComponents()
        url.scheme = "https"
        url.host = "handstrudel.com"
        url.path = "/invite"
        url.queryItems = [URLQueryItem(name: "c", value: code)]
        return url.url!
    }

    /// A post's watch link that also carries the poster's invite code.
    static func watchURL(_ video: Video, code: String?) -> URL {
        guard let code, var parts = URLComponents(url: video.watchURL, resolvingAgainstBaseURL: false) else {
            return video.watchURL
        }
        parts.queryItems = (parts.queryItems ?? []) + [URLQueryItem(name: "invite", value: code)]
        return parts.url ?? video.watchURL
    }

    /// The code in `https://handstrudel.com/invite?c=…`, a `/watch?v=…&invite=…` link, or
    /// `handstrudel://invite/<code>`. `isInviteOnly` is true when there's nothing else to open.
    static func parse(_ url: URL) -> (code: String, isInviteOnly: Bool)? {
        if url.scheme == "handstrudel", url.host == "invite", url.pathComponents.count == 2 {
            return normalize(url.lastPathComponent).map { ($0, true) }
        }
        guard let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              parts.scheme == "https", parts.host == SocialConfig.watchURL.host,
              parts.user == nil, parts.password == nil, parts.port == nil else { return nil }
        let items = parts.queryItems ?? []
        switch parts.path {
        case "/invite", "/invite/":
            return normalize(items.first { $0.name == "c" }?.value).map { ($0, true) }
        case "/watch", "/watch/":
            return normalize(items.first { $0.name == "invite" }?.value).map { ($0, false) }
        default:
            return nil
        }
    }
}

// MARK: - Server types

struct InviteSummary: Decodable, Equatable {
    let code: String
    let friendsJoined: Int
    let friendsRewarded: Int
    let rewardLimit: Int

    enum CodingKeys: String, CodingKey {
        case code, friendsJoined = "friends_joined", friendsRewarded = "friends_rewarded", rewardLimit = "reward_limit"
    }

    var url: URL { InviteCode.url(for: code) }
    var reachedLimit: Bool { friendsRewarded >= rewardLimit }

    /// "3 friends joined" — nil before anyone has.
    var joinedText: String? {
        switch friendsJoined {
        case 0: return nil
        case 1: return "1 friend joined"
        default: return "\(friendsJoined) friends joined"
        }
    }
}

struct InviteCelebration: Identifiable, Decodable, Equatable {
    let id: UUID
    let role: String
    let friendUsername: String?
    let expiresAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, role, friendUsername = "friend_username", expiresAt = "expires_at"
    }

    var isInviter: Bool { role == "inviter" }

    var message: String {
        let friend = friendUsername.map { "@\($0)" }
        if isInviter {
            return "\(friend ?? "Your friend") posted their first take. You both get 7 days of HandStrudel+."
        }
        return "Your first take is live. You and \(friend ?? "the friend who invited you") each get 7 days of HandStrudel+."
    }
}

/// Someone who joined with your invite (only you can list them).
struct IntroPerson: Identifiable, Decodable, Equatable {
    let id: UUID
    let username: String?
    let displayName: String?
    let avatarKey: String?
    let joinedAt: Date
    let postedFirstTake: Bool

    enum CodingKeys: String, CodingKey {
        case id = "user_id", username, displayName = "display_name", avatarKey = "avatar_key"
        case joinedAt = "joined_at", postedFirstTake = "posted_first_take"
    }

    var status: String { postedFirstTake ? "Posted their first take" : "Joined" }
}

/// A profile's public intro count and highest milestone badge.
struct IntroStats: Decodable, Equatable {
    static let milestones = [1, 5, 10, 25]
    let intros: Int
    let milestone: Int?
    let badge: String?

    /// "Connector · 12 intros", or nil before the first intro.
    var badgeText: String? {
        guard let badge, intros > 0 else { return nil }
        return "\(badge) · \(intros) \(intros == 1 ? "intro" : "intros")"
    }

    /// "You've introduced 7 people"
    var headline: String {
        intros == 1 ? "You've introduced 1 person" : "You've introduced \(intros) people"
    }

    /// The next badge to aim for, e.g. "3 more for the 10-intro badge".
    var nextMilestoneText: String? {
        guard let next = Self.milestones.first(where: { $0 > intros }) else { return nil }
        let more = next - intros
        return "\(more) more for the \(next)-intro badge"
    }
}

struct IntroducerCandidate: Identifiable, Decodable, Equatable {
    let id: UUID
    let username: String
    let displayName: String?
    let avatarKey: String?
    enum CodingKeys: String, CodingKey { case id, username, displayName = "display_name", avatarKey = "avatar_key" }
}

struct Introducer: Decodable, Equatable {
    let userId: UUID
    let username: String?
    enum CodingKeys: String, CodingKey { case userId = "user_id", username }
}

enum InviteRedeemOutcome: Equatable {
    case accepted(inviter: String?, inviterRewarded: Bool)
    case rejected(String)

    /// Turns the server's `{"ok": false, "reason": …}` into something a person can act on.
    static func message(for reason: String?) -> String {
        switch reason {
        case "not_found": return "We couldn't find that invite code or account. Check it and try again."
        case "self_invite": return "That's your own invite code. Share it with a friend instead."
        case "already_redeemed": return "You've already used an invite code."
        case "already_posted": return "Invite codes need to be entered before your first post."
        default: return "Couldn't check that invite code. Try again."
        }
    }
}

// MARK: - State

@MainActor
final class InviteManager: ObservableObject {
    static let shared = InviteManager()
    private static let pendingKey = "invite.pendingCode"

    @Published private(set) var summary: InviteSummary?
    @Published private(set) var intros: [IntroPerson] = []
    @Published private(set) var stats: IntroStats?
    @Published private(set) var introducer: Introducer?
    /// A code from an invite link, kept until it's used at sign-up (or rejected).
    @Published private(set) var pendingCode: String? = UserDefaults.standard.string(forKey: pendingKey)
    @Published var celebration: InviteCelebration?
    @Published var notice: String?

    private var accountID: UUID?

    /// Captures an invite code from a universal link. Returns true if the link was only an invite.
    func capture(_ url: URL, signedInAndReady: Bool) -> Bool {
        guard let parsed = InviteCode.parse(url) else { return false }
        let (code, inviteOnly) = parsed
        setPending(code)
        if signedInAndReady {
            Task { await redeemPending() }
        } else if inviteOnly {
            notice = "Invite code \(code) saved. Create an account and post your first take: you and your friend each get 7 days of HandStrudel+."
        }
        return inviteOnly
    }

    func setPending(_ code: String?) {
        pendingCode = code
        UserDefaults.standard.set(code, forKey: Self.pendingKey)
    }

    /// The account changed or finished setup.
    func accountChanged(_ id: UUID?, ready: Bool) async {
        if id != accountID {
            accountID = id
            summary = nil
            intros = []
            stats = nil
            introducer = nil
            celebration = nil
        }
        guard id != nil, ready else { return }
        await redeemPending()
        await loadSummary()
        await refreshRewards()
    }

    /// An existing, set-up account opened an invite link: try it, and say what happened.
    private func redeemPending() async {
        guard let code = pendingCode else { return }
        switch await redeem(code) {
        case .accepted(let inviter, let inviterRewarded):
            notice = Self.acceptedMessage(inviter: inviter, inviterRewarded: inviterRewarded)
        case .rejected(let message):
            notice = message
        }
    }

    nonisolated static func acceptedMessage(inviter: String?, inviterRewarded: Bool) -> String {
        let with = inviter.map { " with @\($0)" } ?? ""
        return inviterRewarded
            ? "You're in\(with). Post your first take and you each get 7 days of HandStrudel+."
            : "You're in\(with). Post your first take to get 7 days of HandStrudel+. Your friend has already earned the most invite rewards, but you still count as their intro."
    }

    func redeem(_ code: String) async -> InviteRedeemOutcome {
        guard let normalized = InviteCode.normalize(code) else {
            return .rejected(InviteRedeemOutcome.message(for: "not_found"))
        }
        return await redeem(code: normalized, introducer: nil)
    }

    /// An in-person intro: the new person picked who introduced them by @username.
    func redeem(introducer: UUID) async -> InviteRedeemOutcome {
        await redeem(code: nil, introducer: introducer)
    }

    private func redeem(code: String?, introducer: UUID?) async -> InviteRedeemOutcome {
        struct Params: Encodable { let invite_code: String?; let introducer: UUID? }
        struct Result: Decodable {
            let ok: Bool; let reason: String?; let inviter: String?
            let inviter_rewarded: Bool?
        }
        do {
            let result: Result = try await supabase.rpc("redeem_invite_code", params: Params(
                invite_code: code, introducer: introducer)).execute().value
            setPending(nil)
            return result.ok ? .accepted(inviter: result.inviter, inviterRewarded: result.inviter_rewarded ?? true)
                : .rejected(InviteRedeemOutcome.message(for: result.reason))
        } catch {
            return .rejected("Couldn't check that intro. Check your connection and try again.")
        }
    }

    /// Creators whose @username starts with `prefix`, for picking who introduced you.
    func searchIntroducers(_ prefix: String) async -> [IntroducerCandidate] {
        let query = prefix.lowercased().filter { $0.isLetter || $0.isNumber || $0 == "_" }
        guard query.count >= 2 else { return [] }
        let rows: [IntroducerCandidate]? = try? await supabase.from("profiles")
            .select("id, username, display_name, avatar_key")
            .ilike("username", pattern: "\(query)%")
            .neq("id", value: accountID?.uuidString.lowercased() ?? "")
            .order("username").limit(8).execute().value
        return rows ?? []
    }

    func loadSummary() async {
        let id = accountID
        let rows: [InviteSummary]? = try? await supabase.rpc("my_invite").execute().value
        guard id == accountID, let row = rows?.first else { return }
        summary = row
        await loadIntros()
    }

    /// Your intro list and badge, plus who introduced you. Only you can see these lists.
    func loadIntros() async {
        guard let id = accountID else { return }
        async let people: [IntroPerson]? = try? supabase.rpc("my_intros").execute().value
        async let mine: [IntroStats]? = try? supabase.rpc("intro_stats",
            params: ["profile_id": id.uuidString.lowercased()]).execute().value
        async let by: [Introducer]? = try? supabase.rpc("my_introducer").execute().value
        let (p, s, b) = await (people, mine, by)
        guard id == accountID else { return }
        if let p { intros = p }
        if let s = s?.first { stats = s }
        if let b { introducer = b.first }
    }

    /// Asks the server to grant anything queued for this account, then shows rewards that landed.
    func refreshRewards() async {
        guard accountID != nil, celebration == nil else { return }
        let id = accountID
        try? await supabase.functions.invoke("grant-invite-rewards")
        let rows: [InviteCelebration]? = try? await supabase.rpc("unseen_invite_rewards").execute().value
        guard id == accountID, let first = rows?.first else { return }
        // Pick up the new entitlement now instead of waiting for RevenueCat's cache to expire.
        Purchases.shared.invalidateCustomerInfoCache()
        _ = try? await Purchases.shared.customerInfo()
        celebration = first
        await loadSummary()
    }

    func finishCelebration(_ shown: InviteCelebration) {
        if celebration?.id == shown.id { celebration = nil }
        Task {
            struct Params: Encodable { let grant_ids: [UUID] }
            _ = try? await supabase.rpc("mark_invite_rewards_seen", params: Params(grant_ids: [shown.id])).execute()
            await refreshRewards()
        }
    }

    /// Your own posts' links carry your invite code; anyone else's is the plain watch link.
    func shareURL(for video: Video) -> URL {
        guard let summary, accountID == video.userId, !summary.reachedLimit else { return video.watchURL }
        return InviteCode.watchURL(video, code: summary.code)
    }

    /// A post was confirmed published: if it was an invited friend's first take, the reward follows.
    func postPublished() {
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await refreshRewards()
        }
    }
}

// MARK: - Views

/// "Did someone introduce you?" during username setup. Two ways to answer:
/// - an invite code, pre-filled from an invite link the app opened, or typed, or pasted with
///   the system Paste button (`PasteButton`, Apple's `UIPasteControl`: it reads the clipboard
///   only when tapped and shows no paste-permission alert; the app never reads it silently);
/// - their @username, for in-person intros.
/// Both go through the same server rules. Skipping it is fine; that intro just isn't counted.
struct IntroducerEntry: View {
    enum Mode: String, CaseIterable, Identifiable {
        case code = "Invite code", username = "@username"
        var id: String { rawValue }
    }

    @Binding var code: String
    @Binding var picked: IntroducerCandidate?
    var error: String?
    @State private var expanded = false
    @State private var mode: Mode = .code
    @State private var search = ""
    @State private var results: [IntroducerCandidate] = []

    private var isOpen: Bool { expanded || !code.isEmpty || picked != nil }

    var body: some View {
        Section {
            if isOpen {
                Picker("Introduced with", selection: $mode) {
                    ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("introducer-mode")
                switch mode {
                case .code: codeRow
                case .username: usernameRows
                }
            } else {
                Button("Did someone introduce you?") { expanded = true }
                    .accessibilityIdentifier("invite-code-toggle")
            }
        } header: {
            if isOpen { Text("Who introduced you?") }
        } footer: {
            if let error {
                Text(error).foregroundStyle(.red)
            } else if isOpen {
                Text("When you post your first take, you and your friend each get 7 days of HandStrudel+, free. Optional: leave it empty to skip.")
            }
        }
        .onChange(of: mode) { newMode in
            expanded = true  // keep the section open while switching, even after clearing the code
            if newMode == .code { picked = nil } else { code = "" }
        }
    }

    private var codeRow: some View {
        HStack {
            TextField("Invite code", text: $code)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .font(.body.monospaced())
                .onChange(of: code) { code = InviteCode.sanitizeTyping($0) }
                .accessibilityIdentifier("invite-code-field")
            PasteButton(payloadType: String.self) { strings in
                if let pasted = InviteCode.normalize(strings.first) { code = pasted }
            }
            .labelStyle(.iconOnly)
            .buttonBorderShape(.capsule)
        }
    }

    @ViewBuilder private var usernameRows: some View {
        if let picked {
            HStack {
                Label("@\(picked.username)", systemImage: "person.crop.circle.badge.checkmark")
                Spacer()
                Button("Change") { self.picked = nil; search = "" }
            }
            .accessibilityIdentifier("introducer-picked")
        } else {
            TextField("Search @username", text: $search)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .accessibilityIdentifier("introducer-search")
                .task(id: search) {
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    guard !Task.isCancelled else { return }
                    results = await InviteManager.shared.searchIntroducers(search)
                }
            ForEach(results) { person in
                Button {
                    picked = person
                    results = []
                } label: {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("@\(person.username)").font(.subheadline.weight(.semibold))
                        if let name = person.displayName, !name.isEmpty {
                            Text(name).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}

/// Profile card: your invite link, your intro tally and badge, and who joined through you.
struct InviteFriendsCard: View {
    @Environment(\.studioPalette) private var palette
    @ObservedObject var auth: AuthManager
    @ObservedObject var invites = InviteManager.shared
    var onTrySound: (SoundSetup) -> Void = { _ in }
    var onPlayAlong: (Video) -> Void = { _ in }
    @State private var opened: OpenedProfile?
    @State private var afterDismiss: (() -> Void)?
    @State private var showAll = false

    private struct OpenedProfile: Identifiable { let id: UUID }

    var body: some View {
        if let summary = invites.summary {
            VStack(alignment: .leading, spacing: 14) {
                if let introducer = invites.introducer, let name = introducer.username {
                    Button { opened = .init(id: introducer.userId) } label: {
                        Label("Introduced by @\(name)", systemImage: "hand.wave")
                            .font(.footnote)
                            .foregroundStyle(palette.muted)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Only you and @\(name) can see this.")
                }
                invite(summary)
                if let stats = invites.stats, stats.intros > 0 { tracker(stats) }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.surface, in: RoundedRectangle(cornerRadius: 16))
            .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(palette.border) }
            .sheet(item: $opened, onDismiss: {
                let action = afterDismiss
                afterDismiss = nil
                action?()
            }) { profile in
                CreatorProfileSheet(creatorId: profile.id, auth: auth, onTrySound: { sound in
                    afterDismiss = { onTrySound(sound) }
                    opened = nil
                }, onPlayAlong: { video in
                    afterDismiss = { onPlayAlong(video) }
                    opened = nil
                })
            }
        }
    }

    private func invite(_ summary: InviteSummary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Image(systemName: "gift").foregroundStyle(palette.accent)
                VStack(alignment: .leading, spacing: 4) {
                    Text(summary.reachedLimit ? "Invite friends to HandStrudel"
                         : "Invite friends: you both get a week of HandStrudel+")
                        .font(.headline)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(summary.reachedLimit
                         ? "You've earned the most invite rewards (\(summary.rewardLimit) weeks). New friends still get their own week and still count as your intros."
                         : "Free when a new friend signs up with your link and posts their first take.")
                        .font(.footnote)
                        .foregroundStyle(palette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            HStack {
                ShareLink(item: summary.url, message: Text(summary.reachedLimit
                    ? "Play music with your hands on HandStrudel. Use my invite code \(summary.code) when you sign up to get a week of HandStrudel+."
                    : "Play music with your hands on HandStrudel. Use my invite code \(summary.code) when you sign up and we both get a week of HandStrudel+.")) {
                    Label("Invite", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(ProfileActionStyle())
                .accessibilityIdentifier("invite-share")
                Text(summary.code)
                    .font(.footnote.monospaced())
                    .foregroundStyle(palette.muted)
                    .textSelection(.enabled)
                    .accessibilityLabel("Your invite code, \(summary.code.map(String.init).joined(separator: " "))")
                Spacer()
            }
        }
    }

    private func tracker(_ stats: IntroStats) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()
            HStack(alignment: .firstTextBaseline) {
                Text(stats.headline)
                    .font(.headline)
                    .accessibilityIdentifier("intro-count")
                Spacer()
                if let badge = stats.badgeText { IntroBadgeChip(text: badge) }
            }
            if let next = stats.nextMilestoneText {
                Text(next).font(.footnote).foregroundStyle(palette.muted)
            }
            let people = showAll ? invites.intros : Array(invites.intros.prefix(5))
            ForEach(people) { person in
                Button { opened = .init(id: person.id) } label: { row(person) }
                    .buttonStyle(.plain)
                    .disabled(person.username == nil)
            }
            if invites.intros.count > 5 && !showAll {
                Button("Show all \(invites.intros.count)") { showAll = true }
                    .font(.footnote.weight(.semibold))
            }
            Text("Only you can see who joined through you. Others see your intro count and badge.")
                .font(.caption)
                .foregroundStyle(palette.muted)
        }
    }

    private func row(_ person: IntroPerson) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(palette.background)
                Text((person.username ?? "?").prefix(1).uppercased())
                    .font(.system(.footnote, design: .serif))
                    .foregroundStyle(palette.accent)
                if let key = person.avatarKey, !key.isEmpty {
                    ProfileImage(resource: .init(url: SocialConfig.mediaURL(key), kind: .avatar)) { image in
                        image.resizable().scaledToFill()
                    }
                }
            }
            .frame(width: 34, height: 34)
            .clipShape(Circle())
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(person.username.map { "@\($0)" } ?? "New member")
                    .font(.subheadline.weight(.semibold))
                Text(person.status)
                    .font(.caption)
                    .foregroundStyle(person.postedFirstTake ? palette.accent : palette.muted)
            }
            Spacer()
            if person.username != nil {
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(palette.muted)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

struct IntroBadgeChip: View {
    @Environment(\.studioPalette) private var palette
    let text: String

    var body: some View {
        Label(text, systemImage: "rosette")
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(palette.accent.opacity(0.15), in: Capsule())
            .foregroundStyle(palette.accent)
            .accessibilityIdentifier("intro-badge")
    }
}

/// A creator's public intro badge ("Connector · 12 intros"). Names stay private.
struct PublicIntroBadge: View {
    let userID: UUID
    @State private var stats: IntroStats?

    var body: some View {
        Group {
            if let text = stats?.badgeText { IntroBadgeChip(text: text) }
        }
        .task(id: userID) {
            let rows: [IntroStats]? = try? await supabase.rpc("intro_stats",
                params: ["profile_id": userID.uuidString.lowercased()]).execute().value
            stats = rows?.first
        }
    }
}

struct InviteRewardSheet: View {
    @Environment(\.studioPalette) private var palette
    let celebration: InviteCelebration
    let onDone: () -> Void
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                ForEach(0..<8, id: \.self) { i in
                    Image(systemName: ["sparkle", "music.note", "star.fill", "hand.wave.fill"][i % 4])
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(palette.accent.opacity(0.8))
                        .offset(x: appeared ? cos(Double(i) * .pi / 4) * 78 : 0,
                                y: appeared ? sin(Double(i) * .pi / 4) * 78 : 0)
                        .opacity(appeared ? 1 : 0)
                }
                Image(systemName: "gift.fill")
                    .font(.system(size: 54, weight: .semibold))
                    .foregroundStyle(palette.accent)
                    .scaleEffect(appeared ? 1 : 0.4)
            }
            .frame(height: 190)
            .accessibilityHidden(true)
            Text("A week of HandStrudel+ is yours")
                .font(.system(.title2, design: .serif).weight(.semibold))
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            Text(celebration.message)
                .multilineTextAlignment(.center)
                .foregroundStyle(palette.muted)
            if let expires = celebration.expiresAt {
                Text("Free until \(expires.formatted(date: .abbreviated, time: .shortened)). It won't renew, and there's nothing to cancel.")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(palette.muted)
            }
            Button("Start playing", action: onDone)
                .buttonStyle(StudioActionStyle())
                .accessibilityIdentifier("invite-reward-done")
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.background.ignoresSafeArea())
        .foregroundStyle(palette.ink)
        .presentationDetents([.medium, .large])
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) { appeared = true }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
}

/// Wires invite links, redemption of a saved code, and the reward sheet into the app root.
private struct InviteRewardsModifier: ViewModifier {
    @ObservedObject var auth: AuthManager
    @ObservedObject private var invites = InviteManager.shared
    @Environment(\.scenePhase) private var scenePhase

    private var ready: Bool { auth.isSignedIn && auth.profile != nil && !auth.needsProfileSetup }

    func body(content: Content) -> some View {
        content
            .task(id: "\(auth.userId?.uuidString ?? "-")|\(ready)") {
                guard SocialConfig.isConfigured else { return }
                await invites.accountChanged(auth.userId, ready: ready)
            }
            .onChange(of: scenePhase) { phase in
                if phase == .active && ready { Task { await invites.refreshRewards() } }
            }
            .sheet(item: $invites.celebration) { celebration in
                InviteRewardSheet(celebration: celebration) { invites.finishCelebration(celebration) }
            }
            .alert("Invite", isPresented: Binding(get: { invites.notice != nil },
                                                  set: { if !$0 { invites.notice = nil } })) {
                Button("OK", role: .cancel) {}
            } message: { Text(invites.notice ?? "") }
            #if DEBUG
            .modifier(InvitePreviewHooks(auth: auth))
            #endif
    }
}

#if DEBUG
/// UI-test and screenshot hooks, no backend needed:
/// `--uitest-invite-setup` shows username setup with the invite field;
/// `--uitest-invite-reward=inviter|invitee` shows the reward sheet.
private struct InvitePreviewHooks: ViewModifier {
    @ObservedObject var auth: AuthManager
    @State private var showSetup = ProcessInfo.processInfo.arguments.contains("--uitest-invite-setup")

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $showSetup) {
                NavigationStack { ProfileSetupView(auth: auth).navigationTitle("Your profile") }
            }
            .onAppear {
                guard let role = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--uitest-invite-reward=") })?
                    .split(separator: "=").last.map(String.init) else { return }
                InviteManager.shared.celebration = InviteCelebration(
                    id: UUID(), role: role, friendUsername: role == "inviter" ? "maya" : "sam",
                    expiresAt: Date().addingTimeInterval(7 * 86_400))
            }
    }
}
#endif

extension View {
    func inviteRewards(auth: AuthManager) -> some View { modifier(InviteRewardsModifier(auth: auth)) }
}
