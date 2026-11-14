import SwiftUI

struct StudioActionStyle: ButtonStyle {
    @Environment(\.studioPalette) private var palette
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 54)
            .padding(.horizontal, 18)
            .foregroundStyle(palette.onAccent)
            .background(palette.accent, in: RoundedRectangle(cornerRadius: 17))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct StartOverlayView: View {
    @Environment(\.studioPalette) private var palette
    let status: String
    @ObservedObject var engine: EngineController
    @ObservedObject var storeManager: StoreManager
    let starting: Bool
    let onStart: () -> Void
    let onDrafts: () -> Void
    let onSetups: () -> Void

    @State private var showSounds = false
    @State private var showAppearance = false
    @State private var showInstrumentSheet = false
    @State private var showProgressionSheet = false
    @State private var showScaleSheet = false
    @ScaledMetric(relativeTo: .largeTitle) private var headlineSize = 51.0

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    title
                    heroCard
                    Spacer(minLength: 0)
                    startButton
                    HStack {
                        Button(action: onDrafts) {
                            Label("Private drafts", systemImage: "film.stack")
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .accessibilityIdentifier("private-drafts-button")
                        Button(action: onSetups) {
                            Label("Presets", systemImage: "square.stack")
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .accessibilityIdentifier("music-presets-button")
                    }
                    .font(.subheadline.weight(.semibold))
                    .buttonStyle(.plain)
                    .foregroundStyle(palette.muted)
                    if status.hasPrefix("error:") {
                        Text(status).font(.footnote).foregroundStyle(.orange)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 18)
                .padding(.bottom, 20)
                .frame(maxWidth: 520)
                .frame(minHeight: geometry.size.height)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
        }
        .background(palette.background.ignoresSafeArea())
        .foregroundStyle(palette.ink)
        .tint(palette.accent)
        .sheet(isPresented: $showAppearance) { StudioThemePicker() }
        .sheet(isPresented: $showSounds) {
            soundsSheet
                .presentationDetents([.height(344), .large])
                .presentationDragIndicator(.visible)
        }
        .task {
            if storeManager.products.isEmpty {
                await storeManager.loadProducts()
            }
        }
    }

    private var soundsSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    instrumentChip
                    rowDivider
                    progressionChip
                    rowDivider
                    keyChip
                    rowDivider
                    scaleChip
                }
                .background(palette.surface, in: RoundedRectangle(cornerRadius: 18))
                .overlay { RoundedRectangle(cornerRadius: 18).strokeBorder(palette.border) }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 20)
            }
            .background(palette.background)
            .navigationTitle("Sounds")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showSounds = false }
                }
            }
        }
        .tint(palette.accent)
        .sheet(isPresented: $showInstrumentSheet) {
            InstrumentPickerSheet(selected: $engine.selectedSoundFontInstrument,
                                  storeManager: storeManager)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showProgressionSheet) {
            ProgressionPickerSheet(selected: $engine.chordMelodyProgression,
                                   storeManager: storeManager)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showScaleSheet) {
            ScalePickerSheet(selected: $engine.selectedScale,
                             storeManager: storeManager)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private var title: some View {
        VStack(alignment: .leading, spacing: 17) {
            HStack(spacing: 8) {
                Image(systemName: "waveform")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(palette.accent)
                    .accessibilityHidden(true)
                Text("handstrudel")
                    .font(.subheadline.monospaced().weight(.semibold))
                Spacer()
                Button { showAppearance = true } label: {
                    Image(systemName: "paintpalette")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(palette.accent)
                        .frame(width: 44, height: 44)
                        .background(palette.surface, in: Circle())
                        .overlay { Circle().strokeBorder(palette.border) }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Appearance")
                .accessibilityIdentifier("music-appearance")
            }
            VStack(alignment: .leading, spacing: 7) {
                Text("Play the air.")
                    .font(.system(size: headlineSize, weight: .regular, design: .serif))
                    .tracking(-2)
                    .accessibilityAddTraits(.isHeader)
                Text("Move your hands to make music.")
                    .font(.subheadline)
                    .foregroundStyle(palette.muted)
            }
        }
    }

    private var heroCard: some View {
        VStack(spacing: 0) {
            SoundArtwork(instrument: engine.selectedSoundFontInstrument, key: engine.selectedKey,
                         scale: engine.selectedScale, progression: engine.chordMelodyProgression)
                .frame(height: 225)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Sound artwork")
                .accessibilityValue("\(engine.selectedSoundFontInstrument.name), \(engine.selectedKey.rawValue) \(engine.selectedScale.rawValue), \(engine.chordMelodyProgression.name)")
                .accessibilityIdentifier("sound-artwork")
            Rectangle().fill(palette.border).frame(height: 1)
            Button { showSounds = true } label: {
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(engine.selectedSoundFontInstrument.name)
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(palette.ink)
                        Text("\(engine.selectedKey.rawValue) \(engine.selectedScale.rawValue)  /  \(engine.chordMelodyProgression.name)")
                            .font(.caption.monospaced())
                            .foregroundStyle(palette.muted)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(palette.accent)
                        .frame(width: 44, height: 44)
                        .background(palette.accent.opacity(0.09), in: Circle())
                }
                .padding(16)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Change sound")
            .accessibilityValue(engine.selectedSoundFontInstrument.name)
            .disabled(starting)
        }
        .background(palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 23))
        .overlay { RoundedRectangle(cornerRadius: 23).strokeBorder(palette.border).allowsHitTesting(false) }
    }

    private var instrumentChip: some View {
        Button(action: { showInstrumentSheet = true }) {
            soundRow("Instrument", value: engine.selectedSoundFontInstrument.name, icon: "waveform")
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("sounds-instrument")
    }

    private var progressionChip: some View {
        Button(action: { showProgressionSheet = true }) {
            soundRow("Chords", value: engine.chordMelodyProgression.name, icon: "music.note.list")
        }
        .buttonStyle(.plain)
    }

    private var keyChip: some View {
        Menu {
            ForEach(MusicKey.allCases) { key in
                Button(action: { engine.selectedKey = key }) {
                    if engine.selectedKey == key {
                        Label(key.rawValue, systemImage: "checkmark")
                    } else {
                        Text(key.rawValue)
                    }
                }
            }
        } label: {
            soundRow("Key", value: engine.selectedKey.rawValue, icon: "music.note", chevron: "chevron.up.chevron.down")
        }
    }

    /// Scale chip opens a sheet (not a Menu) because premium scales need a
    /// visible lock badge, which SwiftUI menus can't render.
    private var scaleChip: some View {
        Button(action: { showScaleSheet = true }) {
            soundRow("Scale", value: engine.selectedScale.rawValue, icon: "pianokeys")
        }
        .buttonStyle(.plain)
    }

    private var rowDivider: some View {
        Rectangle().fill(palette.border).frame(height: 1).padding(.leading, 53)
    }

    private func soundRow(_ title: String, value: String, icon: String, chevron: String = "chevron.right") -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body.weight(.medium))
                .foregroundStyle(palette.accent)
                .frame(width: 26)
                .accessibilityHidden(true)
            Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(palette.ink)
            Spacer(minLength: 0)
            Text(value)
                .font(.subheadline)
                .foregroundStyle(palette.muted)
                .multilineTextAlignment(.trailing)
            Image(systemName: chevron)
                .font(.caption.weight(.semibold))
                .foregroundStyle(palette.muted)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 13)
        .frame(minHeight: 53)
        .contentShape(Rectangle())
    }

    private var startButton: some View {
        Group {
            if starting {
                HStack(spacing: 10) {
                    ProgressView().tint(palette.accent)
                    Text(status).font(.caption.monospaced())
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: 54)
                .accessibilityElement(children: .combine)
            } else {
                Button(action: onStart) {
                    HStack {
                        Text("Start playing")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .accessibilityHidden(true)
                    }
                }
                .buttonStyle(StudioActionStyle())
                .accessibilityIdentifier("start-button")
            }
        }
    }
}

private struct SoundArtwork: View {
    @Environment(\.studioPalette) private var palette
    let instrument: SoundFontInstrument
    let key: MusicKey
    let scale: Scale
    let progression: ChordProgression

    var body: some View {
        Canvas { context, size in
            drawBackground(context, size: size)
            drawWeave(context, size: size)
            drawScale(context, size: size)
        }
    }

    private func drawBackground(_ context: GraphicsContext, size: CGSize) {
        let field = CGRect(origin: .zero, size: size)
        context.fill(Path(field), with: .radialGradient(
            Gradient(colors: [palette.glow, palette.background]),
            center: CGPoint(x: size.width * 0.55, y: size.height * 0.37),
            startRadius: 0, endRadius: max(size.width * 0.65, size.height)
        ))

        var grid = Path()
        for x in stride(from: 14.0, to: size.width, by: 14) {
            for y in stride(from: 14.0, to: size.height, by: 14) {
                grid.addEllipse(in: CGRect(x: x, y: y, width: 1.3, height: 1.3))
            }
        }
        context.fill(grid, with: .color(palette.muted.opacity(0.27)))
    }

    private func drawWeave(_ context: GraphicsContext, size: CGSize) {
        let voice = SoundArtworkVoice(instrument)
        let phase: Double = Double(key.semitone) * .pi / 6
        let intervals = scale.intervals
        let chords = Array(progression.degrees.prefix(16))
        let left = 17.0
        let width = max(1, Double(size.width) - left * 2)

        for line in 0..<voice.lines {
            let layer = Double(line) / Double(voice.lines - 1)
            var trace = Path()
            for step in 0...120 {
                let t = Double(step) / 120
                let envelope = pow(max(0, sin(t * .pi)), voice.envelope)
                let scalePosition = t * Double(intervals.count - 1)
                let scaleColor = interpolated(intervals, position: scalePosition) / 12
                let chordPosition = t * Double(max(0, chords.count - 1))
                let contour = interpolated(chords, position: chordPosition) / 6
                let base = 105 + (layer - 0.5) * voice.spread
                let shape = (scaleColor - 0.5) * 20 - (contour - 0.5) * 30
                let y = base + shape + voice.wave(t: t, layer: layer, phase: phase) * envelope
                let point = CGPoint(x: left + t * width, y: y)
                if step == 0 { trace.move(to: point) } else { trace.addLine(to: point) }
            }
            context.stroke(trace, with: .linearGradient(
                Gradient(colors: [palette.accent.opacity(0.10), palette.accent.opacity(0.85),
                                  palette.overtone.opacity(0.52)]),
                startPoint: .zero, endPoint: CGPoint(x: size.width, y: size.height * 0.2)
            ), lineWidth: line.isMultiple(of: 6) ? 1.4 : 0.65)
        }
    }

    private func drawScale(_ context: GraphicsContext, size: CGSize) {
        let left = 17.0
        let width = max(1, Double(size.width) - left * 2)
        let selected = Set(scale.intervals.map { ($0 + key.semitone) % 12 })
        for pitch in 0..<12 {
            let height = pitch == key.semitone ? 13.0 : selected.contains(pitch) ? 7 : 2
            let x = left + Double(pitch) * width / 11
            let tick = CGRect(x: x - 1, y: Double(size.height) - 18 - height, width: 2, height: height)
            let color = pitch == key.semitone ? palette.accent : palette.muted.opacity(selected.contains(pitch) ? 0.8 : 0.35)
            context.fill(Path(roundedRect: tick, cornerRadius: 1), with: .color(color))
        }
    }

    private func interpolated(_ values: [Int], position: Double) -> Double {
        guard !values.isEmpty else { return 3 }
        let index = min(Int(position), values.count - 1)
        let raw = position - Double(index)
        let eased = raw * raw * (3 - 2 * raw)
        return Double(values[index]) + Double(values[min(index + 1, values.count - 1)] - values[index]) * eased
    }
}

struct SoundArtworkVoice {
    enum Contour: Equatable { case bow, pulse, pluck, breath, ripple }

    let contour: Contour
    let program: Double
    let lines: Int
    let envelope: Double
    let spread: Double

    init(_ instrument: SoundFontInstrument) {
        program = Double(instrument.program)
        switch instrument.category {
        case .strings, .ensemble, .synthPad:
            (contour, lines, envelope, spread) = (.bow, 24, 0.7, 78)
        case .piano, .chromaticPercussion, .percussive:
            (contour, lines, envelope, spread) = (.pulse, 16, 0.45, 92)
        case .guitar, .bass, .ethnic:
            (contour, lines, envelope, spread) = (.pluck, 19, 0.55, 64)
        case .brass, .reed, .pipe:
            (contour, lines, envelope, spread) = (.breath, 20, 1.35, 50)
        default:
            (contour, lines, envelope, spread) = (.ripple, 22, 0.9, 70)
        }
    }

    func wave(t: Double, layer: Double, phase: Double) -> Double {
        let sweep = t * .pi
        let color = phase + program * 0.21
        let carrier = sin(sweep * (2.8 + program.truncatingRemainder(dividingBy: 9) * 0.25) + layer * 2.7 + color)
        let overtone = cos(sweep * (5 + program.truncatingRemainder(dividingBy: 6)) + layer * 4 + color)
        switch contour {
        case .bow: return carrier * 39 + overtone * 11
        case .pulse: return (pow(abs(carrier), 4) * 2 - 1) * (18 + layer * 17) + overtone * 8
        case .pluck: return carrier * 19 + overtone * 28 * (1 - t * 0.7)
        case .breath: return carrier * (23 + layer * 25) + overtone * 5
        case .ripple: return carrier * 25 + overtone * (9 + layer * 17)
        }
    }
}

// MARK: - Shared row bits

/// Small "PRO" pill drawn on locked rows. Kept in one place so instrument,
/// progression, and scale sheets all badge the same way.
private struct ProBadge: View {
    @Environment(\.studioPalette) private var palette
    var body: some View {
        Text("PRO")
            .font(.caption2.monospaced().weight(.semibold))
            .foregroundStyle(palette.accent)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(palette.accent.opacity(0.10), in: Capsule())
    }
}

/// Build the paywall the sheet pickers should show when the user taps a
/// locked row. All pickers gate against the single "pro" product, so the
/// copy lives in one place.
@MainActor
private func proPaywall(storeManager: StoreManager) -> some View {
    let resolved = StoreManager.productId(for: "pro")
    let product = storeManager.products.first(where: { $0.productIdentifier == resolved })
    return PaywallOverlay(
        packId: resolved,
        packName: "Pro Upgrade",
        packDescription: "Unlock every instrument, scale, and chord progression.",
        price: product?.localizedPriceString ?? "---",
        items: [
            "120+ additional GM instruments",
            "Every scale — modes, harmonic minor, exotic",
            "Every chord progression — jazz, cinematic, world, and more",
            "One-time purchase",
        ],
        storeManager: storeManager
    )
}

// MARK: - Instrument picker sheet

private struct InstrumentPickerSheet: View {
    @Environment(\.studioPalette) private var palette
    @Binding var selected: SoundFontInstrument
    @ObservedObject var storeManager: StoreManager
    @Environment(\.dismiss) private var dismiss
    @State private var category: GMCategory
    @State private var showPaywall = false

    init(selected: Binding<SoundFontInstrument>, storeManager: StoreManager) {
        self._selected = selected
        self.storeManager = storeManager
        self._category = State(initialValue: selected.wrappedValue.category)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(GMCategory.allCases) { cat in
                            categoryChip(cat)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
                .background(palette.surface)

                List(SOUNDFONT_INSTRUMENTS.filter { $0.category == category }) { inst in
                    row(for: inst)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .background(palette.background)
            .navigationTitle("Instrument")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showPaywall) {
                proPaywall(storeManager: storeManager)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    private func row(for inst: SoundFontInstrument) -> some View {
        let locked = inst.isPremium && !storeManager.isUnlocked(inst.packId ?? "")
        return Button(action: {
            if locked {
                showPaywall = true
            } else {
                selected = inst
                dismiss()
            }
        }) {
            HStack(spacing: 12) {
                Text(inst.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(locked ? palette.muted : palette.ink)
                if locked { ProBadge() }
                Spacer()
                if selected.id == inst.id && !locked {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(palette.accent)
                }
            }
        }
        .listRowBackground(palette.background)
        .accessibilityIdentifier("instrument-\(inst.id)")
    }

    private func categoryChip(_ cat: GMCategory) -> some View {
        let isActive = category == cat
        return Button(action: { category = cat }) {
            pickerCategory(cat.displayName, selected: isActive, palette: palette)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}

// MARK: - Progression picker sheet

private struct ProgressionPickerSheet: View {
    @Environment(\.studioPalette) private var palette
    @Binding var selected: ChordProgression
    @ObservedObject var storeManager: StoreManager
    @Environment(\.dismiss) private var dismiss
    @State private var category: ProgressionCategory
    @State private var showPaywall = false

    init(selected: Binding<ChordProgression>, storeManager: StoreManager) {
        self._selected = selected
        self.storeManager = storeManager
        let cat = selected.wrappedValue.category
        self._category = State(initialValue: cat == .custom ? .essentials : cat)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(ProgressionCategory.allCases.filter { $0 != .custom }) { cat in
                            categoryChip(cat)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
                .background(palette.surface)

                List(CHORD_PROGRESSIONS.filter { $0.category == category }) { prog in
                    row(for: prog)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .background(palette.background)
            .navigationTitle("Chord Progression")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showPaywall) {
                proPaywall(storeManager: storeManager)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    private func row(for prog: ChordProgression) -> some View {
        let locked = prog.isPremium && !storeManager.isUnlocked(prog.packId ?? "")
        return Button(action: {
            if locked {
                showPaywall = true
            } else {
                selected = prog
                dismiss()
            }
        }) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(prog.name)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(locked ? palette.muted : palette.ink)
                    Text("\(prog.degrees.count) chords")
                        .font(.caption)
                        .foregroundStyle(palette.muted)
                }
                if locked { ProBadge() }
                Spacer()
                if selected.id == prog.id && !locked {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(palette.accent)
                }
            }
        }
        .listRowBackground(palette.background)
    }

    private func categoryChip(_ cat: ProgressionCategory) -> some View {
        let isActive = category == cat
        return Button(action: { category = cat }) {
            pickerCategory(cat.displayName, selected: isActive, palette: palette)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}

// MARK: - Scale picker sheet

private struct ScalePickerSheet: View {
    @Environment(\.studioPalette) private var palette
    @Binding var selected: Scale
    @ObservedObject var storeManager: StoreManager
    @Environment(\.dismiss) private var dismiss
    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            List(Scale.allCases) { scale in
                row(for: scale)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(palette.background)
            .navigationTitle("Scale")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showPaywall) {
                proPaywall(storeManager: storeManager)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    private func row(for scale: Scale) -> some View {
        let locked = scale.isPremium && !storeManager.isUnlocked(scale.packId ?? "")
        return Button(action: {
            if locked {
                showPaywall = true
            } else {
                selected = scale
                dismiss()
            }
        }) {
            HStack(spacing: 12) {
                Text(scale.rawValue)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(locked ? palette.muted : palette.ink)
                if locked { ProBadge() }
                Spacer()
                if selected == scale && !locked {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(palette.accent)
                }
            }
        }
        .listRowBackground(palette.background)
    }
}

private func pickerCategory(_ title: String, selected: Bool, palette: StudioPalette) -> some View {
    Text(title)
        .font(.subheadline.weight(.medium))
        .foregroundStyle(selected ? palette.onAccent : palette.ink)
        .padding(.horizontal, 13)
        .padding(.vertical, 7)
        .background(selected ? palette.accent : palette.ink.opacity(0.06), in: Capsule())
        .frame(minHeight: 44)
        .contentShape(Rectangle())
}
