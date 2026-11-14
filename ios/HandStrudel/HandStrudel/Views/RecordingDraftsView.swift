import AVKit
import Photos
import SwiftUI

struct RecordingDraft: Codable, Identifiable, Equatable {
    let id: UUID
    let createdAt: Date
    let instrument: String?
    let mode: String?
    var soundSetup: SoundSetup? = nil
    var backingCredit: BackingCredit? = nil
    var recordedAtHalfSpeed: Bool? = nil
    var trimStart: Double?
    var trimEnd: Double?

    var outputScale: Double { recordedAtHalfSpeed == true ? 0.5 : 1 }
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

    func saveTrim(_ draft: RecordingDraft) throws {
        try writeMetadata(draft)
        if let index = drafts.firstIndex(where: { $0.id == draft.id }) { drafts[index] = draft }
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

    func makeExport(for draft: RecordingDraft, audioOnly: Bool = false) async throws -> URL {
        let source = videoURL(for: draft.id)
        let asset = AVURLAsset(url: source)
        let duration = try await asset.load(.duration).seconds
        guard duration.isFinite, duration > 0 else { throw DraftError.unreadable }
        let start = draft.trimStart ?? 0
        let end = draft.trimEnd ?? duration
        let suffix = audioOnly ? "m4a" : "mp4"
        let output = files.temporaryDirectory.appending(path: "HandStrudel-\(UUID()).\(suffix)")
        if audioOnly, try await asset.loadTracks(withMediaType: .audio).isEmpty {
            throw DraftError.noAudio
        }
        if !audioOnly, draft.outputScale == 1, start == 0, end == duration {
            try files.copyItem(at: source, to: output)
            return output
        }
        guard start.isFinite, end.isFinite, start >= 0, end <= duration, end > start else { throw DraftError.unreadable }
        let range = CMTimeRange(start: CMTime(seconds: start, preferredTimescale: 600),
                                end: CMTime(seconds: end, preferredTimescale: 600))
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
        await exporter.export()
        guard exporter.status == .completed else {
            try? files.removeItem(at: output)
            throw exporter.error ?? DraftError.unreadable
        }
        return output
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

private enum DraftError: LocalizedError {
    case unreadable, photosDenied, noAudio

    var errorDescription: String? {
        switch self {
        case .unreadable: return "This video could not be read or exported."
        case .noAudio: return "This take doesn't have an audio track to export."
        case .photosDenied: return "Allow HandStrudel to add photos in Settings, or use Share to save the video to Files."
        }
    }
}

struct RecordingDraftsView: View {
    @Environment(\.studioPalette) private var palette
    @ObservedObject var store: RecordingDrafts
    @ObservedObject var auth: AuthManager
    let openedDraft: RecordingDraft?
    let onRetake: (() -> Void)?
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
                                Text(draft.instrument ?? "Performance").font(.headline)
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
        RecordingDraftEditor(store: store, auth: auth, draft: draft, onRetake: onRetake)
    }
}

private struct RecordingDraftEditor: View {
    @Environment(\.studioPalette) private var palette
    let store: RecordingDrafts
    @ObservedObject var auth: AuthManager
    @State var draft: RecordingDraft
    let onRetake: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?
    @State private var duration = 0.0
    @State private var busy = false
    @State private var message: String?
    @State private var confirmDelete = false
    @State private var sharing: URL?
    @State private var posting: URL?
    @State private var pendingPost: URL?
    @State private var signIn = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 17) {
                VideoPlayer(player: player)
                    .frame(height: 330)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                if draft.recordedAtHalfSpeed == true {
                    Label("Recorded at half tempo. Preview and exports play at normal tempo.", systemImage: "tortoise")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                if duration > 0 { trimControls }
                if let message {
                    Text(message).font(.footnote).foregroundStyle(.secondary)
                        .accessibilityIdentifier("draft-message")
                }
                if busy { ProgressView("Preparing video") }
                Button { export(saveToPhotos) } label: {
                    Label("Save to Photos", systemImage: "photo.badge.plus")
                }
                .buttonStyle(StudioActionStyle())
                HStack(spacing: 18) {
                    Menu("Share") {
                        Button("Share video", systemImage: "film") { export { sharing = $0 } }
                        Button("Share audio (M4A)", systemImage: "waveform") { export(audioOnly: true) { sharing = $0 } }
                    }
                    if SocialConfig.isConfigured {
                        Button("Post") {
                            export { url in
                                if auth.isSignedIn && !auth.needsProfileSetup { posting = url }
                                else { pendingPost = url; signIn = true }
                            }
                        }
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
                seek(to: draft.trimStart ?? 0)
            } catch { message = error.localizedDescription }
        }
        .onDisappear { player?.pause() }
        .interactiveDismissDisabled(busy)
        .sheet(item: $sharing) { url in
            ShareSheet(activityItems: [url])
                .onDisappear { removeExport(url) }
        }
        .sheet(item: $posting) { url in
            PostComposerView(clip: url, instrument: draft.instrument, mode: draft.mode, soundSetup: draft.soundSetup,
                             backingCredit: draft.backingCredit, auth: auth) {
                message = "Posted. The original is still in Private drafts."
            }
            .onDisappear { removeExport(url) }
        }
        .sheet(isPresented: $signIn, onDismiss: {
            guard let url = pendingPost else { return }
            pendingPost = nil
            if auth.isSignedIn && !auth.needsProfileSetup { posting = url }
            else { removeExport(url) }
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

    private var trimControls: some View {
        let start = draft.trimStart ?? 0
        let end = draft.trimEnd ?? duration
        let minimumLength = min(0.25, duration)
        return VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text("Trim").font(.headline)
                Spacer()
                Button("Reset") { updateTrim(start: 0, end: duration, seekTo: 0) }
            }
            Text("Start · \((start * draft.outputScale).formatted(.number.precision(.fractionLength(1)))) s").font(.caption)
            Slider(value: Binding(get: { start }, set: { updateTrim(start: $0, end: end, seekTo: $0) }),
                   in: 0...max(0.001, end - minimumLength))
                .accessibilityLabel("Trim start")
                .disabled(end <= minimumLength)
            Text("End · \((end * draft.outputScale).formatted(.number.precision(.fractionLength(1)))) s").font(.caption)
            Slider(value: Binding(get: { end }, set: { updateTrim(start: start, end: $0, seekTo: $0) }),
                   in: max(0, min(duration - 0.001, start + minimumLength))...duration)
                .accessibilityLabel("Trim end")
                .disabled(duration <= start + minimumLength)
            Button("Play selection", systemImage: "play.fill") {
                player?.currentItem?.forwardPlaybackEndTime = CMTime(seconds: end * draft.outputScale, preferredTimescale: 600)
                player?.seek(to: CMTime(seconds: start * draft.outputScale, preferredTimescale: 600)) { finished in
                    if finished { Task { @MainActor in player?.play() } }
                }
            }
        }
    }

    private func updateTrim(start: Double, end: Double, seekTo: Double) {
        var updated = draft
        updated.trimStart = start
        updated.trimEnd = end
        do { try store.saveTrim(updated); draft = updated; seek(to: seekTo) }
        catch { message = error.localizedDescription }
    }

    private func seek(to time: Double) {
        player?.pause()
        player?.currentItem?.forwardPlaybackEndTime = .invalid
        player?.seek(to: CMTime(seconds: time * draft.outputScale, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
    }

    private func export(audioOnly: Bool = false, _ use: @escaping (URL) async throws -> Void) {
        guard !busy else { return }
        player?.pause()
        busy = true
        message = nil
        Task {
            defer { busy = false }
            do { try await use(store.makeExport(for: draft, audioOnly: audioOnly)) }
            catch { message = error.localizedDescription }
        }
    }

    private func saveToPhotos(_ url: URL) async throws {
        defer { removeExport(url) }
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { throw DraftError.photosDenied }
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetCreationRequest.forAsset().addResource(with: .video, fileURL: url, options: nil)
        }
        message = "Saved to Photos."
    }

    private func removeExport(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
}
