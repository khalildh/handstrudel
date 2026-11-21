package com.handstrudel.store

import android.app.Activity

/** In-memory [PurchasesBackend] for JVM tests. Every call is scripted through lambdas. */
class FakePurchasesBackend(
    var info: CustomerSnapshot = CustomerSnapshot(),
) : PurchasesBackend {
    var restoreHandler: suspend () -> CustomerSnapshot = { info }
    var purchaseHandler: suspend (String) -> CustomerSnapshot = { info }
    var productsResult: List<StoreProduct> = emptyList()
    var offering = false
    var customerInfoError: Exception? = null

    var restoreCalls = 0
    val logIns = mutableListOf<String>()
    var logOuts = 0
    val purchases = mutableListOf<String>()
    private var listener: ((CustomerSnapshot) -> Unit)? = null

    override suspend fun customerInfo(): CustomerSnapshot {
        customerInfoError?.let { throw it }
        return info
    }

    override suspend fun restore(): CustomerSnapshot {
        restoreCalls++
        return restoreHandler()
    }

    override suspend fun products(ids: List<String>) = productsResult
    override suspend fun hasCurrentOffering() = offering

    override suspend fun purchase(activity: Activity, productId: String): CustomerSnapshot {
        purchases += productId
        return purchaseHandler(productId)
    }

    override suspend fun logIn(appUserId: String): CustomerSnapshot {
        logIns += appUserId
        return info
    }

    override suspend fun logOut(): CustomerSnapshot {
        logOuts++
        return CustomerSnapshot()
    }

    override fun setListener(listener: (CustomerSnapshot) -> Unit) {
        this.listener = listener
    }

    /** Simulates RevenueCat's `UpdatedCustomerInfoListener`. */
    fun push(info: CustomerSnapshot) {
        this.info = info
        listener?.invoke(info)
    }

    companion object {
        /** iOS test helper `customerInfo(productId:entitlementIds:expiration:)`: active unless [expired]. */
        fun customer(productId: String? = null, entitlementIds: List<String> = emptyList(), expired: Boolean = false, subscription: Boolean = false) =
            CustomerSnapshot(
                activeEntitlements = if (productId != null && !expired) entitlementIds.toSet() else emptySet(),
                activeSubscriptions = if (productId != null && subscription && !expired) setOf(productId) else emptySet(),
                allPurchasedProductIds = setOfNotNull(productId),
            )
    }
}
