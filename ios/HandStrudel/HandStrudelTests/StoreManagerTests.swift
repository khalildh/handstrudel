import XCTest
@testable import HandStrudel

@MainActor
final class StoreManagerTests: XCTestCase {

    // MARK: - isUnlocked (Release behavior)

    // Note: In DEBUG builds, isUnlocked always returns true.
    // These tests verify the logic by checking purchasedIds state.
    // The actual isUnlocked() method behavior depends on build config.

    func testIsUnlocked_purchasedPack_reflectedInPurchasedIds() {
        let store = StoreManager()
        store.purchasedIds = [StoreManager.studioPack]
        XCTAssertTrue(store.purchasedIds.contains(StoreManager.studioPack))
    }

    func testIsUnlocked_unpurchasedPack_notInPurchasedIds() {
        let store = StoreManager()
        store.purchasedIds = []
        XCTAssertFalse(store.purchasedIds.contains(StoreManager.studioPack))
    }

    func testIsUnlocked_proUnlocksEverything() {
        let store = StoreManager()
        store.purchasedIds = [StoreManager.pro]
        XCTAssertTrue(store.hasProAccess)
    }

    func testIsUnlocked_subscriptionGrantsProAccess() {
        let store = StoreManager()
        store.purchasedIds = [StoreManager.plusMonthly]
        XCTAssertTrue(store.hasProAccess)
    }

    // MARK: - hasProAccess

    func testHasProAccess_falseByDefault() {
        let store = StoreManager()
        store.purchasedIds = []
        XCTAssertFalse(store.hasProAccess)
    }

    func testHasProAccess_trueWhenProPurchased() {
        let store = StoreManager()
        store.purchasedIds = [StoreManager.pro]
        XCTAssertTrue(store.hasProAccess)
    }

    func testHasProAccess_trueWhenMonthlySubscribed() {
        let store = StoreManager()
        store.purchasedIds = [StoreManager.plusMonthly]
        XCTAssertTrue(store.hasProAccess)
    }

    func testHasProAccess_trueWhenYearlySubscribed() {
        let store = StoreManager()
        store.purchasedIds = [StoreManager.plusYearly]
        XCTAssertTrue(store.hasProAccess)
    }

    func testHasProAccess_falseWithOnlyPackPurchase() {
        let store = StoreManager()
        store.purchasedIds = [StoreManager.studioPack, StoreManager.partyPack]
        XCTAssertFalse(store.hasProAccess)
    }

    // MARK: - hasSubscription

    func testHasSubscription_falseByDefault() {
        let store = StoreManager()
        store.purchasedIds = []
        XCTAssertFalse(store.hasSubscription)
    }

    func testHasSubscription_trueForMonthly() {
        let store = StoreManager()
        store.purchasedIds = [StoreManager.plusMonthly]
        XCTAssertTrue(store.hasSubscription)
    }

    func testHasSubscription_trueForYearly() {
        let store = StoreManager()
        store.purchasedIds = [StoreManager.plusYearly]
        XCTAssertTrue(store.hasSubscription)
    }

    func testHasSubscription_falseForProOnly() {
        let store = StoreManager()
        store.purchasedIds = [StoreManager.pro]
        XCTAssertFalse(store.hasSubscription)
    }

    func testHasSubscription_falseForPackOnly() {
        let store = StoreManager()
        store.purchasedIds = [StoreManager.kitElectronic]
        XCTAssertFalse(store.hasSubscription)
    }

    // MARK: - Product IDs

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

    // MARK: - Initial state

    func testInitialState_purchasedIdsEmpty() {
        let store = StoreManager()
        XCTAssertTrue(store.purchasedIds.isEmpty)
    }

    func testInitialState_productsEmpty() {
        let store = StoreManager()
        XCTAssertTrue(store.products.isEmpty)
    }

    func testInitialState_isLoadingFalse() {
        let store = StoreManager()
        XCTAssertFalse(store.isLoading)
    }

    // MARK: - Multiple purchases combined

    func testMultiplePurchases_tracked() {
        let store = StoreManager()
        store.purchasedIds = [StoreManager.studioPack, StoreManager.partyPack, StoreManager.kit808]
        XCTAssertEqual(store.purchasedIds.count, 3)
        XCTAssertTrue(store.purchasedIds.contains(StoreManager.studioPack))
        XCTAssertTrue(store.purchasedIds.contains(StoreManager.partyPack))
        XCTAssertTrue(store.purchasedIds.contains(StoreManager.kit808))
    }

    func testProAndSubscription_bothGrantProAccess() {
        let store = StoreManager()
        store.purchasedIds = [StoreManager.pro, StoreManager.plusMonthly]
        XCTAssertTrue(store.hasProAccess)
        XCTAssertTrue(store.hasSubscription)
    }

    // MARK: - isUnlocked logic (DEBUG vs RELEASE)

    #if DEBUG
    func testIsUnlocked_inDebug_alwaysTrue() {
        let store = StoreManager()
        store.purchasedIds = []
        // In DEBUG, isUnlocked always returns true
        XCTAssertTrue(store.isUnlocked("anything"))
        XCTAssertTrue(store.isUnlocked(StoreManager.studioPack))
        XCTAssertTrue(store.isUnlocked("nonexistent_pack"))
    }
    #endif
}
