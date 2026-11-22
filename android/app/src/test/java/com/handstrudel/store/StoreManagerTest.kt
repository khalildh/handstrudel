package com.handstrudel.store

import android.app.Activity
import com.handstrudel.store.FakePurchasesBackend.Companion.customer
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.IOException
import java.util.UUID

/** Configured-store behaviour: initial fetch, listener, purchase, refresh and account binding. */
@OptIn(ExperimentalCoroutinesApi::class)
class StoreManagerTest {

    private fun TestScope.store(backend: FakePurchasesBackend) =
        StoreManager(backend, scope = backgroundScope, debug = null)

    @Test fun initialFetch_appliesCustomerInfo() = runTest(UnconfinedTestDispatcher()) {
        val backend = FakePurchasesBackend(customer(ProductIds.PRO, listOf(Entitlements.PRO)))
        val store = store(backend)
        assertTrue(store.isConfigured)
        assertTrue(store.hasProAccess)
        assertTrue(store.isUnlocked("pro"))
        // Pro alone doesn't unlock kits, filters or Plus features (entitlements are per-pack, like iOS).
        assertFalse(store.isUnlocked("kit_808"))
        assertFalse(store.isUnlocked("filter_pack"))
    }

    @Test fun initialFetchFailure_staysLocked() = runTest(UnconfinedTestDispatcher()) {
        val backend = FakePurchasesBackend().apply { customerInfoError = IOException("offline") }
        val store = store(backend)
        assertFalse(store.hasProAccess)
        assertFalse(store.isUnlocked("pro"))
    }

    @Test fun listenerUpdates_unlockAndRelock() = runTest(UnconfinedTestDispatcher()) {
        val backend = FakePurchasesBackend()
        val store = store(backend)
        assertFalse(store.hasPlusFeatures)

        backend.push(customer(ProductIds.PLUS_YEARLY, listOf(Entitlements.PRO, Entitlements.PLUS_FEATURES), subscription = true))
        assertTrue(store.hasPlusFeatures)
        assertTrue(store.hasSubscription)
        assertEquals(setOf(Entitlements.PRO, Entitlements.PLUS_FEATURES), store.state.value.activeEntitlements)

        // Subscription lapses.
        backend.push(customer(ProductIds.PLUS_YEARLY, listOf(Entitlements.PRO, Entitlements.PLUS_FEATURES), expired = true, subscription = true))
        assertFalse(store.hasPlusFeatures)
        assertFalse(store.hasProAccess)
        assertFalse(store.hasSubscription)
    }

    @Test fun purchaseSuccess_appliesNewInfo() = runTest(UnconfinedTestDispatcher()) {
        val backend = FakePurchasesBackend()
        backend.purchaseHandler = { customer(it, listOf(Entitlements.PRO)) }
        val store = store(backend)

        assertEquals(PurchaseResult.Success, store.purchase(Activity(), ProductIds.PRO))
        assertEquals(listOf(ProductIds.PRO), backend.purchases)
        assertTrue(store.isUnlocked("pro"))
        assertNull(store.state.value.purchasingProductId)
    }

    @Test fun purchaseCancelledAndPending() = runTest(UnconfinedTestDispatcher()) {
        val backend = FakePurchasesBackend()
        val store = store(backend)

        backend.purchaseHandler = { throw StoreCancelledException() }
        assertEquals(PurchaseResult.Cancelled, store.purchase(Activity(), ProductIds.PRO))
        assertNull(store.state.value.lastError)

        backend.purchaseHandler = { throw StorePendingException() }
        assertEquals(PurchaseResult.Pending, store.purchase(Activity(), ProductIds.PRO))
        assertFalse(store.hasProAccess)
    }

    @Test fun purchaseFailure_reportsMessage() = runTest(UnconfinedTestDispatcher()) {
        val backend = FakePurchasesBackend()
        backend.purchaseHandler = { throw IllegalStateException(StoreCopy.productUnavailable(it)) }
        val store = store(backend)

        val result = store.purchase(Activity(), ProductIds.KIT_808)
        assertEquals(PurchaseResult.Failed("Product unavailable: com.handstrudel.kit.808"), result)
        assertEquals("Product unavailable: com.handstrudel.kit.808", store.state.value.lastError)
        assertNull(store.state.value.purchasingProductId)
    }

    @Test fun refresh_clearsStalePurchaseError() = runTest(UnconfinedTestDispatcher()) {
        val backend = FakePurchasesBackend()
        backend.purchaseHandler = { throw IllegalStateException("Payment declined") }
        val store = store(backend)
        store.purchase(Activity(), ProductIds.PRO)
        assertEquals("Payment declined", store.state.value.lastError)

        store.refresh()
        assertNull(store.state.value.lastError)
    }

    @Test fun purchaseWithoutLoadedProduct_stillReachesBackend() = runTest(UnconfinedTestDispatcher()) {
        // The store screen offers BUY PRO before products load; the backend fetches on demand (iOS).
        val backend = FakePurchasesBackend()
        backend.purchaseHandler = { customer(ProductIds.PRO, listOf(Entitlements.PRO)) }
        val store = store(backend)
        assertTrue(store.state.value.products.isEmpty())

        assertEquals(PurchaseResult.Success, store.purchase(Activity(), ProductIds.PRO))
        assertEquals(listOf(ProductIds.PRO), backend.purchases)
        assertTrue(store.hasProAccess)
    }

    @Test fun refresh_loadsProductsAndOffering() = runTest(UnconfinedTestDispatcher()) {
        val backend = FakePurchasesBackend()
        backend.productsResult = listOf(StoreProduct(ProductIds.PRO, "Pro", "", "$9.99", false))
        backend.offering = true
        val store = store(backend)

        store.refresh()
        val s = store.state.value
        assertEquals(listOf(ProductIds.PRO), s.products.map { it.id })
        assertTrue(s.offeringAvailable)
        assertFalse(s.isLoading)
    }

    @Test fun appUserId_isUppercaseUuidLikeIos() {
        val id = UUID.fromString("6f1c2b9e-1d2a-4c3b-9e8f-7a6b5c4d3e2f")
        assertEquals("6F1C2B9E-1D2A-4C3B-9E8F-7A6B5C4D3E2F", StoreManager.appUserId(id))
    }

    @Test fun bind_logsInOnSignIn_andOutOnSignOut() = runTest(UnconfinedTestDispatcher()) {
        val a = UUID.fromString("6f1c2b9e-1d2a-4c3b-9e8f-7a6b5c4d3e2f")
        val b = UUID.fromString("0b7e1a52-3f4d-4e9a-8c1b-2d3e4f5a6b7c")
        val backend = FakePurchasesBackend(customer(ProductIds.PRO, listOf(Entitlements.PRO)))
        val store = store(backend)
        val user = MutableStateFlow<UUID?>(null)

        store.bind(user)
        // Launching signed out stays anonymous: no logIn/logOut.
        assertTrue(backend.logIns.isEmpty())
        assertEquals(0, backend.logOuts)

        user.value = a
        assertEquals(listOf("6F1C2B9E-1D2A-4C3B-9E8F-7A6B5C4D3E2F"), backend.logIns)
        assertTrue(store.hasProAccess) // the account's purchases arrive with logIn

        user.value = b // account switch: straight to the next logIn
        assertEquals(listOf("6F1C2B9E-1D2A-4C3B-9E8F-7A6B5C4D3E2F", "0B7E1A52-3F4D-4E9A-8C1B-2D3E4F5A6B7C"), backend.logIns)
        assertEquals(0, backend.logOuts)

        user.value = null
        assertEquals(1, backend.logOuts)
        assertFalse(store.hasProAccess) // logOut returns the anonymous user's (empty) info

        user.value = null
        assertEquals(1, backend.logOuts)
    }

    @Test fun bind_signedInAtLaunch_logsIn() = runTest(UnconfinedTestDispatcher()) {
        val a = UUID.randomUUID()
        val backend = FakePurchasesBackend()
        store(backend).bind(MutableStateFlow(a))
        assertEquals(listOf(a.toString().uppercase()), backend.logIns)
    }
}
