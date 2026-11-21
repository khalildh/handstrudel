package com.handstrudel.store

import android.app.Activity
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import java.util.UUID

/**
 * Entitlement and purchase seam. Owner: store (WS6). Ports iOS `StoreManager`.
 * Consumers (studio-ui, capture, shell) only call this interface.
 */
interface StoreGate {
    /** False when `BuildConfig.REVENUECAT_API_KEY` is blank: nothing paid unlocks, store hidden. */
    val isConfigured: Boolean
    val state: StateFlow<StoreState>

    /** True for free content (`packId == null`) and for packs whose entitlement is active. */
    fun isUnlocked(packId: String?): Boolean
    val hasProAccess: Boolean
    val hasPlusFeatures: Boolean
    val hasSubscription: Boolean

    suspend fun purchase(activity: Activity, productId: String): PurchaseResult
    /** iOS `restorePurchases(for:)`; null when a restore is already running. */
    suspend fun restore(packId: String? = null): RestoreOutcome?

    suspend fun logIn(appUserId: String)
    suspend fun logOut()
    /** Shell calls this once in `AppServices` wiring; store follows sign-in/out (RevenueCat logIn/logOut). */
    fun bind(userId: StateFlow<UUID?>)
}

/** Store UI state. */
data class StoreState(
    val products: List<StoreProduct> = emptyList(),
    val isLoading: Boolean = false,
    val isRestoring: Boolean = false,
    val purchasingProductId: String? = null,
    /** Active entitlement ids: `pro`, `plus_features`, `studio_pack`, `party_pack`, `kit_808`, `kit_electronic`. */
    val activeEntitlements: Set<String> = emptySet(),
    val lastError: String? = null,
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

/** iOS `StoreManager.RestoreOutcome`. */
enum class RestoreOutcome { ACCESS_AVAILABLE, NO_ACTIVE_PURCHASES, REQUESTED_ITEM_UNAVAILABLE, CANCELLED, FAILED }

/** Phase 0 stub == the "no RevenueCat key" behaviour. Store WS replaces it with `StoreManager`. */
class UnconfiguredStoreGate : StoreGate {
    override val isConfigured: Boolean = false
    override val state: StateFlow<StoreState> = MutableStateFlow(StoreState())
    override fun isUnlocked(packId: String?): Boolean = packId == null
    override val hasProAccess: Boolean = false
    override val hasPlusFeatures: Boolean = false
    override val hasSubscription: Boolean = false
    override suspend fun purchase(activity: Activity, productId: String): PurchaseResult =
        PurchaseResult.Failed("Purchases aren't available in this build")
    override suspend fun restore(packId: String?): RestoreOutcome = RestoreOutcome.FAILED
    override suspend fun logIn(appUserId: String) = Unit
    override suspend fun logOut() = Unit
    override fun bind(userId: StateFlow<UUID?>) = Unit
}
