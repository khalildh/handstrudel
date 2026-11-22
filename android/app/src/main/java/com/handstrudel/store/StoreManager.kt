package com.handstrudel.store

import android.app.Activity
import android.content.Context
import com.handstrudel.BuildConfig
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.util.UUID
import java.util.concurrent.atomic.AtomicBoolean

/**
 * What RevenueCat knows about the customer, reduced to plain values so the
 * gating logic is testable without the SDK. Built from `CustomerInfo` by
 * [RevenueCatBackend].
 */
data class CustomerSnapshot(
    /** Entitlement ids whose `isActive` is true. */
    val activeEntitlements: Set<String> = emptySet(),
    val activeSubscriptions: Set<String> = emptySet(),
    /** Every product ever bought, active or not (iOS `allPurchasedProductIdentifiers`). */
    val allPurchasedProductIds: Set<String> = emptySet(),
    val managementUrl: String? = null,
)

/** Thrown by a [PurchasesBackend] when the user cancelled (RevenueCat `purchaseCancelledError`). */
class StoreCancelledException : Exception("cancelled")

/** Thrown by a [PurchasesBackend] when Play reports the payment as pending. */
class StorePendingException : Exception("pending")

/** The RevenueCat surface [StoreManager] needs. [RevenueCatBackend] is the real one; tests fake it. */
interface PurchasesBackend {
    suspend fun customerInfo(): CustomerSnapshot
    suspend fun restore(): CustomerSnapshot
    suspend fun products(ids: List<String>): List<StoreProduct>
    suspend fun hasCurrentOffering(): Boolean
    /** Buys [productId]; returns the new customer info. Throws [StoreCancelledException] / [StorePendingException]. */
    suspend fun purchase(activity: Activity, productId: String): CustomerSnapshot
    suspend fun logIn(appUserId: String): CustomerSnapshot
    suspend fun logOut(): CustomerSnapshot
    /** Pushes every customer-info change (RevenueCat `UpdatedCustomerInfoListener`). */
    fun setListener(listener: (CustomerSnapshot) -> Unit)
}

/**
 * Debug-only overrides (iOS `--force-locked` and the demo "everything unlocked"
 * switches). [StoreManager] honours them only in debug builds; set them from
 * `StoreDebugActivity` (src/debug) over adb, so the paywall and the unlocked
 * state can be seen without a RevenueCat key.
 */
class StoreDebugOverrides {
    /** Entitlements treated as active on top of the real ones. */
    val grantedEntitlements = MutableStateFlow<Set<String>>(emptySet())
    /** Subscription ids treated as active (e.g. `com.handstrudel.plus:monthly`). */
    val grantedSubscriptions = MutableStateFlow<Set<String>>(emptySet())
    /** Every pack reports locked, whatever is owned. */
    val forceLocked = MutableStateFlow(false)

    fun reset() {
        grantedEntitlements.value = emptySet()
        grantedSubscriptions.value = emptySet()
        forceLocked.value = false
    }

    companion object {
        val shared = StoreDebugOverrides()
    }
}

/**
 * RevenueCat-backed [StoreGate]. Port of iOS `Models/StoreManager.swift` (1.0.1).
 *
 * With no backend (blank `REVENUECAT_API_KEY`) it is unconfigured: only free
 * content (`packId == null`) unlocks, purchase/restore report unavailable and
 * nothing touches RevenueCat.
 */
class StoreManager(
    private val backend: PurchasesBackend?,
    private val scope: CoroutineScope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate),
    private val debug: StoreDebugOverrides? = if (BuildConfig.DEBUG) StoreDebugOverrides.shared else null,
) : StoreGate {

    override val isConfigured: Boolean get() = backend != null

    private val _state = MutableStateFlow(StoreState())
    override val state: StateFlow<StoreState> = _state.asStateFlow()

    /** Last customer info from RevenueCat; null until the first fetch (iOS `customerInfo`). */
    private var customerInfo: CustomerSnapshot? = null
    private val restoring = AtomicBoolean(false)

    init {
        if (backend != null) {
            backend.setListener { apply(it) }
            scope.launch { refreshCustomerInfo() }
        }
        if (debug != null) {
            scope.launch {
                combine(debug.grantedEntitlements, debug.grantedSubscriptions, debug.forceLocked) { _, _, _ -> }
                    .collect { publish() }
            }
        }
    }

    // MARK: - Access checks

    /** Real info merged with debug grants; null when there is neither. */
    private fun effective(): CustomerSnapshot? {
        val real = customerInfo
        val d = debug ?: return real
        if (d.forceLocked.value) return CustomerSnapshot()
        val ents = d.grantedEntitlements.value
        val subs = d.grantedSubscriptions.value
        if (ents.isEmpty() && subs.isEmpty()) return real
        val base = real ?: CustomerSnapshot()
        return base.copy(
            activeEntitlements = base.activeEntitlements + ents,
            activeSubscriptions = base.activeSubscriptions + subs,
        )
    }

    override fun isUnlocked(packId: String?): Boolean {
        if (packId == null) return true
        val info = effective() ?: return false
        return Entitlements.entitlementId(packId) in info.activeEntitlements
    }

    /** Pro music content (Pro one-time or a Plus subscription). */
    override val hasProAccess: Boolean
        get() = effective()?.activeEntitlements?.contains(Entitlements.PRO) == true

    /** Plus-only features (filters, themes, premium scales). Pro one-time does not grant these. */
    override val hasPlusFeatures: Boolean
        get() = effective()?.activeEntitlements?.contains(Entitlements.PLUS_FEATURES) == true

    /** An active recurring Plus subscription; not the one-time Pro (see [hasProAccess]). */
    override val hasSubscription: Boolean
        get() = effective()?.activeSubscriptions?.any(ProductIds::isPlusSubscription) == true

    // MARK: - Load

    override suspend fun refresh() {
        val backend = backend ?: return
        // A failure from an earlier purchase (e.g. in a paywall) shouldn't greet the next visit.
        _state.update { it.copy(isLoading = true, lastError = null) }
        try {
            val products = runCatching { backend.products(ProductIds.playFetchIds) }.getOrDefault(emptyList())
            val offering = runCatching { backend.hasCurrentOffering() }.getOrDefault(false)
            _state.update { it.copy(products = products, offeringAvailable = offering) }
            refreshCustomerInfo()
        } finally {
            _state.update { it.copy(isLoading = false) }
        }
    }

    private suspend fun refreshCustomerInfo() {
        val backend = backend ?: return
        try {
            apply(backend.customerInfo())
        } catch (e: CancellationException) {
            throw e
        } catch (_: Exception) {
            // Offline etc.: keep what we had (iOS logs and moves on).
        }
    }

    // MARK: - Purchase

    override suspend fun purchase(activity: Activity, productId: String): PurchaseResult {
        val backend = backend ?: return PurchaseResult.Failed(StoreCopy.UNAVAILABLE)
        _state.update { it.copy(purchasingProductId = productId, lastError = null) }
        return try {
            apply(backend.purchase(activity, productId))
            PurchaseResult.Success
        } catch (e: StoreCancelledException) {
            PurchaseResult.Cancelled
        } catch (e: StorePendingException) {
            PurchaseResult.Pending
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            val message = e.message?.takeIf { it.isNotBlank() } ?: "Purchase failed. Please try again."
            _state.update { it.copy(lastError = message) }
            PurchaseResult.Failed(message)
        } finally {
            _state.update { it.copy(purchasingProductId = null) }
        }
    }

    // MARK: - Restore

    /** iOS `restorePurchases(for:)`. Null means another restore is already running. */
    override suspend fun restore(packId: String?): RestoreOutcome? {
        val backend = backend ?: return RestoreOutcome.FAILED
        if (!restoring.compareAndSet(false, true)) return null
        _state.update { it.copy(isRestoring = true) }
        try {
            val info = backend.restore()
            apply(info)
            if (packId != null && isUnlocked(packId)) return RestoreOutcome.ACCESS_AVAILABLE
            // Purchase history can include expired subscriptions. Only active access counts.
            val hasActivePurchase = hasSubscription || info.activeEntitlements.any {
                Entitlements.legacyProductId(it) != null || it == Entitlements.PLUS_FEATURES
            }
            if (!hasActivePurchase) return RestoreOutcome.NO_ACTIVE_PURCHASES
            return if (packId == null) RestoreOutcome.ACCESS_AVAILABLE else RestoreOutcome.REQUESTED_ITEM_UNAVAILABLE
        } catch (e: StoreCancelledException) {
            return RestoreOutcome.CANCELLED
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            return RestoreOutcome.FAILED
        } finally {
            restoring.set(false)
            _state.update { it.copy(isRestoring = false) }
        }
    }

    // MARK: - Account binding

    /** RevenueCat `logIn`. [appUserId] is the Supabase user id, uppercase like iOS `uuidString`. */
    override suspend fun logIn(appUserId: String) {
        val backend = backend ?: return
        try {
            apply(backend.logIn(appUserId))
        } catch (e: CancellationException) {
            throw e
        } catch (_: Exception) {
            // iOS: `try?` — purchases stay on the current RevenueCat user.
        }
    }

    override suspend fun logOut() {
        val backend = backend ?: return
        try {
            apply(backend.logOut())
        } catch (e: CancellationException) {
            throw e
        } catch (_: Exception) {
        }
    }

    /**
     * Follows sign-in: a new signed-in user → `logIn(UUID uppercase)` (iOS
     * `Purchases.logIn(session.user.id.uuidString)`), signing out → `logOut()`.
     * Launching signed-out does nothing (stays on the anonymous RevenueCat user).
     */
    override fun bind(userId: StateFlow<UUID?>) {
        if (backend == null) return
        scope.launch {
            var last: UUID? = null
            userId.collect { id ->
                when {
                    id != null && id != last -> logIn(appUserId(id))
                    id == null && last != null -> logOut()
                }
                last = id
            }
        }
    }

    // MARK: - Apply

    private fun apply(info: CustomerSnapshot) {
        customerInfo = info
        publish()
    }

    /** Recomputes the published state from the effective customer info. */
    private fun publish() {
        val info = effective()
        // Map active entitlements back to legacy product ids, plus every raw product id (iOS `purchasedIds`).
        val ids = buildSet {
            info?.activeEntitlements?.forEach { ent -> Entitlements.legacyProductId(ent)?.let(::add) }
            info?.allPurchasedProductIds?.let(::addAll)
        }
        _state.update {
            it.copy(
                activeEntitlements = info?.activeEntitlements.orEmpty(),
                activeSubscriptions = info?.activeSubscriptions.orEmpty(),
                purchasedIds = ids,
                managementUrl = info?.managementUrl,
            )
        }
    }

    companion object {
        /** RevenueCat app user id for a Supabase user: the UUID uppercased, as iOS `UUID.uuidString`. */
        fun appUserId(userId: UUID): String = userId.toString().uppercase()

        @Volatile private var instance: StoreManager? = null

        /**
         * The process-wide store. Configures RevenueCat only when
         * `BuildConfig.REVENUECAT_API_KEY` is non-blank; otherwise returns an
         * unconfigured manager (everything paid stays locked).
         */
        fun create(context: Context, apiKey: String = BuildConfig.REVENUECAT_API_KEY): StoreManager =
            instance ?: synchronized(this) {
                instance ?: StoreManager(
                    backend = apiKey.takeIf { it.isNotBlank() }?.let { RevenueCatBackend.configure(context.applicationContext, it) },
                ).also { instance = it }
            }
    }
}
