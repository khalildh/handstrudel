import StoreKit

@MainActor
final class StoreManager: ObservableObject {

    // MARK: - Product IDs

    static let studioPack = "com.handstrudel.pack.studio"
    static let partyPack = "com.handstrudel.pack.party"
    static let experimentalPack = "com.handstrudel.pack.experimental"
    static let analogPack = "com.handstrudel.pack.analog"
    static let texturePack = "com.handstrudel.pack.texture"
    static let vocalPack = "com.handstrudel.pack.vocal"
    static let kit808 = "com.handstrudel.kit.808"
    static let kitElectronic = "com.handstrudel.kit.electronic"
    static let kitWorld = "com.handstrudel.kit.world"
    static let pro = "com.handstrudel.pro"
    static let plusMonthly = "com.handstrudel.plus.monthly"
    static let plusYearly = "com.handstrudel.plus.yearly"

    static let allProductIds: Set<String> = [
        studioPack, partyPack, experimentalPack, analogPack, texturePack, vocalPack,
        kit808, kitElectronic, kitWorld,
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
            print("[StoreManager] Failed to load products: \(error)")
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
            print("[StoreManager] Failed to restore purchases: \(error)")
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

    func isUnlocked(_ packId: String) -> Bool {
        purchasedIds.contains(packId) || hasProAccess
    }

    var hasProAccess: Bool {
        purchasedIds.contains(Self.pro) || hasSubscription
    }

    var hasSubscription: Bool {
        purchasedIds.contains(Self.plusMonthly) || purchasedIds.contains(Self.plusYearly)
    }
}
