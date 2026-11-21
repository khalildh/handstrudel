import SwiftUI
import UIKit
import UserNotifications
import Supabase

/// Per-type push settings, stored in `notification_preferences` (no row means all on).
struct NotificationPreferences: Codable, Equatable {
    var remixes = true
    var takeReplies = true
    var likes = true
    var comments = true
    var followingPosts = true
    var challenges = true

    enum CodingKeys: String, CodingKey {
        case remixes, likes, comments, challenges
        case takeReplies = "take_replies"
        case followingPosts = "following_posts"
    }

    static let toggles: [(title: String, detail: String, key: WritableKeyPath<NotificationPreferences, Bool>)] = [
        ("Play-alongs", "Someone plays along with or remixes your post", \.remixes),
        ("Take replies", "Someone replies to your post with a take", \.takeReplies),
        ("Likes", "At most one per post per hour", \.likes),
        ("Comments", "Someone comments on your post", \.comments),
        ("New posts", "Someone you follow posts", \.followingPosts),
        ("Weekly challenge", "A new challenge starts", \.challenges),
    ]
}

/// Pure helpers, kept separate so they can be unit tested.
enum PushSupport {
    /// The in-app link carried in a push payload, if it's one the app already routes.
    static func link(from userInfo: [AnyHashable: Any]) -> URL? {
        guard let value = userInfo["link"] as? String, let url = URL(string: value),
              PerformanceLink(url: url) != nil else { return nil }
        return url
    }

    static func hex(_ token: Data) -> String { token.map { String(format: "%02x", $0) }.joined() }

    /// Development-signed builds (Xcode, Debug) talk to the APNs sandbox; App Store and
    /// TestFlight builds have no embedded profile, or a production one.
    static func apsEnvironment(provisioningProfile: Data?) -> String {
        guard let profile = provisioningProfile,
              let text = String(data: profile, encoding: .isoLatin1),
              let key = text.range(of: "<key>aps-environment</key>"),
              let open = text.range(of: "<string>", range: key.upperBound..<text.endIndex),
              let close = text.range(of: "</string>", range: open.upperBound..<text.endIndex) else {
            return "production"
        }
        return text[open.upperBound..<close.lowerBound] == "development" ? "sandbox" : "production"
    }
}

/// Owns the push permission, the APNs token, and routing notification taps.
@MainActor
final class PushManager: ObservableObject {
    static let shared = PushManager()

    /// A tapped notification's link; ContentView opens it and clears this.
    @Published var pendingLink: URL?
    @Published private(set) var authorization: UNAuthorizationStatus = .notDetermined

    private var signedInUser: UUID?
    private var token: String?
    private var uploaded: (token: String, user: UUID)?
    private static let askedKey = "pushPermissionAsked"

    private init() {
        Task { await refreshAuthorization() }
    }

    func refreshAuthorization() async {
        authorization = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        if signedInUser != nil, Self.allowsAlerts(authorization) {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    private static func allowsAlerts(_ status: UNAuthorizationStatus) -> Bool {
        status == .authorized || status == .provisional || status == .ephemeral
    }

    // MARK: Permission

    /// Asks once, after a moment that shows why pushes are useful (a first post, a follow).
    /// Never at launch.
    nonisolated func askAfterMilestone() {
        Task { @MainActor in
            guard signedInUser != nil, !UserDefaults.standard.bool(forKey: Self.askedKey) else { return }
            // Let the composer or follow animation finish before the system alert appears.
            try? await Task.sleep(nanoseconds: 800_000_000)
            await requestPermission()
        }
    }

    /// Shows the system prompt if the user hasn't answered it yet.
    @discardableResult
    func requestPermission() async -> Bool {
        await refreshAuthorization()
        guard authorization == .notDetermined else { return Self.allowsAlerts(authorization) }
        UserDefaults.standard.set(true, forKey: Self.askedKey)
        let granted = (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        await refreshAuthorization()
        return granted
    }

    // MARK: Account

    /// Called whenever the signed-in account changes (nil when signed out).
    func accountChanged(to user: UUID?) {
        guard user != signedInUser else { return }
        signedInUser = user
        if user == nil {
            uploaded = nil
        } else {
            Task { await refreshAuthorization() }
            Task { await upload() }
        }
    }

    /// Removes this device's token before signing out, while the session can still delete it.
    func signingOut() async {
        defer { uploaded = nil }
        guard let token, signedInUser != nil else { return }
        _ = try? await supabase.from("device_tokens").delete().eq("token", value: token).execute()
    }

    // MARK: Token

    func didRegister(deviceToken: Data) {
        token = PushSupport.hex(deviceToken)
        Task { await upload() }
    }

    private func upload() async {
        guard SocialConfig.isConfigured, let token, let user = signedInUser,
              uploaded.map({ $0.token != token || $0.user != user }) ?? true else { return }
        struct Params: Encodable { let p_token: String; let p_environment: String }
        let profile = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision")
            .flatMap { try? Data(contentsOf: $0) }
        do {
            try await supabase.rpc("register_device_token", params: Params(
                p_token: token, p_environment: PushSupport.apsEnvironment(provisioningProfile: profile))).execute()
            if signedInUser == user { uploaded = (token, user) }
        } catch {
            debugPrint("Push token upload failed:", error)
        }
    }

    // MARK: Taps

    func open(_ userInfo: [AnyHashable: Any]) {
        if let url = PushSupport.link(from: userInfo) { pendingLink = url }
    }

    // MARK: Preferences

    func loadPreferences() async throws -> NotificationPreferences {
        guard let user = signedInUser else { return NotificationPreferences() }
        let rows: [NotificationPreferences] = try await supabase.from("notification_preferences")
            .select("remixes,take_replies,likes,comments,following_posts,challenges")
            .eq("user_id", value: user).execute().value
        return rows.first ?? NotificationPreferences()
    }

    func save(_ preferences: NotificationPreferences) async throws {
        try await supabase.from("notification_preferences")
            .upsert(preferences, onConflict: "user_id").execute()
    }
}

/// Receives the APNs token and notification taps.
final class PushAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Task { @MainActor in PushManager.shared.didRegister(deviceToken: deviceToken) }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        debugPrint("Push registration failed:", error)
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        Task { @MainActor in
            PushManager.shared.open(userInfo)
            completionHandler()
        }
    }
}

/// Account settings → Notifications.
struct NotificationSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var push = PushManager.shared
    @ObservedObject var auth: AuthManager
    @State private var preferences = NotificationPreferences()
    @State private var loaded = false
    @State private var failed = false
    @State private var saveTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    switch push.authorization {
                    case .denied:
                        Text("Notifications are off for HandStrudel.")
                        Button("Open iPhone Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                        }
                    case .notDetermined:
                        Button("Turn on notifications") { Task { await push.requestPermission() } }
                    default:
                        Label("Notifications are on", systemImage: "bell.badge")
                    }
                } footer: {
                    Text("Choose which activity sends a notification to this iPhone.")
                }
                if auth.isSignedIn {
                    Section("Notify me about") {
                        ForEach(NotificationPreferences.toggles, id: \.title) { item in
                            Toggle(isOn: binding(item.key)) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title)
                                    Text(item.detail).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            .disabled(!loaded)
                            .accessibilityIdentifier("notification-toggle-"
                                + item.title.lowercased().replacingOccurrences(of: " ", with: "-"))
                        }
                    }
                } else {
                    Section { Text("Sign in to get notified about activity on your posts.") }
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .alert("Couldn't update notification settings", isPresented: $failed) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Check your connection and try again.")
            }
            .task {
                await push.refreshAuthorization()
                guard auth.isSignedIn else { return }
                do {
                    preferences = try await push.loadPreferences()
                    loaded = true
                } catch {
                    failed = true
                }
            }
            .onChange(of: scenePhase) { phase in
                if phase == .active { Task { await push.refreshAuthorization() } }
            }
        }
    }

    private func binding(_ key: WritableKeyPath<NotificationPreferences, Bool>) -> Binding<Bool> {
        Binding(get: { preferences[keyPath: key] }, set: { value in
            let previous = preferences
            preferences[keyPath: key] = value
            let next = preferences
            saveTask?.cancel()
            saveTask = Task {
                do {
                    try await push.save(next)
                } catch {
                    guard !Task.isCancelled else { return }
                    preferences = previous
                    failed = true
                }
            }
        })
    }
}
