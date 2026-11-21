import Foundation
import RevenueCat

@MainActor
final class StoreManager: ObservableObject {

    // MARK: - Product IDs
    //
    // Two things are for sale: Pro (one-time) and HandStrudel+ (monthly or
    // yearly). The four old packs are no longer sold; their ids stay so people
    // who bought one keep it (see `isUnlocked`).

    static let studioPack = "com.handstrudel.pack.studio"
    static let partyPack = "com.handstrudel.pack.party"
    static let kit808 = "com.handstrudel.kit.808"
    static let kitElectronic = "com.handstrudel.kit.electronic"
    static let pro = "com.handstrudel.pro"
    static let plusMonthly = "com.handstrudel.plus.monthly"
    static let plusYearly = "com.handstrudel.plus.yearly"

    /// Products the store sells.
    static let allProductIds: Set<String> = [pro, plusMonthly, plusYearly]

    /// What a locked item asks the player to buy.
    enum Offer: Hashable, Identifiable {
        /// Music: instruments, scales, progressions, preset and drum packs.
        /// Pro unlocks it once; HandStrudel+ includes it.
        case pro
        /// Looks: premium camera filters and hand themes. HandStrudel+ only.
        case plus

        var id: Self { self }
    }

    /// Item pack ids that only HandStrudel+ unlocks. Everything else is music,
    /// which Pro unlocks — including unknown ids, so a new item can never end
    /// up subscription-only by accident.
    static let plusOnlyPackIds: Set<String> = ["filter_pack", "visual_pack", "theme_pack"]

    static func offer(for packId: String) -> Offer {
        plusOnlyPackIds.contains(packId) ? .plus : .pro
    }

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
    @Published private(set) var isRestoring = false

    // MARK: - Private

    private var customerInfo: CustomerInfo?
    private var listenerTask: Task<Void, Never>?
    private let restoreCustomerInfo: @MainActor () async throws -> CustomerInfo

    // MARK: - Init

    convenience init() {
        self.init(restoreCustomerInfo: { try await Purchases.shared.restorePurchases() })

        // Initial fetch
        Task { await refreshCustomerInfo() }

        // Listen for CustomerInfo changes
        listenerTask = Task { [weak self] in
            for await info in Purchases.shared.customerInfoStream {
                await MainActor.run { self?.apply(info) }
            }
        }
    }

    // Allows restore tests to run without starting live RevenueCat observers.
    init(restoreCustomerInfo: @escaping @MainActor () async throws -> CustomerInfo) {
        self.restoreCustomerInfo = restoreCustomerInfo
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

    enum RestoreOutcome: Hashable, Identifiable {
        case accessAvailable
        case noActivePurchases
        case requestedItemUnavailable
        case cancelled
        case failed

        var id: Self { self }
    }

    /// A nil outcome means another restore is already in progress.
    func restorePurchases(for packId: String? = nil) async -> RestoreOutcome? {
        guard !isRestoring else { return nil }
        isRestoring = true
        defer { isRestoring = false }

        do {
            let info = try await restoreCustomerInfo()
            apply(info)

            if let packId, isUnlocked(packId) {
                return .accessAvailable
            }

            // Purchase history can include expired subscriptions. Only active access counts.
            let hasActivePurchase = hasSubscription || info.entitlements.active.keys.contains {
                Self.legacyProductId(forEntitlement: $0) != nil || $0 == Self.entitlementPlusFeatures
            }
            guard hasActivePurchase else { return .noActivePurchases }
            return packId == nil ? .accessAvailable : .requestedItemUnavailable
        } catch {
            if error is CancellationError || error as? ErrorCode == .purchaseCancelledError {
                return .cancelled
            }
            print("[StoreManager] Failed to restore: \(error)")
            return .failed
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

    /// The entitlement of a pack people could once buy on its own, if any.
    static func legacyPackEntitlement(for packId: String) -> String? {
        switch packId {
        case "studio", studioPack: return entitlementStudio
        case "party", partyPack: return entitlementParty
        case "kit_808", kit808: return entitlementKit808
        case "kit_electronic", kitElectronic: return entitlementKitElectronic
        default: return nil
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

    func isUnlocked(_ packId: String) -> Bool {
        // Dev override: launch with `--force-locked` (via Xcode scheme arguments)
        // to force-report every pack as locked regardless of real entitlements.
        // Lets us see the paywall UI even when signed into an account that
        // already owns Pro. Not compiled into release builds.
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--force-locked") {
            return false
        }
        if packId == "pro", ProcessInfo.processInfo.arguments.contains("--uitesting"),
           ProcessInfo.processInfo.arguments.contains("--uitest-pro-scales") { return true }
        // Promo-video demo runs show every instrument unlocked.
        if ProcessInfo.processInfo.environment["HANDSTRUDEL_DEMO_SCRIPT"] != nil {
            return true
        }
        #endif
        // NOTE: DEBUG bypass disabled for testing purchase flows.
        // Re-enable by wrapping the body below in `#if DEBUG\nreturn true\n#else ... #endif`.
        switch Self.offer(for: packId) {
        case .plus:
            return hasPlusFeatures
        case .pro:
            if hasProAccess { return true }
            guard let entitlement = Self.legacyPackEntitlement(for: packId) else { return false }
            return customerInfo?.entitlements[entitlement]?.isActive == true
        }
    }

    /// A HandStrudel+ hand theme lent for a week by a 7-day daily-sound streak. The server
    /// grants and times it (`daily_theme_grants`); DailySoundStore passes it in.
    @Published var streakThemeLoan: StreakThemeLoan?

    func isUnlocked(theme: HandTheme) -> Bool {
        guard theme.isPremium else { return true }
        if let packId = theme.packId, isUnlocked(packId) { return true }
        return streakThemeLoan?.isActive(for: theme.id) == true
    }

    func isUnlocked(_ offer: Offer) -> Bool {
        switch offer {
        case .pro: return hasProAccess
        case .plus: return hasPlusFeatures
        }
    }

    /// Bought the one-time Pro unlock (as opposed to getting Pro through +).
    var ownsPro: Bool {
        #if DEBUG
        if let state = Self.uiTestState { return state == "pro" }
        #endif
        return customerInfo?.allPurchasedProductIdentifiers.contains(Self.pro) == true
    }

    #if DEBUG
    /// UI tests: `--uitest-store-state=pro|plus|none` fakes what the player owns.
    static let uiTestState: String? = ProcessInfo.processInfo.arguments
        .first { $0.hasPrefix("--uitest-store-state=") }
        .map { String($0.dropFirst("--uitest-store-state=".count)) }
    #endif

    /// True when the user owns Pro music content (via Pro one-time or Plus subscription).
    var hasProAccess: Bool {
        #if DEBUG
        if ProcessInfo.processInfo.environment["HANDSTRUDEL_DEMO_SCRIPT"] != nil { return true }
        if let state = Self.uiTestState { return state != "none" }
        #endif
        guard let info = customerInfo else { return false }
        // HandStrudel+ includes everything in Pro, whatever the dashboard maps.
        return info.entitlements[Self.entitlementPro]?.isActive == true || hasPlusFeatures
    }

    /// True when the user has Plus-only features (camera filters, hand themes).
    /// Only Plus subscriptions grant this — Pro one-time does not.
    var hasPlusFeatures: Bool {
        #if DEBUG
        if let state = Self.uiTestState { return state == "plus" }
        #endif
        guard let info = customerInfo else { return false }
        return info.entitlements[Self.entitlementPlusFeatures]?.isActive == true || hasSubscription
    }

    /// True when the user has an active recurring subscription (monthly/yearly).
    /// Does NOT include the one-time Pro purchase — `hasProAccess` covers both.
    var hasSubscription: Bool {
        #if DEBUG
        if let state = Self.uiTestState { return state == "plus" }
        #endif
        guard let info = customerInfo else { return false }
        return info.activeSubscriptions.contains(Self.plusMonthly)
            || info.activeSubscriptions.contains(Self.plusYearly)
    }
}
