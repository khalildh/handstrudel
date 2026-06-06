import SwiftUI

struct StartOverlayView: View {
    let status: String
    @ObservedObject var storeManager: StoreManager
    let onStart: (MappingConfig, Bool) -> Void

    @State private var selectedPreset: Preset? = nil
    @State private var starting = false
    @State private var paywallPackId: String?

    private let columns = [
        GridItem(.flexible(), spacing: DS.Space.sm),
        GridItem(.flexible(), spacing: DS.Space.sm),
        GridItem(.flexible(), spacing: DS.Space.sm)
    ]

    private var selectedHue: Double {
        guard let p = selectedPreset else { return DS.signatureHue }
        return Self.hue(of: p.color)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                DS.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    hero
                        .frame(height: geo.size.height * 0.46)

                    picker

                    footer
                }
            }
        }
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

    // MARK: - Hero preview (live weave, retints to the selected sound)

    private var hero: some View {
        ZStack {
            WeaveView(hue: selectedHue, energy: 0.5, space: 0.6, brightness: 0.55, speed: 0.3, complexity: 0.5)
                .opacity(0.9)
                .mask(
                    LinearGradient(colors: [.black, .black, .clear],
                                   startPoint: .top, endPoint: .bottom)
                )

            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Text("hand")
                        .font(.system(size: 26, weight: .ultraLight, design: .monospaced))
                        .foregroundColor(DS.textPrimary)
                    Text("strudel")
                        .font(.system(size: 26, weight: .semibold, design: .monospaced))
                        .foregroundColor(DS.accent(selectedHue))
                }
                .padding(.top, DS.Space.md)

                Spacer()

                if let p = selectedPreset {
                    VStack(spacing: DS.Space.xxs) {
                        Text(p.name)
                            .font(.dsTitle)
                            .foregroundColor(DS.textPrimary)
                        Text(p.description)
                            .font(.dsCallout)
                            .foregroundColor(DS.textSecondary)
                    }
                    .transition(.opacity)
                } else {
                    Text("Pick a sound")
                        .font(.dsTitle3)
                        .foregroundColor(DS.textTertiary)
                }
            }
            .padding(.bottom, DS.Space.lg)
        }
    }

    // MARK: - Picker

    private var picker: some View {
        ScrollView(showsIndicators: false) {
            LazyVGrid(columns: columns, spacing: DS.Space.sm) {
                ForEach(PRESETS) { preset in
                    let locked = preset.isPremium && !storeManager.isUnlocked(preset.packId ?? "")
                    PresetTile(
                        preset: preset,
                        isSelected: selectedPreset?.id == preset.id,
                        isLocked: locked
                    )
                    .onTapGesture {
                        if locked, let packId = preset.packId {
                            paywallPackId = packId
                        } else {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                selectedPreset = preset
                            }
                        }
                    }
                    .accessibilityIdentifier("preset-\(preset.name)")
                }
            }
            .padding(.horizontal, DS.Space.lg)
            .padding(.top, DS.Space.xs)
            .padding(.bottom, DS.Space.md)
        }
    }

    // MARK: - Footer (CTA)

    private var footer: some View {
        VStack(spacing: 0) {
            if starting {
                HStack(spacing: DS.Space.xs) {
                    ProgressView().tint(DS.accent(selectedHue))
                    Text(status)
                        .font(.dsMono(12))
                        .foregroundColor(DS.textSecondary)
                }
                .frame(height: 54)
            } else {
                Button(action: startTapped) {
                    Text(selectedPreset == nil ? "Pick a sound to begin" : "Start playing")
                }
                .buttonStyle(DSPrimaryButtonStyle(accent: DS.accent(selectedHue), enabled: selectedPreset != nil))
                .disabled(selectedPreset == nil)
                .accessibilityIdentifier("lets-go-button")
            }
        }
        .padding(.horizontal, DS.Space.lg)
        .padding(.top, DS.Space.xs)
        .padding(.bottom, DS.Space.md)
    }

    // MARK: - Actions

    private func startTapped() {
        guard let preset = selectedPreset else { return }
        starting = true
        onStart(preset.mapping, false)
    }

    // MARK: - Color helper

    /// RGB (0…1) → hue (0…1), so a preset's color drives the live weave.
    static func hue(of c: (Double, Double, Double)) -> Double {
        let r = c.0, g = c.1, b = c.2
        let maxv = max(r, g, b), minv = min(r, g, b)
        let d = maxv - minv
        if d < 0.0001 { return DS.signatureHue }
        var h: Double
        if maxv == r { h = (g - b) / d; h = h.truncatingRemainder(dividingBy: 6) }
        else if maxv == g { h = (b - r) / d + 2 }
        else { h = (r - g) / d + 4 }
        h /= 6
        return h < 0 ? h + 1 : h
    }

    // MARK: - Paywall plumbing

    private func paywallSheet(for packId: String) -> some View {
        let info = paywallInfo(for: packId)
        let resolvedId = StoreManager.productId(for: packId)
        let product = storeManager.products.first(where: { $0.productIdentifier == resolvedId })
        return PaywallOverlay(
            packId: resolvedId,
            packName: info.name,
            packDescription: info.description,
            price: product?.localizedPriceString ?? "---",
            items: info.items,
            storeManager: storeManager
        )
    }

    private func paywallInfo(for packId: String) -> (name: String, description: String, items: [String]) {
        let resolved = StoreManager.productId(for: packId)
        switch resolved {
        case StoreManager.studioPack: return ("Studio Pack", "7 professional studio presets", ["Tape", "Glass", "Deep", "Foggy", "Pulse", "Cosmic", "Glitch"])
        case StoreManager.partyPack: return ("Party Pack", "9 high-energy party presets", ["EDM", "DnB", "Dubstep", "Rave", "Reggaeton", "Future Bass", "Techno", "Garage", "Phonk"])
        case StoreManager.pro: return ("Pro Upgrade", "Unlock everything", ["Premium scales", "Camera filters", "Hand themes"])
        default: return ("Pack", "Premium content", [])
        }
    }
}

// MARK: - Preset tile (compact picker cell)

struct PresetTile: View {
    let preset: Preset
    let isSelected: Bool
    var isLocked: Bool = false

    private var tint: Color {
        let (r, g, b) = preset.color
        let maxC = max(r, max(g, b))
        let boost = maxC < 0.55 ? 0.55 / max(maxC, 0.01) : 1.0
        return Color(red: min(r * boost, 1), green: min(g * boost, 1), blue: min(b * boost, 1))
    }

    var body: some View {
        VStack(spacing: DS.Space.xxs) {
            Text(preset.emoji)
                .font(.system(size: 24))
            Text(preset.name)
                .font(.dsCaption)
                .foregroundColor(isSelected ? DS.textPrimary : DS.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 68)
        .dsCard(radius: DS.Radius.chip, selected: isSelected, accent: tint)
        .overlay(alignment: .topTrailing) {
            if isLocked { ProBadge(compact: true).padding(DS.Space.xs) }
        }
        .opacity(isLocked ? 0.6 : 1.0)
    }
}
