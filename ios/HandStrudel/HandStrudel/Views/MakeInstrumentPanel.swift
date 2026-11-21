import SwiftUI

/// "Make an instrument" on the wheel: describe it, play it straight away,
/// refine or regenerate, save it to My instruments. Sits over the bottom of the
/// play screen so the wheel stays playable while the panel is open.
struct MakeInstrumentPanel: View {
    @ObservedObject var engine: EngineController
    @ObservedObject var store: StoreManager
    @ObservedObject var myInstruments: MyInstruments = .shared
    var generator: AIInstrumentGenerating = AIInstrumentClient()
    var onClose: () -> Void

    @Environment(\.studioPalette) private var palette
    @State private var consented = AIInstrumentConsent.hasConsented
    @State private var prompt = ""
    @State private var refineText = ""
    @State private var generating = false
    @State private var result: GeneratedInstrument?
    /// The prompt that made the current result (sent with refinements).
    @State private var originalPrompt: String?
    @State private var message: String?
    @State private var saved = false
    @State private var appliedSuggestion = false

    static let promptLimit = 300

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if !consented {
                consent
            } else if generating {
                generatingView
            } else if let result {
                resultView(result)
            } else {
                promptView
            }
            if let message {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.85))
                    .accessibilityIdentifier("ai-message")
            }
            #if DEBUG
            if MIDIProbe.isEnabled { MIDIProbeLabel() }
            #endif
        }
        .padding(16)
        .background(.black.opacity(0.82), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(.white.opacity(0.12)))
        .foregroundStyle(.white)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("make-instrument-panel")
    }

    // MARK: Sections

    private var header: some View {
        HStack {
            Label("Make an instrument", systemImage: "sparkles")
                .font(.headline)
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark").font(.system(size: 14, weight: .bold))
                    .frame(width: 32, height: 32)
                    .background(.white.opacity(0.12), in: Circle())
            }
            .accessibilityLabel("Close")
            .accessibilityIdentifier("ai-close")
        }
    }

    /// One-time disclosure before any prompt leaves the device (5.1.2(i)).
    private var consent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Instruments are designed by Claude, an AI model made by Anthropic.")
                .font(.subheadline.weight(.semibold))
            Text("Only the words you type are sent to Anthropic to design the layout and look. Your camera, microphone and recordings are never sent. Prompts and results are kept with your account to prevent abuse and improve quality. Instruments made this way are labelled \u{201C}Made with AI\u{201D}.")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Button("Not now", action: onClose)
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("ai-consent-decline")
                Spacer()
                Button("Continue") {
                    AIInstrumentConsent.hasConsented = true
                    consented = true
                }
                .buttonStyle(.borderedProminent)
                .tint(palette.mediaAccent)
                .accessibilityIdentifier("ai-consent-accept")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("ai-consent")
    }

    private var promptView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                TextField("Describe your instrument", text: $prompt, axis: .vertical)
                    .lineLimit(1...3)
                    .textFieldStyle(.plain)
                    .padding(10)
                    .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                    .submitLabel(.go)
                    .onSubmit(make)
                    .accessibilityIdentifier("ai-prompt-field")
                Button(action: make) {
                    Image(systemName: "arrow.up").font(.system(size: 16, weight: .bold))
                        .frame(width: 40, height: 40)
                        .background(palette.mediaAccent, in: Circle())
                        .foregroundStyle(palette.mediaOnAccent)
                }
                .disabled(cleanPrompt.isEmpty)
                .accessibilityLabel("Make")
                .accessibilityIdentifier("ai-make-button")
            }
            chips(AIInstrumentExamples.prompts, idPrefix: "ai-example") { example in
                prompt = example
                make()
            }
            if !myInstruments.saved.isEmpty { myInstrumentsRow }
        }
    }

    private var generatingView: some View {
        HStack(spacing: 10) {
            ProgressView().tint(.white)
            Text("Designing your instrument\u{2026}").font(.subheadline)
        }
        .frame(maxWidth: .infinity, minHeight: 60)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("ai-generating")
    }

    private func resultView(_ result: GeneratedInstrument) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(result.spec.name).font(.title3.weight(.bold))
                    .accessibilityIdentifier("ai-result-name")
                if result.spec.isAIGenerated { MadeWithAIBadge() }
            }
            if let description = result.spec.description {
                Text(description).font(.footnote).foregroundStyle(.white.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
            }
            if result.isFallback {
                Text("Couldn't make that one, so here's the closest starting point. Try refining it.")
                    .font(.footnote).foregroundStyle(.yellow.opacity(0.9))
                    .accessibilityIdentifier("ai-fallback-note")
            }
            if let suggestion = result.suggestion, !appliedSuggestion {
                Button { apply(suggestion) } label: {
                    Label("Try \(suggestion.summary)", systemImage: "music.note")
                        .font(.footnote.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .accessibilityHint("Changes your key, scale or tempo. The instrument stays the same.")
                .accessibilityIdentifier("ai-apply-suggestion")
            }
            HStack(spacing: 8) {
                TextField("Refine: \u{201C}bigger zones\u{201D}", text: $refineText)
                    .textFieldStyle(.plain)
                    .padding(9)
                    .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                    .submitLabel(.send)
                    .onSubmit { refine(refineText) }
                    .accessibilityIdentifier("ai-refine-field")
                Button { refine(refineText) } label: {
                    Image(systemName: "wand.and.stars").frame(width: 36, height: 36)
                        .background(.white.opacity(0.15), in: Circle())
                }
                .disabled(refineText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityLabel("Refine")
                .accessibilityIdentifier("ai-refine-button")
            }
            chips(AIInstrumentExamples.refinements, idPrefix: "ai-refine-chip") { refine($0) }
            HStack(spacing: 8) {
                Button { regenerate() } label: { Label("Again", systemImage: "arrow.clockwise") }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Regenerate")
                    .accessibilityIdentifier("ai-regenerate")
                Button { startOver() } label: { Label("New", systemImage: "square.and.pencil") }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("ai-new-prompt")
                Spacer()
                Button { save(result) } label: {
                    Label(saved ? "Saved" : "Save", systemImage: saved ? "checkmark" : "tray.and.arrow.down")
                }
                .buttonStyle(.borderedProminent)
                .tint(palette.mediaAccent)
                .disabled(saved || result.spec.isBuiltIn)
                .accessibilityIdentifier("ai-save")
            }
            .font(.footnote.weight(.semibold))
        }
    }

    private var myInstrumentsRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("My instruments").font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.7))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(myInstruments.saved) { item in
                        if let spec = item.spec {
                            Button {
                                engine.playInstrument(spec)
                                message = "Playing \(spec.name)."
                            } label: {
                                HStack(spacing: 4) {
                                    if spec.isAIGenerated { Image(systemName: "sparkles").font(.caption2) }
                                    Text(spec.name).lineLimit(1)
                                }
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(.white.opacity(engine.wheelInstrument.id == spec.id ? 0.3 : 0.12), in: Capsule())
                            }
                            .accessibilityLabel(spec.isAIGenerated ? "\(spec.name), made with AI" : spec.name)
                            .accessibilityIdentifier("my-instrument-\(spec.id)")
                        }
                    }
                }
            }
        }
    }

    private func chips(_ items: [String], idPrefix: String, action: @escaping (String) -> Void) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    Button { action(item) } label: {
                        Text(item).font(.caption.weight(.medium))
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(.white.opacity(0.12), in: Capsule())
                    }
                    .accessibilityIdentifier("\(idPrefix)-\(index)")
                }
            }
        }
    }

    // MARK: Actions

    private var cleanPrompt: String {
        String(prompt.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Self.promptLimit))
    }

    private func make() {
        let text = cleanPrompt
        guard !text.isEmpty else { return }
        run(AIInstrumentRequest(prompt: text), original: text)
    }

    private func regenerate() {
        guard let originalPrompt else { return }
        run(AIInstrumentRequest(prompt: originalPrompt), original: originalPrompt)
    }

    private func refine(_ change: String) {
        let text = String(change.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Self.promptLimit))
        guard !text.isEmpty, let result else { return }
        run(AIInstrumentRequest(prompt: text, current: result.body, originalPrompt: originalPrompt), original: originalPrompt)
    }

    private func run(_ request: AIInstrumentRequest, original: String?) {
        guard !generating else { return }
        generating = true
        message = nil
        Task { @MainActor in
            defer { generating = false }
            do {
                let generated = try await generator.generate(request)
                result = generated
                originalPrompt = original
                refineText = ""
                let body = String(decoding: generated.body, as: UTF8.self)
                saved = myInstruments.saved.contains { $0.id == generated.spec.id && $0.body == body }
                appliedSuggestion = false
                engine.playInstrument(generated.spec)
                if let remaining = generated.quotaRemaining, remaining <= 2 {
                    message = remaining == 0 ? "That was your last one today." : "\(remaining) left today."
                }
            } catch let error as AIInstrumentError {
                message = error == .signInRequired ? "Sign in on the Profile tab to make instruments." : error.errorDescription
            } catch {
                message = AIInstrumentError.unreachable.errorDescription
            }
        }
    }

    private func save(_ result: GeneratedInstrument) {
        Task { @MainActor in
            if await myInstruments.save(body: result.body, prompt: originalPrompt) {
                saved = true
                message = myInstruments.syncError ?? "Saved to My instruments."
            }
        }
    }

    private func startOver() {
        result = nil
        originalPrompt = nil
        prompt = ""
        message = nil
    }

    /// The suggestion changes the player's own settings, never the instrument.
    private func apply(_ suggestion: MusicSuggestion) {
        if let key = suggestion.musicKey { engine.selectedKey = key }
        if let scale = suggestion.builtInScale {
            let choice = Scale.builtIn(scale)
            if !choice.isPremium || store.hasProAccess { engine.selectedScale = choice }
        }
        if let bpm = suggestion.bpm { engine.bpm = Double(bpm) }
        appliedSuggestion = true
        message = "Applied \(suggestion.summary)."
    }
}

/// The "Made with AI" label on generated instruments.
struct MadeWithAIBadge: View {
    var body: some View {
        Label("Made with AI", systemImage: "sparkles")
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(.white.opacity(0.16), in: Capsule())
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("ai-made-with-ai")
    }
}

#if DEBUG
private struct MIDIProbeLabel: View {
    @ObservedObject private var probe = MIDIProbe.shared
    var body: some View {
        Text(probe.summary)
            .font(.caption2.monospaced())
            .foregroundStyle(.white.opacity(0.5))
            .accessibilityIdentifier("debug-midi-probe")
    }
}
#endif
