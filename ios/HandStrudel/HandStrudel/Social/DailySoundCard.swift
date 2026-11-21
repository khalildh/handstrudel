import SwiftUI

/// "Today's sound" at the top of the Music home: the featured sound and its creator, a
/// countdown to the 00:00 UTC rollover, today's takes and the player's streak.
struct DailySoundCard: View {
    @Environment(\.studioPalette) private var palette
    @Environment(\.isSoundLocked) private var isSoundLocked
    @ObservedObject var store: DailySoundStore
    @ObservedObject var auth: AuthManager
    let onPlay: (SoundSetup) -> Void
    let onPlayAlong: (Video) -> Void
    let onSignIn: () -> Void

    @State private var watching: Video?
    @State private var afterDismiss: PerformanceAction?

    private enum PerformanceAction { case sound(SoundSetup), playAlong(Video) }

    var body: some View {
        Group {
            if let payload = store.payload, let sound = payload.sound {
                card(payload, sound: sound)
            }
        }
        // ContentView loads it at launch and on sign-in; this refreshes when the card reappears.
        .task(id: auth.userId) { await store.refresh(viewer: auth.userId, maxAge: 30) }
        .sheet(item: $watching, onDismiss: {
            switch afterDismiss {
            case .sound(let setup): onPlay(setup)
            case .playAlong(let video): onPlayAlong(video)
            case nil: break
            }
            afterDismiss = nil
        }) { video in
            CreatorVideoView(video: video, auth: auth, onPlayAlong: { video in
                afterDismiss = .playAlong(video)
                watching = nil
            }, onTrySound: { setup in
                afterDismiss = .sound(setup)
                watching = nil
            }, playlist: playlist(for: video))
        }
    }

    private func playlist(for video: Video) -> [Video] {
        guard let payload = store.payload else { return [] }
        return payload.takes.contains { $0.id == video.id } ? payload.takes : []
    }

    private func card(_ payload: DailySoundPayload, sound: DailySound) -> some View {
        StudioSettingsPanel {
            VStack(alignment: .leading, spacing: 14) {
                header
                details(sound)
                playButton(sound)
                takes(payload)
                Rectangle().fill(palette.border).frame(height: 1).accessibilityHidden(true)
                DailyStreakSummary(streak: payload.streak, timeLeft: store.timeLeft, onSignIn: onSignIn)
            }
            .padding(17)
            .background(alignment: .topTrailing) {
                LinearGradient(colors: [palette.glow.opacity(0.35), palette.surface.opacity(0)],
                               startPoint: .topTrailing, endPoint: .center)
                    .clipShape(RoundedRectangle(cornerRadius: 21))
                    .allowsHitTesting(false)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("daily-sound-card")
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Label("TODAY'S SOUND", systemImage: "sun.max")
                .font(.caption2.monospaced().weight(.semibold))
                .tracking(1.6)
                .foregroundStyle(palette.accent)
            Spacer(minLength: 8)
            TimelineView(.periodic(from: .now, by: 30)) { _ in
                if let left = store.timeLeft {
                    Text(left > 0 ? "New sound in \(DailySoundFormat.timeLeft(left))" : "New sound ready")
                        .font(.caption.monospaced())
                        .foregroundStyle(palette.muted)
                        .accessibilityIdentifier("daily-time-left")
                        .task(id: left == 0) { if left == 0 { await store.refresh() } }
                }
            }
        }
    }

    @ViewBuilder private func details(_ sound: DailySound) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(verbatim: sound.displayTitle)
                .font(.system(.title, design: .serif))
                .foregroundStyle(palette.ink)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("daily-sound-title")
            if let setup = sound.setup {
                Text(verbatim: setup.presetDetails)
                    .font(.caption.monospaced())
                    .foregroundStyle(palette.muted)
            }
            if let video = sound.video, let username = video.username {
                Button { watching = video } label: {
                    HStack(spacing: 5) {
                        Text(verbatim: "by @\(username)").font(.subheadline.weight(.semibold))
                        Image(systemName: "play.rectangle").font(.caption).accessibilityHidden(true)
                    }
                    .foregroundStyle(palette.ink)
                    .frame(minHeight: 32)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Watch @\(username)'s performance")
                .accessibilityIdentifier("daily-sound-creator")
            }
            if let note = sound.note, !note.isEmpty {
                Text(verbatim: note).font(.subheadline).foregroundStyle(palette.ink.opacity(0.85))
            }
        }
    }

    @ViewBuilder private func playButton(_ sound: DailySound) -> some View {
        if let setup = sound.setup {
            let locked = isSoundLocked(setup)
            Button { onPlay(setup) } label: {
                Label(locked ? "Unlock & play today's sound" : "Play today's sound",
                      systemImage: locked ? "lock.open.fill" : "play.fill")
            }
            .buttonStyle(StudioActionStyle())
            .accessibilityIdentifier("daily-play-sound")
        } else {
            Text("Update HandStrudel to play today's sound.")
                .font(.footnote).foregroundStyle(palette.muted)
        }
    }

    @ViewBuilder private func takes(_ payload: DailySoundPayload) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(payload.takeCount == 0 ? "No takes yet today. Post the first one."
                 : payload.takeCount == 1 ? "1 take today" : "\(payload.takeCount.formatted()) takes today")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(payload.takeCount == 0 ? palette.muted : palette.ink)
                .accessibilityIdentifier("daily-take-count")
            if !payload.takes.isEmpty {
                HStack(spacing: 8) {
                    ForEach(payload.takes.prefix(4)) { take in
                        Button { watching = take } label: { DailyTakeThumbnail(video: take) }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Take by @\(take.username ?? "creator")")
                    }
                    Spacer(minLength: 0)
                }
                .accessibilityIdentifier("daily-takes")
            }
        }
    }
}

private struct DailyTakeThumbnail: View {
    @Environment(\.studioPalette) private var palette
    let video: Video

    var body: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(palette.background)
            .overlay {
                AsyncImage(url: video.thumbURL) { image in image.resizable().scaledToFill() }
                    placeholder: { Image(systemName: "play.rectangle").foregroundStyle(palette.muted) }
            }
            .overlay(alignment: .bottomLeading) {
                Text(verbatim: "@\(video.username ?? "")")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .lineLimit(1)
                    .foregroundStyle(.white)
                    .padding(4)
                    .shadow(radius: 2)
            }
            .frame(width: 58, height: 82)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay { RoundedRectangle(cornerRadius: 10).strokeBorder(palette.border) }
    }
}

/// Current and best streak, the week's freeze, badges and the theme loan.
struct DailyStreakSummary: View {
    @Environment(\.studioPalette) private var palette
    let streak: DailyStreak?
    let timeLeft: TimeInterval?
    let onSignIn: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            if let streak {
                HStack(alignment: .center, spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                    Label {
                        Text(streak.current == 1 ? "1-day streak" : "\(streak.current)-day streak")
                    } icon: {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(streak.current > 0 ? palette.accent : palette.muted)
                    }
                    .font(.headline.monospaced())
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(streak.current == 1 ? "1-day streak" : "\(streak.current)-day streak")
                    .accessibilityIdentifier("daily-streak-current")
                    Text("Best \(streak.best)")
                        .font(.caption.monospaced())
                        .foregroundStyle(palette.muted)
                        .accessibilityIdentifier("daily-streak-best")
                    }
                    Spacer(minLength: 0)
                    DailyBadgeRow(badges: streak.badges)
                }
                Text(statusLine(streak))
                    .font(.subheadline)
                    .foregroundStyle(streak.postedToday ? palette.accent : palette.ink)
                    .accessibilityIdentifier("daily-streak-status")
                Label(freezeLine(streak), systemImage: "snowflake")
                    .font(.caption)
                    .foregroundStyle(streak.freezeCovering.isEmpty ? palette.muted : palette.ink)
                    .spoken(freezeLine(streak))
                    .accessibilityIdentifier("daily-streak-freeze")
                if let grant = streak.themeGrant, let theme = HAND_THEMES.first(where: { $0.id == grant.themeID }) {
                    let loan = "\(theme.name) hand theme unlocked until \(grant.expiresAt.formatted(date: .abbreviated, time: .omitted))"
                    Label("\(theme.emoji) \(loan)", systemImage: "sparkles")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(palette.accent)
                        .spoken("7-day reward: " + loan)
                        .accessibilityIdentifier("daily-theme-loan")
                } else if let next = streak.nextMilestone {
                    Text(milestoneLine(next, current: streak.current))
                        .font(.caption)
                        .foregroundStyle(palette.muted)
                }
            } else {
                Label("Post a take on today's sound to start a streak.", systemImage: "flame")
                    .font(.subheadline)
                    .foregroundStyle(palette.ink)
                    .spoken("Post a take on today's sound to start a streak.")
                Button("Sign in to keep a streak", action: onSignIn)
                    .font(.subheadline.weight(.semibold))
                    .accessibilityIdentifier("daily-streak-sign-in")
            }
        }
    }

    private func statusLine(_ streak: DailyStreak) -> String {
        if streak.postedToday { return "Today's take counted. Come back tomorrow." }
        if streak.alive, streak.current > 0 {
            let left = timeLeft.map { " in the next \(DailySoundFormat.timeLeft($0))" } ?? " today"
            return "Post a take\(left) to keep your streak."
        }
        return "Post a take on today's sound to start a streak."
    }

    private func freezeLine(_ streak: DailyStreak) -> String {
        if let day = streak.freezeCovering.last {
            return "Your freeze is covering \(DailySoundFormat.weekday(day) ?? day). Post today to keep your streak."
        }
        if let day = streak.freezeUsedOn {
            return "This week's freeze covered \(DailySoundFormat.weekday(day) ?? day). It's back on Monday."
        }
        return streak.freezeAvailable ? "1 freeze this week: one missed day won't reset your streak."
            : "This week's freeze is used. It's back on Monday."
    }

    private func milestoneLine(_ next: Int, current: Int) -> String {
        let days = next - current
        let reward = next == 7 ? "the 7-day badge and a week of a HandStrudel+ hand theme" : "the \(next)-day badge"
        return days == 1 ? "1 more day to \(reward)." : "\(days) more days to \(reward)."
    }
}

/// The 3, 7 and 30-day badges; earned ones are lit.
struct DailyBadgeRow: View {
    @Environment(\.studioPalette) private var palette
    let badges: [Int]
    var showsUnearned = true

    var body: some View {
        HStack(spacing: 4) {
            ForEach(DailyStreak.milestones.filter { showsUnearned || badges.contains($0) }, id: \.self) { milestone in
                let earned = badges.contains(milestone)
                Text("\(milestone)")
                    .font(.caption2.monospaced().weight(.bold))
                    .frame(minWidth: 22, minHeight: 20)
                    .padding(.horizontal, 3)
                    .foregroundStyle(earned ? palette.onAccent : palette.muted)
                    .background(earned ? palette.accent : palette.background.opacity(0.6), in: Capsule())
                    .overlay { Capsule().strokeBorder(earned ? Color.clear : palette.border) }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(badges.isEmpty ? "No streak badges yet"
                            : "Streak badges: " + badges.map { "\($0) days" }.joined(separator: ", "))
        .accessibilityIdentifier("daily-streak-badges")
    }
}

/// The streak line on a creator profile: current, best and earned badges. Attached to a view
/// that is always shown, so the lookup runs even while there's nothing to show yet.
private struct DailyStreakProfileStrip: ViewModifier {
    @Environment(\.studioPalette) private var palette
    let username: String
    @State private var streak: DailyStreakProfile?

    func body(content: Content) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            content
            if let streak, streak.best > 0 {
                HStack(spacing: 8) {
                    Image(systemName: "flame.fill").foregroundStyle(streak.current > 0 ? palette.accent : palette.muted)
                        .accessibilityHidden(true)
                    Text(streak.current > 0 ? "\(streak.current)-day streak" : "No streak today")
                        .font(.subheadline.monospaced().weight(.semibold))
                    Text("Best \(streak.best)").font(.caption.monospaced()).foregroundStyle(palette.muted)
                    Spacer(minLength: 0)
                    DailyBadgeRow(badges: streak.badges, showsUnearned: false)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("profile-daily-streak")
            }
        }
        .task(id: username) { streak = try? await DailySoundService.profileStreak(username: username) }
    }
}

extension View {
    /// Adds a creator's daily-sound streak and badges under this view.
    func dailyStreakStrip(username: String) -> some View { modifier(DailyStreakProfileStrip(username: username)) }
}

/// Shown while posting when the take will count toward today's streak.
struct DailyTakeHint: View {
    @ObservedObject private var store = DailySoundStore.shared
    let setup: SoundSetup?
    /// Takes only count when the playable preset is shared with the post.
    let sharesPreset: Bool

    var body: some View {
        if store.isTodaysSound(setup) {
            Label(sharesPreset ? "Uses today's sound: this take counts toward your streak."
                  : "Share the playable preset for this take to count toward your streak.",
                  systemImage: sharesPreset ? "flame.fill" : "flame")
                .font(.footnote.weight(.semibold))
                .spoken(sharesPreset ? "Uses today's sound: this take counts toward your streak."
                        : "Share the playable preset for this take to count toward your streak.")
                .accessibilityIdentifier("daily-take-hint")
        }
    }
}

private extension View {
    /// One VoiceOver element that reads `text` (not the icon's name).
    func spoken(_ text: String) -> some View {
        accessibilityElement(children: .ignore).accessibilityLabel(text)
    }
}
