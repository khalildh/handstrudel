import StoreKit

@MainActor
final class StoreManager: ObservableObject {

    // MARK: - Product IDs

    static let studioPack = "com.handstrudel.pack.studio"
    static let partyPack = "com.handstrudel.pack.party"
    static let kit808 = "com.handstrudel.kit.808"
    static let kitElectronic = "com.handstrudel.kit.electronic"
    static let pro = "com.handstrudel.pro"
    static let plusMonthly = "com.handstrudel.plus.monthly"
    static let plusYearly = "com.handstrudel.plus.yearly"

    static let allProductIds: Set<String> = [
        studioPack, partyPack,
        kit808, kitElectronic,
        pro,
        plusMonthly, plusYearly
    ]

    // MARK: - Published State

    @Published var products: [Product] = []
    @Published var purchasedIds: Set<String> = []
    @Published var isLoading = false

    // MARK: - Private

    private var updateTask: Task<Void, Never>?

    // MARK: - Init

    init() {
        updateTask = Task.detached { [weak self] in
            for await result in Transaction.updates {
                if let transaction = try? result.payloadValue {
                    await transaction.finish()
                    await self?.updatePurchasedProducts()
                }
            }
        }
    }

    deinit {
        updateTask?.cancel()
    }

    // MARK: - Load Products

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        do {
            products = try await Product.products(for: Self.allProductIds)
        } catch {
            debugPrint("[StoreManager] Failed to load products:", error)
        }
    }

    // MARK: - Purchase

    func purchase(_ product: Product) async throws {
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try verification.payloadValue
            await transaction.finish()
            await updatePurchasedProducts()
        case .userCancelled:
            break
        case .pending:
            break
        @unknown default:
            break
        }
    }

    // MARK: - Restore

    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await updatePurchasedProducts()
        } catch {
            debugPrint("[StoreManager] Failed to restore purchases:", error)
        }
    }

    // MARK: - Update Purchased Products

    func updatePurchasedProducts() async {
        var ids = Set<String>()
        for await result in Transaction.currentEntitlements {
            if let transaction = try? result.payloadValue {
                if transaction.revocationDate == nil {
                    ids.insert(transaction.productID)
                }
            }
        }
        purchasedIds = ids
    }

    // MARK: - Access Checks

    /// Map content packIds to the actual store product that unlocks them
    static func productId(for packId: String) -> String {
        switch packId {
        case "studio", studioPack: return studioPack
        case "party", partyPack: return partyPack
        case "kit_808", kit808: return kit808
        case "kit_electronic", kitElectronic: return kitElectronic
        // Filters, themes, scales, and other pro content
        case "pro", "filter_pack", "visual_pack": return pro
        default: return pro
        }
    }

    func isUnlocked(_ packId: String) -> Bool {
        #if DEBUG
        return true // All premium unlocked for testing
        #else
        let productId = Self.productId(for: packId)
        return purchasedIds.contains(productId) || hasProAccess
        #endif
    }

    var hasProAccess: Bool {
        purchasedIds.contains(Self.pro) || hasSubscription
    }

    var hasSubscription: Bool {
        purchasedIds.contains(Self.plusMonthly) || purchasedIds.contains(Self.plusYearly)
    }
}
