import SwiftUI

struct StartOverlayView: View {
    let status: String
    @ObservedObject var engine: EngineController
    @ObservedObject var storeManager: StoreManager
    let onStart: () -> Void

    @State private var starting = false
    @State private var showInstrumentSheet = false
    @State private var showProgressionSheet = false

    var body: some View {
        GeometryReader { _ in
            ZStack {
                LinearGradient(
                    colors: [Color.black, Color(white: 0.06), Color.black],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer(minLength: 24)

                    title
                        .padding(.bottom, 36)

                    heroCard
                        .padding(.horizontal, 24)
                        .padding(.bottom, 22)

                    chipGrid
                        .padding(.horizontal, 24)

                    Spacer()

                    startButton
                        .padding(.horizontal, 24)
                        .padding(.bottom, 32)
                }
            }
        }
        .sheet(isPresented: $showInstrumentSheet) {
            InstrumentPickerSheet(selected: $engine.selectedSoundFontInstrument)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showProgressionSheet) {
            ProgressionPickerSheet(selected: $engine.chordMelodyProgression)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Title

    private var title: some View {
        VStack(spacing: 10) {
            HStack(spacing: 0) {
                Text("hand")
                    .font(.system(size: 44, weight: .ultraLight, design: .monospaced))
                    .foregroundColor(.white.opacity(0.7))
                Text("strudel")
                    .font(.system(size: 44, weight: .bold, design: .monospaced))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.green, .cyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }
            Text("your hands are the instrument")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.45))
        }
    }

    // MARK: - Hero card

    private var heroCard: some View {
        VStack(spacing: 10) {
            Text(engine.selectedSoundFontInstrument.emoji)
                .font(.system(size: 54))

            Text(engine.selectedSoundFontInstrument.name)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            HStack(spacing: 6) {
                Text("\(engine.selectedKey.rawValue) \(engine.selectedScale.rawValue)")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.7))
                Text("·")
                    .foregroundColor(.white.opacity(0.35))
                Text(engine.chordMelodyProgression.emoji)
                    .font(.system(size: 13))
                Text(engine.chordMelodyProgression.name)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(
                    LinearGradient(
                        colors: [Color.green.opacity(0.10), Color.cyan.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Chips

    private var chipGrid: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                instrumentChip
                progressionChip
            }
            HStack(spacing: 10) {
                keyChip
                scaleChip
            }
        }
    }

    private var instrumentChip: some View {
        Button(action: { showInstrumentSheet = true }) {
            chipBody(
                emoji: engine.selectedSoundFontInstrument.emoji,
                caption: "INSTRUMENT",
                value: engine.selectedSoundFontInstrument.name
            )
        }
    }

    private var progressionChip: some View {
        Button(action: { showProgressionSheet = true }) {
            chipBody(
                emoji: engine.chordMelodyProgression.emoji,
                caption: "CHORDS",
                value: engine.chordMelodyProgression.name
            )
        }
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
            chipBody(emoji: nil, caption: "KEY", value: engine.selectedKey.rawValue)
        }
    }

    private var scaleChip: some View {
        Menu {
            ForEach(Scale.allCases) { scale in
                Button(action: { engine.selectedScale = scale }) {
                    if engine.selectedScale == scale {
                        Label(scale.rawValue, systemImage: "checkmark")
                    } else {
                        Text(scale.rawValue)
                    }
                }
            }
        } label: {
            chipBody(emoji: nil, caption: "SCALE", value: engine.selectedScale.rawValue)
        }
    }

    private func chipBody(emoji: String?, caption: String, value: String) -> some View {
        HStack(spacing: 10) {
            if let emoji {
                Text(emoji).font(.system(size: 22))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(caption)
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .tracking(1.2)
                    .foregroundColor(.white.opacity(0.35))
                Text(value)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.down")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white.opacity(0.35))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Start button

    private var startButton: some View {
        Group {
            if starting {
                VStack(spacing: 8) {
                    ProgressView().tint(.green)
                    Text(status)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.green.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 58)
            } else {
                Button(action: {
                    starting = true
                    onStart()
                }) {
                    Text("START")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .tracking(2)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 58)
                        .background(
                            LinearGradient(
                                colors: [.green, Color(red: 0.0, green: 0.8, blue: 0.6)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(18)
                        .shadow(color: .green.opacity(0.4), radius: 18)
                }
                .accessibilityIdentifier("start-button")
            }
        }
    }
}

// MARK: - Instrument picker sheet

private struct InstrumentPickerSheet: View {
    @Binding var selected: SoundFontInstrument
    @Environment(\.dismiss) private var dismiss
    @State private var category: GMCategory

    init(selected: Binding<SoundFontInstrument>) {
        self._selected = selected
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
                .background(Color(white: 0.08))

                List(SOUNDFONT_INSTRUMENTS.filter { $0.category == category }) { inst in
                    Button(action: {
                        selected = inst
                        dismiss()
                    }) {
                        HStack(spacing: 12) {
                            Text(inst.emoji).font(.system(size: 22))
                            Text(inst.name)
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundColor(.primary)
                            Spacer()
                            if selected.id == inst.id {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.green)
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Instrument")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func categoryChip(_ cat: GMCategory) -> some View {
        let isActive = category == cat
        return Button(action: { category = cat }) {
            HStack(spacing: 5) {
                Text(cat.emoji).font(.system(size: 12))
                Text(cat.displayName)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(isActive ? .green : .primary.opacity(0.7))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                Capsule().fill(isActive ? Color.green.opacity(0.15) : Color.primary.opacity(0.05))
            )
        }
    }
}

// MARK: - Progression picker sheet

private struct ProgressionPickerSheet: View {
    @Binding var selected: ChordProgression
    @Environment(\.dismiss) private var dismiss
    @State private var category: ProgressionCategory

    init(selected: Binding<ChordProgression>) {
        self._selected = selected
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
                .background(Color(white: 0.08))

                List(CHORD_PROGRESSIONS.filter { $0.category == category }) { prog in
                    Button(action: {
                        selected = prog
                        dismiss()
                    }) {
                        HStack(spacing: 12) {
                            Text(prog.emoji).font(.system(size: 22))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(prog.name)
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    .foregroundColor(.primary)
                                Text("\(prog.degrees.count) chords")
                                    .font(.system(size: 11, design: .rounded))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if selected.id == prog.id {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.green)
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Chord Progression")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func categoryChip(_ cat: ProgressionCategory) -> some View {
        let isActive = category == cat
        return Button(action: { category = cat }) {
            HStack(spacing: 5) {
                Text(cat.emoji).font(.system(size: 12))
                Text(cat.displayName)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(isActive ? .green : .primary.opacity(0.7))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                Capsule().fill(isActive ? Color.green.opacity(0.15) : Color.primary.opacity(0.05))
            )
        }
    }
}
