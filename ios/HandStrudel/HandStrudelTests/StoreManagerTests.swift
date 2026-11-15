import RevenueCat
import XCTest
@testable import HandStrudel

@MainActor
final class StoreManagerTests: XCTestCase {

    // MARK: - Product ID constants

    func testAllProductIds_containsAllPacks() {
        XCTAssertTrue(StoreManager.allProductIds.contains(StoreManager.studioPack))
        XCTAssertTrue(StoreManager.allProductIds.contains(StoreManager.partyPack))
    }

    func testAllProductIds_containsAllKits() {
        XCTAssertTrue(StoreManager.allProductIds.contains(StoreManager.kit808))
        XCTAssertTrue(StoreManager.allProductIds.contains(StoreManager.kitElectronic))
    }

    func testAllProductIds_containsPro() {
        XCTAssertTrue(StoreManager.allProductIds.contains(StoreManager.pro))
    }

    func testAllProductIds_containsSubscriptions() {
        XCTAssertTrue(StoreManager.allProductIds.contains(StoreManager.plusMonthly))
        XCTAssertTrue(StoreManager.allProductIds.contains(StoreManager.plusYearly))
    }

    func testAllProductIds_hasExpectedCount() {
        // 2 packs + 2 kits + 1 pro + 2 subscriptions = 7
        XCTAssertEqual(StoreManager.allProductIds.count, 7)
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

    // MARK: - entitlementId(for:) mapping

    func testEntitlementId_studio() {
        XCTAssertEqual(StoreManager.entitlementId(for: "studio"), StoreManager.entitlementStudio)
        XCTAssertEqual(StoreManager.entitlementId(for: StoreManager.studioPack), StoreManager.entitlementStudio)
    }

    func testEntitlementId_party() {
        XCTAssertEqual(StoreManager.entitlementId(for: "party"), StoreManager.entitlementParty)
        XCTAssertEqual(StoreManager.entitlementId(for: StoreManager.partyPack), StoreManager.entitlementParty)
    }

    func testEntitlementId_kit808() {
        XCTAssertEqual(StoreManager.entitlementId(for: "kit_808"), StoreManager.entitlementKit808)
        XCTAssertEqual(StoreManager.entitlementId(for: StoreManager.kit808), StoreManager.entitlementKit808)
    }

    func testEntitlementId_kitElectronic() {
        XCTAssertEqual(StoreManager.entitlementId(for: "kit_electronic"), StoreManager.entitlementKitElectronic)
        XCTAssertEqual(StoreManager.entitlementId(for: StoreManager.kitElectronic), StoreManager.entitlementKitElectronic)
    }

    func testEntitlementId_pro() {
        XCTAssertEqual(StoreManager.entitlementId(for: "pro"), StoreManager.entitlementPro)
        XCTAssertEqual(StoreManager.entitlementId(for: StoreManager.pro), StoreManager.entitlementPro)
    }

    func testEntitlementId_filterAndVisual_mapToPlusFeatures() {
        XCTAssertEqual(StoreManager.entitlementId(for: "filter_pack"), StoreManager.entitlementPlusFeatures)
        XCTAssertEqual(StoreManager.entitlementId(for: "visual_pack"), StoreManager.entitlementPlusFeatures)
        XCTAssertEqual(StoreManager.entitlementId(for: "theme_pack"), StoreManager.entitlementPlusFeatures)
        XCTAssertEqual(StoreManager.entitlementId(for: "scale_pack"), StoreManager.entitlementPlusFeatures)
    }

    func testEntitlementId_unknownDefaultsToPlusFeatures() {
        XCTAssertEqual(StoreManager.entitlementId(for: "unknown_thing"), StoreManager.entitlementPlusFeatures)
    }

    // MARK: - productId(for:) legacy mapping

    func testProductId_studio() {
        XCTAssertEqual(StoreManager.productId(for: "studio"), StoreManager.studioPack)
    }

    func testProductId_party() {
        XCTAssertEqual(StoreManager.productId(for: "party"), StoreManager.partyPack)
    }

    func testProductId_unknownDefaultsToPro() {
        XCTAssertEqual(StoreManager.productId(for: "anything"), StoreManager.pro)
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
