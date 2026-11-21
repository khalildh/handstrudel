package com.handstrudel.store

/**
 * Store product ids. The legacy constants are iOS `StoreManager`'s (kept so the
 * packId mapping is identical across platforms); the Google Play ids are what
 * the Android build fetches and buys (docs/android-parity.md WS6, risk R3).
 */
object ProductIds {
    // iOS / legacy product ids (StoreManager.swift).
    const val STUDIO_PACK = "com.handstrudel.pack.studio"
    const val PARTY_PACK = "com.handstrudel.pack.party"
    const val KIT_808 = "com.handstrudel.kit.808"
    const val KIT_ELECTRONIC = "com.handstrudel.kit.electronic"
    const val PRO = "com.handstrudel.pro"
    const val IOS_PLUS_MONTHLY = "com.handstrudel.plus.monthly"
    const val IOS_PLUS_YEARLY = "com.handstrudel.plus.yearly"

    /** iOS `allProductIds` (2 packs + 2 kits + pro + 2 subscriptions). */
    val iosAllProductIds: Set<String> = setOf(
        STUDIO_PACK, PARTY_PACK, KIT_808, KIT_ELECTRONIC, PRO, IOS_PLUS_MONTHLY, IOS_PLUS_YEARLY,
    )

    // Google Play. Pro and the kits keep the iOS ids (one-time, non-consumable).
    // Plus is one subscription with two base plans; RevenueCat names each
    // purchasable option `<subscriptionId>:<basePlanId>`.
    const val PLUS_SUBSCRIPTION = "com.handstrudel.plus"
    const val PLUS_MONTHLY = "$PLUS_SUBSCRIPTION:monthly"
    const val PLUS_YEARLY = "$PLUS_SUBSCRIPTION:yearly"

    /** What `StoreManager.loadProducts` asks Play for (subscriptions by subscription id). */
    val playFetchIds: List<String> = listOf(PRO, KIT_808, KIT_ELECTRONIC, PLUS_SUBSCRIPTION)

    /** Plus base plans, monthly first. */
    val plusPlans: List<String> = listOf(PLUS_MONTHLY, PLUS_YEARLY)

    /**
     * True for an active-subscription id that is HandStrudel+ on either store:
     * Play (`com.handstrudel.plus` / `com.handstrudel.plus:<basePlan>`) or the iOS
     * monthly/yearly products (same RevenueCat project, so an iOS subscription
     * shows up in the Android customer info).
     */
    fun isPlusSubscription(id: String): Boolean =
        id == PLUS_SUBSCRIPTION || id.startsWith("$PLUS_SUBSCRIPTION:") ||
            id == IOS_PLUS_MONTHLY || id == IOS_PLUS_YEARLY

    /** iOS `StoreManager.productId(for:)`: packId → the product that unlocks it (unknown → Pro). */
    fun productId(packId: String): String = when (packId) {
        "studio", STUDIO_PACK -> STUDIO_PACK
        "party", PARTY_PACK -> PARTY_PACK
        "kit_808", KIT_808 -> KIT_808
        "kit_electronic", KIT_ELECTRONIC -> KIT_ELECTRONIC
        "pro", "filter_pack", "visual_pack" -> PRO
        else -> PRO
    }
}
