package com.handstrudel.store

/** Store UI state, published by [StoreGate.state]. */
data class StoreState(
    val products: List<StoreProduct> = emptyList(),
    val isLoading: Boolean = false,
    val isRestoring: Boolean = false,
    val purchasingProductId: String? = null,
    /** Active entitlement ids: `pro`, `plus_features`, `studio_pack`, `party_pack`, `kit_808`, `kit_electronic`. */
    val activeEntitlements: Set<String> = emptySet(),
    val lastError: String? = null,
    /** iOS `purchasedIds`: legacy product ids of active entitlements + every purchased product id. */
    val purchasedIds: Set<String> = emptySet(),
    /** Active subscription product ids (any store in the RevenueCat project). */
    val activeSubscriptions: Set<String> = emptySet(),
    /** Where "Manage subscription" goes (RevenueCat's management URL), when known. */
    val managementUrl: String? = null,
    /** True when RevenueCat has a current offering, so the HandStrudel+ paywall can show. */
    val offeringAvailable: Boolean = false,
)

data class StoreProduct(
    val id: String,
    val title: String,
    val description: String,
    val displayPrice: String,
    val isSubscription: Boolean,
)

sealed interface PurchaseResult {
    data object Success : PurchaseResult
    data object Cancelled : PurchaseResult
    data object Pending : PurchaseResult
    data class Failed(val message: String) : PurchaseResult
}

/** User-facing store copy shared by the manager and the UI. */
object StoreCopy {
    /** Google Play pending purchase (e.g. cash or a slow payment method). */
    const val PENDING = "Your purchase is pending. It will unlock once the payment completes."
    fun productUnavailable(id: String) = "Product unavailable: $id"
}
