import Foundation
import RevenueCat

@MainActor
final class StoreManager: ObservableObject {

    // MARK: - Product IDs (legacy — kept for callers that still reference them)

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

    // MARK: - Entitlement IDs (must match RevenueCat dashboard)

    static let entitlementPro = "pro"               // music content unlock (Pro one-time + Plus subs)
    static let entitlementPlusFeatures = "plus_features" // filters, themes, premium scales — Plus subs only
    static let entitlementStudio = "studio_pack"
    static let entitlementParty = "party_pack"
    static let entitlementKit808 = "kit_808"
    static let entitlementKitElectronic = "kit_electronic"

    // MARK: - Published State

    @Published var products: [StoreProduct] = []
    @Published var purchasedIds: Set<String> = []
    @Published var isLoading = false

    // MARK: - Private

    private var customerInfo: CustomerInfo?
    private var listenerTask: Task<Void, Never>?

    // MARK: - Init

    init() {
        // Initial fetch
        Task { await refreshCustomerInfo() }

        // Listen for CustomerInfo changes
        listenerTask = Task { [weak self] in
            for await info in Purchases.shared.customerInfoStream {
                await MainActor.run { self?.apply(info) }
            }
        }
    }

    deinit {
        listenerTask?.cancel()
    }

    // MARK: - Load Products

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }

        // Fetch ALL products (subscriptions + one-time packs/kits/pro) directly
        // from StoreKit via RevenueCat. Just loading offerings.current would only
        // give us the subscription packages — the pack and Pro buttons need the
        // one-time products too.
        let fetched = await Purchases.shared.products(Array(Self.allProductIds))
        products = fetched
        if products.count < Self.allProductIds.count {
            let loadedIds = Set(products.map { $0.productIdentifier })
            let missing = Self.allProductIds.subtracting(loadedIds)
            print("[StoreManager] WARNING: missing products from StoreKit: \(missing)")
        }
        await refreshCustomerInfo()
    }

    // MARK: - Purchase

    enum StoreError: LocalizedError {
        case productNotFound(String)
        var errorDescription: String? {
            switch self {
            case .productNotFound(let id): return "Product unavailable: \(id)"
            }
        }
    }

    func purchase(_ product: StoreProduct) async throws {
        let result = try await Purchases.shared.purchase(product: product)
        apply(result.customerInfo)
    }

    /// Convenience: purchase by product ID. Fetches the product on demand if it
    /// hasn't been loaded yet (instead of failing silently).
    func purchase(productId: String) async throws {
        if let product = products.first(where: { $0.productIdentifier == productId }) {
            try await purchase(product)
            return
        }
        // Try fetching directly from StoreKit
        let fetched = await Purchases.shared.products([productId])
        guard let product = fetched.first else {
            throw StoreError.productNotFound(productId)
        }
        // Add to cache for future lookups
        if !products.contains(where: { $0.productIdentifier == productId }) {
            products.append(product)
        }
        try await purchase(product)
    }

    // MARK: - Restore

    func restorePurchases() async {
        do {
            let info = try await Purchases.shared.restorePurchases()
            apply(info)
        } catch {
            print("[StoreManager] Failed to restore: \(error)")
        }
    }

    // MARK: - Refresh

    private func refreshCustomerInfo() async {
        do {
            let info = try await Purchases.shared.customerInfo()
            apply(info)
        } catch {
            print("[StoreManager] Failed to fetch customerInfo: \(error)")
        }
    }

    private func apply(_ info: CustomerInfo) {
        customerInfo = info
        // Map active entitlements back to "purchased" product IDs so legacy callers work
        var ids = Set<String>()
        for (entitlementId, entitlement) in info.entitlements.active {
            if entitlement.isActive {
                if let mapped = Self.legacyProductId(forEntitlement: entitlementId) {
                    ids.insert(mapped)
                }
            }
        }
        // Also track raw product identifiers
        for productId in info.allPurchasedProductIdentifiers {
            ids.insert(productId)
        }
        purchasedIds = ids
    }

    // MARK: - Access Checks

    /// Map content packIds to the RevenueCat entitlement that unlocks them.
    /// - Music content (packs, kits) → individual entitlements granted by Pro or Plus.
    /// - Cosmetic / premium features (filters, themes, premium scales) → `plus_features`,
    ///   which only Plus subscriptions grant. Pro one-time buyers do NOT get these.
    static func entitlementId(for packId: String) -> String {
        switch packId {
        case "studio", studioPack: return entitlementStudio
        case "party", partyPack: return entitlementParty
        case "kit_808", kit808: return entitlementKit808
        case "kit_electronic", kitElectronic: return entitlementKitElectronic
        case "pro": return entitlementPro
        // Filters, hand themes, premium scales — Plus-only features
        case "filter_pack", "visual_pack", "theme_pack", "scale_pack":
            return entitlementPlusFeatures
        default: return entitlementPlusFeatures
        }
    }

    /// Map entitlement back to a legacy product ID (for purchasedIds set)
    static func legacyProductId(forEntitlement entitlementId: String) -> String? {
        switch entitlementId {
        case entitlementStudio: return studioPack
        case entitlementParty: return partyPack
        case entitlementKit808: return kit808
        case entitlementKitElectronic: return kitElectronic
        case entitlementPro: return pro
        default: return nil
        }
    }

    /// Legacy: kept for callers that pass packId/productId strings
    static func productId(for packId: String) -> String {
        switch packId {
        case "studio", studioPack: return studioPack
        case "party", partyPack: return partyPack
        case "kit_808", kit808: return kit808
        case "kit_electronic", kitElectronic: return kitElectronic
        case "pro", "filter_pack", "visual_pack": return pro
        default: return pro
        }
    }

    func isUnlocked(_ packId: String) -> Bool {
        // NOTE: DEBUG bypass disabled for testing purchase flows.
        // Re-enable by wrapping the body below in `#if DEBUG\nreturn true\n#else ... #endif`.
        guard let info = customerInfo else { return false }
        let entId = Self.entitlementId(for: packId)
        return info.entitlements[entId]?.isActive == true
    }

    /// True when the user owns Pro music content (via Pro one-time or Plus subscription).
    var hasProAccess: Bool {
        guard let info = customerInfo else { return false }
        return info.entitlements[Self.entitlementPro]?.isActive == true
    }

    /// True when the user has Plus-only features (filters, themes, premium scales).
    /// Only Plus subscriptions grant this — Pro one-time does not.
    var hasPlusFeatures: Bool {
        guard let info = customerInfo else { return false }
        return info.entitlements[Self.entitlementPlusFeatures]?.isActive == true
    }

    /// True when the user has an active recurring subscription (monthly/yearly).
    /// Does NOT include the one-time Pro purchase — `hasProAccess` covers both.
    var hasSubscription: Bool {
        guard let info = customerInfo else { return false }
        return info.activeSubscriptions.contains(Self.plusMonthly)
            || info.activeSubscriptions.contains(Self.plusYearly)
    }
}
