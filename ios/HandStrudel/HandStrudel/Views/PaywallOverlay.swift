import SwiftUI

struct PaywallOverlay: View {
    let packId: String
    let packName: String
    let packDescription: String
    let price: String
    let items: [String]
    @ObservedObject var storeManager: StoreManager
    @Environment(\.dismiss) private var dismiss

    @State private var purchasing = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            DS.background.ignoresSafeArea()

            AmbientAccent(period: 28) { color, _ in
                RadialGradient(colors: [color.opacity(0.14), .clear],
                               center: .top, startRadius: 0, endRadius: 300)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: DS.Space.lg) {
                        // Header
                        VStack(spacing: DS.Space.sm) {
                            IconTile(symbol: "sparkles", tint: DS.signature, size: 64)
                                .padding(.bottom, DS.Space.xxs)

                            Text(packName)
                                .font(.dsTitle)
                                .foregroundColor(DS.textPrimary)
                                .multilineTextAlignment(.center)

                            Text(packDescription)
                                .font(.dsCallout)
                                .foregroundColor(DS.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, DS.Space.xl)
                        .padding(.horizontal, DS.Space.lg)

                        // Includes
                        VStack(alignment: .leading, spacing: DS.Space.sm) {
                            DSSectionHeader("Includes")
                            VStack(alignment: .leading, spacing: DS.Space.sm) {
                                ForEach(items, id: \.self) { item in
                                    HStack(spacing: DS.Space.sm) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 16))
                                            .foregroundColor(DS.signature)
                                        Text(item)
                                            .font(.dsBody)
                                            .foregroundColor(DS.textPrimary)
                                        Spacer(minLength: 0)
                                    }
                                }
                            }
                            .padding(DS.Space.md)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .dsCard()
                        }
                        .padding(.horizontal, DS.Space.lg)
                    }
                    .padding(.bottom, DS.Space.md)
                }

                // Pinned action area — visible at any sheet height.
                VStack(spacing: DS.Space.sm) {
                    Button(action: purchaseTapped) {
                        Group {
                            if purchasing {
                                ProgressView().tint(.black)
                            } else {
                                HStack(spacing: DS.Space.xs) {
                                    Text("Unlock")
                                    Text("·").opacity(0.5)
                                    Text(price).font(.dsMono(15, .semibold))
                                }
                            }
                        }
                    }
                    .buttonStyle(DSPrimaryButtonStyle())
                    .disabled(purchasing)
                    .accessibilityIdentifier("paywall-unlock")

                    Button(action: restoreTapped) {
                        Text("Restore Purchases")
                            .font(.dsFootnote)
                            .foregroundColor(DS.textTertiary)
                    }
                    .disabled(purchasing)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.dsCaption)
                            .foregroundColor(.red.opacity(0.85))
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, DS.Space.lg)
                .padding(.top, DS.Space.sm)
                .padding(.bottom, DS.Space.md)
            }
        }
    }

    private func purchaseTapped() {
        let resolvedId = StoreManager.productId(for: packId)
        purchasing = true
        errorMessage = nil
        Task {
            do {
                try await storeManager.purchase(productId: resolvedId)
                if storeManager.isUnlocked(packId) { dismiss() }
            } catch {
                errorMessage = error.localizedDescription
            }
            purchasing = false
        }
    }

    private func restoreTapped() {
        purchasing = true
        errorMessage = nil
        Task {
            await storeManager.restorePurchases()
            if storeManager.isUnlocked(packId) { dismiss() }
            purchasing = false
        }
    }
}
