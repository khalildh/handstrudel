import Foundation
import SwiftUI

@MainActor
final class AppAnalytics {
    nonisolated static let optInKey = "appUsageAnalyticsEnabled"
    private static let lastActiveDayKey = "appUsageAnalyticsLastActiveDay"
    private static let firstNoteKey = "appUsageAnalyticsFirstNote"
    static let shared = AppAnalytics(enabled: !ProcessInfo.processInfo.arguments.contains("--uitesting"), hits: { hit in
        Task {
            guard UserDefaults.standard.bool(forKey: optInKey) else { return }
            await sendEvent(hit)
        }
    })

    /// Every name here must be on the database allow-list in
    /// `supabase/migrations/20261121070000_crash_diagnostics_funnel.sql` (a unit test checks).
    enum Event: String, Encodable, CaseIterable {
        case activeDay = "active_day"
        case returnDay = "return_day"
        /// Once per install: the funnel's "first note played".
        case firstNote = "first_note"
        case recordingStarted = "recording_started"
        case recordingSaved = "recording_saved"
        case recordingPosted = "recording_posted"
        /// A Pro sound opened from the feed by someone without Pro.
        case lockedSoundTapped = "locked_sound_tapped"
        /// That sound unlocked (purchase or restore) from its unlock screen.
        case lockedSoundUnlocked = "locked_sound_unlocked"

        // Growth funnel (1.0.2). See `Funnel` for when each is sent.
        case storeViewed = "store_viewed"
        case purchaseStarted = "purchase_started"
        case purchaseCompleted = "purchase_completed"
        case restoreTapped = "restore_tapped"
        case inviteLinkShared = "invite_link_shared"
        case inviteCodeRedeemed = "invite_code_redeemed"
        case invitedFirstPost = "invited_first_post"
        case replyStarted = "reply_started"
        case replyPosted = "reply_posted"
        case challengeLinkShared = "challenge_link_shared"
        case challengeLinkOpened = "challenge_link_opened"
        case dailySoundOpened = "daily_sound_opened"
        case dailyTakePosted = "daily_take_posted"
        case streakExtended = "streak_extended"
        case soundPageOpened = "sound_page_opened"
        case playThisSoundTapped = "play_this_sound_tapped"
        case notificationOpened = "notification_opened"
        case firstPostPublished = "first_post_published"

        /// Events that must carry a detail, and the details the database accepts for them.
        static let allowedDetails: [Event: Set<String>] = [
            .purchaseStarted: Set(PurchaseProduct.allCases.map(\.rawValue)),
            .purchaseCompleted: Set(PurchaseProduct.allCases.map(\.rawValue)),
            .notificationOpened: Set(NotificationKind.allCases.map(\.rawValue)),
        ]
    }

    /// The `detail` sent with purchase events.
    enum PurchaseProduct: String, CaseIterable {
        case pro, plusMonthly = "plus_monthly", plusYearly = "plus_yearly"

        init?(productId: String) {
            switch productId {
            case StoreManager.pro: self = .pro
            case StoreManager.plusMonthly: self = .plusMonthly
            case StoreManager.plusYearly: self = .plusYearly
            default: return nil
            }
        }
    }

    /// The `detail` sent with `notification_opened`. Unknown push types are sent as `other`.
    enum NotificationKind: String, CaseIterable {
        case remix, takeReply = "take_reply", like, comment, followingPost = "following_post", challenge
        case dailySound = "daily_sound", streakAtRisk = "streak_at_risk", other

        init(pushType: String) { self = NotificationKind(rawValue: pushType) ?? .other }
    }

    /// One event as sent to `record_app_usage_event`.
    struct Hit: Equatable {
        let event: Event
        var detail: String? = nil
    }

    private let defaults: UserDefaults
    private let enabled: Bool
    private let send: (Hit) -> Void
    var isOptedIn: Bool { enabled && defaults.bool(forKey: Self.optInKey) }

    init(defaults: UserDefaults = .standard, enabled: Bool = true, hits: @escaping (Hit) -> Void) {
        self.defaults = defaults
        self.enabled = enabled
        self.send = hits
    }

    convenience init(defaults: UserDefaults = .standard, enabled: Bool = true, send: @escaping (Event) -> Void) {
        self.init(defaults: defaults, enabled: enabled, hits: { send($0.event) })
    }

    func recordActiveDay(now: Date = .now) {
        guard isOptedIn else { return }
        let day = Int(floor(now.timeIntervalSince1970 / 86_400))
        let previous = defaults.object(forKey: Self.lastActiveDayKey) as? Int
        guard previous.map({ day > $0 }) ?? true else { return }
        defaults.set(day, forKey: Self.lastActiveDayKey)
        send(Hit(event: .activeDay))
        if previous != nil { send(Hit(event: .returnDay)) }
    }

    func record(_ event: Event) {
        guard isOptedIn else { return }
        if event == .firstNote {
            guard !defaults.bool(forKey: Self.firstNoteKey) else { return }
            defaults.set(true, forKey: Self.firstNoteKey)
        }
        guard Event.allowedDetails[event] == nil else {
            assertionFailure("\(event.rawValue) needs a detail")
            return
        }
        send(Hit(event: event))
    }

    func record(_ event: Event, detail: String) {
        guard isOptedIn else { return }
        guard Event.allowedDetails[event]?.contains(detail) == true else {
            assertionFailure("\(detail) isn't an allowed detail for \(event.rawValue)")
            return
        }
        send(Hit(event: event, detail: detail))
    }

    /// Sends `event` the first time this install reaches it. The milestone is remembered even while
    /// opted out (on the device only), so opting in later doesn't count a later post as the first.
    func recordOnce(_ event: Event, key: String) {
        let flag = "appUsageAnalyticsOnce.\(key)"
        guard !defaults.bool(forKey: flag) else { return }
        defaults.set(true, forKey: flag)
        record(event)
    }

    /// A local, never-sent marker (for example "this install redeemed an invite").
    func setMarker(_ key: String) { defaults.set(true, forKey: "appUsageAnalyticsMarker.\(key)") }
    func hasMarker(_ key: String) -> Bool { defaults.bool(forKey: "appUsageAnalyticsMarker.\(key)") }

    private struct EventPayload: Encodable {
        let p_event: Event
        let p_detail: String?

        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(p_event, forKey: .p_event)
            // 1.0.1-era servers only know p_event; leave the key out when there's no detail.
            try c.encodeIfPresent(p_detail, forKey: .p_detail)
        }
        enum CodingKeys: String, CodingKey { case p_event, p_detail }
    }

    /// The request `sendEvent` posts; split out so tests can check it without a network.
    static func request(for hit: Hit, baseURL: URL, anonKey: String) -> URLRequest {
        var request = URLRequest(url: baseURL.appending(path: "rest/v1/rpc/record_app_usage_event"), timeoutInterval: 8)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.httpBody = try? JSONEncoder().encode(EventPayload(p_event: hit.event, p_detail: hit.detail))
        return request
    }

    private static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.httpShouldSetCookies = false
        config.urlCredentialStorage = nil
        return URLSession(configuration: config)
    }()

    private static func sendEvent(_ hit: Hit) async {
        guard SocialConfig.isConfigured else { return }
        let request = request(for: hit, baseURL: SocialConfig.supabaseURL, anonKey: SocialConfig.supabaseAnonKey)
        // Best effort: don't queue or retry events on the device.
        _ = try? await session.data(for: request)
    }
}

struct UsageAnalyticsSettings: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppAnalytics.optInKey) private var optedIn = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Share usage analytics", isOn: $optedIn)
                } footer: {
                    Text("Help improve HandStrudel by sharing counts of app use, first notes, recordings and posts, store visits and purchases, invites, replies, daily sounds and opened notifications, plus crash and hang reports. Crash reports include the app and iOS version, the iPhone model and where in the app the problem happened. We don't send audio, camera or gesture data, custom scale names, or account or device IDs. You can turn this off at any time.")
                }
            }
            .navigationTitle("Usage Analytics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .onChange(of: optedIn) { if $0 { AppAnalytics.shared.recordActiveDay() } }
        }
    }
}
