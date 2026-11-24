package com.handstrudel.store

/**
 * RevenueCat entitlement ids and the packId → entitlement mapping. A 1:1 port of
 * iOS `StoreManager.entitlementId(for:)` / `legacyProductId(forEntitlement:)`
 * (`Models/StoreManager.swift`, 1.0.1). Pure: no RevenueCat types, unit-tested
 * in `AT/store/EntitlementsTest`.
 *
 * The ids must match the RevenueCat dashboard (shared with iOS, so a purchase on
 * one platform unlocks the same content on the other for the same account).
 */
object Entitlements {
    /** Music content unlock (Pro one-time + Plus subscriptions). */
    const val PRO = "pro"
    /** Filters, hand themes, premium scales: Plus subscriptions only. */
    const val PLUS_FEATURES = "plus_features"
    const val STUDIO = "studio_pack"
    const val PARTY = "party_pack"
    const val KIT_808 = "kit_808"
    const val KIT_ELECTRONIC = "kit_electronic"

    val all: Set<String> = setOf(PRO, PLUS_FEATURES, STUDIO, PARTY, KIT_808, KIT_ELECTRONIC)

    /**
     * Maps a content packId (or a product id) to the entitlement that unlocks it.
     * - Music content (packs, kits, pro) → its own entitlement, granted by Pro or Plus.
     * - Filters, hand themes, premium scales and anything unknown → [PLUS_FEATURES],
     *   which only Plus grants. Pro one-time buyers do NOT get these.
     */
    fun entitlementId(packId: String): String = when (packId) {
        "studio", ProductIds.STUDIO_PACK -> STUDIO
        "party", ProductIds.PARTY_PACK -> PARTY
        "kit_808", ProductIds.KIT_808 -> KIT_808
        "kit_electronic", ProductIds.KIT_ELECTRONIC -> KIT_ELECTRONIC
        "pro", ProductIds.PRO -> PRO
        "filter_pack", "visual_pack", "theme_pack", "scale_pack" -> PLUS_FEATURES
        else -> PLUS_FEATURES
    }

    /** Entitlement → the legacy (iOS) product id it stands for; null for [PLUS_FEATURES] and unknown ids. */
    fun legacyProductId(entitlementId: String): String? = when (entitlementId) {
        STUDIO -> ProductIds.STUDIO_PACK
        PARTY -> ProductIds.PARTY_PACK
        KIT_808 -> ProductIds.KIT_808
        KIT_ELECTRONIC -> ProductIds.KIT_ELECTRONIC
        PRO -> ProductIds.PRO
        else -> null
    }
}
