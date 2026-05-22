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

    func testInitialState_hasProAccessFalse() {
        let store = StoreManager()
        XCTAssertFalse(store.hasProAccess)
    }

    func testInitialState_hasSubscriptionFalse() {
        let store = StoreManager()
        XCTAssertFalse(store.hasSubscription)
    }

    func testInitialState_hasPlusFeaturesFalse() {
        let store = StoreManager()
        XCTAssertFalse(store.hasPlusFeatures)
    }

    func testInitialState_isUnlockedFalse() {
        let store = StoreManager()
        // Without a customerInfo, isUnlocked returns false in release config
        XCTAssertFalse(store.isUnlocked(StoreManager.studioPack))
        XCTAssertFalse(store.isUnlocked("anything"))
    }
}
