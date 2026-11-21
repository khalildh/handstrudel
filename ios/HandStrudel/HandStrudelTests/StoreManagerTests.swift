import RevenueCat
import XCTest
@testable import HandStrudel

@MainActor
final class StoreManagerTests: XCTestCase {

    // MARK: - What's for sale

    func testStoreSellsOnlyProAndPlus() {
        XCTAssertEqual(StoreManager.allProductIds, [StoreManager.pro, StoreManager.plusMonthly, StoreManager.plusYearly])
    }

    // MARK: - Entitlement IDs (must match RevenueCat dashboard)

    func testEntitlementIds_areDefined() {
        XCTAssertEqual(StoreManager.entitlementPro, "pro")
        XCTAssertEqual(StoreManager.entitlementPlusFeatures, "plus_features")
        XCTAssertEqual(StoreManager.entitlementStudio, "studio_pack")
        XCTAssertEqual(StoreManager.entitlementParty, "party_pack")
        XCTAssertEqual(StoreManager.entitlementKit808, "kit_808")
        XCTAssertEqual(StoreManager.entitlementKitElectronic, "kit_electronic")
    }

    // MARK: - Which offer unlocks an item

    func testMusicItemsAskForProAndLooksAskForPlus() {
        for packId in ["pro", StoreManager.pro, "studio", "party", "kit_808", "kit_electronic", "scale_pack"] {
            XCTAssertEqual(StoreManager.offer(for: packId), .pro, packId)
        }
        for packId in ["filter_pack", "visual_pack", "theme_pack"] {
            XCTAssertEqual(StoreManager.offer(for: packId), .plus, packId)
        }
        XCTAssertEqual(StoreManager.offer(for: "something_new"), .pro,
                       "A new item never becomes subscription-only by accident.")
    }

    func testLegacyPackEntitlements() {
        XCTAssertEqual(StoreManager.legacyPackEntitlement(for: "studio"), StoreManager.entitlementStudio)
        XCTAssertEqual(StoreManager.legacyPackEntitlement(for: StoreManager.partyPack), StoreManager.entitlementParty)
        XCTAssertEqual(StoreManager.legacyPackEntitlement(for: "kit_808"), StoreManager.entitlementKit808)
        XCTAssertEqual(StoreManager.legacyPackEntitlement(for: "kit_electronic"), StoreManager.entitlementKitElectronic)
        XCTAssertNil(StoreManager.legacyPackEntitlement(for: "pro"))
        XCTAssertNil(StoreManager.legacyPackEntitlement(for: "filter_pack"))
    }

    // MARK: - Who can play what

    func testProOwnersGetAllMusicButNotTheLooks() async {
        let store = await restored(customerInfo(productId: StoreManager.pro, entitlementIds: [StoreManager.entitlementPro]))
        for packId in ["pro", "studio", "party", "kit_808", "kit_electronic", "something_new"] {
            XCTAssertTrue(store.isUnlocked(packId), packId)
        }
        XCTAssertFalse(store.isUnlocked("filter_pack"))
        XCTAssertFalse(store.isUnlocked("visual_pack"))
        XCTAssertTrue(store.ownsPro)
        XCTAssertFalse(store.hasSubscription, "A Pro owner can still subscribe to HandStrudel+.")
    }

    func testOldPackBuyersKeepTheirPackOnly() async {
        let store = await restored(customerInfo(productId: StoreManager.studioPack, entitlementIds: [StoreManager.entitlementStudio]))
        XCTAssertTrue(store.isUnlocked("studio"))
        XCTAssertFalse(store.isUnlocked("party"))
        XCTAssertFalse(store.isUnlocked("kit_808"))
        XCTAssertFalse(store.isUnlocked("pro"))
        XCTAssertFalse(store.ownsPro)
    }

    func testPlusIncludesProEvenIfTheDashboardOnlyGrantsPlusFeatures() async {
        let store = await restored(customerInfo(productId: StoreManager.plusYearly,
                                                entitlementIds: [StoreManager.entitlementPlusFeatures],
                                                expiration: Date().addingTimeInterval(86_400)))
        XCTAssertTrue(store.hasProAccess)
        for packId in ["pro", "studio", "kit_808", "filter_pack", "visual_pack"] {
            XCTAssertTrue(store.isUnlocked(packId), packId)
        }
        XCTAssertFalse(store.ownsPro, "Getting Pro through + isn't owning it.")
    }

    func testAnActiveSubscriptionCountsAsPlusWithoutEntitlements() async {
        let store = await restored(customerInfo(productId: StoreManager.plusMonthly, entitlementIds: [],
                                                expiration: Date().addingTimeInterval(86_400)))
        XCTAssertTrue(store.hasSubscription)
        XCTAssertTrue(store.hasPlusFeatures)
        XCTAssertTrue(store.isUnlocked(.pro))
        XCTAssertTrue(store.isUnlocked(.plus))
    }

    func testProOwnerWhoSubscribesHasBoth() async {
        let info = customerInfo(products: [
            (StoreManager.pro, nil, [StoreManager.entitlementPro]),
            (StoreManager.plusYearly, Date().addingTimeInterval(86_400), [StoreManager.entitlementPlusFeatures]),
        ])
        let store = await restored(info)
        XCTAssertTrue(store.ownsPro)
        XCTAssertTrue(store.hasSubscription)
        XCTAssertTrue(store.isUnlocked("filter_pack"))
    }

    // MARK: - legacyProductId(forEntitlement:)

    func testLegacyProductId_pro() {
        XCTAssertEqual(StoreManager.legacyProductId(forEntitlement: StoreManager.entitlementPro), StoreManager.pro)
    }

    func testLegacyProductId_studio() {
        XCTAssertEqual(StoreManager.legacyProductId(forEntitlement: StoreManager.entitlementStudio), StoreManager.studioPack)
    }

    func testLegacyProductId_party() {
        XCTAssertEqual(StoreManager.legacyProductId(forEntitlement: StoreManager.entitlementParty), StoreManager.partyPack)
    }

    func testLegacyProductId_kit808() {
        XCTAssertEqual(StoreManager.legacyProductId(forEntitlement: StoreManager.entitlementKit808), StoreManager.kit808)
    }

    func testLegacyProductId_kitElectronic() {
        XCTAssertEqual(StoreManager.legacyProductId(forEntitlement: StoreManager.entitlementKitElectronic), StoreManager.kitElectronic)
    }

    func testLegacyProductId_unknownReturnsNil() {
        XCTAssertNil(StoreManager.legacyProductId(forEntitlement: "nonexistent"))
    }

    // MARK: - Initial state

    func testInitialState_purchasedIdsEmpty() {
        let store = emptyStore()
        XCTAssertTrue(store.purchasedIds.isEmpty)
    }

    func testInitialState_productsEmpty() {
        let store = emptyStore()
        XCTAssertTrue(store.products.isEmpty)
    }

    func testInitialState_isLoadingFalse() {
        let store = emptyStore()
        XCTAssertFalse(store.isLoading)
    }

    func testInitialState_hasProAccessFalse() {
        let store = emptyStore()
        XCTAssertFalse(store.hasProAccess)
    }

    func testInitialState_hasSubscriptionFalse() {
        let store = emptyStore()
        XCTAssertFalse(store.hasSubscription)
    }

    func testInitialState_hasPlusFeaturesFalse() {
        let store = emptyStore()
        XCTAssertFalse(store.hasPlusFeatures)
    }

    func testInitialState_isUnlockedFalse() {
        let store = emptyStore()
        // Without a customerInfo, isUnlocked returns false in release config
        XCTAssertFalse(store.isUnlocked(StoreManager.studioPack))
        XCTAssertFalse(store.isUnlocked("anything"))
        XCTAssertFalse(store.isUnlocked("filter_pack"))
        XCTAssertFalse(store.ownsPro)
    }

    // MARK: - Restore

    func testRestore_lifetimeProUnlocksProPaywallButNotPlus() async {
        let info = customerInfo(productId: StoreManager.pro, entitlementIds: [StoreManager.entitlementPro])
        let store = StoreManager { info }

        let result = await store.restorePurchases(for: StoreManager.pro)

        XCTAssertEqual(result, .accessAvailable)
        XCTAssertTrue(store.isUnlocked(StoreManager.pro))
        XCTAssertTrue(store.hasProAccess)
        XCTAssertFalse(store.hasPlusFeatures)
        XCTAssertFalse(store.hasSubscription)
        XCTAssertFalse(store.isRestoring)
    }

    func testRestore_bothPlusPlansGrantProAndPlusFeatures() async {
        for plan in [StoreManager.plusMonthly, StoreManager.plusYearly] {
            let info = customerInfo(
                productId: plan,
                entitlementIds: [StoreManager.entitlementPro, StoreManager.entitlementPlusFeatures],
                expiration: Date().addingTimeInterval(86_400)
            )
            let store = StoreManager { info }

            let result = await store.restorePurchases()

            XCTAssertEqual(result, .accessAvailable, plan)
            XCTAssertTrue(store.hasSubscription, plan)
            XCTAssertTrue(store.isUnlocked(StoreManager.pro), plan)
            XCTAssertTrue(store.hasPlusFeatures, plan)
        }
    }

    func testRestore_reportsWhenActivePurchaseDoesNotUnlockRequestedItem() async {
        let info = customerInfo(productId: StoreManager.pro, entitlementIds: [StoreManager.entitlementPro])
        let store = StoreManager { info }

        let result = await store.restorePurchases(for: "filter_pack")

        XCTAssertEqual(result, .requestedItemUnavailable)
        XCTAssertFalse(store.isUnlocked("filter_pack"))
        XCTAssertTrue(store.hasProAccess)
    }

    func testRestore_reportsNoActivePurchasesForEmptyAccount() async {
        let store = emptyStore()

        let result = await store.restorePurchases()

        XCTAssertEqual(result, .noActivePurchases)
        XCTAssertFalse(store.isRestoring)
    }

    func testRestore_doesNotCountExpiredSubscriptionHistoryAsActive() async {
        let info = customerInfo(
            productId: StoreManager.plusYearly,
            entitlementIds: [StoreManager.entitlementPro, StoreManager.entitlementPlusFeatures],
            expiration: Date().addingTimeInterval(-86_400)
        )
        let store = StoreManager { info }

        let result = await store.restorePurchases()

        XCTAssertEqual(result, .noActivePurchases)
        XCTAssertTrue(store.purchasedIds.contains(StoreManager.plusYearly))
        XCTAssertFalse(store.hasSubscription)
        XCTAssertFalse(store.hasProAccess)
        XCTAssertFalse(store.hasPlusFeatures)
    }

    func testRestore_failurePreservesEntitlementsAndAllowsRetry() async {
        let info = customerInfo(productId: StoreManager.pro, entitlementIds: [StoreManager.entitlementPro])
        var calls = 0
        let store = StoreManager {
            calls += 1
            if calls == 2 { throw URLError(.notConnectedToInternet) }
            return info
        }

        let first = await store.restorePurchases()
        let failed = await store.restorePurchases(for: StoreManager.pro)

        XCTAssertEqual(first, .accessAvailable)
        XCTAssertEqual(failed, .failed)
        XCTAssertTrue(store.hasProAccess)
        XCTAssertFalse(store.isRestoring)

        let retry = await store.restorePurchases()
        XCTAssertEqual(retry, .accessAvailable)
        XCTAssertEqual(calls, 3)
    }

    func testRestore_cancellationHasItsOwnOutcome() async {
        let store = StoreManager { throw ErrorCode.purchaseCancelledError as NSError }

        let result = await store.restorePurchases()

        XCTAssertEqual(result, .cancelled)
        XCTAssertFalse(store.isRestoring)
    }

    func testRestore_ignoresDuplicateWhileRequestIsInFlight() async {
        let info = customerInfo()
        let (requests, started) = AsyncStream<Void>.makeStream()
        let (responses, complete) = AsyncStream<CustomerInfo>.makeStream()
        var calls = 0
        let store = StoreManager {
            calls += 1
            guard calls == 1 else { return info }
            started.yield(())
            var iterator = responses.makeAsyncIterator()
            return await iterator.next() ?? info
        }
        let first = Task { await store.restorePurchases() }
        var iterator = requests.makeAsyncIterator()
        _ = await iterator.next()

        XCTAssertTrue(store.isRestoring)
        let duplicate = await store.restorePurchases()
        XCTAssertNil(duplicate)
        XCTAssertTrue(store.isRestoring)
        XCTAssertEqual(calls, 1)

        complete.yield(info)
        complete.finish()
        started.finish()
        let result = await first.value
        XCTAssertEqual(result, .noActivePurchases)
        XCTAssertFalse(store.isRestoring)
    }

    private func restored(_ info: CustomerInfo) async -> StoreManager {
        let store = StoreManager { info }
        _ = await store.restorePurchases()
        return store
    }

    /// Several purchases at once: (product, expiration, entitlements).
    private func customerInfo(products: [(String, Date?, [String])]) -> CustomerInfo {
        let now = Date()
        var entitlements: [String: EntitlementInfo] = [:]
        var expirations: [String: Date] = [:]
        for (productId, expiration, ids) in products {
            expirations[productId] = expiration
            let isActive = expiration.map { $0 > now } ?? true
            for id in ids {
                entitlements[id] = EntitlementInfo(
                    identifier: id, isActive: isActive, willRenew: isActive && expiration != nil, periodType: .normal,
                    expirationDate: expiration, store: .appStore, productIdentifier: productId,
                    isSandbox: true, ownershipType: .purchased
                )
            }
        }
        return CustomerInfo(
            entitlements: EntitlementInfos(entitlements: entitlements),
            expirationDatesByProductId: expirations,
            allPurchasedProductIds: Set(products.map(\.0)),
            requestDate: now, firstSeen: now, originalAppUserId: "test-user"
        )
    }

    private func emptyStore() -> StoreManager {
        let info = customerInfo()
        return StoreManager { info }
    }

    private func customerInfo(
        productId: String? = nil,
        entitlementIds: [String] = [],
        expiration: Date? = nil
    ) -> CustomerInfo {
        let now = Date()
        var entitlements: [String: EntitlementInfo] = [:]
        var expirations: [String: Date] = [:]
        if let productId {
            expirations[productId] = expiration
            let isActive = expiration.map { $0 > now } ?? true
            for id in entitlementIds {
                entitlements[id] = EntitlementInfo(
                    identifier: id, isActive: isActive, willRenew: isActive && expiration != nil, periodType: .normal,
                    expirationDate: expiration, store: .appStore, productIdentifier: productId,
                    isSandbox: true, ownershipType: .purchased
                )
            }
        }
        return CustomerInfo(
            entitlements: EntitlementInfos(entitlements: entitlements),
            expirationDatesByProductId: expirations,
            allPurchasedProductIds: Set(productId.map { [$0] } ?? []),
            requestDate: now, firstSeen: now, originalAppUserId: "test-user"
        )
    }
}
