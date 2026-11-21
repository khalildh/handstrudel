package com.handstrudel.store

import com.handstrudel.store.FakePurchasesBackend.Companion.customer
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.async
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.IOException

/** Port of the restore cases in iOS `StoreManagerTests`, against a fake customer-info source. */
@OptIn(ExperimentalCoroutinesApi::class)
class RestoreOutcomeTest {

    private fun TestScope.store(backend: FakePurchasesBackend) =
        StoreManager(backend, scope = backgroundScope, debug = null)

    @Test fun initialState_everythingLocked() = runTest(UnconfinedTestDispatcher()) {
        val store = store(FakePurchasesBackend())
        val s = store.state.value
        assertTrue(s.purchasedIds.isEmpty())
        assertTrue(s.products.isEmpty())
        assertFalse(s.isLoading)
        assertFalse(store.hasProAccess)
        assertFalse(store.hasSubscription)
        assertFalse(store.hasPlusFeatures)
        assertFalse(store.isUnlocked(ProductIds.STUDIO_PACK))
        assertFalse(store.isUnlocked("anything"))
        assertTrue(store.isUnlocked(null))
    }

    @Test fun lifetimeProUnlocksProPaywallButNotPlus() = runTest(UnconfinedTestDispatcher()) {
        val backend = FakePurchasesBackend()
        backend.restoreHandler = { customer(ProductIds.PRO, listOf(Entitlements.PRO)) }
        val store = store(backend)

        assertEquals(RestoreOutcome.ACCESS_AVAILABLE, store.restore(ProductIds.PRO))
        assertTrue(store.isUnlocked(ProductIds.PRO))
        assertTrue(store.isUnlocked("pro"))
        assertTrue(store.hasProAccess)
        assertFalse(store.hasPlusFeatures)
        assertFalse(store.hasSubscription)
        assertFalse(store.state.value.isRestoring)
        assertTrue(ProductIds.PRO in store.state.value.purchasedIds)
    }

    @Test fun bothPlusPlansGrantProAndPlusFeatures() = runTest(UnconfinedTestDispatcher()) {
        for (plan in listOf(ProductIds.PLUS_MONTHLY, ProductIds.PLUS_YEARLY, ProductIds.IOS_PLUS_MONTHLY, ProductIds.IOS_PLUS_YEARLY)) {
            val backend = FakePurchasesBackend()
            backend.restoreHandler = { customer(plan, listOf(Entitlements.PRO, Entitlements.PLUS_FEATURES), subscription = true) }
            val store = store(backend)

            assertEquals(plan, RestoreOutcome.ACCESS_AVAILABLE, store.restore())
            assertTrue(plan, store.hasSubscription)
            assertTrue(plan, store.isUnlocked(ProductIds.PRO))
            assertTrue(plan, store.hasPlusFeatures)
            assertTrue(plan, store.isUnlocked("filter_pack"))
            assertTrue(plan, store.isUnlocked("theme_pack"))
            assertTrue(plan, store.isUnlocked("scale_pack"))
        }
    }

    @Test fun reportsWhenActivePurchaseDoesNotUnlockRequestedItem() = runTest(UnconfinedTestDispatcher()) {
        val backend = FakePurchasesBackend()
        backend.restoreHandler = { customer(ProductIds.PRO, listOf(Entitlements.PRO)) }
        val store = store(backend)

        assertEquals(RestoreOutcome.REQUESTED_ITEM_UNAVAILABLE, store.restore("filter_pack"))
        assertFalse(store.isUnlocked("filter_pack"))
        assertTrue(store.hasProAccess)
    }

    @Test fun reportsNoActivePurchasesForEmptyAccount() = runTest(UnconfinedTestDispatcher()) {
        val store = store(FakePurchasesBackend())
        assertEquals(RestoreOutcome.NO_ACTIVE_PURCHASES, store.restore())
        assertEquals(RestoreOutcome.NO_ACTIVE_PURCHASES, store.restore("pro"))
        assertFalse(store.state.value.isRestoring)
    }

    @Test fun doesNotCountExpiredSubscriptionHistoryAsActive() = runTest(UnconfinedTestDispatcher()) {
        val backend = FakePurchasesBackend()
        backend.restoreHandler = {
            customer(ProductIds.PLUS_YEARLY, listOf(Entitlements.PRO, Entitlements.PLUS_FEATURES), expired = true, subscription = true)
        }
        val store = store(backend)

        assertEquals(RestoreOutcome.NO_ACTIVE_PURCHASES, store.restore())
        assertTrue(ProductIds.PLUS_YEARLY in store.state.value.purchasedIds)
        assertFalse(store.hasSubscription)
        assertFalse(store.hasProAccess)
        assertFalse(store.hasPlusFeatures)
    }

    @Test fun kitEntitlementAloneCountsAsActivePurchase() = runTest(UnconfinedTestDispatcher()) {
        val backend = FakePurchasesBackend()
        backend.restoreHandler = { customer(ProductIds.KIT_808, listOf(Entitlements.KIT_808)) }
        val store = store(backend)

        assertEquals(RestoreOutcome.ACCESS_AVAILABLE, store.restore())
        assertEquals(RestoreOutcome.ACCESS_AVAILABLE, store.restore("kit_808"))
        assertEquals(RestoreOutcome.REQUESTED_ITEM_UNAVAILABLE, store.restore("pro"))
        assertFalse(store.hasProAccess)
    }

    @Test fun unknownEntitlementIsNotAnActivePurchase() = runTest(UnconfinedTestDispatcher()) {
        val backend = FakePurchasesBackend()
        backend.restoreHandler = { customer("com.other.thing", listOf("some_other_entitlement")) }
        val store = store(backend)
        assertEquals(RestoreOutcome.NO_ACTIVE_PURCHASES, store.restore())
    }

    @Test fun failurePreservesEntitlementsAndAllowsRetry() = runTest(UnconfinedTestDispatcher()) {
        val info = customer(ProductIds.PRO, listOf(Entitlements.PRO))
        val backend = FakePurchasesBackend()
        backend.restoreHandler = {
            if (backend.restoreCalls == 2) throw IOException("offline")
            info
        }
        val store = store(backend)

        assertEquals(RestoreOutcome.ACCESS_AVAILABLE, store.restore())
        assertEquals(RestoreOutcome.FAILED, store.restore(ProductIds.PRO))
        assertTrue(store.hasProAccess)
        assertFalse(store.state.value.isRestoring)

        assertEquals(RestoreOutcome.ACCESS_AVAILABLE, store.restore())
        assertEquals(3, backend.restoreCalls)
    }

    @Test fun cancellationHasItsOwnOutcome() = runTest(UnconfinedTestDispatcher()) {
        val backend = FakePurchasesBackend()
        backend.restoreHandler = { throw StoreCancelledException() }
        val store = store(backend)

        assertEquals(RestoreOutcome.CANCELLED, store.restore())
        assertFalse(store.state.value.isRestoring)
    }

    @Test fun ignoresDuplicateWhileRequestIsInFlight() = runTest(UnconfinedTestDispatcher()) {
        val info = CustomerSnapshot()
        val started = CompletableDeferred<Unit>()
        val response = CompletableDeferred<CustomerSnapshot>()
        val backend = FakePurchasesBackend()
        backend.restoreHandler = {
            if (backend.restoreCalls == 1) {
                started.complete(Unit)
                response.await()
            } else info
        }
        val store = store(backend)

        val first = async { store.restore() }
        started.await()

        assertTrue(store.state.value.isRestoring)
        assertNull(store.restore())
        assertTrue(store.state.value.isRestoring)
        assertEquals(1, backend.restoreCalls)

        response.complete(info)
        assertEquals(RestoreOutcome.NO_ACTIVE_PURCHASES, first.await())
        assertFalse(store.state.value.isRestoring)
    }
}
