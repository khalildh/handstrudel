package com.handstrudel.store

import android.app.Activity
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.UUID

/**
 * No RevenueCat key: nothing paid unlocks and nothing crashes. Purchases fail the way iOS
 * fails when StoreKit returns no product ("Product unavailable: <id>"), restore fails.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class UnconfiguredStoreTest {

    private val paidPacks = listOf(
        "pro", ProductIds.PRO, "kit_808", "kit_electronic", "studio", "party",
        "filter_pack", "visual_pack", "theme_pack", "scale_pack", "unknown",
    )

    private fun assertLocked(store: StoreGate) {
        assertFalse(store.isConfigured)
        assertTrue(store.isUnlocked(null))
        paidPacks.forEach { assertFalse(it, store.isUnlocked(it)) }
        assertFalse(store.hasProAccess)
        assertFalse(store.hasPlusFeatures)
        assertFalse(store.hasSubscription)
    }

    @Test fun managerWithoutBackend_locksEverythingPaid() = runTest(UnconfinedTestDispatcher()) {
        val store = StoreManager(backend = null, scope = backgroundScope, debug = null)
        assertLocked(store)

        assertEquals(PurchaseResult.Failed("Product unavailable: com.handstrudel.pro"), store.purchase(Activity(), ProductIds.PRO))
        assertEquals("Product unavailable: com.handstrudel.pro", store.state.value.lastError)
        assertEquals(RestoreOutcome.FAILED, store.restore())
        // Reloading the store (on appear) clears the old error, like a configured store.
        store.refresh()
        store.logIn("ABC")
        store.logOut()
        store.bind(MutableStateFlow(UUID.randomUUID()))
        assertLocked(store)
        assertEquals(StoreState(), store.state.value)
    }

    @Test fun unconfiguredFake_matchesManager() = runTest {
        val store = UnconfiguredStoreGate()
        assertLocked(store)
        assertEquals(PurchaseResult.Failed("Product unavailable: com.handstrudel.pro"), store.purchase(Activity(), ProductIds.PRO))
        assertEquals(RestoreOutcome.FAILED, store.restore())
    }

    @Test fun noKey_everyStoreProductFailsWithItsId() = runTest(UnconfinedTestDispatcher()) {
        val store = StoreManager(backend = null, scope = backgroundScope, debug = null)
        listOf(ProductIds.KIT_808, ProductIds.KIT_ELECTRONIC, ProductIds.PRO, ProductIds.PLUS_MONTHLY).forEach { id ->
            val result = store.purchase(Activity(), id)
            assertEquals(PurchaseResult.Failed(StoreCopy.productUnavailable(id)), result)
            assertEquals("Product unavailable: $id", store.state.value.lastError)
            // Nothing is left "purchasing", and nothing loaded (paywall shows "---").
            assertEquals(null, store.state.value.purchasingProductId)
            assertTrue(store.state.value.products.isEmpty())
        }
        assertFalse(store.state.value.offeringAvailable)
        assertLocked(store)
    }

    @Test fun noKey_paywallProductIdsResolveLikeIos() {
        // Locked rows open the paywall for these pack ids; UNLOCK buys the resolved product.
        assertEquals(ProductIds.PRO, ProductIds.productId("pro"))
        assertEquals(ProductIds.PRO, ProductIds.productId("filter_pack"))
        assertEquals(ProductIds.KIT_808, ProductIds.productId("kit_808"))
        assertEquals(ProductIds.KIT_ELECTRONIC, ProductIds.productId("kit_electronic"))
    }

    @Test fun debugGrant_unlocksWithoutKey() = runTest(UnconfinedTestDispatcher()) {
        val debug = StoreDebugOverrides()
        val store = StoreManager(backend = null, scope = backgroundScope, debug = debug)
        assertFalse(store.hasProAccess)

        debug.grantedEntitlements.value = setOf(Entitlements.PRO)
        assertTrue(store.hasProAccess)
        assertTrue(store.isUnlocked("pro"))
        assertFalse(store.isUnlocked("filter_pack"))
        assertEquals(setOf(Entitlements.PRO), store.state.value.activeEntitlements)
        assertTrue(ProductIds.PRO in store.state.value.purchasedIds)
        // Still no way to buy.
        assertFalse(store.isConfigured)

        debug.grantedEntitlements.value = setOf(Entitlements.PRO, Entitlements.PLUS_FEATURES)
        debug.grantedSubscriptions.value = setOf(ProductIds.PLUS_MONTHLY)
        assertTrue(store.hasPlusFeatures)
        assertTrue(store.hasSubscription)
        assertTrue(store.isUnlocked("theme_pack"))

        debug.reset()
        assertLocked(store)
        assertTrue(store.state.value.activeEntitlements.isEmpty())
    }

    @Test fun debugForceLocked_overridesRealEntitlements() = runTest(UnconfinedTestDispatcher()) {
        val debug = StoreDebugOverrides()
        val backend = FakePurchasesBackend(FakePurchasesBackend.customer(ProductIds.PRO, listOf(Entitlements.PRO)))
        val store = StoreManager(backend, scope = backgroundScope, debug = debug)
        assertTrue(store.hasProAccess)

        debug.forceLocked.value = true
        assertFalse(store.hasProAccess)
        assertFalse(store.isUnlocked("pro"))
        assertTrue(store.isUnlocked(null))

        debug.forceLocked.value = false
        assertTrue(store.hasProAccess)
    }
}
