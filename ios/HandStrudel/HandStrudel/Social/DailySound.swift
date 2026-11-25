import Foundation
import Supabase

// MARK: - Models

/// Today's featured sound, its takes and the viewer's streak, from the `daily_sound_today` RPC.
/// Days roll over at 00:00 UTC for everyone; every time in here comes from the server.
struct DailySoundPayload: Decodable {
    /// The UTC date, "yyyy-MM-dd".
    let day: String
    let startsAt: Date
    let endsAt: Date
    let serverNow: Date
    let sound: DailySound?
    let takeCount: Int
    let takes: [Video]
    /// Nil when signed out.
    let streak: DailyStreak?

    enum CodingKeys: String, CodingKey {
        case day, sound, takes, streak
        case startsAt = "starts_at"
        case endsAt = "ends_at"
        case serverNow = "server_now"
        case takeCount = "take_count"
    }

    init(from decoder: Decoder) throws {
        let row = try decoder.container(keyedBy: CodingKeys.self)
        day = try row.decode(String.self, forKey: .day)
        startsAt = try row.decode(Date.self, forKey: .startsAt)
        endsAt = try row.decode(Date.self, forKey: .endsAt)
        serverNow = try row.decode(Date.self, forKey: .serverNow)
        sound = try row.decodeIfPresent(DailySound.self, forKey: .sound)
        takeCount = try row.decodeIfPresent(Int.self, forKey: .takeCount) ?? 0
        // One malformed take never hides the whole card.
        takes = (try? row.decode([FailableVideo].self, forKey: .takes))?.compactMap(\.video) ?? []
        streak = try row.decodeIfPresent(DailyStreak.self, forKey: .streak)
    }

    private struct FailableVideo: Decodable {
        let video: Video?
        init(from decoder: Decoder) throws { video = try? Video(from: decoder) }
    }
}

struct DailySound: Decodable {
    /// Nil when this app version can't play the sound.
    let setup: SoundSetup?
    let title: String?
    let note: String?
    /// "scheduled" by the owner or picked "auto"matically.
    let source: String
    /// The featured post. Nil when it's gone, hidden, or its creator is blocked either way.
    let video: Video?

    enum CodingKeys: String, CodingKey { case setup, title, note, source, video }

    init(from decoder: Decoder) throws {
        let row = try decoder.container(keyedBy: CodingKeys.self)
        let setup = try? row.decode(SoundSetup.self, forKey: .setup)
        self.setup = setup?.isValid == true ? setup : nil
        title = try row.decodeIfPresent(String.self, forKey: .title)
        note = try row.decodeIfPresent(String.self, forKey: .note)
        source = try row.decodeIfPresent(String.self, forKey: .source) ?? "auto"
        video = try? row.decodeIfPresent(Video.self, forKey: .video)
    }

    var displayTitle: String {
        if let title, !title.trimmingCharacters(in: .whitespaces).isEmpty { return title }
        return setup?.instrumentName ?? "Today's sound"
    }
}

struct DailyStreak: Decodable, Equatable {
    let current: Int
    let best: Int
    let postedToday: Bool
    let alive: Bool
    /// Missed days the week's freeze is holding until the next take ("yyyy-MM-dd").
    let freezeCovering: [String]
    let freezeAvailable: Bool
    /// The day this week's freeze covered, once used.
    let freezeUsedOn: String?
    /// When the streak ends without another take.
    let endsAt: Date?
    let badges: [Int]
    let nextMilestone: Int?
    let themeGrant: ThemeGrant?

    struct ThemeGrant: Decodable, Equatable {
        let themeID: String
        let expiresAt: Date
        enum CodingKeys: String, CodingKey {
            case themeID = "theme_id"
            case expiresAt = "expires_at"
        }
    }

    enum CodingKeys: String, CodingKey {
        case current, best, alive, badges
        case postedToday = "posted_today"
        case freezeCovering = "freeze_covering"
        case freezeAvailable = "freeze_available"
        case freezeUsedOn = "freeze_used_on"
        case endsAt = "ends_at"
        case nextMilestone = "next_milestone"
        case themeGrant = "theme_grant"
    }

    init(current: Int, best: Int, postedToday: Bool, alive: Bool, freezeCovering: [String] = [],
         freezeAvailable: Bool = true, freezeUsedOn: String? = nil, endsAt: Date? = nil, badges: [Int] = [],
         nextMilestone: Int? = nil, themeGrant: ThemeGrant? = nil) {
        self.current = current; self.best = best; self.postedToday = postedToday; self.alive = alive
        self.freezeCovering = freezeCovering; self.freezeAvailable = freezeAvailable; self.freezeUsedOn = freezeUsedOn
        self.endsAt = endsAt; self.badges = badges; self.nextMilestone = nextMilestone; self.themeGrant = themeGrant
    }

    init(from decoder: Decoder) throws {
        let row = try decoder.container(keyedBy: CodingKeys.self)
        current = try row.decodeIfPresent(Int.self, forKey: .current) ?? 0
        best = try row.decodeIfPresent(Int.self, forKey: .best) ?? 0
        postedToday = try row.decodeIfPresent(Bool.self, forKey: .postedToday) ?? false
        alive = try row.decodeIfPresent(Bool.self, forKey: .alive) ?? false
        freezeCovering = try row.decodeIfPresent([String].self, forKey: .freezeCovering) ?? []
        freezeAvailable = try row.decodeIfPresent(Bool.self, forKey: .freezeAvailable) ?? false
        freezeUsedOn = try row.decodeIfPresent(String.self, forKey: .freezeUsedOn)
        endsAt = try row.decodeIfPresent(Date.self, forKey: .endsAt)
        badges = try row.decodeIfPresent([Int].self, forKey: .badges) ?? []
        nextMilestone = try row.decodeIfPresent(Int.self, forKey: .nextMilestone)
        themeGrant = try? row.decodeIfPresent(ThemeGrant.self, forKey: .themeGrant)
    }

    static let milestones = [3, 7, 30]
}

/// A creator's public streak, from `daily_streak_profile`.
struct DailyStreakProfile: Decodable, Equatable {
    let current: Int
    let best: Int
    let badges: [Int]
}

/// A HandStrudel+ hand theme lent for a week by a 7-day streak. The grant lives on the server
/// (`daily_theme_grants`); the app only times what's left on the device's uptime clock,
/// which changing the date and time in Settings doesn't move.
struct StreakThemeLoan: Equatable {
    let themeID: String
    /// `ProcessInfo.systemUptime` at which the loan ends.
    let endsAtUptime: TimeInterval
    /// For display only.
    let expiresAt: Date

    init(themeID: String, expiresAt: Date, serverNow: Date, uptime: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        self.themeID = themeID
        self.expiresAt = expiresAt
        endsAtUptime = uptime + expiresAt.timeIntervalSince(serverNow)
    }

    func isActive(for themeID: String, uptime: TimeInterval = ProcessInfo.processInfo.systemUptime) -> Bool {
        themeID == self.themeID && uptime < endsAtUptime
    }

    var theme: HandTheme? { HAND_THEMES.first { $0.id == themeID } }
}

extension SoundSetup {
    /// True when a post with this setup is a take on a daily sound with `other`: the same
    /// instrument, key, scale and progression. Tempo, mode and mix may differ. Mirrors
    /// `daily_internal.sound_signature` on the server.
    func isSameDailySound(as other: SoundSetup) -> Bool {
        guard useSoundFont == other.useSoundFont,
              useSoundFont ? instrument == other.instrument : waveform == other.waveform,
              key == other.key, scale == other.scale, progression == other.progression else { return false }
        return progression != "custom" || customDegrees == other.customDegrees
    }
}

// MARK: - Service

enum DailySoundService {
    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let text = try decoder.singleValueContainer().decode(String.self)
            guard let date = parseDate(text) else {
                throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Bad date \(text)"))
            }
            return date
        }
        return decoder
    }()

    /// Postgres JSON timestamps: "2026-11-21T00:00:00+00:00", with or without fractional seconds.
    static func parseDate(_ text: String) -> Date? {
        let plain = ISO8601DateFormatter()
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: text) ?? plain.date(from: text)
    }

    static func today() async throws -> DailySoundPayload {
        let data = try await supabase.rpc("daily_sound_today").execute().data
        return try decoder.decode(DailySoundPayload.self, from: data)
    }

    static func profileStreak(username: String) async throws -> DailyStreakProfile? {
        struct Parameters: Encodable { let target_username: String }
        let data = try await supabase.rpc("daily_streak_profile", params: Parameters(target_username: username)).execute().data
        if data.isEmpty || String(decoding: data, as: UTF8.self) == "null" { return nil }
        return try decoder.decode(DailyStreakProfile.self, from: data)
    }
}

// MARK: - Store

/// Holds today's sound for the Music home card, the post composer and the hand theme loan.
@MainActor
final class DailySoundStore: ObservableObject {
    static let shared = DailySoundStore()

    @Published private(set) var payload: DailySoundPayload?
    @Published private(set) var isLoading = false
    @Published private(set) var loadFailed = false
    /// The hand theme a 7-day streak lent the player, if it's still running.
    @Published private(set) var themeLoan: StreakThemeLoan?

    private var fetchedAtUptime: TimeInterval = 0
    private var loadedViewer: UUID?
    private var serverNowAtFetch: Date?
    private let load: () async throws -> DailySoundPayload
    private let uptime: () -> TimeInterval

    init(load: @escaping () async throws -> DailySoundPayload = DailySoundService.today,
         uptime: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) {
        self.load = load
        self.uptime = uptime
    }

    /// The server's clock, advanced by the device's uptime since the last fetch.
    var serverNow: Date? {
        serverNowAtFetch.map { $0.addingTimeInterval(uptime() - fetchedAtUptime) }
    }

    /// Time left in today's window, or nil before the first load.
    var timeLeft: TimeInterval? {
        guard let payload, let now = serverNow else { return nil }
        return max(0, payload.endsAt.timeIntervalSince(now))
    }

    var isStale: Bool { timeLeft == 0 }

    /// Reloads unless a load for the same account finished within `maxAge` seconds on the same day.
    func refresh(viewer: UUID? = nil, maxAge: TimeInterval = 0) async {
        if maxAge > 0, payload != nil, !isStale, loadedViewer == viewer, uptime() - fetchedAtUptime < maxAge { return }
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let next = try await load()
            serverNowAtFetch = next.serverNow
            fetchedAtUptime = uptime()
            loadedViewer = viewer
            payload = next
            themeLoan = next.streak?.themeGrant.map {
                StreakThemeLoan(themeID: $0.themeID, expiresAt: $0.expiresAt, serverNow: next.serverNow, uptime: fetchedAtUptime)
            }
            loadFailed = false
        } catch {
            if !(error is CancellationError) { loadFailed = true }
        }
    }

    /// Forget the signed-in player's streak (after signing out) until the next load.
    func clear() {
        payload = nil
        serverNowAtFetch = nil
        themeLoan = nil
    }

    /// Whether posting with `setup` right now would count as a take on today's sound.
    func isTodaysSound(_ setup: SoundSetup?) -> Bool {
        guard let setup, let today = payload?.sound?.setup, !isStale else { return false }
        return setup.isSameDailySound(as: today)
    }
}

// MARK: - Formatting

enum DailySoundFormat {
    /// "5h 12m", "48m", or "under a minute".
    static func timeLeft(_ interval: TimeInterval) -> String {
        let minutes = Int(interval / 60)
        if minutes < 1 { return "under a minute" }
        let hours = minutes / 60
        return hours > 0 ? "\(hours)h \(minutes % 60)m" : "\(minutes)m"
    }

    private static let dayParser: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    /// The weekday of a UTC day such as "2026-11-19" ("Thursday").
    static func weekday(_ day: String) -> String? {
        guard let date = dayParser.date(from: day) else { return nil }
        var style = Date.FormatStyle().weekday(.wide)
        style.timeZone = TimeZone(identifier: "UTC")!
        return date.formatted(style)
    }
}
