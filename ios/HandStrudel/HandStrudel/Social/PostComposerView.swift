import AVKit
import SwiftUI

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

/// Preview a just-recorded clip, add a caption, post it to HandStrudel.
struct PostComposerView: View {
    let clip: URL
    let instrument: String?
    let mode: String?
    let soundSetup: SoundSetup?
    let backingCredit: BackingCredit?
    @ObservedObject var auth: AuthManager
    var onPosted: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @StateObject private var uploader = VideoUploader()
    @State private var caption = ""
    @State private var player: AVPlayer?
    @State private var shareSound = false
    @State private var commentsEnabled = true
    @State private var backingEnabled = false

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

                    if let instrument {
                        Label(instrument, systemImage: "music.note").font(.footnote).foregroundStyle(.secondary)
                    }
                    if soundSetup?.isValid == true {
                        Toggle("Let others try this sound", isOn: $shareSound)
                            .font(.subheadline)
                            .disabled(isBusy)
                    }
                    Toggle("Allow comments", isOn: $commentsEnabled)
                        .font(.subheadline)
                        .disabled(isBusy)
                    if let backingCredit {
                        Label("Inspired by @\(backingCredit.username)", systemImage: "waveform")
                            .font(.subheadline).foregroundStyle(.secondary)
                    } else {
                        Toggle("Allow others to play along", isOn: $backingEnabled)
                            .font(.subheadline).disabled(isBusy)
                        if backingEnabled {
                            Text("Anyone can use this clip's audio, including any voice, as a backing loop in a credited performance.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }

                    status

                    Button(action: post) {
                        Text(isBusy ? "Posting…" : "Post").font(.headline).frame(maxWidth: .infinity).padding()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isBusy || auth.userId == nil)
                }
                .padding()
            }
            .navigationTitle("New post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(isBusy) } }
        }
        .onAppear {
            let p = AVPlayer(url: clip)
            p.isMuted = false
            player = p
            p.play()
        }
        .onDisappear { player?.pause() }
        .interactiveDismissDisabled(isBusy)
    }

    private var isBusy: Bool {
        switch uploader.phase { case .preparing, .uploading: return true; default: return false }
    }

    @ViewBuilder private var status: some View {
        switch uploader.phase {
        case .preparing: ProgressView("Preparing video…")
        case .uploading(let f): ProgressView(value: f) { Text("Uploading…") }
        case .failed(let msg): Text(msg).foregroundStyle(.red).font(.footnote)
        default: EmptyView()
        }
    }

    private func post() {
        guard let uid = auth.userId else { return }
        Task {
            if await uploader.post(clip: clip, caption: caption, instrument: instrument, mode: mode,
                                   soundSetup: shareSound ? soundSetup : nil, commentsEnabled: commentsEnabled,
                                   backingEnabled: backingEnabled, backingCredit: backingCredit, userId: uid) {
                onPosted()
                dismiss()
            }
        }
    }
}
