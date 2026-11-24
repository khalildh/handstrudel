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
    /**
     * False when `BuildConfig.REVENUECAT_API_KEY` is blank: nothing paid unlocks. The store and
     * PRO badges still show (iOS with no products loaded); purchases fail with "Product unavailable".
     */
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

    /**
     * Reloads products, the current offering and customer info (iOS `loadProducts`).
     * The store screen calls it on appear. Default no-op so test fakes needn't implement it.
     */
    suspend fun refresh() {}

    suspend fun logIn(appUserId: String)
    suspend fun logOut()
    /** Shell calls this once in `AppServices` wiring; store follows sign-in/out (RevenueCat logIn/logOut). */
    fun bind(userId: StateFlow<UUID?>)
}

/**
 * The "no RevenueCat key" behaviour as a plain fake (handy in other workstreams' tests).
 * The app uses [StoreManager.create], which behaves the same way when the key is blank.
 */
class UnconfiguredStoreGate : StoreGate {
    override val isConfigured: Boolean = false
    override val state: StateFlow<StoreState> = MutableStateFlow(StoreState())
    override fun isUnlocked(packId: String?): Boolean = packId == null
    override val hasProAccess: Boolean = false
    override val hasPlusFeatures: Boolean = false
    override val hasSubscription: Boolean = false
    override suspend fun purchase(activity: Activity, productId: String): PurchaseResult =
        PurchaseResult.Failed(StoreCopy.productUnavailable(productId))
    override suspend fun restore(packId: String?): RestoreOutcome = RestoreOutcome.FAILED
    override suspend fun logIn(appUserId: String) = Unit
    override suspend fun logOut() = Unit
    override fun bind(userId: StateFlow<UUID?>) = Unit
}
