import SwiftUI

struct StoreView: View {
    @ObservedObject var storeManager: StoreManager
    @State private var plusToggle: PlusPeriod = .monthly

    enum PlusPeriod { case monthly, yearly }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                // Title
                Text("STORE")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.top, 16)

                // Preset Packs
                sectionHeader("PRESET PACKS")
                packRow(
                    id: StoreManager.studioPack,
                    name: "Studio Pack",
                    emoji: "🎛️",
                    contents: ["Studio preset", "Cinematic preset"],
                    description: "Professional studio presets"
                )
                packRow(
                    id: StoreManager.partyPack,
                    name: "Party Pack",
                    emoji: "🎉",
                    contents: ["Party preset", "Rave preset"],
                    description: "High-energy party presets"
                )
                packRow(
                    id: StoreManager.experimentalPack,
                    name: "Experimental Pack",
                    emoji: "🧪",
                    contents: ["Glitch preset", "Ambient preset"],
                    description: "Experimental sound presets"
                )

                // Sound Packs
                sectionHeader("SOUND PACKS")
                packRow(
                    id: StoreManager.analogPack,
                    name: "Analog Pack",
                    emoji: "📻",
                    contents: ["FM synth", "Supersaw", "Pulse"],
                    description: "Warm analog-style waveforms"
                )
                packRow(
                    id: StoreManager.texturePack,
                    name: "Texture Pack",
                    emoji: "🌊",
                    contents: ["Noise", "Metallic", "Pad"],
                    description: "Textural sound sources"
                )
                packRow(
                    id: StoreManager.vocalPack,
                    name: "Vocal Pack",
                    emoji: "🎤",
                    contents: ["Choir", "Formant", "Whisper"],
                    description: "Vocal synthesis sounds"
                )

                // Drum Kits
                sectionHeader("DRUM KITS")
                packRow(
                    id: StoreManager.kit808,
                    name: "808 Kit",
                    emoji: "🥁",
                    contents: ["808 kick", "808 snare", "808 hat patterns"],
                    description: "Classic 808 drum machine"
                )
                packRow(
                    id: StoreManager.kitElectronic,
                    name: "Electronic Kit",
                    emoji: "⚡",
                    contents: ["Electro kick", "Glitch snare", "Digital hat patterns"],
                    description: "Modern electronic drums"
                )
                packRow(
                    id: StoreManager.kitWorld,
                    name: "World Kit",
                    emoji: "🌍",
                    contents: ["Djembe", "Tabla", "World percussion patterns"],
                    description: "World percussion drums"
                )

                // Pro
                sectionHeader("PRO")
                proRow

                // HandStrudel+
                sectionHeader("HANDSTRUDEL+")
                subscriptionRow

                // Restore
                Button(action: {
                    Task { await storeManager.restorePurchases() }
                }) {
                    Text("Restore Purchases")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.4))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .padding(.bottom, 20)
            }
            .padding(.horizontal, 20)
        }
        .background(Color.black.ignoresSafeArea())
        .task {
            if storeManager.products.isEmpty {
                await storeManager.loadProducts()
            }
        }
    }

    // MARK: - Components

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundColor(.secondary)
            .tracking(1.5)
    }

    private func packRow(id: String, name: String, emoji: String, contents: [String], description: String) -> some View {
        let unlocked = storeManager.isUnlocked(id)
        let product = storeManager.products.first(where: { $0.id == id })

        return HStack(spacing: 14) {
            Text(emoji)
                .font(.system(size: 28))
                .frame(width: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text(contents.joined(separator: " · "))
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(.white.opacity(0.4))
                    .lineLimit(1)
            }

            Spacer()

            if unlocked {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.green)
            } else {
                Button(action: {
                    guard let product else { return }
                    Task { try? await storeManager.purchase(product) }
                }) {
                    Text(product?.displayPrice ?? "---")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(.black)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.green)
                        .cornerRadius(10)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(unlocked ? Color.green.opacity(0.3) : Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    private var proRow: some View {
        let unlocked = storeManager.hasProAccess
        let product = storeManager.products.first(where: { $0.id == StoreManager.pro })

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("⭐")
                    .font(.system(size: 28))
                Text("HandStrudel Pro")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
                if unlocked {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.green)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                featureItem("All preset packs")
                featureItem("All sound packs")
                featureItem("All drum kits")
                featureItem("One-time purchase")
            }

            if !unlocked {
                Button(action: {
                    guard let product else { return }
                    Task { try? await storeManager.purchase(product) }
                }) {
                    Text(product?.displayPrice ?? "---")
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.green)
                        .cornerRadius(12)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(unlocked ? Color.green.opacity(0.3) : Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    private var subscriptionRow: some View {
        let subscribed = storeManager.hasSubscription
        let monthlyProduct = storeManager.products.first(where: { $0.id == StoreManager.plusMonthly })
        let yearlyProduct = storeManager.products.first(where: { $0.id == StoreManager.plusYearly })

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("✨")
                    .font(.system(size: 28))
                Text("HandStrudel+")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
                if subscribed {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.green)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                featureItem("Everything in Pro")
                featureItem("Early access to new content")
                featureItem("Exclusive presets & sounds")
            }

            if !subscribed {
                // Period toggle
                HStack(spacing: 0) {
                    periodButton("Monthly", period: .monthly, price: monthlyProduct?.displayPrice)
                    periodButton("Yearly", period: .yearly, price: yearlyProduct?.displayPrice)
                }
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.06))
                )

                Button(action: {
                    let product = plusToggle == .monthly ? monthlyProduct : yearlyProduct
                    guard let product else { return }
                    Task { try? await storeManager.purchase(product) }
                }) {
                    Text("SUBSCRIBE")
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.green)
                        .cornerRadius(12)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(subscribed ? Color.green.opacity(0.3) : Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    private func periodButton(_ label: String, period: PlusPeriod, price: String?) -> some View {
        let isActive = plusToggle == period
        return Button(action: { plusToggle = period }) {
            VStack(spacing: 2) {
                Text(label)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(isActive ? .green : .white.opacity(0.5))
                Text(price ?? "---")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(isActive ? .green.opacity(0.7) : .white.opacity(0.3))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isActive ? Color.green.opacity(0.12) : Color.clear)
            )
        }
    }

    private func featureItem(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.green)
            Text(text)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.7))
        }
    }
}
