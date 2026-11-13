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
    @ObservedObject var auth: AuthManager
    var onPosted: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @StateObject private var uploader = VideoUploader()
    @State private var caption = ""
    @State private var player: AVPlayer?

    var body: some View {
        NavigationStack {
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

                status
                Spacer()

                Button(action: post) {
                    Text(isBusy ? "Posting…" : "Post").font(.headline).frame(maxWidth: .infinity).padding()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isBusy || auth.userId == nil)
            }
            .padding()
            .navigationTitle("New post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
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
            if await uploader.post(clip: clip, caption: caption, instrument: instrument, mode: mode, userId: uid) {
                onPosted()
                dismiss()
            }
        }
    }
}
