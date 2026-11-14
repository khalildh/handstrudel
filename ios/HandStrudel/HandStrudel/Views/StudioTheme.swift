import SwiftUI

enum StudioTheme: String, CaseIterable, Identifiable {
    case volt, tide, afterglow, paper

    static let storageKey = "studioTheme"
    var id: Self { self }

    var title: String {
        switch self {
        case .volt: return "Volt"
        case .tide: return "Deep Tide"
        case .afterglow: return "Afterglow"
        case .paper: return "Paper & Ink"
        }
    }

    var subtitle: String {
        switch self {
        case .volt: return "Lime on charcoal"
        case .tide: return "Glacier blue on deep navy"
        case .afterglow: return "Honey and coral on indigo"
        case .paper: return "Rust red on warm ivory"
        }
    }

    var colorScheme: ColorScheme { self == .paper ? .light : .dark }

    var palette: StudioPalette {
        switch self {
        case .volt:
            return .init(background: 0x0A0C0C, surface: 0x141816, ink: 0xF3F6EE, muted: 0xA5AFA5,
                         accent: 0xD3F974, onAccent: 0x0A0C0C, mediaAccent: 0xD3F974,
                         glow: 0x2B401F, overtone: 0x42BD8C)
        case .tide:
            return .init(background: 0x081320, surface: 0x102339, ink: 0xF0F8FF, muted: 0xA1B9D0,
                         accent: 0x84E5FF, onAccent: 0x081320, mediaAccent: 0x84E5FF,
                         glow: 0x15405D, overtone: 0x8B9DFF)
        case .afterglow:
            return .init(background: 0x181326, surface: 0x292038, ink: 0xFFF4E8, muted: 0xC2AFC5,
                         accent: 0xFFBE76, onAccent: 0x241625, mediaAccent: 0xFFBE76,
                         glow: 0x533047, overtone: 0xFF7D9C)
        case .paper:
            return .init(background: 0xFAF4E8, surface: 0xEFE4D2, ink: 0x261C19, muted: 0x614B41,
                         accent: 0x963424, onAccent: 0xFFF8EF, mediaAccent: 0xFFAA92,
                         glow: 0xEFD2AD, overtone: 0xB75447, borderOpacity: 0.17)
        }
    }
}

struct StudioPalette {
    let background: Color
    let surface: Color
    let ink: Color
    let muted: Color
    let accent: Color
    let onAccent: Color
    let mediaAccent: Color
    let mediaOnAccent: Color
    let glow: Color
    let overtone: Color
    let border: Color
    var recording: Color { Color(rgb: 0xFF524F) }

    init(background: UInt32, surface: UInt32, ink: UInt32, muted: UInt32, accent: UInt32,
         onAccent: UInt32, mediaAccent: UInt32, glow: UInt32, overtone: UInt32, borderOpacity: Double = 0.12) {
        self.background = Color(rgb: background)
        self.surface = Color(rgb: surface)
        self.ink = Color(rgb: ink)
        self.muted = Color(rgb: muted)
        self.accent = Color(rgb: accent)
        self.onAccent = Color(rgb: onAccent)
        self.mediaAccent = Color(rgb: mediaAccent)
        mediaOnAccent = Color(rgb: mediaAccent == accent ? onAccent : 0x25100C)
        self.glow = Color(rgb: glow)
        self.overtone = Color(rgb: overtone)
        border = Color(rgb: ink).opacity(borderOpacity)
    }
}

private extension Color {
    init(rgb: UInt32) {
        self.init(red: Double((rgb >> 16) & 255) / 255, green: Double((rgb >> 8) & 255) / 255,
                  blue: Double(rgb & 255) / 255)
    }
}

private struct StudioPaletteKey: EnvironmentKey {
    static let defaultValue = StudioTheme.volt.palette
}

extension EnvironmentValues {
    var studioPalette: StudioPalette {
        get { self[StudioPaletteKey.self] }
        set { self[StudioPaletteKey.self] = newValue }
    }
}

struct StudioThemePicker: View {
    @AppStorage(StudioTheme.storageKey) private var theme: StudioTheme = .volt
    @Environment(\.dismiss) private var dismiss
    @Environment(\.studioPalette) private var palette

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Choose the look of your studio and feed.")
                        .font(.subheadline)
                        .foregroundStyle(palette.muted)
                        .padding(.bottom, 4)
                    ForEach(StudioTheme.allCases) { option in
                        Button { theme = option } label: {
                            themeCard(option)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("theme-\(option.rawValue)")
                        .accessibilityLabel(option.title)
                        .accessibilityHint(option.subtitle)
                        .accessibilityAddTraits(theme == option ? .isSelected : [])
                    }
                }
                .padding(20)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
            .background(palette.background.ignoresSafeArea())
            .navigationTitle("Appearance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .tint(palette.accent)
    }

    private func themeCard(_ option: StudioTheme) -> some View {
        let sample = option.palette
        return HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 11)
                .fill(LinearGradient(colors: [sample.glow, sample.background], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 58, height: 54)
                .overlay {
                    Image(systemName: "waveform")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(sample.accent)
                }
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(option.title).font(.system(.title3, design: .serif)).foregroundStyle(palette.ink)
                Text(option.subtitle).font(.caption).foregroundStyle(palette.muted)
            }
            Spacer(minLength: 4)
            Image(systemName: theme == option ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(theme == option ? palette.accent : palette.muted)
                .accessibilityHidden(true)
        }
        .padding(11)
        .frame(minHeight: 76)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(theme == option ? palette.accent : palette.border) }
        .contentShape(RoundedRectangle(cornerRadius: 16))
    }
}
