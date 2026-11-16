import AVKit
import Photos
import SwiftUI

struct RecordingDraft: Codable, Identifiable, Equatable {
    static let titleLimit = 60

    let id: UUID
    let createdAt: Date
    let instrument: String?
    let mode: String?
    var soundSetup: SoundSetup? = nil
    var backingCredit: BackingCredit? = nil
    var recordedAtHalfSpeed: Bool? = nil
    var trimStart: Double?
    var trimEnd: Double?
    var title: String? = nil
    var postSubmissions: [UUID: DraftPostSubmission]? = nil

    var displayTitle: String { title ?? instrument ?? "Performance" }
    var outputScale: Double { recordedAtHalfSpeed == true ? 0.5 : 1 }

    static func normalizedTitle(_ input: String) -> String? {
        let singleLine = input.split { character in
            character.isWhitespace || character.unicodeScalars.allSatisfy { $0.properties.generalCategory == .control }
        }.joined(separator: " ")
        let title = String(singleLine.prefix(titleLimit)).trimmingCharacters(in: .whitespaces)
        return title.isEmpty ? nil : title
    }
}

struct DraftTrimSelection: Equatable {
    enum Edge { case start, end }

    let duration: Double
    let start: Double
    let end: Double

    var minimumLength: Double { min(0.25, duration) }
    var isFullLength: Bool { start == 0 && end == duration }

    init?(duration: Double, start: Double? = nil, end: Double? = nil) {
        let first = start ?? 0
        let last = end ?? duration
        guard duration.isFinite, first.isFinite, last.isFinite,
              first >= 0, first < last, last <= duration else { return nil }
        self.duration = duration
        self.start = first
        self.end = last
    }

    func moving(_ edge: Edge, to capturedTime: Double) -> Self {
        guard capturedTime.isFinite else { return self }
        switch edge {
        case .start:
            return Self(duration: duration, start: min(max(0, end - minimumLength), max(0, capturedTime)), end: end) ?? self
        case .end:
            return Self(duration: duration, start: start, end: max(min(duration, start + minimumLength), min(duration, capturedTime))) ?? self
        }
    }

    var range: CMTimeRange {
        CMTimeRange(start: CMTime(seconds: start, preferredTimescale: 600),
                    end: CMTime(seconds: end, preferredTimescale: 600))
    }
}

@MainActor
final class RecordingDrafts: ObservableObject {
    static let recordingLimit = 60
    @Published private(set) var drafts: [RecordingDraft] = []
    @Published private(set) var loadError: String?
    private let directory: URL
    private let files = FileManager.default

    init(directory: URL = URL.applicationSupportDirectory.appending(path: "PerformanceDrafts", directoryHint: .isDirectory)) {
        self.directory = directory
        do {
            try prepareDirectory()
            drafts = try files.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
                .compactMap { folder in
                    guard let id = UUID(uuidString: folder.lastPathComponent),
                          files.fileExists(atPath: videoURL(for: id).path) else { return nil }
                    if let data = try? Data(contentsOf: metadataURL(for: id)),
                       let draft = try? JSONDecoder().decode(RecordingDraft.self, from: data), draft.id == id {
                        return draft
                    }
                    let date = (try? files.attributesOfItem(atPath: videoURL(for: id).path)[.creationDate] as? Date) ?? Date()
                    return RecordingDraft(id: id, createdAt: date, instrument: nil, mode: nil)
                }
                .sorted { $0.createdAt > $1.createdAt }
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func prepareDirectory() throws {
        try files.createDirectory(at: directory, withIntermediateDirectories: true)
        var localDirectory = directory
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try localDirectory.setResourceValues(values)
    }

    // Create metadata before capture, so a completed file is discoverable after an app restart.
    func begin(instrument: String?, mode: String?, soundSetup: SoundSetup? = nil,
               backingCredit: BackingCredit? = nil, halfSpeed: Bool = false) throws -> RecordingDraft {
        try prepareDirectory()
        let draft = RecordingDraft(id: UUID(), createdAt: Date(), instrument: instrument, mode: mode,
                                   soundSetup: soundSetup, backingCredit: backingCredit,
                                   recordedAtHalfSpeed: halfSpeed ? true : nil)
        try files.createDirectory(at: folder(for: draft.id), withIntermediateDirectories: false)
        do {
            try writeMetadata(draft)
        } catch {
            discardUnfinished(draft)
            throw error
        }
        return draft
    }

    func complete(_ draft: RecordingDraft) throws {
        let url = videoURL(for: draft.id)
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size > 0 else { throw DraftError.unreadable }
        if !drafts.contains(where: { $0.id == draft.id }) { drafts.insert(draft, at: 0) }
    }

    @discardableResult
    func saveTrim(_ draft: RecordingDraft) throws -> RecordingDraft {
        try updateDraft(draft.id) {
            $0.trimStart = draft.trimStart
            $0.trimEnd = draft.trimEnd
        }
    }

    func rename(_ id: UUID, to title: String) throws -> RecordingDraft {
        try updateDraft(id) { $0.title = RecordingDraft.normalizedTitle(title) }
    }

    func postSubmission(for draftID: UUID, accountID: UUID) -> DraftPostSubmission? {
        drafts.first { $0.id == draftID }?.postSubmissions?[accountID]
    }

    @discardableResult
    func replacePostSubmission(_ previous: DraftPostSubmission?, with next: DraftPostSubmission?,
                               draftID: UUID, accountID: UUID) throws -> Bool {
        guard postSubmission(for: draftID, accountID: accountID) == previous else { return false }
        try updateDraft(draftID) {
            var submissions = $0.postSubmissions ?? [:]
            submissions[accountID] = next
            $0.postSubmissions = submissions.isEmpty ? nil : submissions
        }
        return true
    }

    private func updateDraft(_ id: UUID, _ update: (inout RecordingDraft) -> Void) throws -> RecordingDraft {
        guard let index = drafts.firstIndex(where: { $0.id == id }) else { throw DraftError.missingDraft }
        var updated = drafts[index]
        update(&updated)
        try writeMetadata(updated)
        drafts[index] = updated
        return updated
    }

    func delete(_ draft: RecordingDraft) throws {
        try files.removeItem(at: folder(for: draft.id))
        drafts.removeAll { $0.id == draft.id }
    }

    func discardUnfinished(_ draft: RecordingDraft) {
        try? files.removeItem(at: folder(for: draft.id))
    }

    func videoURL(for id: UUID) -> URL {
        folder(for: id).appending(path: "take.mp4")
    }

    private func folder(for id: UUID) -> URL {
        directory.appending(path: id.uuidString, directoryHint: .isDirectory)
    }

    private func metadataURL(for id: UUID) -> URL {
        folder(for: id).appending(path: "draft.json")
    }

    private func writeMetadata(_ draft: RecordingDraft) throws {
        try JSONEncoder().encode(draft).write(to: metadataURL(for: draft.id), options: .atomic)
    }

    func makeExport(for draft: RecordingDraft, audioOnly: Bool = false) async throws -> RecordingDraftExport {
        let source = videoURL(for: draft.id)
        let asset = AVURLAsset(url: source)
        let duration = try await asset.load(.duration).seconds
        guard let trim = DraftTrimSelection(duration: duration, start: draft.trimStart, end: draft.trimEnd)
        else { throw DraftError.invalidTrim }
        if audioOnly, try await asset.loadTracks(withMediaType: .audio).isEmpty {
            throw DraftError.noAudio
        }
        return try await RecordingDraftExport.prepare(audioOnly: audioOnly) { output in
            if !audioOnly, draft.outputScale == 1, trim.isFullLength {
                try files.copyItem(at: source, to: output)
                return
            }
            let range = trim.range
            guard range.duration > .zero else { throw DraftError.invalidTrim }
            let exportAsset: AVAsset
            if draft.outputScale < 1 {
                exportAsset = try await Self.scaledAsset(asset, range: range, scale: draft.outputScale)
            } else {
                exportAsset = asset
            }
            let preset = audioOnly ? AVAssetExportPresetAppleM4A : AVAssetExportPresetHighestQuality
            guard let exporter = AVAssetExportSession(asset: exportAsset, presetName: preset) else { throw DraftError.unreadable }
            exporter.outputURL = output
            exporter.outputFileType = audioOnly ? .m4a : .mp4
            if draft.outputScale == 1 { exporter.timeRange = range }
            else { exporter.audioTimePitchAlgorithm = .spectral }
            try Task.checkCancellation()
            await exporter.export()
            guard exporter.status == .completed else { throw exporter.error ?? DraftError.unreadable }
        }
    }

    static func scaledAsset(_ asset: AVAsset, range: CMTimeRange, scale: Double) async throws -> AVComposition {
        let composition = AVMutableComposition()
        for type in [AVMediaType.video, .audio] {
            for track in try await asset.loadTracks(withMediaType: type) {
                let available = try await track.load(.timeRange)
                let selection = available.intersection(range)
                guard selection.isValid, !selection.isEmpty else { continue }
                guard let output = composition.addMutableTrack(withMediaType: type, preferredTrackID: kCMPersistentTrackID_Invalid)
                else { throw DraftError.unreadable }
                try output.insertTimeRange(selection, of: track, at: selection.start - range.start)
                if type == .video { output.preferredTransform = try await track.load(.preferredTransform) }
            }
        }
        guard composition.duration > .zero else { throw DraftError.unreadable }
        let outputRange = CMTimeRange(start: .zero, duration: composition.duration)
        composition.scaleTimeRange(outputRange,
                                   toDuration: CMTimeMultiplyByFloat64(composition.duration, multiplier: scale))
        return composition
    }
}

// Owns only a temporary copy, never the draft's source file.
final class RecordingDraftExport: Identifiable {
    let url: URL
    var id: URL { url }

    private init(url: URL) { self.url = url }

    @MainActor
    static func prepare(in directory: URL = FileManager.default.temporaryDirectory, audioOnly: Bool,
                        write: @MainActor (URL) async throws -> Void) async throws -> RecordingDraftExport {
        try Task.checkCancellation()
        let suffix = audioOnly ? "m4a" : "mp4"
        let export = RecordingDraftExport(url: directory.appending(path: "HandStrudel-\(UUID()).\(suffix)"))
        try await write(export.url)
        // A writer may finish even after the editor goes away.
        try Task.checkCancellation()
        return export
    }

    func remove() { try? FileManager.default.removeItem(at: url) }

    deinit { remove() }
}

private enum DraftError: LocalizedError {
    case unreadable, invalidTrim, photosDenied, noAudio, missingDraft

    var errorDescription: String? {
        switch self {
        case .unreadable: return "This video could not be read or exported."
        case .invalidTrim: return "This trim no longer fits the video. Reset it or choose a new range before exporting."
        case .noAudio: return "This take doesn't have an audio track to export."
        case .photosDenied: return "Allow HandStrudel to add photos in Settings, or use Share to save the video to Files."
        case .missingDraft: return "This draft is no longer in Private drafts."
        }
    }
}

struct RecordingDraftsView: View {
    @Environment(\.studioPalette) private var palette
    @ObservedObject var store: RecordingDrafts
    @ObservedObject var auth: AuthManager
    let openedDraft: RecordingDraft?
    let onRetake: (() -> Void)?
    var onSuccessfulTake: (UUID) -> Void = { _ in }
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if let openedDraft {
                    editor(openedDraft)
                } else if store.drafts.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "film.stack").font(.largeTitle).foregroundStyle(palette.accent)
                        Text(store.loadError == nil ? "No drafts yet" : "Drafts couldn’t load").font(.headline)
                        Text(store.loadError ?? "Your recordings stay here until you delete them.")
                            .foregroundStyle(.secondary)
                    }
                    .multilineTextAlignment(.center)
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(store.drafts) { draft in
                        NavigationLink {
                            editor(draft)
                        } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(draft.displayTitle).font(.headline).lineLimit(2)
                                if draft.title != nil, let instrument = draft.instrument {
                                    Text(instrument).font(.subheadline).foregroundStyle(.secondary)
                                }
                                Text(draft.createdAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle(openedDraft == nil ? "Private drafts" : "Review take")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .background(palette.background)
        }
        .tint(palette.accent)
    }

    private func editor(_ draft: RecordingDraft) -> some View {
        RecordingDraftEditor(store: store, auth: auth, draft: draft, onRetake: onRetake, onSuccessfulTake: onSuccessfulTake)
    }
}

private struct RecordingDraftEditor: View {
    @Environment(\.studioPalette) private var palette
    @ObservedObject var store: RecordingDrafts
    @ObservedObject var auth: AuthManager
    @State var draft: RecordingDraft
    let onRetake: (() -> Void)?
    let onSuccessfulTake: (UUID) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?
    @State private var duration = 0.0
    @State private var frames: [Int: CGImage] = [:]
    @State private var pendingTrim: DraftTrimSelection?
    @State private var scrubPosition: Double?
    @State private var previewVersion = 0
    @State private var fineTrimExpanded = false
    @State private var exportTask: Task<Void, Never>?
    @State private var message: String?
    @State private var showNameEditor = false
    @State private var confirmDelete = false
    @State private var sharing: RecordingDraftExport?
    @State private var posting: RecordingDraftExport?
    @State private var pendingPost: RecordingDraftExport?
    @State private var signIn = false
    @StateObject private var postStatus = VideoUploader()
    private var busy: Bool { exportTask != nil }

    private var postSubmission: DraftPostSubmission? {
        auth.userId.flatMap { store.postSubmission(for: draft.id, accountID: $0) }
    }

    private var savedTrim: DraftTrimSelection? {
        DraftTrimSelection(duration: duration, start: draft.trimStart, end: draft.trimEnd)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 17) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(draft.displayTitle)
                        .font(.title2.weight(.semibold))
                        .accessibilityAddTraits(.isHeader)
                    Button {
                        player?.pause()
                        showNameEditor = true
                    } label: {
                        Label(draft.title == nil ? "Name private draft" : "Rename private draft", systemImage: "pencil")
                            .font(.subheadline.weight(.semibold))
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityIdentifier("rename-private-draft")
                    .disabled(busy)
                }
                VideoPlayer(player: player)
                    .frame(height: 330)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                if draft.recordedAtHalfSpeed == true {
                    Label("Recorded at half tempo. Preview and exports play at normal tempo.", systemImage: "tortoise")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                if let trim = pendingTrim ?? savedTrim ?? DraftTrimSelection(duration: duration) { trimControls(trim) }
                if let message {
                    Text(message).font(.footnote).foregroundStyle(.secondary)
                        .accessibilityIdentifier("draft-message")
                }
                if busy { ProgressView("Preparing video") }
                Button { export(saveToPhotos) } label: {
                    Label("Save to Photos", systemImage: "photo.badge.plus")
                }
                .buttonStyle(StudioActionStyle())
                .disabled(savedTrim == nil || pendingTrim != nil)
                HStack(spacing: 18) {
                    Menu("Share") {
                        Button("Share video", systemImage: "film") { export { sharing = $0 } }
                        Button("Share audio (M4A)", systemImage: "waveform") { export(audioOnly: true) { sharing = $0 } }
                    }
                    .disabled(savedTrim == nil || pendingTrim != nil)
                    if SocialConfig.isConfigured {
                        postAction
                    }
                    Spacer()
                    if let onRetake { Button("Retake", action: onRetake) }
                }
                Button("Delete draft", role: .destructive) { confirmDelete = true }
                    .padding(.top, 6)
            }
            .padding(20)
            .disabled(busy)
        }
        .background(palette.background)
        .task(id: auth.userId) { await refreshPostStatus(waitForResult: false) }
        .task {
            let url = store.videoURL(for: draft.id)
            do {
                let asset = AVURLAsset(url: url)
                let mediaDuration = try await asset.load(.duration)
                let seconds = mediaDuration.seconds
                guard seconds.isFinite, seconds > 0 else { throw DraftError.unreadable }
                let item: AVPlayerItem
                if draft.outputScale < 1 {
                    let composition = try await RecordingDrafts.scaledAsset(
                        asset, range: CMTimeRange(start: .zero, duration: mediaDuration), scale: draft.outputScale)
                    item = AVPlayerItem(asset: composition)
                    item.audioTimePitchAlgorithm = .spectral
                } else {
                    item = AVPlayerItem(asset: asset)
                }
                guard !Task.isCancelled else { return }
                player = AVPlayer(playerItem: item)
                duration = seconds
                if let savedTrim { seek(to: savedTrim.start) }
                else { message = DraftError.invalidTrim.localizedDescription; seek(to: 0) }
                await loadFilmstrip(for: asset, duration: seconds)
            } catch { message = error.localizedDescription }
        }
        .onDisappear {
            previewVersion += 1
            player?.currentItem?.cancelPendingSeeks()
            player?.pause()
            exportTask?.cancel()
        }
        .interactiveDismissDisabled(busy)
        .sheet(isPresented: $showNameEditor) {
            PrivateDraftNameEditor(name: draft.title ?? "") { name in
                draft = try store.rename(draft.id, to: name)
            }
        }
        .sheet(item: $sharing) { copy in
            ShareSheet(activityItems: [copy.url])
                .onDisappear(perform: copy.remove)
        }
        .sheet(item: $posting) { copy in
            PostComposerView(clip: copy.url, draftID: draft.id, drafts: store,
                             instrument: draft.instrument, mode: draft.mode, soundSetup: draft.soundSetup,
                             backingCredit: draft.backingCredit, auth: auth, onLeaveWhileChecking: {
                message = "Submitted for checking. Your original is still in Private drafts."
            }) {
                message = "Posted. The original is still in Private drafts."
                onSuccessfulTake(draft.id)
            }
            .onDisappear(perform: copy.remove)
        }
        .sheet(isPresented: $signIn, onDismiss: {
            guard let copy = pendingPost else { return }
            pendingPost = nil
            if auth.isSignedIn && !auth.needsProfileSetup { posting = copy }
        }) { SignInView(auth: auth) }
        .confirmationDialog("Delete this private draft?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete draft", role: .destructive) {
                do { try store.delete(draft); dismiss() }
                catch { message = error.localizedDescription }
            }
        } message: {
            Text("Copies you’ve already saved or shared will stay where you put them.")
        }
    }

    @ViewBuilder private var postAction: some View {
        switch postSubmission {
        case .pending:
            Button(postStatus.isBusy ? "Checking post…" : "Check post status") {
                Task { await refreshPostStatus(waitForResult: true) }
            }
            .disabled(postStatus.isBusy)
        case .published(let id):
            let url = SocialConfig.watchURL.appending(queryItems: [URLQueryItem(name: "v", value: id.uuidString.lowercased())])
            Link("View post", destination: url)
        case nil:
            Button("Post") {
                export { copy in
                    if auth.isSignedIn && !auth.needsProfileSetup { posting = copy }
                    else { pendingPost = copy; signIn = true }
                }
            }
            .disabled(savedTrim == nil || pendingTrim != nil)
        }
    }

    private func refreshPostStatus(waitForResult: Bool) async {
        guard let accountID = auth.userId, postSubmission?.isPending == true, !postStatus.isBusy else { return }
        let posted = await postStatus.resume(draftID: draft.id, accountID: accountID, store: store, waitForResult: waitForResult)
        guard !Task.isCancelled, auth.userId == accountID else { return }
        if posted {
            message = "Posted. The original is still in Private drafts."
            onSuccessfulTake(draft.id)
        } else {
            switch postStatus.phase {
            case .failed(let detail): message = detail
            case .pending(let detail) where postSubmission?.isPending == true: message = detail
            default: break
            }
        }
    }

    private func trimControls(_ trim: DraftTrimSelection) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Trim").font(.headline)
                Spacer()
                Button("Reset") {
                    if let full = DraftTrimSelection(duration: duration) { editTrim(full, seekTo: 0, commit: true) }
                }
                .disabled(trim.isFullLength && savedTrim != nil)
                .accessibilityIdentifier("draft-trim-reset")
            }
            Text("Drag the handles to trim. Tap a frame to preview it.")
                .font(.caption).foregroundStyle(palette.muted)
            DraftTrimFilmstrip(trim: trim, frames: frames, scrubPosition: scrubPosition, outputScale: draft.outputScale,
                               onScrub: { if !busy { seek(to: $0) } }, onEdit: editTrim)
            HStack(alignment: .firstTextBaseline) {
                Text("\(timeLabel(trim.start)) to \(timeLabel(trim.end))")
                    .foregroundStyle(palette.muted)
                    .accessibilityIdentifier("draft-trim-range")
                Spacer()
                Text("\(timeLabel(trim.end - trim.start)) selected")
                    .fontWeight(.semibold)
            }
            .font(.caption.monospacedDigit())
            Button("Play selection", systemImage: "play.fill") { playSelection(trim) }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("draft-play-selection")
            DisclosureGroup("Fine trim", isExpanded: $fineTrimExpanded) {
                VStack(spacing: 5) {
                    trimNudges(trim, edge: .start)
                    trimNudges(trim, edge: .end)
                }
                .padding(.top, 6)
            }
            .font(.subheadline)
            .accessibilityIdentifier("draft-fine-trim")
        }
    }

    private func trimNudges(_ trim: DraftTrimSelection, edge: DraftTrimSelection.Edge) -> some View {
        let name = edge == .start ? "Start" : "End"
        let position = edge == .start ? trim.start : trim.end
        let step = 0.1 / draft.outputScale
        return HStack {
            Text(name).font(.subheadline.weight(.semibold))
            Spacer()
            ForEach([-1, 1], id: \.self) { direction in
                let next = trim.moving(edge, to: position + Double(direction) * step)
                Button {
                    editTrim(next, seekTo: edge == .start ? next.start : next.end, commit: true)
                } label: {
                    Image(systemName: direction < 0 ? "minus" : "plus").frame(minWidth: 28, minHeight: 32)
                }
                .buttonStyle(.bordered)
                .disabled(next == trim)
                .accessibilityLabel("\(name) 0.1 seconds \(direction < 0 ? "earlier" : "later")")
            }
        }
    }

    private func editTrim(_ trim: DraftTrimSelection, seekTo time: Double, commit: Bool) {
        guard !busy else { return }
        seek(to: time)
        if !commit { pendingTrim = trim; return }
        pendingTrim = nil
        var updated = draft
        updated.trimStart = trim.isFullLength ? nil : trim.start
        updated.trimEnd = trim.isFullLength ? nil : trim.end
        if updated == draft { return }
        do {
            draft = try store.saveTrim(updated)
            message = nil
        }
        catch { message = error.localizedDescription }
    }

    private func loadFilmstrip(for asset: AVAsset, duration: Double) async {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 152, height: 152)
        generator.requestedTimeToleranceBefore = CMTime(seconds: 0.1, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter = generator.requestedTimeToleranceBefore
        let count = DraftTrimFilmstrip.frameCount
        let times = (0..<count).map { CMTime(seconds: duration * (Double($0) + 0.5) / Double(count), preferredTimescale: 600) }
        for await result in generator.images(for: times) {
            guard !Task.isCancelled else { generator.cancelAllCGImageGeneration(); return }
            if case .success(let time, let image, _) = result, let index = times.firstIndex(of: time) {
                frames[index] = image
            }
        }
    }

    private func timeLabel(_ captured: Double) -> String {
        "\((captured * draft.outputScale).formatted(.number.precision(.fractionLength(2)))) s"
    }

    private func playSelection(_ trim: DraftTrimSelection) {
        guard let player else { return }
        seek(to: trim.start)
        let version = previewVersion
        player.currentItem?.forwardPlaybackEndTime = playbackTime(trim.end)
        player.seek(to: playbackTime(trim.start), toleranceBefore: .zero, toleranceAfter: .zero) { finished in
            if finished {
                Task { @MainActor in
                    guard version == previewVersion else { return }
                    player.play()
                }
            }
        }
    }

    private func playbackTime(_ captured: Double) -> CMTime {
        CMTime(seconds: captured * draft.outputScale, preferredTimescale: 600)
    }

    private func seek(to time: Double) {
        previewVersion += 1
        scrubPosition = time
        player?.pause()
        player?.currentItem?.cancelPendingSeeks()
        player?.currentItem?.forwardPlaybackEndTime = .invalid
        player?.seek(to: playbackTime(time), toleranceBefore: .zero, toleranceAfter: .zero)
    }

    private func export(audioOnly: Bool = false, _ use: @escaping @MainActor (RecordingDraftExport) async throws -> Void) {
        guard !busy, savedTrim != nil, pendingTrim == nil else { return }
        previewVersion += 1
        player?.currentItem?.cancelPendingSeeks()
        player?.pause()
        message = nil
        exportTask = Task {
            defer { exportTask = nil }
            do {
                try Task.checkCancellation()
                let copy = try await store.makeExport(for: draft, audioOnly: audioOnly)
                try Task.checkCancellation()
                try await use(copy)
            } catch {
                if !Task.isCancelled { message = error.localizedDescription }
            }
        }
    }

    private func saveToPhotos(_ copy: RecordingDraftExport) async throws {
        defer { copy.remove() }
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        try Task.checkCancellation()
        guard status == .authorized || status == .limited else { throw DraftError.photosDenied }
        let url = copy.url
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetCreationRequest.forAsset().addResource(with: .video, fileURL: url, options: nil)
        }
        try Task.checkCancellation()
        message = "Saved to Photos."
        onSuccessfulTake(draft.id)
    }
}

private struct DraftTrimFilmstrip: View {
    static let frameCount = 7
    private static let space = "draft-timeline"
    private static let gutter: CGFloat = 22
    private static let height: CGFloat = 65

    @Environment(\.studioPalette) private var palette
    let trim: DraftTrimSelection
    let frames: [Int: CGImage]
    let scrubPosition: Double?
    let outputScale: Double
    let onScrub: (Double) -> Void
    let onEdit: (DraftTrimSelection, Double, Bool) -> Void
    @State private var dragOrigin: DraftTrimSelection?

    var body: some View {
        GeometryReader { geometry in
            let gutter = min(Self.gutter, geometry.size.width / 4)
            let width = max(1, geometry.size.width - 2 * gutter)
            let startX = gutter + width * trim.start / trim.duration
            let endX = gutter + width * trim.end / trim.duration
            ZStack(alignment: .topLeading) {
                filmFrames(width: width)
                    .position(x: gutter + width / 2, y: Self.height / 2)
                    .accessibilityHidden(true)
                    .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.space))
                        .onChanged { value in onScrub(trim.duration * min(1, max(0, (value.location.x - gutter) / width))) })
                selectionOverlay(gutter: gutter, width: width, startX: startX, endX: endX)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                handle(.start, center: startX - 9, width: width)
                handle(.end, center: endX + 9, width: width)
            }
        }
        .coordinateSpace(name: Self.space)
        .frame(height: Self.height)
        .accessibilityIdentifier("draft-filmstrip")
    }

    private func filmFrames(width: CGFloat) -> some View {
        HStack(spacing: 0) {
            ForEach(0..<Self.frameCount, id: \.self) { index in
                Rectangle()
                    .fill(palette.muted.opacity(0.19))
                    .overlay {
                        if let image = frames[index] {
                            Image(decorative: image, scale: 1).resizable().scaledToFill()
                        } else {
                            Image(systemName: "film").font(.caption).foregroundStyle(palette.muted)
                        }
                    }
                    .frame(width: width / CGFloat(Self.frameCount), height: Self.height)
                    .clipped()
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
    }

    private func selectionOverlay(gutter: CGFloat, width: CGFloat, startX: CGFloat, endX: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            Rectangle().fill(.black.opacity(0.63))
                .frame(width: max(0, startX - gutter), height: Self.height)
                .offset(x: gutter)
            Rectangle().fill(.black.opacity(0.63))
                .frame(width: max(0, gutter + width - endX), height: Self.height)
                .offset(x: endX)
            RoundedRectangle(cornerRadius: 5).strokeBorder(palette.accent, lineWidth: 2.5)
                .frame(width: max(1, endX - startX), height: Self.height)
                .offset(x: startX)
            if let scrubPosition {
                Rectangle().fill(.white)
                    .frame(width: 2, height: Self.height - 8)
                    .shadow(color: .black.opacity(0.8), radius: 2)
                    .offset(x: gutter + min(1, max(0, scrubPosition / trim.duration)) * width - 1, y: 4)
            }
        }
    }

    private func handle(_ edge: DraftTrimSelection.Edge, center: CGFloat, width: CGFloat) -> some View {
        let isStart = edge == .start
        let value = isStart ? trim.start : trim.end
        return RoundedRectangle(cornerRadius: 6)
            .fill(palette.accent)
            .overlay {
                Image(systemName: isStart ? "chevron.compact.left" : "chevron.compact.right")
                    .font(.caption.weight(.black)).foregroundStyle(palette.onAccent)
            }
            .frame(width: 18, height: Self.height)
            .frame(width: 44, height: Self.height, alignment: isStart ? .trailing : .leading)
            .contentShape(Rectangle())
            .position(x: center + (isStart ? -13 : 13), y: Self.height / 2)
            .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.space))
                .onChanged { gesture in
                    if dragOrigin == nil { dragOrigin = trim }
                    applyDrag(edge, translation: gesture.translation.width, width: width, commit: false)
                }
                .onEnded { gesture in
                    applyDrag(edge, translation: gesture.translation.width, width: width, commit: true)
                    dragOrigin = nil
                })
            .accessibilityLabel(isStart ? "Trim start" : "Trim end")
            .accessibilityValue("\((value * outputScale).formatted(.number.precision(.fractionLength(2)))) seconds")
            .accessibilityIdentifier(isStart ? "draft-trim-start" : "draft-trim-end")
            .accessibilityAdjustableAction { direction in
                let step = 0.1 / outputScale
                switch direction {
                case .increment: update(edge, trim: trim, to: value + step, commit: true)
                case .decrement: update(edge, trim: trim, to: value - step, commit: true)
                @unknown default: break
                }
            }
    }

    private func applyDrag(_ edge: DraftTrimSelection.Edge, translation: CGFloat, width: CGFloat, commit: Bool) {
        let origin = dragOrigin ?? trim
        let start = edge == .start ? origin.start : origin.end
        update(edge, trim: origin, to: start + origin.duration * translation / width, commit: commit)
    }

    private func update(_ edge: DraftTrimSelection.Edge, trim: DraftTrimSelection, to value: Double, commit: Bool) {
        let next = trim.moving(edge, to: value)
        onEdit(next, edge == .start ? next.start : next.end, commit)
    }
}

private struct PrivateDraftNameEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State var name: String
    @State private var error: String?
    let onSave: (String) throws -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Draft name", text: $name)
                        .accessibilityIdentifier("private-draft-name")
                        .submitLabel(.done)
                        .onSubmit(save)
                    if let error {
                        Text(error).foregroundStyle(.red)
                    }
                } footer: {
                    Text("This name stays on this device and isn't shared or posted. Leave it blank to remove it. Only the first \(RecordingDraft.titleLimit) characters are saved.")
                }
            }
            .navigationTitle("Private draft name")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save) }
            }
        }
    }

    private func save() {
        do {
            try onSave(name)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
