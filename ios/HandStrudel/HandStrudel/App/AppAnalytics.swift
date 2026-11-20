import Foundation
import SwiftUI

@MainActor
final class AppAnalytics {
    static let optInKey = "appUsageAnalyticsEnabled"
    private static let lastActiveDayKey = "appUsageAnalyticsLastActiveDay"
    private static let firstNoteKey = "appUsageAnalyticsFirstNote"
    static let shared = AppAnalytics(enabled: !ProcessInfo.processInfo.arguments.contains("--uitesting")) { event in
        Task {
            guard UserDefaults.standard.bool(forKey: optInKey) else { return }
            await sendEvent(event)
        }
    }

    enum Event: String, Encodable {
        case activeDay = "active_day"
        case returnDay = "return_day"
        case firstNote = "first_note"
        case recordingStarted = "recording_started"
        case recordingSaved = "recording_saved"
        case recordingPosted = "recording_posted"
        /// A Pro sound opened from the feed by someone without Pro.
        case lockedSoundTapped = "locked_sound_tapped"
        /// That sound unlocked (purchase or restore) from its unlock screen.
        case lockedSoundUnlocked = "locked_sound_unlocked"
    }

    private let defaults: UserDefaults
    private let enabled: Bool
    private let send: (Event) -> Void
    private var isOptedIn: Bool { enabled && defaults.bool(forKey: Self.optInKey) }

    init(defaults: UserDefaults = .standard, enabled: Bool = true, send: @escaping (Event) -> Void) {
        self.defaults = defaults
        self.enabled = enabled
        self.send = send
    }

    func recordActiveDay(now: Date = .now) {
        guard isOptedIn else { return }
        let day = Int(floor(now.timeIntervalSince1970 / 86_400))
        let previous = defaults.object(forKey: Self.lastActiveDayKey) as? Int
        guard previous.map({ day > $0 }) ?? true else { return }
        defaults.set(day, forKey: Self.lastActiveDayKey)
        send(.activeDay)
        if previous != nil { send(.returnDay) }
    }

    func record(_ event: Event) {
        guard isOptedIn else { return }
        if event == .firstNote {
            guard !defaults.bool(forKey: Self.firstNoteKey) else { return }
            defaults.set(true, forKey: Self.firstNoteKey)
        }
        send(event)
    }

    private struct EventPayload: Encodable { let p_event: Event }

    private static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.httpShouldSetCookies = false
        config.urlCredentialStorage = nil
        return URLSession(configuration: config)
    }()

    private static func sendEvent(_ event: Event) async {
        guard SocialConfig.isConfigured else { return }
        var request = URLRequest(
            url: SocialConfig.supabaseURL.appending(path: "rest/v1/rpc/record_app_usage_event"),
            timeoutInterval: 8
        )
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SocialConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.httpBody = try? JSONEncoder().encode(EventPayload(p_event: event))
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
                    Text("Help improve HandStrudel by sharing counts of app use, first notes, recordings, and Pro sounds unlocked from the feed. We don't send audio, camera or gesture data, custom scale names, or account or device IDs. You can turn this off at any time.")
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
