import AVKit
import SwiftUI

/// Admin-only review of reported posts and comments (Profile → Moderation).
/// Every action runs through an admin-checked RPC and lands in the audit log.
struct ModerationView: View {
    @Environment(\.studioPalette) private var palette
    @Environment(\.dismiss) private var dismiss
    @State private var filter: ModerationService.Filter = .open
    @State private var sort: ModerationService.Sort = .newest
    @State private var items: [ModerationItem] = []
    @State private var media: [UUID: ModerationService.Media] = [:]
    @State private var loading = false
    @State private var canLoadMore = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    intro
                    controls
                    if let error {
                        StudioSettingsPanel {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(error).font(.subheadline)
                                Button("Try again") { Task { await reload() } }
                                    .buttonStyle(ProfileActionStyle())
                            }
                            .padding(16)
                        }
                    } else if items.isEmpty && !loading {
                        StudioSettingsPanel {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(filter == .open ? "Nothing to review" : "Nothing here")
                                    .font(.system(.title3, design: .serif))
                                Text(filter == .open ? "New reports on posts and comments show up here."
                                                     : "No posts or comments match this filter.")
                                    .font(.subheadline).foregroundStyle(palette.muted)
                            }
                            .padding(16)
                            .accessibilityElement(children: .combine)
                            .accessibilityIdentifier("moderation-empty")
                        }
                    }
                    ForEach(items) { item in
                        NavigationLink {
                            ModerationDetailView(item: item, media: media[item.videoId]) { await reload() }
                        } label: {
                            ModerationRow(item: item, thumb: media[item.videoId]?.thumb)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("moderation-item-\(item.targetId.uuidString.lowercased())")
                        .task { if item == items.last && canLoadMore { await loadMore() } }
                    }
                    if loading { ProgressView().frame(maxWidth: .infinity).padding() }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
                .frame(maxWidth: 650)
                .frame(maxWidth: .infinity)
            }
            .refreshable { await reload() }
            .background(palette.background.ignoresSafeArea())
            .navigationTitle("Moderation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    NavigationLink { ModerationLogView() } label: { Label("Audit log", systemImage: "clock.arrow.circlepath") }
                        .accessibilityIdentifier("moderation-log")
                }
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .task(id: "\(filter.rawValue)-\(sort.rawValue)") { await reload() }
        }
        .tint(palette.accent)
        .foregroundStyle(palette.ink)
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("HANDSTRUDEL / MODERATION", systemImage: "shield.lefthalf.filled")
                .font(.system(.caption2, design: .monospaced).weight(.semibold))
                .tracking(1.35)
                .foregroundStyle(palette.accent)
            Text("Reported content")
                .font(.system(.largeTitle, design: .serif))
                .accessibilityAddTraits(.isHeader)
            Text("Three reports hide a post or comment automatically. Review it, then restore, hide or dismiss.")
                .font(.subheadline).foregroundStyle(palette.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 8)
    }

    private var controls: some View {
        HStack(spacing: 10) {
            Picker("Show", selection: $filter) {
                ForEach(ModerationService.Filter.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("moderation-filter")
            Menu {
                Picker("Sort", selection: $sort) {
                    ForEach(ModerationService.Sort.allCases) { Text($0.title).tag($0) }
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .frame(width: 44, height: 32)
                    .background(palette.surface, in: Capsule())
                    .overlay { Capsule().strokeBorder(palette.border) }
            }
            .accessibilityLabel("Sort: \(sort.title)")
        }
    }

    private func reload() async {
        loading = true
        defer { loading = false }
        do {
            let page = try await ModerationService.queue(filter: filter, sort: sort)
            items = page
            canLoadMore = page.count == ModerationService.pageSize
            error = nil
            await loadMedia(for: page)
        } catch {
            items = []
            self.error = "Couldn't load the queue. Check your connection and try again."
        }
    }

    private func loadMore() async {
        guard !loading else { return }
        loading = true
        defer { loading = false }
        guard let page = try? await ModerationService.queue(filter: filter, sort: sort, offset: items.count) else { return }
        let known = Set(items.map(\.id))
        items += page.filter { !known.contains($0.id) }
        canLoadMore = page.count == ModerationService.pageSize
        await loadMedia(for: page)
    }

    private func loadMedia(for page: [ModerationItem]) async {
        let missing = page.map(\.videoId).filter { media[$0] == nil }
        // Playback for hidden posts needs signed URLs; without them rows show a placeholder.
        if let signed = try? await ModerationService.media(for: missing) { media.merge(signed) { $1 } }
    }
}

private struct ModerationRow: View {
    @Environment(\.studioPalette) private var palette
    let item: ModerationItem
    let thumb: URL?

    var body: some View {
        StudioSettingsPanel {
            HStack(alignment: .top, spacing: 12) {
                ModerationThumb(url: thumb ?? publicThumb)
                    .frame(width: 64, height: 86)
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Text(item.kind == .post ? "POST" : "COMMENT")
                            .font(.system(.caption2, design: .monospaced).weight(.semibold))
                            .foregroundStyle(palette.accent)
                        ModerationStateChip(state: item.state)
                    }
                    Text(item.body.isEmpty ? "No caption" : item.body)
                        .font(.subheadline)
                        .foregroundStyle(item.body.isEmpty ? palette.muted : palette.ink)
                        .lineLimit(3)
                    Text(item.author + (item.authorBanned ? " · banned" : ""))
                        .font(.caption.weight(.semibold))
                    Text(reportSummary)
                        .font(.caption).foregroundStyle(palette.muted)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(palette.muted)
            }
            .padding(12)
        }
        .accessibilityElement(children: .combine)
    }

    /// Visible posts still play through the public worker if signed URLs aren't available.
    private var publicThumb: URL? { item.state == .visible ? SocialConfig.mediaURL(item.thumbKey) : nil }

    private var reportSummary: String {
        let count = item.openReports > 0 ? "\(item.openReports) open" : "\(item.totalReports) reviewed"
        let noun = (item.openReports > 0 ? item.openReports : item.totalReports) == 1 ? "report" : "reports"
        let reasons = item.reasons.isEmpty ? "" : " · " + item.reasons.joined(separator: ", ")
        return "\(count) \(noun)\(reasons)"
    }
}

private struct ModerationThumb: View {
    @Environment(\.studioPalette) private var palette
    let url: URL?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10).fill(palette.background)
            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image): image.resizable().scaledToFill()
                    case .failure: Image(systemName: "eye.slash").foregroundStyle(palette.muted)
                    default: ProgressView()
                    }
                }
            } else {
                Image(systemName: "eye.slash").foregroundStyle(palette.muted)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay { RoundedRectangle(cornerRadius: 10).strokeBorder(palette.border) }
        .accessibilityHidden(true)
    }
}

private struct ModerationStateChip: View {
    @Environment(\.studioPalette) private var palette
    let state: ModerationItem.State

    var body: some View {
        Text(state.title)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 7).padding(.vertical, 2)
            .foregroundStyle(state.isHidden ? palette.onAccent : palette.ink)
            .background(state.isHidden ? palette.accent : palette.background, in: Capsule())
            .overlay { Capsule().strokeBorder(palette.border) }
    }
}

struct ModerationDetailView: View {
    @Environment(\.studioPalette) private var palette
    @Environment(\.dismiss) private var dismiss
    @State var item: ModerationItem
    let media: ModerationService.Media?
    let onChange: () async -> Void
    @State private var reports: [ModerationReport] = []
    @State private var player: AVPlayer?
    @State private var note = ""
    @State private var pending: ModerationService.Action?
    @State private var working = false
    @State private var error: String?
    @State private var done: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                content
                details
                reportList
                actions
            }
            .padding(20)
            .frame(maxWidth: 650)
            .frame(maxWidth: .infinity)
        }
        .background(palette.background.ignoresSafeArea())
        .navigationTitle(item.kind == .post ? "Reported post" : "Reported comment")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if item.kind == .post, let url = media?.video ?? publicVideo { player = AVPlayer(url: url) }
            reports = (try? await ModerationService.reports(for: item)) ?? []
        }
        .onDisappear { player?.pause() }
        .confirmationDialog(pending.map(confirmTitle) ?? "", isPresented: Binding(
            get: { pending != nil }, set: { if !$0 { pending = nil } }), titleVisibility: .visible) {
            if let action = pending {
                Button(buttonTitle(action), role: action == .ban || action == .hide ? .destructive : nil) {
                    Task { await run(action) }
                }
                .accessibilityIdentifier("moderation-confirm")
            }
        } message: {
            if let action = pending { Text(confirmMessage(action)) }
        }
        .alert("Couldn't moderate", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(error ?? "") }
    }

    private var publicVideo: URL? { item.state == .visible ? SocialConfig.mediaURL(item.videoKey) : nil }

    @ViewBuilder private var content: some View {
        if item.kind == .post {
            Group {
                if let player {
                    VideoPlayer(player: player)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "eye.slash").font(.title2)
                        Text("Preview unavailable").font(.subheadline)
                    }
                    .foregroundStyle(palette.muted)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(palette.surface)
                }
            }
            .aspectRatio(9 / 16, contentMode: .fit)
            .frame(maxHeight: 460)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 21))
            .overlay { RoundedRectangle(cornerRadius: 21).strokeBorder(palette.border) }
            .accessibilityIdentifier("moderation-player")
        }
        StudioSettingsPanel {
            VStack(alignment: .leading, spacing: 8) {
                Text(item.kind == .post ? "CAPTION" : "COMMENT")
                    .font(.system(.caption2, design: .monospaced).weight(.semibold))
                    .foregroundStyle(palette.accent)
                Text(item.body.isEmpty ? "No caption" : item.body)
                    .font(.system(.title3, design: .serif))
                    .foregroundStyle(item.body.isEmpty ? palette.muted : palette.ink)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
        }
    }

    private var details: some View {
        StudioSettingsPanel {
            VStack(spacing: 0) {
                ModerationFactRow("Author", value: item.author + (item.authorBanned ? " (banned)" : ""), icon: "person")
                StudioSettingsDivider()
                ModerationFactRow("State", value: item.state.title, icon: item.state.isHidden ? "eye.slash" : "eye")
                    .accessibilityIdentifier("moderation-state")
                StudioSettingsDivider()
                ModerationFactRow("Reports", value: "\(item.openReports) open of \(item.totalReports)", icon: "flag")
                StudioSettingsDivider()
                ModerationFactRow("Posted", value: item.createdAt.formatted(date: .abbreviated, time: .shortened),
                                 icon: "calendar")
            }
        }
    }

    private var reportList: some View {
        StudioSettingsPanel {
            VStack(alignment: .leading, spacing: 10) {
                Text("Reports").font(.system(.title3, design: .serif))
                if reports.isEmpty {
                    Text("No reports. This item was moderated directly.").font(.subheadline).foregroundStyle(palette.muted)
                }
                ForEach(reports) { report in
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(report.reason.capitalized).font(.subheadline.weight(.semibold))
                            Text(report.reporterUsername.map { "@\($0)" } ?? "Deleted account")
                                .font(.caption).foregroundStyle(palette.muted)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(report.createdAt, style: .relative).font(.caption).foregroundStyle(palette.muted)
                            if report.reviewedAt != nil {
                                Text("Reviewed").font(.caption2.weight(.semibold)).foregroundStyle(palette.muted)
                            }
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(16)
        }
    }

    private var actions: some View {
        StudioSettingsPanel {
            VStack(alignment: .leading, spacing: 10) {
                Text("Actions").font(.system(.title3, design: .serif))
                TextField("Note for the audit log (optional)", text: $note, axis: .vertical)
                    .lineLimit(1...3)
                    .padding(10)
                    .background(palette.background, in: RoundedRectangle(cornerRadius: 11))
                    .overlay { RoundedRectangle(cornerRadius: 11).strokeBorder(palette.border) }
                if let done {
                    Label(done, systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(palette.accent)
                        .accessibilityIdentifier("moderation-done")
                }
                if item.state.isHidden {
                    actionButton(.restore, "Restore \(noun)", "eye", disabled: item.authorBanned)
                }
                if item.state != .adminHidden && item.state != .banned {
                    actionButton(.hide, "Hide \(noun)", "eye.slash", primary: true)
                }
                if item.openReports > 0 {
                    actionButton(.dismiss, "Dismiss reports", "checkmark")
                }
                if item.authorBanned {
                    actionButton(.unban, "Unban \(item.author)", "person.crop.circle.badge.checkmark")
                } else {
                    actionButton(.ban, "Ban \(item.author)", "person.crop.circle.badge.xmark")
                }
                if item.authorBanned && item.state.isHidden {
                    Text("Unban the author to restore their posts and comments.")
                        .font(.caption).foregroundStyle(palette.muted)
                }
            }
            .padding(16)
            .disabled(working)
        }
    }

    private var noun: String { item.kind == .post ? "post" : "comment" }

    private func actionButton(_ action: ModerationService.Action, _ title: String, _ icon: String,
                              primary: Bool = false, disabled: Bool = false) -> some View {
        Button { pending = action } label: { Label(title, systemImage: icon) }
            .buttonStyle(ProfileActionStyle(primary: primary))
            .disabled(disabled)
            .accessibilityIdentifier("moderation-\(action.rawValue)")
    }

    private func confirmTitle(_ action: ModerationService.Action) -> String {
        switch action {
        case .hide: "Hide this \(noun)?"
        case .restore: "Restore this \(noun)?"
        case .dismiss: "Dismiss \(item.openReports == 1 ? "this report" : "these reports")?"
        case .ban: "Ban \(item.author)?"
        case .unban: "Unban \(item.author)?"
        }
    }

    private func buttonTitle(_ action: ModerationService.Action) -> String {
        switch action {
        case .hide: "Hide"
        case .restore: "Restore"
        case .dismiss: "Dismiss"
        case .ban: "Ban account"
        case .unban: "Unban account"
        }
    }

    private func confirmMessage(_ action: ModerationService.Action) -> String {
        switch action {
        case .hide: "It leaves the feed, profiles, sound pages and counts for everyone except its author."
        case .restore: "It becomes public again and its open reports are marked reviewed."
        case .dismiss: "The reports are marked reviewed. Whether it's visible doesn't change."
        case .ban: "Every post and comment by this account is hidden, and it can't post or comment until unbanned."
        case .unban: "The account can post again, and what the ban hid comes back. Items hidden for other reasons stay hidden."
        }
    }

    private func run(_ action: ModerationService.Action) async {
        working = true
        defer { working = false }
        do {
            try await ModerationService.perform(action, on: item, note: note)
            note = ""
            done = switch action {
            case .hide: "Hidden"
            case .restore: "Restored"
            case .dismiss: "Reports dismissed"
            case .ban: "Account banned"
            case .unban: "Account unbanned"
            }
            await onChange()
            if let fresh = try? await ModerationService.queue(filter: .all, sort: .newest)
                .first(where: { $0.id == item.id }) {
                item = fresh
            }
            reports = (try? await ModerationService.reports(for: item)) ?? reports
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct ModerationLogView: View {
    @Environment(\.studioPalette) private var palette
    @State private var entries: [ModerationLogEntry] = []
    @State private var loaded = false
    @State private var failed = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                Text("Every moderation action, newest first.")
                    .font(.subheadline).foregroundStyle(palette.muted)
                if failed {
                    Text("Couldn't load the audit log.").foregroundStyle(palette.muted)
                } else if loaded && entries.isEmpty {
                    Text("No moderation actions yet.").foregroundStyle(palette.muted)
                }
                StudioSettingsPanel {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                            if index > 0 { Rectangle().fill(palette.border).frame(height: 1) }
                            VStack(alignment: .leading, spacing: 3) {
                                Text("\(entry.adminUsername.map { "@\($0)" } ?? "An admin") \(entry.summary)")
                                    .font(.subheadline.weight(.semibold))
                                if let note = entry.note { Text(note).font(.subheadline) }
                                Text(entry.createdAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption).foregroundStyle(palette.muted)
                            }
                            .padding(.vertical, 10)
                            .accessibilityElement(children: .combine)
                            .accessibilityIdentifier("moderation-log-entry")
                            .task { if entry == entries.last && entries.count % ModerationService.pageSize == 0 { await more() } }
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .opacity(entries.isEmpty ? 0 : 1)
            }
            .padding(20)
            .frame(maxWidth: 650)
            .frame(maxWidth: .infinity)
        }
        .refreshable { await load() }
        .background(palette.background.ignoresSafeArea())
        .navigationTitle("Audit log")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        do {
            entries = try await ModerationService.log()
            failed = false
        } catch {
            failed = true
        }
        loaded = true
    }

    private func more() async {
        guard let page = try? await ModerationService.log(offset: entries.count) else { return }
        entries += page
    }
}

/// A read-only settings row (title, value, icon) in the studio card style.
private struct ModerationFactRow: View {
    @Environment(\.studioPalette) private var palette
    let title: String
    let value: String
    let icon: String

    init(_ title: String, value: String, icon: String) {
        self.title = title
        self.value = value
        self.icon = icon
    }

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(palette.accent)
                .frame(width: 32, height: 32)
                .background(palette.accent.opacity(0.09), in: RoundedRectangle(cornerRadius: 9))
                .accessibilityHidden(true)
            Text(title).font(.subheadline.weight(.semibold))
            Spacer(minLength: 8)
            Text(value).font(.subheadline.monospaced()).foregroundStyle(palette.muted)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 10)
        .frame(minHeight: 54)
        .accessibilityElement(children: .combine)
    }
}
