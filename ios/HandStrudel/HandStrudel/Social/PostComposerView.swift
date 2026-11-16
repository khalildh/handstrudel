import AVKit
import SwiftUI

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
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
    var onLeaveWhileChecking: () -> Void = {}
    var onPosted: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @StateObject private var uploader = VideoUploader()
    @State private var caption = ""
    @State private var player: AVPlayer?
    @State private var shareSound = false
    @State private var commentsEnabled = true
    @State private var backingEnabled = false
    @State private var leftWhileChecking = false

    private var submission: DraftPostSubmission? {
        auth.userId.flatMap { drafts.postSubmission(for: draftID, accountID: $0) }
    }

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
                            Toggle("Share playable preset", isOn: $shareSound)
                                .font(.subheadline)
                                .disabled(uploader.isBusy || submission != nil)
                            Text(shareSound ? soundSetup.presetDetails : "Let viewers play or privately save your instrument settings. This doesn't share backing audio.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Toggle("Allow comments", isOn: $commentsEnabled)
                        .font(.subheadline)
                        .disabled(uploader.isBusy || submission != nil)
                    if let backingCredit {
                        Label("Inspired by @\(backingCredit.username)", systemImage: "waveform")
                            .font(.subheadline).foregroundStyle(.secondary)
                    } else {
                        Toggle("Allow others to play along", isOn: $backingEnabled)
                            .font(.subheadline).disabled(uploader.isBusy || submission != nil)
                        if backingEnabled {
                            Text("Anyone can use this clip's audio, including any voice, as a backing loop in a credited performance.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }

                    status

                    Button(action: post) {
                        Text(postLabel).font(.headline).frame(maxWidth: .infinity).padding()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(uploader.isBusy || auth.userId == nil || (submission != nil && submission?.isPending == false))
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
                    Button(submission == nil ? "Cancel" : "Done") {
                        if submission?.isPending == true {
                            leftWhileChecking = true
                            onLeaveWhileChecking()
                        }
                        dismiss()
                    }
                    .disabled(uploader.isBusy && uploader.phase != .checking)
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
        .interactiveDismissDisabled(uploader.isBusy)
    }

    private var postLabel: String {
        if uploader.isBusy { return "Posting…" }
        guard let submission else { return "Post" }
        return submission.isPending ? "Check post status" : "Posted"
    }

    @ViewBuilder private var status: some View {
        switch uploader.phase {
        case .preparing: ProgressView("Preparing video…")
        case .uploading(let f): ProgressView(value: f) { Text("Uploading…") }
        case .checking: ProgressView("Checking video. You can leave this screen.")
        case .pending(let msg): Text(msg).foregroundStyle(.secondary).font(.footnote)
        case .failed(let msg): Text(msg).foregroundStyle(.red).font(.footnote)
        default: EmptyView()
        }
    }

    private func post() {
        guard let accountID = auth.userId else { return }
        Task {
            if await uploader.post(clip: clip, draftID: draftID, accountID: accountID, store: drafts,
                                   caption: caption, instrument: instrument, mode: mode,
                                   soundSetup: shareSound ? soundSetup : nil, commentsEnabled: commentsEnabled,
                                   backingEnabled: backingEnabled, backingCredit: backingCredit) {
                onPosted()
                if !leftWhileChecking { dismiss() }
            }
        }
    }
}
