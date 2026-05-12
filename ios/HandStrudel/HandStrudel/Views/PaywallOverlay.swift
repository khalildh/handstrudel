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
            Color.black.ignoresSafeArea()

            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Text(packName)
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundColor(.white)

                    Text(packDescription)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 32)

                // Items list
                VStack(alignment: .leading, spacing: 10) {
                    Text("INCLUDES")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                        .tracking(1.5)

                    ForEach(items, id: \.self) { item in
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.green)
                            Text(item)
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)

                Spacer()

                // Price
                Text(price)
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundColor(.green)

                // Unlock button
                Button(action: purchaseTapped) {
                    Group {
                        if purchasing {
                            ProgressView()
                                .tint(.black)
                        } else {
                            Text("UNLOCK")
                                .font(.system(size: 18, weight: .black, design: .rounded))
                        }
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.green)
                    .cornerRadius(16)
                }
                .disabled(purchasing)
                .padding(.horizontal, 24)

                // Restore
                Button(action: restoreTapped) {
                    Text("Restore Purchases")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.4))
                }
                .disabled(purchasing)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(.red.opacity(0.8))
                }

                Spacer()
            }
        }
    }

    private func purchaseTapped() {
        let resolvedId = StoreManager.productId(for: packId)
        guard let product = storeManager.products.first(where: { $0.id == resolvedId }) else { return }
        purchasing = true
        errorMessage = nil
        Task {
            do {
                try await storeManager.purchase(product)
                if storeManager.isUnlocked(packId) {
                    dismiss()
                }
            } catch {
                errorMessage = "Purchase failed. Try again."
            }
            purchasing = false
        }
    }

    private func restoreTapped() {
        purchasing = true
        errorMessage = nil
        Task {
            await storeManager.restorePurchases()
            if storeManager.isUnlocked(packId) {
                dismiss()
            }
            purchasing = false
        }
    }
}
