package com.handstrudel.store

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** Port of iOS `StoreManagerTests` (ids and mappings) plus the Android Play ids. */
class EntitlementsTest {

    // Product id constants

    @Test fun allProductIds_containsPacksKitsProAndSubscriptions() {
        val all = ProductIds.iosAllProductIds
        listOf(
            ProductIds.STUDIO_PACK, ProductIds.PARTY_PACK, ProductIds.KIT_808, ProductIds.KIT_ELECTRONIC,
            ProductIds.PRO, ProductIds.IOS_PLUS_MONTHLY, ProductIds.IOS_PLUS_YEARLY,
        ).forEach { assertTrue(it, it in all) }
        assertEquals(7, all.size)
    }

    @Test fun productIds_matchIos() {
        assertEquals("com.handstrudel.pack.studio", ProductIds.STUDIO_PACK)
        assertEquals("com.handstrudel.pack.party", ProductIds.PARTY_PACK)
        assertEquals("com.handstrudel.kit.808", ProductIds.KIT_808)
        assertEquals("com.handstrudel.kit.electronic", ProductIds.KIT_ELECTRONIC)
        assertEquals("com.handstrudel.pro", ProductIds.PRO)
        assertEquals("com.handstrudel.plus.monthly", ProductIds.IOS_PLUS_MONTHLY)
        assertEquals("com.handstrudel.plus.yearly", ProductIds.IOS_PLUS_YEARLY)
    }

    @Test fun playIds() {
        assertEquals("com.handstrudel.plus:monthly", ProductIds.PLUS_MONTHLY)
        assertEquals("com.handstrudel.plus:yearly", ProductIds.PLUS_YEARLY)
        assertEquals(listOf(ProductIds.PRO, ProductIds.KIT_808, ProductIds.KIT_ELECTRONIC, "com.handstrudel.plus"), ProductIds.playFetchIds)
    }

    // Entitlement ids (must match the RevenueCat dashboard)

    @Test fun entitlementIds_areDefined() {
        assertEquals("pro", Entitlements.PRO)
        assertEquals("plus_features", Entitlements.PLUS_FEATURES)
        assertEquals("studio_pack", Entitlements.STUDIO)
        assertEquals("party_pack", Entitlements.PARTY)
        assertEquals("kit_808", Entitlements.KIT_808)
        assertEquals("kit_electronic", Entitlements.KIT_ELECTRONIC)
    }

    // entitlementId(packId)

    @Test fun entitlementId_studio() {
        assertEquals(Entitlements.STUDIO, Entitlements.entitlementId("studio"))
        assertEquals(Entitlements.STUDIO, Entitlements.entitlementId(ProductIds.STUDIO_PACK))
    }

    @Test fun entitlementId_party() {
        assertEquals(Entitlements.PARTY, Entitlements.entitlementId("party"))
        assertEquals(Entitlements.PARTY, Entitlements.entitlementId(ProductIds.PARTY_PACK))
    }

    @Test fun entitlementId_kit808() {
        assertEquals(Entitlements.KIT_808, Entitlements.entitlementId("kit_808"))
        assertEquals(Entitlements.KIT_808, Entitlements.entitlementId(ProductIds.KIT_808))
    }

    @Test fun entitlementId_kitElectronic() {
        assertEquals(Entitlements.KIT_ELECTRONIC, Entitlements.entitlementId("kit_electronic"))
        assertEquals(Entitlements.KIT_ELECTRONIC, Entitlements.entitlementId(ProductIds.KIT_ELECTRONIC))
    }

    @Test fun entitlementId_pro() {
        assertEquals(Entitlements.PRO, Entitlements.entitlementId("pro"))
        assertEquals(Entitlements.PRO, Entitlements.entitlementId(ProductIds.PRO))
    }

    @Test fun entitlementId_filterVisualThemeScale_mapToPlusFeatures() {
        listOf("filter_pack", "visual_pack", "theme_pack", "scale_pack").forEach {
            assertEquals(it, Entitlements.PLUS_FEATURES, Entitlements.entitlementId(it))
        }
    }

    @Test fun entitlementId_unknownDefaultsToPlusFeatures() {
        assertEquals(Entitlements.PLUS_FEATURES, Entitlements.entitlementId("unknown_thing"))
        assertEquals(Entitlements.PLUS_FEATURES, Entitlements.entitlementId(""))
        // Plus product ids are not packs; they fall through like iOS.
        assertEquals(Entitlements.PLUS_FEATURES, Entitlements.entitlementId(ProductIds.PLUS_MONTHLY))
    }

    @Test fun entitlementId_isCaseSensitiveLikeSwift() {
        assertEquals(Entitlements.PLUS_FEATURES, Entitlements.entitlementId("PRO"))
    }

    // productId(packId) legacy mapping

    @Test fun productId_mapping() {
        assertEquals(ProductIds.STUDIO_PACK, ProductIds.productId("studio"))
        assertEquals(ProductIds.PARTY_PACK, ProductIds.productId("party"))
        assertEquals(ProductIds.KIT_808, ProductIds.productId("kit_808"))
        assertEquals(ProductIds.KIT_ELECTRONIC, ProductIds.productId("kit_electronic"))
        assertEquals(ProductIds.KIT_808, ProductIds.productId(ProductIds.KIT_808))
        assertEquals(ProductIds.PRO, ProductIds.productId("pro"))
        assertEquals(ProductIds.PRO, ProductIds.productId("filter_pack"))
        assertEquals(ProductIds.PRO, ProductIds.productId("visual_pack"))
        assertEquals(ProductIds.PRO, ProductIds.productId("anything"))
    }

    // legacyProductId(entitlement)

    @Test fun legacyProductId_mapping() {
        assertEquals(ProductIds.PRO, Entitlements.legacyProductId(Entitlements.PRO))
        assertEquals(ProductIds.STUDIO_PACK, Entitlements.legacyProductId(Entitlements.STUDIO))
        assertEquals(ProductIds.PARTY_PACK, Entitlements.legacyProductId(Entitlements.PARTY))
        assertEquals(ProductIds.KIT_808, Entitlements.legacyProductId(Entitlements.KIT_808))
        assertEquals(ProductIds.KIT_ELECTRONIC, Entitlements.legacyProductId(Entitlements.KIT_ELECTRONIC))
        assertNull(Entitlements.legacyProductId(Entitlements.PLUS_FEATURES))
        assertNull(Entitlements.legacyProductId("nonexistent"))
    }

    // Subscriptions

    @Test fun isPlusSubscription_acceptsPlayAndIosIds() {
        assertTrue(ProductIds.isPlusSubscription("com.handstrudel.plus"))
        assertTrue(ProductIds.isPlusSubscription("com.handstrudel.plus:monthly"))
        assertTrue(ProductIds.isPlusSubscription("com.handstrudel.plus:yearly"))
        assertTrue(ProductIds.isPlusSubscription("com.handstrudel.plus.monthly"))
        assertTrue(ProductIds.isPlusSubscription("com.handstrudel.plus.yearly"))
        assertFalse(ProductIds.isPlusSubscription("com.handstrudel.pro"))
        assertFalse(ProductIds.isPlusSubscription("com.handstrudel.plusplus"))
        assertFalse(ProductIds.isPlusSubscription("com.handstrudel.plus.weekly"))
    }

    // Paywall copy

    @Test fun packInfo_matchesIos() {
        assertEquals("Pro Upgrade", PackCatalog.info("pro").name)
        assertEquals(PackCatalog.pro, PackCatalog.info("filter_pack")) // resolves to the Pro product like iOS
        assertEquals("808 Kit", PackCatalog.info("kit_808").name)
        assertEquals(8, PackCatalog.info("kit_808").items.size)
        assertEquals("Electronic Kit", PackCatalog.info(ProductIds.KIT_ELECTRONIC).name)
        assertEquals("Studio Pack", PackCatalog.info("studio").name)
        assertEquals(9, PackCatalog.info("party").items.size)
        assertEquals(4, PackCatalog.pro.items.size)
    }

    @Test fun restoreMessages_coverEveryOutcome() {
        RestoreOutcome.entries.forEach { assertTrue(it.message.isNotBlank()) }
        assertTrue(RestoreOutcome.NO_ACTIVE_PURCHASES.message.contains("Google account"))
    }
}
