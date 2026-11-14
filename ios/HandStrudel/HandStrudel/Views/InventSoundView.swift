#if DEBUG
import SwiftUI
import UniformTypeIdentifiers

struct InventSoundView: View {
    @Environment(\.studioPalette) private var palette
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    let onPlay: (InventedSound) -> Void
    @State private var prompt = ""
    @State private var candidates: [InventedSound] = []
    @State private var saved: [InventedSound] = []
    @State private var sampler = SoundFontEngine()
    @State private var preview: Task<Void, Never>?
    @State private var preparation: Task<Void, Never>?
    @State private var busy = false
    @State private var auditioning: UUID?
    @State private var importWAV = false
    @State private var error: String?
    #if targetEnvironment(simulator)
    @State private var provider: InventedSound.AudioProvider?
    private var aiEnabled: Bool { ProcessInfo.processInfo.environment["HANDSTRUDEL_LOCAL_AUDIO_LAB"] == "1" }
    #endif

    private let suggestions = ["Glass kalimba", "Soft wooden mallet", "Bright metallic bell"]
    private var cleaned: String { prompt.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("SOUND LAB / PROTOTYPE", systemImage: "waveform")
                            .font(.caption.monospaced().weight(.semibold)).foregroundStyle(palette.accent)
                        Text("Invent a sound").font(.system(.largeTitle, design: .serif))
                        Text("Describe a tone, hear it, then play it on the wheel.")
                            .font(.subheadline).foregroundStyle(palette.muted)
                        TextField("A glass kalimba with a soft knock", text: $prompt)
                            .padding(12)
                            .background(palette.background, in: RoundedRectangle(cornerRadius: 10))
                            .accessibilityIdentifier("invent-prompt")
                            .onChange(of: prompt) { if $0.count > 160 { prompt = String($0.prefix(160)) } }
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(suggestions, id: \.self) { idea in
                                    Button(idea) { prompt = idea }
                                        .font(.caption.weight(.semibold))
                                        .padding(8)
                                        .background(palette.background, in: Capsule())
                                }
                            }
                        }
                        #if targetEnvironment(simulator)
                        if aiEnabled { aiControls }
                        #endif
                        Button {
                            let text = cleaned
                            prepare { try InventedSound.variants(for: text) }
                        } label: {
                            Text("Generate two synth variations")
                        }
                        .buttonStyle(StudioActionStyle())
                        .disabled(cleaned.isEmpty || busy)
                        .opacity(cleaned.isEmpty ? 0.55 : 1)
                        .accessibilityIdentifier("invent-generate")
                        Text("The synth works offline and doesn't use AI.")
                            .font(.footnote).foregroundStyle(palette.muted)
                        if busy { ProgressView("Preparing sound…").font(.footnote) }
                    }
                    .padding(16)
                    .background(palette.surface, in: RoundedRectangle(cornerRadius: 18))
                    Button("Import a generated WAV", systemImage: "waveform.badge.plus") { importWAV = true }
                        .disabled(busy)
                    Text("Import a short, dry single note near middle C. We'll check its pitch and tune it for the wheel.")
                        .font(.footnote).foregroundStyle(palette.muted)
                    if let error { Label(error, systemImage: "exclamationmark.circle").font(.footnote) }
                    if !candidates.isEmpty {
                        Text("New sounds").font(.headline).accessibilityAddTraits(.isHeader)
                        ForEach(candidates) { sound in soundRow(sound, isSaved: saved.contains { $0.id == sound.id }) }
                    }
                    if !saved.isEmpty {
                        Text("Private library").font(.headline).accessibilityAddTraits(.isHeader)
                        ForEach(saved) { sound in
                            soundRow(sound, isSaved: true).contextMenu {
                                Button("Delete saved sound", role: .destructive) {
                                    do { try sound.delete(); saved = InventedSound.saved() }
                                    catch { self.error = error.localizedDescription }
                                }
                            }
                        }
                    }
                }
                .padding(18)
                .frame(maxWidth: 510)
                .frame(maxWidth: .infinity)
            }
            .background(palette.background.ignoresSafeArea())
            .foregroundStyle(palette.ink)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .tint(palette.accent)
        .fileImporter(isPresented: $importWAV, allowedContentTypes: [.wav]) { result in
            switch result {
            case .success(let url): prepare { [try InventedSound.imported(from: url)] }
            case .failure(let error): self.error = error.localizedDescription
            }
        }
        .onAppear { saved = InventedSound.saved() }
        #if targetEnvironment(simulator)
        .task { if aiEnabled { provider = await InventedSound.AudioProvider.available() } }
        #endif
        .onDisappear { preparation?.cancel(); stopPreview() }
        .onChange(of: scenePhase) { if $0 != .active { stopPreview() } }
    }

    #if targetEnvironment(simulator)
    @ViewBuilder private var aiControls: some View {
        if let provider {
            Button("Generate with AI", systemImage: "sparkles") {
                let text = cleaned
                prepare { [try await InventedSound.generatedByStability(prompt: text, provider: provider)] }
            }
            .buttonStyle(StudioActionStyle())
            .disabled(busy || cleaned.isEmpty)
            .accessibilityIdentifier(provider == .local ? "invent-ai-local" : "invent-ai-cloud")
            Text(provider == .local
                 ? "Stable Audio runs on this Mac. Your prompt stays here."
                 : "Sends your prompt to Stability AI and uses one paid generation.")
                .font(.footnote).foregroundStyle(palette.muted)
        } else {
            Button("Reconnect AI bridge", systemImage: "arrow.clockwise") {
                Task { provider = await InventedSound.AudioProvider.available() }
            }
            Text("Start the Sound Lab bridge on this Mac, then reconnect.")
                .font(.footnote).foregroundStyle(palette.muted)
        }
    }
    #endif

    private func soundRow(_ sound: InventedSound, isSaved: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(sound.name, systemImage: "waveform").font(.headline)
            HStack {
                Button(auditioning == sound.id ? "Stop" : "Hear", systemImage: "speaker.wave.2") {
                    if auditioning == sound.id { stopPreview() } else { hear(sound) }
                }
                .accessibilityIdentifier("invent-audition")
                Button("Play with hands", systemImage: "hand.raised") {
                    stopPreview()
                    onPlay(sound)
                    dismiss()
                }
                .accessibilityIdentifier("invent-play")
                if !isSaved {
                    Button {
                        do { try sound.save(); saved = InventedSound.saved() }
                        catch { self.error = error.localizedDescription }
                    } label: { Image(systemName: "bookmark") }
                    .accessibilityLabel("Save privately")
                    .accessibilityIdentifier("invent-save")
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 12))
    }

    private func prepare(_ work: @escaping @Sendable () async throws -> [InventedSound]) {
        preparation?.cancel()
        stopPreview()
        busy = true
        error = nil
        preparation = Task {
            let worker = Task.detached(priority: .userInitiated) { try await work() }
            do {
                let sounds = try await withTaskCancellationHandler {
                    try await worker.value
                } onCancel: { worker.cancel() }
                guard !Task.isCancelled else { return }
                candidates = sounds
            } catch {
                guard !Task.isCancelled else { return }
                self.error = error.localizedDescription
            }
            busy = false
        }
    }

    private func hear(_ sound: InventedSound) {
        stopPreview()
        do {
            try sampler.loadInventedSound(sound.caf)
            auditioning = sound.id
            preview = Task {
                sampler.noteOn(voice: "preview", midi: 60, velocity: 0.85)
                do {
                    try await Task.sleep(for: .milliseconds(430))
                    sampler.releaseTemporaryVoice("preview")
                    for (index, midi) in [60, 64, 67, 71].enumerated() {
                        sampler.noteOn(voice: "chord\(index)", midi: midi, velocity: 0.60)
                    }
                    try await Task.sleep(for: .seconds(1.25))
                    stopPreview()
                } catch { /* stopPreview already cut the notes. */ }
            }
        } catch { self.error = "Couldn't play that sample. Try another sound." }
    }

    private func stopPreview() {
        preview?.cancel()
        preview = nil
        auditioning = nil
        if sampler.isPlayingInventedSound { sampler.clearInventedSound() }
    }
}
#endif
