import SwiftUI
import UniformTypeIdentifiers

struct ControlSheet: View {
    @Environment(\.studioPalette) private var palette
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var engine: EngineController
    @ObservedObject var storeManager: StoreManager
    @Binding var playInput: StudioPlayInput
    @Binding var hideSkeletonWhenRecording: Bool
    @Binding var recordPerformanceMicrophone: Bool
    @State private var showStore = false
    @State private var showLearnPicker = false
    @State private var startLessonOnDismiss = false
    @State private var paywallPackId: String?
    @State private var showAudioExport = false
    @State private var audioExportError: String?
    @State private var exportingLoop = false
    @State private var showSetups = false
    @State private var exportedAudioURL: URL?
    @State private var soundFontCategory: GMCategory = DEFAULT_SOUNDFONT_INSTRUMENT.category
    @State private var customProgressionText = ""
    @State private var progressionCategory: ProgressionCategory = .essentials
    /// Keep secondary modes out of the way until the player requests them.
    @State private var showOtherModes = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    sectionHeader("PLAY INPUT", icon: "hand.tap")
                    StudioInputPicker(selection: $playInput)
                }
                sectionDivider

                if hasModeContextControls {
                    modeSection
                    sectionDivider
                }
                harmonySection
                Button { showSetups = true } label: { Label("Presets", systemImage: "square.stack") }
                    .buttonStyle(.bordered)
                sectionDivider
                otherModesPickerSection

                // The Strudel waveform / sampled-instrument picker only has
                // an audible effect when the active mode is voiced through the
                // WebView synth. SoundFont-routed modes have their own
                // instrument picker tucked inside the chord+melody block.
                if !activePathUsesSoundFont {
                    sectionDivider
                    soundSection
                }

                // BPM and the parameter strip only matter for modes that play
                // Strudel patterns or feed the effect chain. Chord-melody
                // family modes (Split / Radial / Chord+Melody / SoundFont) are
                // direct noteOn/noteOff against the sampler or synth, so the
                // smoothed musical params aren't doing anything — hide them.
                // BPM still feeds drums / quantize / auto-strum but it's noise
                // for the first-run user; they can dig into Melodic mode if
                // they actually need tempo control without drums.
                if !isChordMelodyFamily {
                    sectionDivider
                    bpmSection

                    sectionDivider
                    paramsSection
                }

                sectionDivider
                drumTrackSection(
                    label: "DRUMS 1",
                    loop: $engine.selectedDrumLoop,
                    volume: $engine.drumVolume,
                    bpm: $engine.drumBPM
                )

                sectionDivider
                drumTrackSection(
                    label: "DRUMS 2",
                    loop: $engine.selectedDrumLoop2,
                    volume: $engine.drumVolume2,
                    bpm: $engine.drumBPM2
                )

                sectionDivider
                filterSection

                sectionDivider
                handThemeSection

                if !engine.savedLoops.isEmpty {
                    sectionDivider
                    loopsSection
                }

                sectionDivider
                recordingSection

                if !engine.savedSnippets.isEmpty {
                    sectionDivider
                    snippetsSection
                }

                if !engine.track.slots.isEmpty {
                    sectionDivider
                    trackSection
                }

            }
            .padding(20)
        }
        .accessibilityIdentifier("music-settings-scroll")
        .safeAreaInset(edge: .top, spacing: 0) { settingsHeader }
        .background(palette.background.ignoresSafeArea())
        .sheet(isPresented: $showStore) {
            StoreView(storeManager: storeManager)
        }
        .sheet(isPresented: $showSetups) {
            SoundSetupsView(engine: engine, store: storeManager) { setup in
                engine.applySoundSetup(setup, store: storeManager)
                showSetups = false
            }
        }
        .sheet(isPresented: $showLearnPicker, onDismiss: {
            if startLessonOnDismiss { startLessonOnDismiss = false; dismiss() }
        }) {
            LearnSongPicker { song in
                engine.loadLearnSong(song)
                startLessonOnDismiss = true
                showLearnPicker = false
            }
        }
        .sheet(isPresented: $showAudioExport) {
            if let url = exportedAudioURL {
                ShareSheet(activityItems: [url]).onDisappear { try? FileManager.default.removeItem(at: url) }
            }
        }
        .alert("Audio export", isPresented: Binding(
            get: { audioExportError != nil }, set: { if !$0 { audioExportError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: { Text(audioExportError ?? "") }
        .sheet(item: $paywallPackId) { packId in
            paywallSheet(for: packId)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .task {
            if storeManager.products.isEmpty {
                await storeManager.loadProducts()
            }
        }
    }

    // MARK: - Helpers

    private var settingsHeader: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                settingsTitle
                Spacer(minLength: 4)
                settingsActions
            }
            VStack(alignment: .leading, spacing: 5) {
                settingsTitle
                settingsActions
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.background)
        .overlay(alignment: .bottom) { sectionDivider }
    }

    private var settingsTitle: some View {
        Text("Music settings")
            .font(.system(.title2, design: .serif))
            .accessibilityAddTraits(.isHeader)
    }

    private var settingsActions: some View {
        HStack(spacing: 10) {
            Button { showStore = true } label: {
                Image(systemName: "bag")
                    .frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityLabel("Store")
            Button("Done") { dismiss() }
                .fontWeight(.semibold)
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityIdentifier("music-settings-done")
        }
        .buttonStyle(.plain)
        .foregroundStyle(palette.accent)
    }

    private var sectionDivider: some View {
        Rectangle()
            .fill(palette.ink.opacity(0.06))
            .frame(height: 1)
    }

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(palette.accent.opacity(0.6))
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.secondary)
                .tracking(1.5)
        }
    }

    private func paywallSheet(for packId: String) -> some View {
        let info = packInfo(for: packId)
        let resolvedId = StoreManager.productId(for: packId)
        let product = storeManager.products.first(where: { $0.productIdentifier == resolvedId })
        return PaywallOverlay(
            packId: packId,
            packName: info.name,
            packDescription: info.description,
            price: product?.localizedPriceString ?? "---",
            items: info.items,
            storeManager: storeManager
        )
    }

    private func packInfo(for packId: String) -> (name: String, description: String, items: [String]) {
        let resolved = StoreManager.productId(for: packId)
        switch resolved {
        case StoreManager.studioPack: return ("Studio Pack", "7 professional studio presets", ["Tape", "Glass", "Deep", "Foggy", "Pulse", "Cosmic", "Glitch"])
        case StoreManager.partyPack: return ("Party Pack", "9 high-energy party presets", ["EDM", "DnB", "Dubstep", "Rave", "Reggaeton", "Future Bass", "Techno", "Garage", "Phonk"])
        case StoreManager.kit808: return ("808 Kit", "8 hip-hop & urban drum patterns", ["Boom Bap", "Drill", "Lo-Fi Hip Hop", "R&B", "Afrobeat", "Bounce", "Jersey Club", "Memphis"])
        case StoreManager.kitElectronic: return ("Electronic Kit", "8 electronic drum patterns", ["Techno", "Breakbeat", "IDM", "Jungle", "Ambient", "Industrial", "2-Step", "Synthwave"])
        case StoreManager.pro: return ("Pro Upgrade", "Unlock every instrument, scale, and chord progression.", ["120+ additional GM instruments", "Every scale — modes, harmonic minor, exotic", "Every chord progression — jazz, cinematic, world, and more", "One-time purchase"])
        default: return ("Pack", "Premium content", [])
        }
    }

    // MARK: - Mode

    private enum AppMode: String { case melodic, flow, hybrid, lead, grid, drums, learn, chordMelody, radialChordMelody, splitChordMelody, scaleChordMelody, soundFont }
    private var currentMode: AppMode {
        if engine.learnModeEnabled { return .learn }
        if engine.radialChordMelodyModeEnabled { return .radialChordMelody }
        if engine.splitChordMelodyModeEnabled { return .splitChordMelody }
        if engine.scaleChordMelodyModeEnabled { return .scaleChordMelody }
        if engine.chordMelodyModeEnabled { return .chordMelody }
        if engine.soundFontModeEnabled { return .soundFont }
        if engine.gridModeEnabled { return .grid }
        if engine.drumModeEnabled { return .drums }
        if engine.leadModeEnabled { return .lead }
        if engine.hybridModeEnabled { return .hybrid }
        if engine.flowModeEnabled { return .flow }
        return .melodic
    }

    private func setMode(_ mode: AppMode) {
        engine.switchMode(
            grid: mode == .grid,
            drums: mode == .drums,
            learn: mode == .learn,
            chordMelody: mode == .chordMelody,
            lead: mode == .lead,
            hybrid: mode == .hybrid,
            flow: mode == .flow,
            soundFont: mode == .soundFont,
            radialChordMelody: mode == .radialChordMelody,
            splitChordMelody: mode == .splitChordMelody,
            scaleChordMelody: mode == .scaleChordMelody
        )
        if mode == .learn && engine.currentLearnSong == nil {
            showLearnPicker = true
        }
    }

    /// Whether the current mode has any contextual controls to surface at the
    /// top of the sheet. Modes without mode-specific UI in `modeSection`
    /// (Melodic/Flow/Hybrid/Lead/Drums/Learn) cause the section + divider to
    /// hide entirely so the sheet doesn't open with a vacant rectangle.
    private var hasModeContextControls: Bool {
        switch currentMode {
        case .chordMelody, .radialChordMelody, .splitChordMelody, .scaleChordMelody,
             .soundFont, .grid:
            return true
        default:
            return false
        }
    }

    /// The chord+melody family: shared two-hand interaction, direct noteOn/Off
    /// against either the SoundFont sampler or the Strudel synth (no patterns,
    /// no effect chain in play). Used to prune sections of the settings sheet
    /// that have no audible effect in these modes.
    private var isChordMelodyFamily: Bool {
        switch currentMode {
        case .chordMelody, .radialChordMelody, .splitChordMelody, .scaleChordMelody, .soundFont:
            return true
        default:
            return false
        }
    }

    /// Whether the active mode routes through the SoundFont sampler — in
    /// which case the `selectedWaveform` picker (Strudel synth voices /
    /// bundled samples) is decorative and should be hidden.
    private var activePathUsesSoundFont: Bool {
        switch currentMode {
        case .soundFont: return true
        case .splitChordMelody: return engine.splitUseSoundFont
        case .scaleChordMelody: return engine.scaleUseSoundFont
        case .radialChordMelody: return engine.radialUseSoundFont
        default: return false
        }
    }

    private var modeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            // The mode picker lives at the bottom of the sheet now
            // (`otherModesPickerSection`). This section only carries the
            // contextual controls for whatever the active mode is.

            if currentMode == .chordMelody || currentMode == .radialChordMelody || currentMode == .splitChordMelody || currentMode == .scaleChordMelody {
                quantizeRow
                VStack(alignment: .leading, spacing: 10) {
                    Text(currentMode == .radialChordMelody
                        ? "One wheel shared by both hands: reach toward the outer ring (lettered chords) with the chord hand, the inner ring (lettered notes) with the melody hand. Rest in the center to hold — any chord or note is one move away. Pinch the chord hand for an accent."
                        : currentMode == .splitChordMelody
                        ? "Single circle split in half: chord hand fans across the left semicircle (chords top → bottom), melody hand fans across the right semicircle (high pitch at top, low at bottom). Rest in the center to hold. Each hand stays on its own half — straying to the other side just holds the current voice."
                        : currentMode == .scaleChordMelody
                        ? "Like Split, but the melody half plays the full diatonic scale (7 notes per octave instead of just chord tones) and the chord half voices 7th chords. The outer ring on the melody side shifts the note up or down an octave."
                        : "Chord hand holds the harmony as a quiet pad. Move up/down to shift the chord octave. Melody hand plays notes snapped to the current chord. Pinch the chord hand for an accent.")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Progression")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary.opacity(0.7))
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(ProgressionCategory.allCases) { cat in
                                    progressionCategoryChip(cat)
                                }
                            }
                        }
                        .onAppear { syncProgressionCategoryToSelection() }
                        .onChange(of: engine.chordMelodyProgression) { _ in
                            syncProgressionCategoryToSelection()
                        }
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                if engine.chordMelodyProgression.isCustom {
                                    progressionChip(engine.chordMelodyProgression)
                                }
                                ForEach(CHORD_PROGRESSIONS.filter { $0.category == progressionCategory }) { prog in
                                    progressionChip(prog)
                                }
                            }
                        }

                        // Manual entry: type any progression in Roman numerals
                        // ("I V vi IV") or scale-degree numbers ("1 5 6 4").
                        HStack(spacing: 6) {
                            TextField("Type a progression…", text: $customProgressionText)
                                .font(.system(size: 12, design: .rounded))
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled(true)
                                .submitLabel(.go)
                                .onSubmit { applyCustomProgression() }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(Capsule().fill(Color.primary.opacity(0.05)))
                                .overlay(Capsule().stroke(palette.ink.opacity(0.07), lineWidth: 0.5))
                                .accessibilityIdentifier("progression-input")

                            Button(action: applyCustomProgression) {
                                Text("Set")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundColor(customProgressionPreview == nil ? .secondary : palette.accent)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule().fill(customProgressionPreview == nil
                                            ? Color.primary.opacity(0.04)
                                            : palette.accent.opacity(0.12))
                                    )
                            }
                            .disabled(customProgressionPreview == nil)
                            .accessibilityIdentifier("progression-set")
                        }
                    }

                    Toggle(isOn: $engine.chordMelodySwapHands) {
                        Text("Swap hands (right = chords)")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(.primary.opacity(0.8))
                    }
                    .tint(palette.accent)

                    Toggle(isOn: $engine.chordMelodyAutoStrum) {
                        Text("Auto-strum (re-articulate on each beat)")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(.primary.opacity(0.8))
                    }
                    .tint(palette.accent)

                    if currentMode == .radialChordMelody || currentMode == .splitChordMelody || currentMode == .scaleChordMelody {
                        let useSF = Binding<Bool>(
                            get: {
                                switch currentMode {
                                case .radialChordMelody: return engine.radialUseSoundFont
                                case .splitChordMelody: return engine.splitUseSoundFont
                                case .scaleChordMelody: return engine.scaleUseSoundFont
                                default: return false
                                }
                            },
                            set: {
                                switch currentMode {
                                case .radialChordMelody: engine.radialUseSoundFont = $0
                                case .splitChordMelody: engine.splitUseSoundFont = $0
                                case .scaleChordMelody: engine.scaleUseSoundFont = $0
                                default: break
                                }
                            }
                        )
                        Toggle(isOn: useSF) {
                            Text("Voice through SoundFont")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundColor(.primary.opacity(0.8))
                        }
                        .tint(palette.accent)

                        if useSF.wrappedValue {
                            VStack(alignment: .leading, spacing: 6) {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 6) {
                                        ForEach(GMCategory.allCases) { cat in
                                            soundFontCategoryChip(cat)
                                        }
                                    }
                                }
                                .onAppear { soundFontCategory = engine.selectedSoundFontInstrument.category }
                                .onChange(of: engine.selectedSoundFontInstrument) { new in
                                    soundFontCategory = new.category
                                }
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 6) {
                                        ForEach(SOUNDFONT_INSTRUMENTS.filter { $0.category == soundFontCategory }) { inst in
                                            soundFontChip(inst)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Pad volume")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundColor(.primary.opacity(0.8))
                            Spacer()
                            Text(String(format: "%.0f%%", engine.chordMelodyPadVolume / 0.6 * 100))
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $engine.chordMelodyPadVolume, in: 0...0.6)
                            .tint(palette.accent)
                    }
                }
                .padding(.top, 2)
            }

            if currentMode == .soundFont {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Chord+melody played through a real SoundFont instrument. Chord hand holds the harmony; melody hand plays notes snapped to the current chord. Requires a General MIDI .sf2 in the app bundle (see Resources/soundfonts).")
                        .onAppear { soundFontCategory = engine.selectedSoundFontInstrument.category }
                        .onChange(of: engine.selectedSoundFontInstrument) { new in
                            soundFontCategory = new.category
                        }
                        .font(.system(size: 10, design: .rounded))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Instrument")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary.opacity(0.7))
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(GMCategory.allCases) { cat in
                                    soundFontCategoryChip(cat)
                                }
                            }
                        }
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(SOUNDFONT_INSTRUMENTS.filter { $0.category == soundFontCategory }) { inst in
                                    soundFontChip(inst)
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Progression")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary.opacity(0.7))
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(CHORD_PROGRESSIONS) { prog in
                                    progressionChip(prog)
                                }
                            }
                        }
                    }

                    Toggle(isOn: $engine.chordMelodySwapHands) {
                        Text("Swap hands (right = chords)")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(.primary.opacity(0.8))
                    }
                    .tint(palette.accent)

                    Toggle(isOn: $engine.chordMelodyAutoStrum) {
                        Text("Auto-strum (re-articulate on each beat)")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(.primary.opacity(0.8))
                    }
                    .tint(palette.accent)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Pad volume")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundColor(.primary.opacity(0.8))
                            Spacer()
                            Text(String(format: "%.0f%%", engine.chordMelodyPadVolume / 0.6 * 100))
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $engine.chordMelodyPadVolume, in: 0...0.6)
                            .tint(palette.accent)
                    }
                }
                .padding(.top, 2)
            }

            if currentMode == .grid {
                quantizeRow
                Text("Pinch to play notes. Move hand up/down to change pitch.")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundColor(.secondary)
                    .padding(.top, 2)

                // Octave range controls
                HStack(spacing: 12) {
                    // Octave range
                    HStack(spacing: 6) {
                        Text("Range")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                        ForEach([1, 2, 3], id: \.self) { range in
                            Button(action: { engine.gridOctaveRange = range }) {
                                Text("\(range)")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundColor(engine.gridOctaveRange == range ? palette.accent : .secondary)
                                    .frame(width: 28, height: 28)
                                    .background(Circle().fill(engine.gridOctaveRange == range ? palette.accent.opacity(0.15) : Color.primary.opacity(0.04)))
                            }
                        }
                    }

                    Spacer()

                    // Base octave
                    HStack(spacing: 4) {
                        Text("Oct")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                        Button(action: { if engine.gridBaseOctave > 1 { engine.gridBaseOctave -= 1 } }) {
                            Image(systemName: "minus")
                                .font(.system(size: 10, weight: .bold))
                                .frame(width: 24, height: 24)
                                .background(Circle().fill(Color.primary.opacity(0.06)))
                                .foregroundColor(.secondary)
                        }
                        Text("\(engine.gridBaseOctave)")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(palette.accent)
                            .frame(width: 20)
                        Button(action: { if engine.gridBaseOctave < 6 { engine.gridBaseOctave += 1 } }) {
                            Image(systemName: "plus")
                                .font(.system(size: 10, weight: .bold))
                                .frame(width: 24, height: 24)
                                .background(Circle().fill(Color.primary.opacity(0.06)))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    /// All modes — including Split — live behind a disclosure at the very
    /// bottom of the sheet. A first-run user lands in Split by default and
    /// never has to think about modes. Anyone curious has to scroll past
    /// every other section to find this.
    private var otherModesPickerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button { withAnimation(.easeInOut(duration: 0.18)) { showOtherModes.toggle() } } label: {
                HStack(spacing: 8) {
                    Image(systemName: "ellipsis.circle").accessibilityHidden(true)
                    Text("Other modes").font(.subheadline.weight(.semibold))
                    Spacer(minLength: 8)
                    Text(currentModeName).font(.caption).foregroundStyle(palette.muted)
                    Image(systemName: showOtherModes ? "chevron.up" : "chevron.down")
                        .font(.caption).accessibilityHidden(true)
                }
                .frame(minHeight: 44)
                .foregroundStyle(palette.ink)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Other modes")
            .accessibilityValue(showOtherModes ? "Expanded, \(currentModeName)" : "Collapsed, \(currentModeName)")
            .accessibilityIdentifier("music-other-modes")

            if showOtherModes {
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        modeButton("Split", icon: "circle.lefthalf.filled", mode: .splitChordMelody)
                        modeButton("Scale", icon: "music.quarternote.3", mode: .scaleChordMelody)
                        modeButton("Radial", icon: "circle.circle", mode: .radialChordMelody)
                    }
                    HStack(spacing: 8) {
                        modeButton("Chord+Melody", icon: "hand.raised.fingers.spread", mode: .chordMelody)
                        modeButton("SoundFont", icon: "pianokeys.inverse", mode: .soundFont)
                        modeButton("Melodic", icon: "pianokeys", mode: .melodic)
                    }
                    HStack(spacing: 8) {
                        modeButton("Flow", icon: "waveform", mode: .flow)
                        modeButton("Hybrid", icon: "waveform.path", mode: .hybrid)
                        modeButton("Lead", icon: "guitars", mode: .lead)
                    }
                    HStack(spacing: 8) {
                        modeButton("Grid", icon: "square.grid.3x3", mode: .grid)
                        modeButton("Drums", icon: "beats.headphones", mode: .drums)
                        modeButton("Learn", icon: "music.note.list", mode: .learn)
                    }
                }
            }
        }
        .onAppear {
            if currentMode != .splitChordMelody && currentMode != .scaleChordMelody { showOtherModes = true }
        }
    }

    private var currentModeName: String {
        switch currentMode {
        case .melodic: return "Melodic"
        case .flow: return "Flow"
        case .hybrid: return "Hybrid"
        case .lead: return "Lead"
        case .grid: return "Grid"
        case .drums: return "Drums"
        case .learn: return "Learn"
        case .chordMelody: return "Chord + Melody"
        case .radialChordMelody: return "Radial"
        case .splitChordMelody: return "Split"
        case .scaleChordMelody: return "Scale"
        case .soundFont: return "SoundFont"
        }
    }

    private func modeButton(_ label: String, icon: String, mode: AppMode) -> some View {
        let isActive = currentMode == mode
        return Button(action: { setMode(mode) }) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(isActive ? palette.accent : .primary.opacity(0.5))
                Text(label)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(isActive ? palette.accent : .primary.opacity(0.6))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isActive
                        ? LinearGradient(colors: [palette.accent.opacity(0.2), palette.accent.opacity(0.08)], startPoint: .top, endPoint: .bottom)
                        : LinearGradient(colors: [Color.primary.opacity(0.04), Color.primary.opacity(0.02)], startPoint: .top, endPoint: .bottom))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isActive ? palette.accent.opacity(0.5) : palette.ink.opacity(0.06), lineWidth: isActive ? 1.5 : 0.5)
            )
        }
        .accessibilityIdentifier("mode-\(mode.rawValue)")
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    private func soundFontCategoryChip(_ cat: GMCategory) -> some View {
        let isActive = soundFontCategory == cat
        return Button(action: { soundFontCategory = cat }) {
            HStack(spacing: 5) {
                Text(cat.emoji).font(.system(size: 12))
                Text(cat.displayName)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(isActive ? .blue : .primary.opacity(0.6))
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(isActive ? Color.blue.opacity(0.12) : Color.primary.opacity(0.03))
            )
            .overlay(
                Capsule().stroke(isActive ? Color.blue.opacity(0.5) : palette.ink.opacity(0.05), lineWidth: isActive ? 1 : 0.5)
            )
        }
    }

    private func soundFontChip(_ inst: SoundFontInstrument) -> some View {
        let isActive = engine.selectedSoundFontInstrument.id == inst.id
        return Button(action: { engine.selectedSoundFontInstrument = inst }) {
            HStack(spacing: 6) {
                Text(inst.emoji).font(.system(size: 14))
                Text(inst.name)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(isActive ? palette.accent : .primary.opacity(0.75))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                Capsule().fill(isActive ? palette.accent.opacity(0.12) : Color.primary.opacity(0.04))
            )
            .overlay(
                Capsule().stroke(isActive ? palette.accent.opacity(0.5) : palette.ink.opacity(0.06), lineWidth: isActive ? 1 : 0.5)
            )
        }
    }

    /// "Sync to beat" toggle + divisor picker. Reused by Grid and
    /// Chord+Melody / SoundFont modes since the quantize behaviour is
    /// identical — both gate note onsets to the same beat clock.
    @ViewBuilder
    private var quantizeRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(isOn: $engine.quantizeEnabled) {
                Text("Sync to beat (snap notes to the grid)")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.primary.opacity(0.8))
            }
            .tint(palette.accent)

            if engine.quantizeEnabled {
                HStack(spacing: 8) {
                    Text("Grid")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                    ForEach([(4.0, "1/4"), (8.0, "1/8"), (16.0, "1/16")], id: \.0) { div, label in
                        Button(action: { engine.quantizeDiv = div }) {
                            Text(label)
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(engine.quantizeDiv == div ? palette.accent : .secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(engine.quantizeDiv == div ? palette.accent.opacity(0.15) : Color.primary.opacity(0.04)))
                        }
                    }
                    Spacer()
                }
            }
        }
        .padding(.top, 2)
    }

    private func progressionCategoryChip(_ cat: ProgressionCategory) -> some View {
        let isActive = progressionCategory == cat
        return Button(action: { progressionCategory = cat }) {
            HStack(spacing: 5) {
                Text(cat.emoji).font(.system(size: 12))
                Text(cat.displayName)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(isActive ? .blue : .primary.opacity(0.6))
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(isActive ? Color.blue.opacity(0.12) : Color.primary.opacity(0.03))
            )
            .overlay(
                Capsule().stroke(isActive ? Color.blue.opacity(0.5) : palette.ink.opacity(0.05), lineWidth: isActive ? 1 : 0.5)
            )
        }
    }

    // Snap the category filter to whichever bucket the active progression
    // belongs to. Custom progressions stick to the user's current filter so
    // they can keep browsing while their typed-in one rides at the front.
    private func syncProgressionCategoryToSelection() {
        let cat = engine.chordMelodyProgression.category
        if cat != .custom { progressionCategory = cat }
    }

    private var customProgressionPreview: ChordProgression? {
        guard let prog = ChordProgression.parse(customProgressionText) else { return nil }
        return prog.degrees.isEmpty ? nil : prog
    }

    private func applyCustomProgression() {
        guard let parsed = ChordProgression.parse(customProgressionText) else { return }
        let label = parsed.degrees.map(romanNumeral).joined(separator: " ")
        engine.chordMelodyProgression = ChordProgression(
            id: "custom", name: label, emoji: "✍️", degrees: parsed.degrees, category: .custom)
    }

    /// Diatonic Roman numeral for a 0-based scale degree (0 = I … 6 = vii°).
    private func romanNumeral(_ degree: Int) -> String {
        let numerals = ["I", "ii", "iii", "IV", "V", "vi", "vii°"]
        return numerals.indices.contains(degree) ? numerals[degree] : "\(degree + 1)"
    }

    private func progressionChip(_ prog: ChordProgression) -> some View {
        let isActive = engine.chordMelodyProgression.id == prog.id
        return Button(action: { engine.chordMelodyProgression = prog }) {
            HStack(spacing: 6) {
                Text(prog.emoji)
                    .font(.system(size: 14))
                Text(prog.name)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(isActive ? palette.accent : .primary.opacity(0.75))
                Text("\(prog.degrees.count)")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(palette.ink.opacity(isActive ? 0.7 : 0.35))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(
                        Capsule().fill(isActive ? palette.accent.opacity(0.2) : palette.ink.opacity(0.06))
                    )
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                Capsule().fill(isActive ? palette.accent.opacity(0.12) : Color.primary.opacity(0.04))
            )
            .overlay(
                Capsule().stroke(isActive ? palette.accent.opacity(0.5) : palette.ink.opacity(0.06), lineWidth: isActive ? 1 : 0.5)
            )
        }
    }


    // MARK: - Harmony

    private var harmonySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("HARMONY", icon: "music.note")

            // Key picker
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(MusicKey.allCases) { key in
                        Button(action: {
                            engine.selectedKey = key
                            engine.recomputeScaleNotes()
                        }) {
                            Text(key.rawValue)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(engine.selectedKey == key ? palette.accent : .primary.opacity(0.6))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 9)
                                .background(
                                    Capsule()
                                        .fill(engine.selectedKey == key ? palette.accent.opacity(0.15) : Color.primary.opacity(0.04))
                                )
                                .overlay(
                                    Capsule()
                                        .stroke(engine.selectedKey == key ? palette.accent.opacity(0.4) : Color.clear, lineWidth: 1.5)
                                )
                        }
                    }
                }
            }

            // Scale picker
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Scale.allCases) { scale in
                        let locked = scale.isPremium && !storeManager.isUnlocked(scale.packId ?? "")
                        Button(action: {
                            if locked, let packId = scale.packId {
                                paywallPackId = packId
                            } else {
                                engine.selectedScale = scale
                                engine.recomputeScaleNotes()
                            }
                        }) {
                            Text(scale.rawValue)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(engine.selectedScale == scale ? palette.accent : .primary.opacity(0.6))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(engine.selectedScale == scale ? palette.accent.opacity(0.15) : Color.primary.opacity(0.04))
                                )
                                .overlay(
                                    Capsule()
                                        .stroke(engine.selectedScale == scale ? palette.accent.opacity(0.4) : Color.clear, lineWidth: 1.5)
                                )
                                .overlay(alignment: .topTrailing) {
                                    if locked {
                                        Text("PRO")
                                            .font(.system(size: 6, weight: .bold, design: .rounded))
                                            .foregroundColor(palette.ink.opacity(0.8))
                                            .padding(.horizontal, 3)
                                            .padding(.vertical, 1)
                                            .background(Capsule().fill(palette.ink.opacity(0.15)))
                                            .offset(x: 4, y: -4)
                                    }
                                }
                                .opacity(locked ? 0.5 : 1.0)
                        }
                    }
                }
            }

            // Toggles - pill style
            HStack(spacing: 12) {
                pillToggle("Chords", icon: "music.note.list", isOn: $engine.chordMode)
                pillToggle("Circle of 5ths", icon: "circle.circle", isOn: $engine.circleOfFifthsEnabled)
            }
        }
    }

    private func pillToggle(_ label: String, icon: String, isOn: Binding<Bool>) -> some View {
        Button(action: { isOn.wrappedValue.toggle() }) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(label)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
            }
            .foregroundColor(isOn.wrappedValue ? palette.accent : .primary.opacity(0.5))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isOn.wrappedValue ? palette.accent.opacity(0.15) : Color.primary.opacity(0.04))
            )
            .overlay(
                Capsule()
                    .stroke(isOn.wrappedValue ? palette.accent.opacity(0.4) : palette.ink.opacity(0.06), lineWidth: isOn.wrappedValue ? 1.5 : 0.5)
            )
        }
    }

    // MARK: - Sound

    private var soundSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("SOUND", icon: "waveform")

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8)
            ], spacing: 8) {
                ForEach(WAVEFORMS) { wf in
                    waveformCard(wf)
                }
            }
        }
    }

    private func waveformCard(_ wf: Waveform) -> some View {
        let locked = wf.isPremium && !storeManager.isUnlocked(wf.packId ?? "")
        let isSelected = engine.selectedWaveform == wf.id
        return Button(action: {
            if locked, let packId = wf.packId {
                paywallPackId = packId
            } else {
                engine.selectedWaveform = wf.id
            }
        }) {
            VStack(spacing: 5) {
                Text(wf.emoji)
                    .font(.system(size: 20))
                Text(wf.name)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(isSelected ? palette.accent : .primary.opacity(0.6))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected
                        ? LinearGradient(colors: [palette.accent.opacity(0.2), palette.accent.opacity(0.08)], startPoint: .top, endPoint: .bottom)
                        : LinearGradient(colors: [Color.primary.opacity(0.04), Color.primary.opacity(0.02)], startPoint: .top, endPoint: .bottom))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? palette.accent.opacity(0.5) : palette.ink.opacity(0.06), lineWidth: isSelected ? 1.5 : 0.5)
            )
            .overlay(alignment: .topTrailing) {
                if locked {
                    Text("PRO")
                        .font(.system(size: 8, weight: .heavy, design: .rounded))
                        .foregroundColor(palette.ink.opacity(0.8))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(.ultraThinMaterial))
                        .padding(5)
                }
            }
            .opacity(locked ? 0.5 : 1.0)
        }
    }

    // MARK: - Drums

    private func drumTrackSection(label: String, loop: Binding<DrumLoop>, volume: Binding<Double>, bpm: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(label, icon: "beats.headphones")

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8)
            ], spacing: 8) {
                ForEach(DRUM_LOOPS) { drumLoop in
                    let locked = drumLoop.isPremium && !storeManager.isUnlocked(drumLoop.packId ?? "")
                    Button(action: {
                        if locked, let packId = drumLoop.packId {
                            paywallPackId = packId
                        } else {
                            loop.wrappedValue = drumLoop
                        }
                    }) {
                        VStack(spacing: 5) {
                            Text(drumLoop.emoji)
                                .font(.system(size: 22))
                            Text(drumLoop.name)
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundColor(loop.wrappedValue.id == drumLoop.id ? palette.accent : .primary.opacity(0.6))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(loop.wrappedValue.id == drumLoop.id
                                    ? LinearGradient(colors: [palette.accent.opacity(0.2), palette.accent.opacity(0.08)], startPoint: .top, endPoint: .bottom)
                                    : LinearGradient(colors: [Color.primary.opacity(0.04), Color.primary.opacity(0.02)], startPoint: .top, endPoint: .bottom))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(loop.wrappedValue.id == drumLoop.id ? palette.accent.opacity(0.5) : palette.ink.opacity(0.06), lineWidth: loop.wrappedValue.id == drumLoop.id ? 1.5 : 0.5)
                        )
                        .overlay(alignment: .topTrailing) {
                            if locked {
                                Text("PRO")
                                    .font(.system(size: 8, weight: .heavy, design: .rounded))
                                    .foregroundColor(palette.ink.opacity(0.8))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(.ultraThinMaterial))
                                    .padding(5)
                            }
                        }
                        .opacity(locked ? 0.5 : 1.0)
                    }
                }
            }

            if loop.wrappedValue.id != "none" {
                HStack(spacing: 8) {
                    Text("VOL")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary.opacity(0.6))
                        .frame(width: 28)
                    Slider(value: volume, in: 0.2...2.0)
                        .tint(palette.accent)
                    Text(String(format: "%.0f%%", volume.wrappedValue * 100))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(width: 40, alignment: .trailing)
                }

                HStack(spacing: 8) {
                    Text("BPM")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary.opacity(0.6))
                        .frame(width: 28)
                    Slider(value: bpm, in: 40...240, step: 1)
                        .tint(palette.accent)
                    Text("\(Int(bpm.wrappedValue.rounded()))")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(width: 35, alignment: .trailing)
                }
            }
        }
    }

    // MARK: - BPM

    private var bpmSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("BPM", icon: "metronome")

            HStack {
                Spacer()
                Text("\(Int(engine.manualBPM.rounded()))")
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                    .foregroundColor(palette.accent)
                Spacer()
            }

            if engine.bpmIsMapped {
                Text("Controlled by hand")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(.secondary)
            } else {
                HStack(spacing: 10) {
                    Button(action: { engine.manualBPM = max(50, engine.manualBPM - 1) }) {
                        Image(systemName: "minus")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.primary.opacity(0.6))
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(Color.primary.opacity(0.06)))
                    }

                    Slider(value: Binding(
                        get: { engine.manualBPM },
                        set: { engine.manualBPM = $0 }
                    ), in: 50...205, step: 1)
                    .tint(palette.accent)

                    Button(action: { engine.manualBPM = min(205, engine.manualBPM + 1) }) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.primary.opacity(0.6))
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(Color.primary.opacity(0.06)))
                    }
                }
            }
        }
    }

    // MARK: - Params

    private var paramsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("PARAMETERS", icon: "slider.horizontal.3")

            ForEach(PARAM_DEFS) { def in
                let isActive = engine.config.left.values.contains(def.id) ||
                               engine.config.right.values.contains(def.id)
                if isActive {
                    paramRow(def: def)
                }
            }
        }
    }

    private func paramRow(def: ParamDef) -> some View {
        let isLocked = engine.lockedParams.contains(def.id)
        let currentValue = isLocked
            ? (engine.manualValues[def.id] ?? def.defaultValue)
            : (engine.smoothedParams[def.id] ?? def.defaultValue)

        return VStack(spacing: 4) {
            HStack(spacing: 8) {
                // Lock toggle with filled circle background
                Button(action: { engine.toggleLock(def.id) }) {
                    ZStack {
                        Circle()
                            .fill(isLocked ? Color.orange.opacity(0.2) : Color.clear)
                            .frame(width: 24, height: 24)
                        Image(systemName: isLocked ? "lock.fill" : "lock.open")
                            .font(.system(size: 11))
                            .foregroundColor(isLocked ? .orange : .secondary.opacity(0.4))
                    }
                }
                .frame(width: 24)

                Text(def.label)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(isLocked ? .orange : .primary)
                    .frame(width: 55, alignment: .leading)

                if isLocked {
                    Slider(value: Binding(
                        get: { engine.manualValues[def.id] ?? def.defaultValue },
                        set: { engine.setManualValue(def.id, value: $0) }
                    ), in: def.min...def.max)
                    .tint(.orange)
                } else {
                    let normalized = (currentValue - def.min) / (def.max - def.min)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.primary.opacity(0.08))
                            Capsule()
                                .fill(palette.accent.opacity(0.5))
                                .frame(width: geo.size.width * max(0, min(1, normalized)))
                        }
                    }
                    .frame(height: 8)
                }

                Text(def.format(currentValue))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: 50, alignment: .trailing)
            }
        }
        .frame(minHeight: 32)
    }

    // MARK: - Recording Settings

    // MARK: - Filters

    private var filterSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("FILTERS", icon: "camera.filters")

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8)
            ], spacing: 8) {
                ForEach(CAMERA_FILTERS) { filter in
                    let locked = filter.isPremium && !storeManager.isUnlocked(filter.packId ?? "")
                    let isSelected = engine.selectedFilter.id == filter.id
                    Button(action: {
                        if locked, let packId = filter.packId {
                            paywallPackId = packId
                        } else {
                            engine.selectedFilter = filter
                        }
                    }) {
                        VStack(spacing: 2) {
                            Text(filter.emoji)
                                .font(.system(size: 18))
                            Text(filter.name)
                                .font(.system(size: 8, weight: .semibold, design: .rounded))
                                .foregroundColor(isSelected ? palette.accent : .primary.opacity(0.6))
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(isSelected ? palette.accent.opacity(0.12) : Color.primary.opacity(0.04))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(isSelected ? palette.accent.opacity(0.4) : Color.clear, lineWidth: 1.5)
                        )
                        .overlay(alignment: .topTrailing) {
                            if locked {
                                Text("PRO")
                                    .font(.system(size: 7, weight: .bold, design: .rounded))
                                    .foregroundColor(palette.ink.opacity(0.8))
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(palette.ink.opacity(0.15)))
                                    .padding(4)
                            }
                        }
                        .opacity(locked ? 0.5 : 1.0)
                    }
                }
            }
        }
    }

    // MARK: - Hand Theme

    private var handThemeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("HAND THEME", icon: "hand.raised")

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8)
            ], spacing: 8) {
                ForEach(HAND_THEMES) { theme in
                    let locked = theme.isPremium && !storeManager.isUnlocked(theme.packId ?? "")
                    let isSelected = engine.selectedHandTheme.id == theme.id
                    Button(action: {
                        if locked, let packId = theme.packId {
                            paywallPackId = packId
                        } else {
                            engine.selectedHandTheme = theme
                        }
                    }) {
                        VStack(spacing: 2) {
                            Text(theme.emoji)
                                .font(.system(size: 18))
                            Text(theme.name)
                                .font(.system(size: 8, weight: .semibold, design: .rounded))
                                .foregroundColor(isSelected ? palette.accent : .primary.opacity(0.6))
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(isSelected ? palette.accent.opacity(0.12) : Color.primary.opacity(0.04))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(isSelected ? palette.accent.opacity(0.4) : Color.clear, lineWidth: 1.5)
                        )
                        .overlay(alignment: .topTrailing) {
                            if locked {
                                Text("PRO")
                                    .font(.system(size: 7, weight: .bold, design: .rounded))
                                    .foregroundColor(palette.ink.opacity(0.8))
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(palette.ink.opacity(0.15)))
                                    .padding(4)
                            }
                        }
                        .opacity(locked ? 0.5 : 1.0)
                    }
                }
            }
        }
    }

    // MARK: - Loops

    private var loopsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionHeader("LOOPS", icon: "waveform.circle")
                Spacer()
                if !engine.playingLoopIds.isEmpty {
                    Button(action: engine.stopAllLoops) {
                        Text("Stop All")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(.red.opacity(0.8))
                    }
                }
            }

            Text("Tap the red circle button to record a loop. Loops auto-play and layer on top of each other.")
                .font(.system(size: 10, design: .rounded))
                .foregroundColor(.secondary)

            // Bar length picker
            HStack(spacing: 6) {
                Text("Length")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                ForEach(LoopRecorder.barOptions, id: \.self) { bars in
                    Button(action: { engine.setLoopRecordingBars(bars) }) {
                        Text("\(bars) bars")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(engine.loopRecordingBars == bars ? palette.accent : .secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                Capsule().fill(engine.loopRecordingBars == bars ? palette.accent.opacity(0.15) : Color.primary.opacity(0.04))
                            )
                    }
                }
            }

            // Saved loops
            ForEach(engine.savedLoops) { loop in
                HStack(spacing: 10) {
                    // Play/stop toggle
                    Button(action: { engine.toggleLoopPlayback(loop.id) }) {
                        Image(systemName: engine.playingLoopIds.contains(loop.id) ? "stop.circle.fill" : "play.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(engine.playingLoopIds.contains(loop.id) ? .orange : palette.accent)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(loop.name)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                        HStack(spacing: 6) {
                            Text(loop.mode)
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundColor(palette.accent)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(palette.accent.opacity(0.15)))
                            Text(loop.hasCapturedAudio == true ? "Captured audio" : "Note events")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.secondary)
                            Text("\(String(format: "%.1f", loop.duration))s")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    // Export audio
                    Button(action: {
                        exportingLoop = true
                        Task {
                            defer { exportingLoop = false }
                            do {
                                if loop.hasCapturedAudio == true { exportedAudioURL = try AudioExporter.shareCaptured(loop) }
                                else { exportedAudioURL = try await AudioExporter.exportLoop(loop) }
                                showAudioExport = true
                            } catch {
                                audioExportError = "Couldn't export this loop. The original is still saved."
                            }
                        }
                    }) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 14))
                            .foregroundColor(palette.accent.opacity(0.6))
                    }
                    .accessibilityLabel(loop.hasCapturedAudio == true ? "Export WAV" : "Export approximate M4A")
                    .disabled(exportingLoop)

                    // Delete
                    Button(action: { engine.deleteLoop(loop.id) }) {
                        Image(systemName: "trash")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary.opacity(0.5))
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var recordingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("RECORDING", icon: "video")

            pillToggle("Hide hand tracking in recordings", icon: "hand.raised.slash", isOn: $hideSkeletonWhenRecording)
            pillToggle("Include microphone (solo takes)", icon: "mic", isOn: $recordPerformanceMicrophone)
        }
    }

    // MARK: - Snippets

    private var snippetsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("SAVED SNIPPETS", icon: "bookmark")

            ForEach(Array(engine.savedSnippets.enumerated()), id: \.offset) { idx, snippet in
                HStack {
                    Button(action: { engine.toggleSnippet(idx) }) {
                        Image(systemName: engine.playingSet.contains(idx) ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(engine.playingSet.contains(idx) ? .orange : palette.accent)
                    }
                    VStack(alignment: .leading) {
                        Text("Snippet #\(idx + 1)")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                        Text("\(snippet.bpm) bpm")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button(action: { engine.addToTrack(idx) }) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 18))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Track

    private var trackSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                sectionHeader("TRACK", icon: "list.bullet.rectangle")
                Spacer()
                Button(action: engine.toggleTrackPlay) {
                    Image(systemName: engine.trackPlaying ? "stop.circle.fill" : "play.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(engine.trackPlaying ? .orange : palette.accent)
                }
            }

            HStack(spacing: 6) {
                ForEach([0.5, 1.0, 2.0, 4.0], id: \.self) { speed in
                    Button(action: { engine.setTrackSpeed(speed) }) {
                        Text("\(speed == Double(Int(speed)) ? "\(Int(speed))" : String(format: "%.1f", speed))x")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(engine.track.speed == speed ? palette.accent : .secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(engine.track.speed == speed ? palette.accent.opacity(0.15) : Color.clear))
                    }
                }
            }

            ForEach(Array(engine.track.slots.enumerated()), id: \.offset) { slotIdx, snippetIdx in
                HStack {
                    Text("\(slotIdx + 1).")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.secondary)
                    Text("Snippet #\(snippetIdx + 1)")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                    Spacer()
                    Button(action: { engine.removeFromTrack(slotIdx) }) {
                        Image(systemName: "xmark.circle")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}

struct LoopShelfView: View {
    @Environment(\.studioPalette) private var palette
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var engine: EngineController
    @State private var renameTarget: RecordedLoop?
    @State private var nextName = ""
    @State private var deleteTarget: RecordedLoop?
    @State private var exportURL: URL?
    @State private var isExporting = false
    @State private var message: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    Label("PRIVATE AUDIO LIBRARY", systemImage: "waveform")
                        .font(.caption.monospaced().weight(.semibold)).foregroundStyle(palette.accent)
                    Text("Loop shelf").font(.system(.largeTitle, design: .serif)).accessibilityAddTraits(.isHeader)
                    Text(engine.isRunning ? "Layer loops with the live instrument." : "Preview captured audio without opening the wheel.")
                        .font(.subheadline).foregroundStyle(palette.muted)
                    Picker("New recording length", selection: Binding(get: { engine.loopRecordingBars }, set: engine.setLoopRecordingBars)) {
                        ForEach(LoopRecorder.barOptions, id: \.self) { bars in
                            Text(bars == 1 ? "1 bar" : "\(bars) bars").tag(bars)
                        }
                    }
                    .accessibilityIdentifier("loop-recording-length")
                    if engine.savedLoops.isEmpty {
                        Label("No loops yet", systemImage: "repeat").font(.headline)
                        Text("Tap the repeat button on the wheel to capture app audio.")
                            .font(.subheadline).foregroundStyle(palette.muted)
                    }
                    ForEach(engine.savedLoops) { loop in loopRow(loop) }
                    if isExporting { ProgressView("Preparing audio") }
                }
                .padding(20)
                .frame(maxWidth: 540)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .background(palette.background.ignoresSafeArea())
            .foregroundStyle(palette.ink)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .tint(palette.accent)
        .onDisappear {
            engine.persistLoops()
            if !engine.isRunning { engine.stopAllLoops() }
        }
        .sheet(item: $exportURL) { url in
            ShareSheet(activityItems: [url])
                .onDisappear { try? FileManager.default.removeItem(at: url) }
        }
        .alert("Rename loop", isPresented: Binding(get: { renameTarget != nil }, set: { if !$0 { renameTarget = nil } }),
               presenting: renameTarget) { loop in
            TextField("Loop name", text: $nextName)
            Button("Save") { _ = engine.renameLoop(loop.id, to: nextName) }
                .disabled(RecordedLoop.cleanName(nextName).isEmpty)
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Delete this loop?", isPresented: Binding(get: { deleteTarget != nil }, set: { if !$0 { deleteTarget = nil } }),
                            titleVisibility: .visible, presenting: deleteTarget) { loop in
            Button("Delete loop", role: .destructive) { engine.deleteLoop(loop.id) }
            Button("Cancel", role: .cancel) {}
        } message: { _ in Text("Any WAV copies you've shared will stay where you saved them.") }
        .alert("Loops", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(message ?? "") }
    }

    private func loopRow(_ loop: RecordedLoop) -> some View {
        let playing = engine.playingLoopIds.contains(loop.id)
        let captured = loop.hasCapturedAudio == true
        return VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                Button {
                    if !engine.toggleLoopPlayback(loop.id) { message = "This loop couldn't play. Its audio file may be unavailable." }
                } label: {
                    Image(systemName: playing ? "stop.fill" : "play.fill")
                        .foregroundStyle(palette.onAccent)
                        .frame(width: 44, height: 44)
                        .background(palette.accent, in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(!captured && !engine.isRunning)
                .accessibilityLabel("\(playing ? "Stop" : "Play") \(loop.name)")
                VStack(alignment: .leading, spacing: 4) {
                    Text(loop.name).font(.headline)
                    Text(captured ? "WAV · \(loop.duration.formatted(.number.precision(.fractionLength(1)))) s" : "Older note-event loop")
                        .font(.caption.monospacedDigit()).foregroundStyle(palette.muted)
                }
                Spacer(minLength: 3)
                Menu {
                    Button("Rename", systemImage: "pencil") { nextName = loop.name; renameTarget = loop }
                    Button(captured ? "Export original WAV" : "Export approximate M4A", systemImage: "square.and.arrow.up") { export(loop) }
                        .disabled(isExporting)
                    Button("Delete", systemImage: "trash", role: .destructive) { deleteTarget = loop }
                } label: {
                    Image(systemName: "ellipsis.circle").frame(width: 44, height: 44)
                }
                .accessibilityLabel("Actions for \(loop.name)")
            }
            if captured {
                HStack(spacing: 10) {
                    Button {
                        engine.toggleLoopMute(loop.id)
                    } label: {
                        Image(systemName: loop.muted == true ? "speaker.slash.fill" : "speaker.wave.2")
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(palette.accent)
                    .accessibilityLabel(loop.muted == true ? "Unmute \(loop.name)" : "Mute \(loop.name)")
                    Slider(value: Binding(get: { loop.playbackGain }, set: { engine.setLoopGain($0, for: loop.id) }),
                           in: 0...1, step: 0.05, onEditingChanged: { if !$0 { engine.persistLoops() } })
                        .accessibilityLabel("Volume for \(loop.name)")
                    Text(loop.playbackGain, format: .percent.precision(.fractionLength(0)))
                        .font(.caption.monospacedDigit()).foregroundStyle(palette.muted)
                        .accessibilityHidden(true)
                }
            } else if !engine.isRunning {
                Text("Open the wheel to play this older loop.").font(.caption).foregroundStyle(palette.muted)
            }
        }
        .padding(12)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(palette.border).allowsHitTesting(false) }
    }

    private func export(_ loop: RecordedLoop) {
        guard !isExporting else { return }
        isExporting = true
        Task {
            defer { isExporting = false }
            do {
                if loop.hasCapturedAudio == true { exportURL = try AudioExporter.shareCaptured(loop) }
                else { exportURL = try await AudioExporter.exportLoop(loop) }
            } catch { message = "Couldn't export this loop. The original is still saved." }
        }
    }
}

struct SoundSetupsView: View {
    @Environment(\.studioPalette) private var palette
    @ObservedObject var engine: EngineController
    @ObservedObject var store: StoreManager
    let onUse: (SoundSetup) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var setups = PersistenceManager.shared.loadSetups()
    @State private var name = ""
    @State private var choosingImport = false
    @State private var showingImportReview = false
    @State private var pendingImport: SoundPresetPack?
    @State private var showingExport = false
    @State private var exportDocument: SoundPresetFile?
    @State private var message: String?

    private var cleanName: String { String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40)) }

    var body: some View {
        NavigationStack {
            List {
                if let sound = engine.soundSetupForSaving, sound.isValid {
                    Section("Current sound") {
                        TextField("Preset name", text: $name)
                            .accessibilityIdentifier("preset-name")
                        Button("Save current preset") {
                            if PersistenceManager.shared.addPreset(sound, named: cleanName) {
                                setups = PersistenceManager.shared.loadSetups()
                                name = ""
                            }
                        }
                        .disabled(cleanName.isEmpty || setups.contains { $0.name == cleanName && $0.sound == sound })
                    }
                }
                Section("Saved on this device") {
                    if setups.isEmpty {
                        Text("Save a sound from the studio or from a performance in the feed.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(setups) { setup in
                        let locked = !setup.sound.requiredPacks.allSatisfy { store.isUnlocked($0) }
                        Button { onUse(setup.sound) } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(setup.name)
                                    Text([setup.sound.instrumentName, setup.sound.presetDetails]
                                        .compactMap { $0 }.joined(separator: " / "))
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if locked { Image(systemName: "lock").accessibilityLabel("Requires a sound pack") }
                            }
                        }
                        .disabled(locked || !setup.sound.isValid)
                        .contextMenu {
                            Button("Export this preset", systemImage: "square.and.arrow.up") { export([setup]) }
                                .disabled(!setup.sound.isValid)
                        }
                    }
                    .onDelete { indices in
                        setups.remove(atOffsets: indices)
                        PersistenceManager.shared.saveSetups(setups)
                    }
                }
            }
            .navigationTitle("Presets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Import preset file", systemImage: "square.and.arrow.down") { choosingImport = true }
                            .accessibilityIdentifier("preset-import")
                        Button("Export all presets", systemImage: "square.and.arrow.up") { export(setups) }
                            .accessibilityIdentifier("preset-export")
                            .disabled(setups.isEmpty)
                    } label: {
                        Label("Move or back up presets", systemImage: "arrow.up.arrow.down")
                    }
                    .accessibilityIdentifier("preset-transfer")
                    .accessibilityHint("Preset files carry settings, not recordings or purchased sound packs.")
                }
            }
        }
        .tint(palette.accent)
        .fileImporter(isPresented: $choosingImport, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url):
                Task {
                    do {
                        pendingImport = try await Task.detached(priority: .userInitiated) { try SoundPresetPack.read(from: url) }.value
                        showingImportReview = true
                    } catch { message = error.localizedDescription }
                }
            case .failure(let error): message = error.localizedDescription
            }
        }
        .fileExporter(isPresented: $showingExport, document: exportDocument,
                      contentType: .json, defaultFilename: "HandStrudel Presets") { result in
            if case .failure(let error) = result { message = error.localizedDescription }
            exportDocument = nil
        }
        .confirmationDialog("Import HandStrudel presets?", isPresented: $showingImportReview, titleVisibility: .visible) {
            Button("Import presets") {
                guard let pendingImport else { return }
                self.pendingImport = nil
                do {
                    let count = try PersistenceManager.shared.importPresetPack(pendingImport)
                    setups = PersistenceManager.shared.loadSetups()
                    message = count == 0 ? "These presets are already saved on this device." : "Imported \(count) of \(pendingImport.presets.count) presets."
                } catch { message = error.localizedDescription }
            }
            Button("Cancel", role: .cancel) { pendingImport = nil }
        } message: {
            if let pendingImport {
                Text("This file contains \(pendingImport.presets.count) presets. Existing presets won't be replaced.")
            }
        }
        .alert("Presets", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(message ?? "") }
    }

    private func export(_ setups: [NamedSoundSetup]) {
        do {
            exportDocument = SoundPresetFile(data: try SoundPresetPack(setups).encoded())
            showingExport = true
        } catch { message = error.localizedDescription }
    }
}

private struct SoundPresetFile: FileDocument {
    static let readableContentTypes: [UTType] = [.json]
    let data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw CocoaError(.fileReadCorruptFile) }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
