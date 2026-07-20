import SwiftUI
import RevenueCat
import RevenueCatUI

struct StoreView: View {
    @ObservedObject var storeManager: StoreManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                // Title
                Text("STORE")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.top, 16)

                // Drum Kits
                sectionHeader("DRUM KITS")
                packRow(
                    id: StoreManager.kit808,
                    name: "808 Kit",
                    emoji: "🥁",
                    contents: ["Boom Bap", "Drill", "Lo-Fi Hip Hop", "R&B", "Afrobeat", "Bounce", "Jersey Club", "Memphis", "Bossa Nova", "Reggae"],
                    description: "10 hip-hop, urban & world drum patterns"
                )
                packRow(
                    id: StoreManager.kitElectronic,
                    name: "Electronic Kit",
                    emoji: "⚡",
                    contents: ["Techno", "Breakbeat", "IDM", "Jungle", "Ambient", "Industrial", "2-Step", "Synthwave"],
                    description: "8 electronic drum patterns"
                )

                // Pro
                sectionHeader("PRO")
                proRow

                // HandStrudel+
                sectionHeader("HANDSTRUDEL+")
                subscriptionRow

                // Required policy links — also surfaced inside the RevenueCat
                // paywall, but kept here so they're always reachable from the
                // Store screen regardless of paywall state.
                HStack(spacing: 20) {
                    Link("Privacy Policy", destination: URL(string: "https://handstrudel.com/privacy")!)
                    Link("Terms of Use", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                }
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.5))
                .frame(maxWidth: .infinity)
                .padding(.top, 8)

                Spacer().frame(height: 20)
            }
            .padding(.horizontal, 20)
        }
        .background(Color.black.ignoresSafeArea())
        .task {
            // Always reload — if a previous load failed, products would be
            // missing and pack buttons would show "---" with no action.
            await storeManager.loadProducts()
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
        let product = storeManager.products.first(where: { $0.productIdentifier == id })

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
                    Task { try? await storeManager.purchase(productId: id) }
                }) {
                    HStack(spacing: 6) {
                        Text("Buy")
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                        if let price = product?.localizedPriceString {
                            Text(price)
                                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        }
                    }
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
        let product = storeManager.products.first(where: { $0.productIdentifier == StoreManager.pro })

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
                featureItem("120+ instruments")
                featureItem("Every scale — modes, harmonic minor, exotic")
                featureItem("Every chord progression")
                featureItem("All drum kits")
                featureItem("Premium camera filters + hand themes")
                featureItem("One-time purchase")
            }

            if !unlocked {
                Button(action: {
                    Task { try? await storeManager.purchase(productId: StoreManager.pro) }
                }) {
                    HStack(spacing: 8) {
                        Text("BUY PRO")
                            .font(.system(size: 16, weight: .black, design: .rounded))
                        if let price = product?.localizedPriceString {
                            Text("• \(price)")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .opacity(0.7)
                        }
                    }
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

    @State private var showPaywall = false
    @State private var showCustomerCenter = false

    private var subscriptionRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                featureItem("Everything in Pro")
                featureItem("Early access to new content")
                featureItem("Exclusive presets & sounds")
            }

            if storeManager.hasSubscription {
                VStack(spacing: 10) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Subscribed")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)

                    Button(action: { showCustomerCenter = true }) {
                        Text("MANAGE SUBSCRIPTION")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
                            )
                    }
                }
                .padding(.vertical, 4)
            } else if storeManager.hasProAccess {
                // One-time Pro purchase — no subscription to manage
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Pro — Lifetime Access")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            } else {
                Button(action: { showPaywall = true }) {
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
                .stroke(storeManager.hasProAccess ? Color.green.opacity(0.3) : Color.white.opacity(0.06), lineWidth: 1)
        )
        .sheet(isPresented: $showPaywall) {
            PaywallView(displayCloseButton: true)
        }
        .sheet(isPresented: $showCustomerCenter) {
            CustomerCenterView()
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
