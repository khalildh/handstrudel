import SwiftUI
import UIKit
import UniformTypeIdentifiers

// MARK: - Feed chip

/// The instrument a take was played on, under the caption: name, "Made with AI" and credit.
struct PostInstrumentChip: View {
    @Environment(\.studioPalette) private var palette
    let video: Video
    let summary: PostInstrumentSummary
    var onMedia = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "circle.circle")
                Text(summary.name).lineLimit(1)
                if summary.aiGenerated {
                    Text("AI").font(.caption2.weight(.heavy))
                        .padding(.horizontal, 4).padding(.vertical, 1)
                        .overlay { Capsule().strokeBorder(.white.opacity(0.5)) }
                }
                if let credit = summary.credit(poster: video.username) {
                    Text(credit).lineLimit(1).opacity(0.75)
                }
                Image(systemName: "chevron.up").font(.system(size: 9, weight: .bold))
            }
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .foregroundStyle(onMedia ? palette.mediaAccent : palette.ink)
            .background(onMedia ? AnyShapeStyle(.black.opacity(0.66)) : AnyShapeStyle(palette.surface), in: Capsule())
            .overlay { Capsule().strokeBorder(.white.opacity(0.18)) }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Instrument: \(summary.name)\(summary.aiGenerated ? ", made with AI" : "")")
        .accessibilityValue(summary.credit(poster: video.username) ?? "")
        .accessibilityIdentifier("post-instrument-chip")
    }
}

// MARK: - Instrument sheet

/// Play, keep or remix the instrument a post was played on. Every action loads the file from the
/// post and validates it with the loader first.
struct PostInstrumentSheet: View {
    @Environment(\.studioPalette) private var palette
    @Environment(\.isSoundLocked) private var isSoundLocked
    @Environment(\.dismiss) private var dismiss
    let video: Video
    let summary: PostInstrumentSummary
    @ObservedObject private var store = MyInstrumentsStore.shared
    @State private var chain: [InstrumentChainLink] = []
    @State private var working = false
    @State private var message: String?
    @State private var failure: String?
    @State private var remixing: MyInstrument?

    /// Whoever made the version on this post.
    private var maker: String? { summary.kind == .copy ? summary.sourceUsername : video.username }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    if chain.count > 1 { chainList }
                    actions
                    if let message {
                        Label(message, systemImage: "checkmark.circle").font(.footnote).foregroundStyle(palette.muted)
                            .accessibilityIdentifier("post-instrument-message")
                    }
                    if let failure {
                        Text(failure).font(.footnote).foregroundStyle(.red).accessibilityIdentifier("post-instrument-error")
                    }
                }
                .frame(maxWidth: 480, alignment: .leading)
                .padding(22)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .background(palette.background.ignoresSafeArea())
            .navigationTitle("Instrument")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .sheet(item: $remixing) { item in
                InstrumentEditorView(itemID: item.id, title: "Remix")
            }
        }
        .tint(palette.accent)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .task(id: video.id) {
            chain = (try? await FeedService.instrumentChain(for: video.id)) ?? []
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(summary.name, systemImage: "circle.circle")
                .font(.title2.weight(.semibold)).foregroundStyle(palette.ink)
                .accessibilityIdentifier("post-instrument-name")
            if summary.aiGenerated {
                Label("Made with AI", systemImage: "sparkles").font(.caption.weight(.semibold))
                    .foregroundStyle(palette.accent).accessibilityIdentifier("post-instrument-ai")
            }
            if let credit = summary.credit(poster: video.username) {
                Text(credit).font(.subheadline).foregroundStyle(palette.ink)
                    .accessibilityIdentifier("post-instrument-credit")
            }
            if let line = summary.remixLine { Text(line).font(.subheadline).foregroundStyle(palette.muted) }
            if let line = summary.remixCountLine {
                Label(line, systemImage: "arrow.triangle.branch").font(.subheadline).foregroundStyle(palette.muted)
                    .accessibilityIdentifier("post-instrument-remix-count")
            }
            Text("The instrument is the layout you play. Its sound comes from your own settings unless you play it exactly.")
                .font(.footnote).foregroundStyle(palette.muted)
        }
    }

    private var chainList: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Remix chain").font(.caption.weight(.semibold)).foregroundStyle(palette.muted)
            ForEach(chain) { link in
                HStack(spacing: 6) {
                    Image(systemName: link.depth == chain.count - 1 ? "star" : "arrow.turn.left.up")
                        .foregroundStyle(palette.muted)
                    Text("@\(link.username ?? "creator")").font(.subheadline.weight(.semibold))
                    Text(link.instrumentName ?? "").font(.subheadline).foregroundStyle(palette.muted).lineLimit(1)
                    if link.depth == chain.count - 1 && link.kind == .own {
                        Text("Original").font(.caption2.weight(.bold)).foregroundStyle(palette.accent)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("post-instrument-chain-link")
            }
        }
    }

    @ViewBuilder private var actions: some View {
        Button("Play this instrument", systemImage: "play.fill") { play(exactly: false) }
            .buttonStyle(ProfileActionStyle(primary: true))
            .accessibilityHint("Plays this layout with your own sound")
            .accessibilityIdentifier("play-post-instrument")
            .disabled(working)
        if let setup = video.soundSetup {
            Button(isSoundLocked(setup) ? "Unlock & play this exactly" : "Play this exactly",
                   systemImage: isSoundLocked(setup) ? "lock.open.fill" : "play.square.stack") { play(exactly: true) }
                .buttonStyle(ProfileActionStyle())
                .accessibilityHint("Plays this instrument with this post's sound")
                .accessibilityIdentifier("play-post-instrument-exactly")
                .disabled(working)
        }
        Button(store.hasSaved(post: video.id) ? "Saved to My instruments" : "Save to My instruments",
               systemImage: store.hasSaved(post: video.id) ? "checkmark" : "tray.and.arrow.down") { save() }
            .buttonStyle(ProfileActionStyle())
            .accessibilityIdentifier("save-post-instrument")
            .disabled(working || !summary.remixesAllowed || store.hasSaved(post: video.id))
        Button("Remix", systemImage: "slider.horizontal.3") { remix() }
            .buttonStyle(ProfileActionStyle())
            .accessibilityHint("Opens an editable copy credited to this post")
            .accessibilityIdentifier("remix-post-instrument")
            .disabled(working || !summary.remixesAllowed)
        if !summary.remixesAllowed {
            Text("The creator turned off saving and remixing. You can still play it.")
                .font(.footnote).foregroundStyle(palette.muted)
                .accessibilityIdentifier("post-instrument-remixes-off")
        }
    }

    private func load(_ use: @escaping (InstrumentDocument) throws -> Void) {
        working = true
        failure = nil
        Task {
            defer { working = false }
            do { try use(try await FeedService.instrument(for: video.id)) }
            catch { failure = error.localizedDescription }
        }
    }

    private func play(exactly: Bool) {
        load { document in
            let request = PlayInstrumentRequest(document: document, sourceVideoID: video.id,
                                                sound: exactly ? video.soundSetup : nil)
            // The Music tab closes every sheet, this one included, before it opens the wheel.
            request.send()
        }
    }

    private func save() {
        load { document in
            try store.save(document, fromPost: video.id, by: maker)
            message = "Saved to My instruments"
            Task { await store.sync() }
        }
    }

    private func remix() {
        load { document in
            remixing = try store.remix(document, fromPost: video.id, by: maker)
            Task { await store.sync() }
        }
    }
}

// MARK: - My instruments

/// Saved, created, remixed and imported instruments, synced to the account. Each one can be
/// played, edited (copies you own), exported as a `.handstrudel-instrument` file or deleted.
struct MyInstrumentsView: View {
    @Environment(\.studioPalette) private var palette
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = MyInstrumentsStore.shared
    var notice: String? = nil
    @State private var editing: MyInstrument?
    @State private var importing = false
    @State private var exported: ExportedInstrument?
    @State private var failure: String?
    @State private var confirmDelete: MyInstrument?

    struct ExportedInstrument: Identifiable {
        let url: URL
        var id: URL { url }
    }

    var body: some View {
        NavigationStack {
            List {
                if let notice {
                    Label(notice, systemImage: "checkmark.circle").foregroundStyle(palette.muted)
                        .accessibilityIdentifier("my-instruments-notice")
                }
                if store.items.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("No instruments yet").font(.headline)
                        Text("Save an instrument from a post, remix one, or import a .\(InstrumentDocument.fileExtension) file.")
                            .font(.subheadline).foregroundStyle(palette.muted)
                    }
                    .accessibilityIdentifier("my-instruments-empty")
                }
                ForEach(store.items) { item in row(item) }
                if let failure {
                    Text(failure).font(.footnote).foregroundStyle(.red).accessibilityIdentifier("my-instruments-error")
                }
                if let error = store.syncError { Text(error).font(.footnote).foregroundStyle(palette.muted) }
            }
            .navigationTitle("My instruments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    Button("Import", systemImage: "square.and.arrow.down") { importing = true }
                        .accessibilityIdentifier("import-instrument")
                }
            }
            .refreshable { await store.sync() }
            .task { await store.sync() }
            .fileImporter(isPresented: $importing, allowedContentTypes: [InstrumentDocument.fileType, .json]) { result in
                do { _ = try store.importFile(at: try result.get()); Task { await store.sync() } }
                catch { failure = error.localizedDescription }
            }
            .sheet(item: $editing) { item in InstrumentEditorView(itemID: item.id, title: "Edit instrument") }
            .sheet(item: $exported) { file in ShareSheet(activityItems: [file.url]).ignoresSafeArea() }
            .confirmationDialog("Delete this instrument?", isPresented: Binding(get: { confirmDelete != nil },
                                                                                 set: { if !$0 { confirmDelete = nil } }),
                                titleVisibility: .visible, presenting: confirmDelete) { item in
                Button("Delete \(item.name)", role: .destructive) {
                    store.delete(item.id)
                    Task { await store.sync() }
                }
            }
        }
        .tint(palette.accent)
    }

    private func row(_ item: MyInstrument) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(item.name).font(.headline).lineLimit(1)
                    if item.document.isAIGenerated {
                        Label("Made with AI", systemImage: "sparkles").labelStyle(.iconOnly)
                            .foregroundStyle(palette.accent).accessibilityLabel("Made with AI")
                    }
                }
                Text(item.origin).font(.caption).foregroundStyle(palette.muted)
                if store.isDeviceOnly(item.id) && store.accountID != nil {
                    Text("On this device only").font(.caption2).foregroundStyle(palette.muted)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("my-instrument")
            Spacer()
            Button { play(item) } label: { Image(systemName: "play.fill").frame(width: 44, height: 44) }
                .buttonStyle(.borderless)
                .accessibilityLabel("Play \(item.name)")
                .accessibilityIdentifier("play-my-instrument")
            Menu {
                if item.isEditable {
                    Button("Edit", systemImage: "slider.horizontal.3") { editing = item }
                }
                Button("Export file", systemImage: "square.and.arrow.up") { export(item) }
                    .accessibilityIdentifier("export-my-instrument")
                Button("Delete", systemImage: "trash", role: .destructive) { confirmDelete = item }
            } label: {
                Image(systemName: "ellipsis.circle").frame(width: 44, height: 44)
            }
            .accessibilityLabel("More for \(item.name)")
            .accessibilityIdentifier("my-instrument-menu")
        }
    }

    private func play(_ item: MyInstrument) {
        let request = PlayInstrumentRequest(document: item.document, sourceVideoID: item.sourceVideoID, sound: nil)
        request.send()
    }

    private func export(_ item: MyInstrument) {
        do {
            let url = try item.document.exportFile()
            #if DEBUG
            // UI tests read the exported file back from the host.
            if let directory = ProcessInfo.processInfo.environment["HANDSTRUDEL_TEST_EXPORT_DIR"] {
                let copy = URL(fileURLWithPath: directory).appendingPathComponent(url.lastPathComponent)
                try? FileManager.default.removeItem(at: copy)
                try? FileManager.default.copyItem(at: url, to: copy)
            }
            #endif
            exported = ExportedInstrument(url: url)
        } catch {
            failure = error.localizedDescription
        }
    }
}

// MARK: - Editing a copy

/// Edit a remix or other instrument you own. Only the structure changes; the sound stays
/// whatever the player has chosen. The result is validated like any received file.
struct InstrumentEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = MyInstrumentsStore.shared
    let itemID: UUID
    let title: String
    @State private var name = ""
    @State private var chordsOnRight = false
    @State private var octaveBand = true
    @State private var radius = 1.0
    @State private var restRadius = 0.36
    @State private var loaded = false
    @State private var failure: String?

    private var item: MyInstrument? { store.item(id: itemID) }

    var body: some View {
        NavigationStack {
            Form {
                if let item {
                    Section {
                        TextField("Name", text: $name)
                            .accessibilityIdentifier("instrument-editor-name")
                        if let source = item.sourceUsername, item.kind == .remixed {
                            Text("Remix of @\(source)'s instrument").font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    Section("Layout") {
                        Picker("Chords on", selection: $chordsOnRight) {
                            Text("Left").tag(false)
                            Text("Right").tag(true)
                        }
                        Toggle("Octave rim on notes", isOn: $octaveBand)
                        LabeledContent("Wheel size") {
                            Slider(value: $radius, in: InstrumentSpec.SplitWheel.radiusRange)
                        }
                        LabeledContent("Rest hole") {
                            Slider(value: $restRadius, in: InstrumentSpec.SplitWheel.restRadiusRange)
                        }
                    }
                    if let failure { Text(failure).foregroundStyle(.red) }
                    Section {
                        Button("Play", systemImage: "play.fill") {
                            guard let document = apply() else { return }
                            let request = PlayInstrumentRequest(document: document, sourceVideoID: item.sourceVideoID, sound: nil)
                            request.send()
                        }
                        .accessibilityIdentifier("play-edited-instrument")
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { if apply() != nil { dismiss() } }
                        .accessibilityIdentifier("save-edited-instrument")
                }
            }
            .onAppear(perform: fill)
        }
    }

    private func fill() {
        guard !loaded, let spec = item?.document.spec else { return }
        loaded = true
        name = spec.name
        chordsOnRight = spec.chords.side == .right
        octaveBand = spec.notes.octaveBand
        radius = spec.surface.radius
        restRadius = spec.surface.restRadius
    }

    /// Save the edits; returns the saved file.
    @discardableResult
    private func apply() -> InstrumentDocument? {
        guard let item else { return nil }
        do {
            let round = { (value: Double) in InstrumentJSON.double((value * 100).rounded() / 100) }
            let document = try item.document
                .setting(["name"], to: .string(name))
                .setting(["chords", "side"], to: .string(chordsOnRight ? "right" : "left"))
                .setting(["notes", "octave_band"], to: .bool(octaveBand))
                .setting(["surface", "radius"], to: round(radius))
                .setting(["surface", "rest_radius"], to: round(restRadius))
            store.update(item.id, document: document)
            Task { await store.sync() }
            return document
        } catch {
            failure = error.localizedDescription
            return nil
        }
    }
}

// MARK: - On stage

/// Which instrument file the wheel is playing, with its credit, shown on the stage.
struct StageInstrumentChip: View {
    @ObservedObject var engine: EngineController

    var body: some View {
        if let instrument = engine.customInstrument {
            Label(instrument.name, systemImage: "circle.circle")
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .foregroundStyle(.white)
                .background(.black.opacity(0.5), in: Capsule())
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Instrument: \(instrument.name)")
                .accessibilityValue("Sound: \(engine.selectedSoundFontInstrument.name)")
                .accessibilityIdentifier("stage-instrument")
        }
    }
}

/// Close every sheet the app is showing, then run `action` (used before opening the Music tab
/// from a post's instrument, whichever screen it was tapped on).
@MainActor
func dismissAllSheets(then action: @escaping () -> Void) {
    let root = UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.keyWindow?.rootViewController }.first
    guard let root, root.presentedViewController != nil else { action(); return }
    var done = false
    let finish = {
        guard !done else { return }
        done = true
        action()
    }
    root.dismiss(animated: true) { DispatchQueue.main.async(execute: finish) }
    // UIKit skips the completion when a sheet was already dismissing itself.
    DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: finish)
}
