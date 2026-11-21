import AVKit
import SwiftUI

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

struct PostSharingOptions {
    var sharePlayablePreset = true
    var allowPlayAlong = true

    func sharedPreset(_ setup: SoundSetup?) -> SoundSetup? {
        guard sharePlayablePreset, let setup, setup.isValid else { return nil }
        return setup
    }

    /// The notes behind "Learn to play" travel with the playable preset, never without it.
    func sharedNotes(_ track: NoteTrack?, setup: SoundSetup?) -> NoteTrack? {
        guard sharedPreset(setup) != nil, let track, track.isValid else { return nil }
        return track
    }

    static func canShareBacking(hasAudio: Bool, backingCredit: BackingCredit?) -> Bool {
        hasAudio && backingCredit == nil
    }

    func sharesBacking(hasAudio: Bool, backingCredit: BackingCredit?) -> Bool {
        allowPlayAlong && Self.canShareBacking(hasAudio: hasAudio, backingCredit: backingCredit)
    }
}

enum DraftPostUpdate {
    case checking
    case posted
    case failed(String)
}

/// Preview a just-recorded clip, add a caption, post it to HandStrudel.
struct PostComposerView: View {
    let clip: URL
    let draftID: UUID
    @ObservedObject var drafts: RecordingDrafts
    let instrument: String?
    let mode: String?
    let soundSetup: SoundSetup?
    let backingCredit: BackingCredit?
    @ObservedObject var auth: AuthManager
    let onSubmissionAccepted: () -> Void
    let onPostUpdate: (DraftPostUpdate) -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var uploader = VideoUploader()
    @State private var caption = ""
    @State private var player: AVPlayer?
    @State private var sharing = PostSharingOptions()
    @State private var commentsEnabled = true
    @State private var hasAudio: Bool?

    private var submission: DraftPostSubmission? {
        auth.userId.flatMap { drafts.postSubmission(for: draftID, accountID: $0) }
    }

    private var checkingAudio: Bool { backingCredit == nil && hasAudio == nil }
    private var noteTrack: NoteTrack? { drafts.drafts.first { $0.id == draftID }?.postedNoteTrack }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    VideoPlayer(player: player)
                        .aspectRatio(9 / 19.5, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .frame(maxHeight: 360)

                    TextField("Say something about it…", text: $caption, axis: .vertical)
                        .lineLimit(1...3)
                        .padding(12)
                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                        .onChange(of: caption) { caption = String($0.prefix(150)) }
                        .disabled(uploader.isBusy || submission != nil)

                    if let instrument {
                        Label(instrument, systemImage: "music.note").font(.footnote).foregroundStyle(.secondary)
                    }
                    if let soundSetup, soundSetup.isValid {
                        VStack(alignment: .leading, spacing: 4) {
                            Toggle("Share playable preset", isOn: $sharing.sharePlayablePreset)
                                .font(.subheadline)
                                .disabled(uploader.isBusy || submission != nil)
                            Text(sharing.sharePlayablePreset
                                 ? soundSetup.presetDetails + (noteTrack == nil ? "" : " · Learn to play")
                                 : "Your instrument settings and notes won't be shared.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    DailyTakeHint(setup: soundSetup, sharesPreset: sharing.sharePlayablePreset)
                    Toggle("Allow comments", isOn: $commentsEnabled)
                        .font(.subheadline)
                        .disabled(uploader.isBusy || submission != nil)
                    if let backingCredit {
                        Label("Inspired by @\(backingCredit.username)", systemImage: "waveform")
                            .font(.subheadline).foregroundStyle(.secondary)
                    } else if PostSharingOptions.canShareBacking(hasAudio: hasAudio == true, backingCredit: backingCredit) {
                        Toggle("Allow others to play along", isOn: $sharing.allowPlayAlong)
                            .font(.subheadline).disabled(uploader.isBusy || submission != nil)
                        Text("When on, anyone can reuse this clip's audio, including any voice, as a credited backing loop.")
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text(checkingAudio ? "Checking for play-along audio…" : "Play-along audio isn't available for this take.")
                            .font(.caption).foregroundStyle(.secondary)
                    }

                    status

                    Button(action: post) {
                        Text(postLabel).font(.headline).frame(maxWidth: .infinity).padding()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(uploader.isBusy || auth.userId == nil || (submission == nil && checkingAudio)
                              || (submission != nil && submission?.isPending == false))
                    Text("We check your video and thumbnail before they appear publicly.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            .navigationTitle("New post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(submission == nil ? "Cancel" : "Done") { dismiss() }
                        .disabled(uploader.isBusy)
                }
            }
        }
        .onAppear {
            let p = AVPlayer(url: clip)
            p.isMuted = false
            player = p
            p.play()
        }
        .onDisappear { player?.pause() }
        .task(id: clip) {
            guard backingCredit == nil else { return }
            let tracks = try? await AVURLAsset(url: clip).loadTracks(withMediaType: .audio)
            if !Task.isCancelled { hasAudio = tracks?.isEmpty == false }
        }
        .interactiveDismissDisabled(uploader.isBusy)
    }

    private var postLabel: String {
        if uploader.isBusy { return "Posting…" }
        guard let submission else { return "Post publicly" }
        return submission.isPending ? "Check post status" : "Posted"
    }

    @ViewBuilder private var status: some View {
        switch uploader.phase {
        case .preparing: ProgressView("Preparing video…")
        case .uploading(let f): ProgressView(value: f) { Text("Uploading…") }
        case .checking: ProgressView("Submitting video…")
        case .pending(let msg): Text(msg).foregroundStyle(.secondary).font(.footnote)
        case .failed(let msg): Text(msg).foregroundStyle(.red).font(.footnote)
        default: EmptyView()
        }
    }

    private func post() {
        guard let accountID = auth.userId, submission != nil || !checkingAudio else { return }
        let preset = sharing.sharedPreset(soundSetup)
        let notes = sharing.sharedNotes(noteTrack, setup: soundSetup)
        let allowBacking = sharing.sharesBacking(hasAudio: hasAudio == true, backingCredit: backingCredit)
        Task {
            var handedOff = false
            func leaveComposer() {
                handedOff = true
                onSubmissionAccepted()
                dismiss()
            }
            let posted = await uploader.post(clip: clip, draftID: draftID, accountID: accountID, store: drafts,
                                             caption: caption, instrument: instrument, mode: mode,
                                             soundSetup: preset, noteTrack: notes, commentsEnabled: commentsEnabled,
                                             backingEnabled: allowBacking, backingCredit: backingCredit) {
                guard auth.userId == accountID else { return }
                leaveComposer()
                onPostUpdate(.checking)
            }
            guard auth.userId == accountID else { return }
            if posted {
                if !handedOff { leaveComposer() }
                onPostUpdate(.posted)
            } else if handedOff, case .failed(let message) = uploader.phase {
                onPostUpdate(.failed(message))
            }
        }
    }
}
