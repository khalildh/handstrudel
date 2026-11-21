package com.handstrudel.store

import android.app.Activity
import android.content.Context
import com.revenuecat.purchases.CustomerInfo
import com.revenuecat.purchases.LogLevel
import com.revenuecat.purchases.ProductType
import com.revenuecat.purchases.PurchaseParams
import com.revenuecat.purchases.Purchases
import com.revenuecat.purchases.PurchasesConfiguration
import com.revenuecat.purchases.PurchasesErrorCode
import com.revenuecat.purchases.PurchasesException
import com.revenuecat.purchases.PurchasesTransactionException
import com.revenuecat.purchases.awaitCustomerInfo
import com.revenuecat.purchases.awaitGetProducts
import com.revenuecat.purchases.awaitLogIn
import com.revenuecat.purchases.awaitLogOut
import com.revenuecat.purchases.awaitOfferings
import com.revenuecat.purchases.awaitPurchase
import com.revenuecat.purchases.awaitRestore
import com.revenuecat.purchases.interfaces.UpdatedCustomerInfoListener
import com.revenuecat.purchases.models.StoreProduct as RcProduct

/** [PurchasesBackend] over the RevenueCat Android SDK. Only created when an API key exists. */
class RevenueCatBackend private constructor(private val purchases: Purchases) : PurchasesBackend {

    /** RevenueCat products by id, so a purchase doesn't refetch what the store already loaded. */
    private val cache = mutableMapOf<String, RcProduct>()

    override suspend fun customerInfo(): CustomerSnapshot = purchases.awaitCustomerInfo().snapshot()

    override suspend fun restore(): CustomerSnapshot = translating { purchases.awaitRestore().snapshot() }

    override suspend fun products(ids: List<String>): List<StoreProduct> {
        val fetched = fetch(ids)
        // Loaded products, in fetch order; Plus plans monthly before yearly.
        return fetched.sortedBy { order(it.id) }.map { it.toStoreProduct() }
    }

    override suspend fun hasCurrentOffering(): Boolean = purchases.awaitOfferings().current != null

    override suspend fun purchase(activity: Activity, productId: String): CustomerSnapshot {
        val product = cache[productId]
            ?: fetch(listOf(productId.substringBefore(':'))).firstOrNull { it.id == productId || productId == it.id.substringBefore(':') }
            ?: throw IllegalStateException(StoreCopy.productUnavailable(productId))
        return translating {
            purchases.awaitPurchase(PurchaseParams.Builder(activity, product).build()).customerInfo.snapshot()
        }
    }

    override suspend fun logIn(appUserId: String): CustomerSnapshot =
        translating { purchases.awaitLogIn(appUserId).customerInfo.snapshot() }

    override suspend fun logOut(): CustomerSnapshot = translating { purchases.awaitLogOut().snapshot() }

    override fun setListener(listener: (CustomerSnapshot) -> Unit) {
        purchases.updatedCustomerInfoListener = UpdatedCustomerInfoListener { listener(it.snapshot()) }
    }

    private suspend fun fetch(ids: List<String>): List<RcProduct> {
        val inApp = ids.filterNot { it == ProductIds.PLUS_SUBSCRIPTION }
        val subs = ids.filter { it == ProductIds.PLUS_SUBSCRIPTION }
        val out = mutableListOf<RcProduct>()
        if (inApp.isNotEmpty()) out += purchases.awaitGetProducts(inApp, ProductType.INAPP)
        if (subs.isNotEmpty()) out += purchases.awaitGetProducts(subs, ProductType.SUBS)
        out.forEach { cache[it.id] = it }
        return out
    }

    private fun order(id: String): Int {
        val plan = ProductIds.plusPlans.indexOf(id)
        if (plan >= 0) return 100 + plan
        val i = ProductIds.playFetchIds.indexOf(id)
        return if (i >= 0) i else 50
    }

    private inline fun <T> translating(block: () -> T): T = try {
        block()
    } catch (e: PurchasesTransactionException) {
        if (e.userCancelled) throw StoreCancelledException()
        throw e.translated()
    } catch (e: PurchasesException) {
        throw e.translated()
    }

    private fun PurchasesException.translated(): Exception = when (code) {
        PurchasesErrorCode.PurchaseCancelledError -> StoreCancelledException()
        PurchasesErrorCode.PaymentPendingError -> StorePendingException()
        else -> IllegalStateException(error.message, this)
    }

    companion object {
        fun configure(context: Context, apiKey: String): RevenueCatBackend {
            if (!Purchases.isConfigured) {
                Purchases.logLevel = LogLevel.ERROR
                Purchases.configure(PurchasesConfiguration.Builder(context, apiKey).build())
            }
            return RevenueCatBackend(Purchases.sharedInstance)
        }
    }
}

private fun CustomerInfo.snapshot() = CustomerSnapshot(
    activeEntitlements = entitlements.active.filterValues { it.isActive }.keys,
    activeSubscriptions = activeSubscriptions,
    allPurchasedProductIds = allPurchasedProductIds,
    managementUrl = managementURL?.toString(),
)

private fun RcProduct.toStoreProduct() = StoreProduct(
    id = id,
    title = name.ifBlank { title },
    description = description,
    displayPrice = price.formatted,
    isSubscription = type == ProductType.SUBS,
)
