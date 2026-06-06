import SwiftUI
import RevenueCat
import RevenueCatUI

struct StoreView: View {
    @ObservedObject var storeManager: StoreManager

    @State private var showPaywall = false
    @State private var showCustomerCenter = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Space.xl) {
                Text("Store")
                    .font(.dsLargeTitle)
                    .foregroundColor(DS.textPrimary)
                    .padding(.top, DS.Space.md)

                // Preset Packs
                section("Preset Packs") {
                    packRow(
                        id: StoreManager.studioPack,
                        name: "Studio Pack", emoji: "🎛️",
                        contents: ["Tape", "Glass", "Deep", "Foggy", "Pulse", "Cosmic", "Glitch"]
                    )
                    packRow(
                        id: StoreManager.partyPack,
                        name: "Party Pack", emoji: "🎉",
                        contents: ["EDM", "DnB", "Dubstep", "Rave", "Reggaeton", "Future Bass", "Techno", "Garage", "Phonk"]
                    )
                }

                // Drum Kits
                section("Drum Kits") {
                    packRow(
                        id: StoreManager.kit808,
                        name: "808 Kit", emoji: "🥁",
                        contents: ["Boom Bap", "Drill", "Lo-Fi Hip Hop", "R&B", "Afrobeat", "Bounce", "Jersey Club", "Memphis", "Bossa Nova", "Reggae"]
                    )
                    packRow(
                        id: StoreManager.kitElectronic,
                        name: "Electronic Kit", emoji: "⚡",
                        contents: ["Techno", "Breakbeat", "IDM", "Jungle", "Ambient", "Industrial", "2-Step", "Synthwave"]
                    )
                }

                // Pro
                section("Pro") { proCard }

                // Subscription
                section("HandStrudel+") { subscriptionCard }

                // Policy links
                HStack(spacing: DS.Space.lg) {
                    Link("Privacy Policy", destination: URL(string: "https://handstrudel.com/privacy")!)
                    Link("Terms of Use", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                }
                .font(.dsFootnote)
                .foregroundColor(DS.textTertiary)
                .frame(maxWidth: .infinity)
                .padding(.top, DS.Space.xs)

                Spacer().frame(height: DS.Space.md)
            }
            .padding(.horizontal, DS.Space.lg)
        }
        .background(DS.background.ignoresSafeArea())
        .task { await storeManager.loadProducts() }
    }

    // MARK: - Layout helpers

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            DSSectionHeader(title)
            content()
        }
    }

    // MARK: - Pack row

    private func packRow(id: String, name: String, emoji: String, contents: [String]) -> some View {
        let unlocked = storeManager.isUnlocked(id)
        let product = storeManager.products.first(where: { $0.productIdentifier == id })

        return HStack(spacing: DS.Space.sm) {
            IconTile(emoji: emoji, tint: DS.signature, size: 46)

            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(.dsHeadline)
                    .foregroundColor(DS.textPrimary)
                Text(contents.joined(separator: " · "))
                    .font(.dsCaption)
                    .foregroundColor(DS.textTertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: DS.Space.xs)

            if unlocked {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(DS.signature)
            } else {
                Button(action: { Task { try? await storeManager.purchase(productId: id) } }) {
                    Text(product?.localizedPriceString ?? "Buy")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.horizontal, DS.Space.md)
                        .padding(.vertical, 9)
                        .background(Capsule().fill(DS.signature))
                }
                .fixedSize()
            }
        }
        .padding(DS.Space.sm)
        .dsCard(selected: unlocked)
    }

    // MARK: - Pro

    private var proCard: some View {
        let unlocked = storeManager.hasProAccess
        let product = storeManager.products.first(where: { $0.productIdentifier == StoreManager.pro })

        return VStack(alignment: .leading, spacing: DS.Space.md) {
            HStack(spacing: DS.Space.sm) {
                IconTile(symbol: "star.fill", tint: DS.signature, size: 46)
                VStack(alignment: .leading, spacing: 2) {
                    Text("HandStrudel Pro")
                        .font(.dsTitle3)
                        .foregroundColor(DS.textPrimary)
                    Text("One-time purchase")
                        .font(.dsCaption)
                        .foregroundColor(DS.textTertiary)
                }
                Spacer()
                if unlocked {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(DS.signature)
                }
            }

            VStack(alignment: .leading, spacing: DS.Space.xs) {
                featureItem("All preset packs")
                featureItem("All sound packs")
                featureItem("All drum kits")
            }

            if !unlocked {
                Button(action: { Task { try? await storeManager.purchase(productId: StoreManager.pro) } }) {
                    HStack(spacing: DS.Space.xs) {
                        Text("Get Pro")
                        if let price = product?.localizedPriceString {
                            Text("·").opacity(0.5)
                            Text(price).font(.dsMono(15, .semibold))
                        }
                    }
                }
                .buttonStyle(DSPrimaryButtonStyle())
            }
        }
        .padding(DS.Space.md)
        .dsCard(selected: unlocked)
    }

    // MARK: - Subscription

    private var subscriptionCard: some View {
        VStack(alignment: .leading, spacing: DS.Space.md) {
            VStack(alignment: .leading, spacing: DS.Space.xs) {
                featureItem("Everything in Pro")
                featureItem("Early access to new content")
                featureItem("Exclusive presets & sounds")
            }

            if storeManager.hasSubscription {
                statusPill("Subscribed")
                Button("Manage Subscription") { showCustomerCenter = true }
                    .buttonStyle(DSSecondaryButtonStyle())
            } else if storeManager.hasProAccess {
                statusPill("Pro — Lifetime Access")
            } else {
                Button("Subscribe") { showPaywall = true }
                    .buttonStyle(DSPrimaryButtonStyle())
            }
        }
        .padding(DS.Space.md)
        .dsCard(selected: storeManager.hasProAccess)
        .sheet(isPresented: $showPaywall) {
            PaywallView(displayCloseButton: true)
        }
        .sheet(isPresented: $showCustomerCenter) {
            CustomerCenterView()
        }
    }

    private func statusPill(_ text: String) -> some View {
        HStack(spacing: DS.Space.xs) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(DS.signature)
            Text(text)
                .font(.dsCallout)
                .foregroundColor(DS.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Space.xs)
    }

    private func featureItem(_ text: String) -> some View {
        HStack(spacing: DS.Space.xs) {
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(DS.signature)
            Text(text)
                .font(.dsCallout)
                .foregroundColor(DS.textSecondary)
        }
    }
}
