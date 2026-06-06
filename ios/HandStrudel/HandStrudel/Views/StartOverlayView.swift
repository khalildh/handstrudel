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
        GridItem(.flexible(), spacing: DS.Space.sm)
    ]

    var body: some View {
        ZStack {
            DS.background.ignoresSafeArea()

            // A single, restrained accent glow at the top — the one expressive
            // element, drifting slowly through the spectrum.
            AmbientAccent(period: 30, sat: 0.7) { color, _ in
                RadialGradient(
                    colors: [color.opacity(0.16), .clear],
                    center: .top, startRadius: 0, endRadius: 360
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)
            }

            VStack(spacing: 0) {
                header
                    .padding(.top, DS.Space.xl)
                    .padding(.bottom, DS.Space.lg)

                presetGrid

                footer
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

    // MARK: - Header

    private var header: some View {
        VStack(spacing: DS.Space.sm) {
            AmbientAccent(period: 30) { color, _ in
                HStack(spacing: 0) {
                    Text("hand")
                        .font(.system(size: 40, weight: .ultraLight, design: .monospaced))
                        .foregroundColor(DS.textPrimary)
                    Text("strudel")
                        .font(.system(size: 40, weight: .semibold, design: .monospaced))
                        .foregroundColor(color)
                }
            }
            .frame(height: 48)

            Text("Your hands are the instrument")
                .font(.dsCallout)
                .foregroundColor(DS.textSecondary)
        }
    }

    // MARK: - Preset grid

    private var presetGrid: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: DS.Space.sm) {
                DSSectionHeader("Pick a sound")
                    .padding(.horizontal, DS.Space.xxs)

                LazyVGrid(columns: columns, spacing: DS.Space.sm) {
                    ForEach(PRESETS) { preset in
                        let locked = preset.isPremium && !storeManager.isUnlocked(preset.packId ?? "")
                        PresetCard(
                            preset: preset,
                            isSelected: selectedPreset?.id == preset.id,
                            isLocked: locked
                        )
                        .onTapGesture {
                            if locked, let packId = preset.packId {
                                paywallPackId = packId
                            } else {
                                withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                                    selectedPreset = preset
                                }
                            }
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("preset-\(preset.name)")
                    }
                }
            }
            .padding(.horizontal, DS.Space.lg)
            .padding(.bottom, DS.Space.md)
        }
    }

    // MARK: - Footer (CTA)

    private var footer: some View {
        VStack(spacing: DS.Space.sm) {
            if starting {
                HStack(spacing: DS.Space.xs) {
                    ProgressView().tint(DS.signature)
                    Text(status)
                        .font(.dsMono(12))
                        .foregroundColor(DS.textSecondary)
                }
                .frame(height: 54)
            } else {
                AmbientAccent(period: 30) { color, _ in
                    Button(action: startTapped) {
                        Text(selectedPreset == nil ? "Pick a sound to begin" : "Start playing")
                    }
                    .buttonStyle(DSPrimaryButtonStyle(accent: color, enabled: selectedPreset != nil))
                    .disabled(selectedPreset == nil)
                    .accessibilityIdentifier("lets-go-button")
                }
                .frame(height: 54)
            }
        }
        .padding(.horizontal, DS.Space.lg)
        .padding(.top, DS.Space.sm)
        .padding(.bottom, DS.Space.md)
    }

    // MARK: - Actions

    private func startTapped() {
        guard let preset = selectedPreset else { return }
        starting = true
        onStart(preset.mapping, false)
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

// MARK: - Preset card

struct PresetCard: View {
    let preset: Preset
    let isSelected: Bool
    var isLocked: Bool = false

    private var presetColor: Color {
        // Lift dark preset colors so they stay legible as an accent on black.
        let (r, g, b) = preset.color
        let maxC = max(r, max(g, b))
        let boost = maxC < 0.55 ? 0.55 / max(maxC, 0.01) : 1.0
        return Color(red: min(r * boost, 1), green: min(g * boost, 1), blue: min(b * boost, 1))
    }

    var body: some View {
        HStack(spacing: DS.Space.sm) {
            IconTile(emoji: preset.emoji, tint: presetColor, size: 46)

            VStack(alignment: .leading, spacing: 2) {
                Text(preset.name)
                    .font(.dsHeadline)
                    .foregroundColor(DS.textPrimary)
                Text(preset.description)
                    .font(.dsCaption)
                    .foregroundColor(DS.textTertiary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(DS.Space.sm)
        .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
        .dsCard(selected: isSelected, accent: presetColor)
        .overlay(alignment: .topTrailing) {
            if isLocked { ProBadge().padding(DS.Space.xs) }
        }
        .opacity(isLocked ? 0.6 : 1.0)
        .scaleEffect(isSelected ? 1.02 : 1.0)
    }
}
