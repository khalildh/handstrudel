import SwiftUI

enum StudioStyle {
    static let background = Color(red: 0.040, green: 0.049, blue: 0.048)
    static let surface = Color(red: 0.079, green: 0.094, blue: 0.087)
    static let ink = Color(red: 0.953, green: 0.964, blue: 0.932)
    static let muted = Color(red: 0.647, green: 0.685, blue: 0.648)
    static let accent = Color(red: 0.828, green: 0.974, blue: 0.455)
    static let border = Color.white.opacity(0.12)
    static let recording = Color(red: 1, green: 0.32, blue: 0.31)
}

struct StudioActionStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 54)
            .padding(.horizontal, 18)
            .foregroundStyle(StudioStyle.background)
            .background(StudioStyle.accent.opacity(configuration.isPressed ? 0.80 : 1),
                        in: RoundedRectangle(cornerRadius: 17))
    }
}

struct StartOverlayView: View {
    let status: String
    @ObservedObject var engine: EngineController
    @ObservedObject var storeManager: StoreManager
    let starting: Bool
    let onStart: () -> Void
    let onDrafts: () -> Void
    let onSetups: () -> Void

    @State private var showSounds = false
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
                            Label("Saved setups", systemImage: "bookmark")
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                    .buttonStyle(.plain)
                    .foregroundStyle(StudioStyle.muted)
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
        .background(StudioStyle.background.ignoresSafeArea())
        .foregroundStyle(StudioStyle.ink)
        .tint(StudioStyle.accent)
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
                .background(StudioStyle.surface, in: RoundedRectangle(cornerRadius: 18))
                .overlay { RoundedRectangle(cornerRadius: 18).strokeBorder(StudioStyle.border) }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 20)
            }
            .background(StudioStyle.background)
            .navigationTitle("Sounds")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showSounds = false }
                }
            }
        }
        .tint(StudioStyle.accent)
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
                    .foregroundStyle(StudioStyle.accent)
                    .accessibilityHidden(true)
                Text("handstrudel")
                    .font(.subheadline.monospaced().weight(.semibold))
            }
            VStack(alignment: .leading, spacing: 7) {
                Text("Play the air.")
                    .font(.system(size: headlineSize, weight: .regular, design: .serif))
                    .tracking(-2)
                    .accessibilityAddTraits(.isHeader)
                Text("Move your hands to make music.")
                    .font(.subheadline)
                    .foregroundStyle(StudioStyle.muted)
            }
        }
    }

    private var heroCard: some View {
        VStack(spacing: 0) {
            SoundArtwork(program: Int(engine.selectedSoundFontInstrument.program))
                .frame(height: 225)
                .accessibilityHidden(true)
            Rectangle().fill(StudioStyle.border).frame(height: 1)
            Button { showSounds = true } label: {
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(engine.selectedSoundFontInstrument.name)
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(StudioStyle.ink)
                        Text("\(engine.selectedKey.rawValue) \(engine.selectedScale.rawValue)  /  \(engine.chordMelodyProgression.name)")
                            .font(.caption.monospaced())
                            .foregroundStyle(StudioStyle.muted)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(StudioStyle.accent)
                        .frame(width: 44, height: 44)
                        .background(StudioStyle.accent.opacity(0.09), in: Circle())
                }
                .padding(16)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Change sound")
            .accessibilityValue(engine.selectedSoundFontInstrument.name)
            .disabled(starting)
        }
        .background(StudioStyle.surface)
        .clipShape(RoundedRectangle(cornerRadius: 23))
        .overlay { RoundedRectangle(cornerRadius: 23).strokeBorder(StudioStyle.border).allowsHitTesting(false) }
    }

    private var instrumentChip: some View {
        Button(action: { showInstrumentSheet = true }) {
            soundRow("Instrument", value: engine.selectedSoundFontInstrument.name, icon: "waveform")
        }
        .buttonStyle(.plain)
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
        Rectangle().fill(StudioStyle.border).frame(height: 1).padding(.leading, 53)
    }

    private func soundRow(_ title: String, value: String, icon: String, chevron: String = "chevron.right") -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body.weight(.medium))
                .foregroundStyle(StudioStyle.accent)
                .frame(width: 26)
                .accessibilityHidden(true)
            Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(StudioStyle.ink)
            Spacer(minLength: 0)
            Text(value)
                .font(.subheadline)
                .foregroundStyle(StudioStyle.muted)
                .multilineTextAlignment(.trailing)
            Image(systemName: chevron)
                .font(.caption.weight(.semibold))
                .foregroundStyle(StudioStyle.muted)
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
                    ProgressView().tint(StudioStyle.accent)
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
    let program: Int

    var body: some View {
        Canvas { context, size in
            let field = CGRect(origin: .zero, size: size)
            context.fill(Path(field), with: .radialGradient(
                Gradient(colors: [Color(red: 0.17, green: 0.25, blue: 0.12), StudioStyle.background]),
                center: CGPoint(x: size.width * 0.55, y: size.height * 0.37),
                startRadius: 0, endRadius: max(size.width * 0.65, size.height)
            ))

            var grid = Path()
            for x in stride(from: 14.0, to: size.width, by: 14) {
                for y in stride(from: 14.0, to: size.height, by: 14) {
                    grid.addEllipse(in: CGRect(x: x, y: y, width: 1.3, height: 1.3))
                }
            }
            context.fill(grid, with: .color(StudioStyle.muted.opacity(0.27)))

            // Each GM program changes the phase and harmonics of the weave.
            let phase = Double(program) * 0.19
            let harmonic = Double(2 + program % 4)
            for line in 0..<25 {
                let layer = Double(line) / 24
                var trace = Path()
                for step in 0...120 {
                    let t = Double(step) / 120
                    let envelope = pow(max(0, sin(t * .pi)), 0.78)
                    let fundamental = sin(t * .pi * 3.1 + layer * 2.7 + phase)
                    let overtone = cos(t * .pi * harmonic + layer * 4 + phase)
                    let y = size.height * (0.29 + layer * 0.39)
                        + (fundamental * 43 + overtone * 18) * envelope
                    let point = CGPoint(x: 17 + t * (size.width - 34), y: y)
                    if step == 0 { trace.move(to: point) } else { trace.addLine(to: point) }
                }
                context.stroke(trace, with: .linearGradient(
                    Gradient(colors: [StudioStyle.accent.opacity(0.10), StudioStyle.accent.opacity(0.85),
                                      Color(red: 0.26, green: 0.74, blue: 0.55).opacity(0.34)]),
                    startPoint: .zero, endPoint: CGPoint(x: size.width, y: size.height * 0.2)
                ), lineWidth: line.isMultiple(of: 6) ? 1.4 : 0.65)
            }
        }
    }
}

// MARK: - Shared row bits

/// Small "PRO" pill drawn on locked rows. Kept in one place so instrument,
/// progression, and scale sheets all badge the same way.
private struct ProBadge: View {
    var body: some View {
        Text("PRO")
            .font(.caption2.monospaced().weight(.semibold))
            .foregroundStyle(StudioStyle.accent)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(StudioStyle.accent.opacity(0.10), in: Capsule())
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
                .background(StudioStyle.surface)

                List(SOUNDFONT_INSTRUMENTS.filter { $0.category == category }) { inst in
                    row(for: inst)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .background(StudioStyle.background)
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
                    .foregroundStyle(locked ? StudioStyle.muted : StudioStyle.ink)
                if locked { ProBadge() }
                Spacer()
                if selected.id == inst.id && !locked {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(StudioStyle.accent)
                }
            }
        }
        .listRowBackground(StudioStyle.background)
    }

    private func categoryChip(_ cat: GMCategory) -> some View {
        let isActive = category == cat
        return Button(action: { category = cat }) {
            pickerCategory(cat.displayName, selected: isActive)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}

// MARK: - Progression picker sheet

private struct ProgressionPickerSheet: View {
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
                .background(StudioStyle.surface)

                List(CHORD_PROGRESSIONS.filter { $0.category == category }) { prog in
                    row(for: prog)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .background(StudioStyle.background)
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
                        .foregroundStyle(locked ? StudioStyle.muted : StudioStyle.ink)
                    Text("\(prog.degrees.count) chords")
                        .font(.caption)
                        .foregroundStyle(StudioStyle.muted)
                }
                if locked { ProBadge() }
                Spacer()
                if selected.id == prog.id && !locked {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(StudioStyle.accent)
                }
            }
        }
        .listRowBackground(StudioStyle.background)
    }

    private func categoryChip(_ cat: ProgressionCategory) -> some View {
        let isActive = category == cat
        return Button(action: { category = cat }) {
            pickerCategory(cat.displayName, selected: isActive)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}

// MARK: - Scale picker sheet

private struct ScalePickerSheet: View {
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
            .background(StudioStyle.background)
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
                    .foregroundStyle(locked ? StudioStyle.muted : StudioStyle.ink)
                if locked { ProBadge() }
                Spacer()
                if selected == scale && !locked {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(StudioStyle.accent)
                }
            }
        }
        .listRowBackground(StudioStyle.background)
    }
}

private func pickerCategory(_ title: String, selected: Bool) -> some View {
    Text(title)
        .font(.subheadline.weight(.medium))
        .foregroundStyle(selected ? StudioStyle.background : StudioStyle.ink)
        .padding(.horizontal, 13)
        .padding(.vertical, 7)
        .background(selected ? StudioStyle.accent : Color.white.opacity(0.06), in: Capsule())
        .frame(minHeight: 44)
        .contentShape(Rectangle())
}
