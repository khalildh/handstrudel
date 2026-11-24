package com.handstrudel.store

/** Paywall copy for a pack. iOS `ControlSheetView.packInfo(for:)` / `proPaywall(storeManager:)`. */
data class PackInfo(val name: String, val description: String, val items: List<String>)

object PackCatalog {
    val pro = PackInfo(
        name = "Pro Upgrade",
        description = "Unlock every instrument, scale, and chord progression.",
        items = listOf(
            "120+ additional GM instruments",
            "Every scale — modes, harmonic minor, exotic",
            "Every chord progression — jazz, cinematic, world, and more",
            "One-time purchase",
        ),
    )

    fun info(packId: String): PackInfo = when (ProductIds.productId(packId)) {
        ProductIds.STUDIO_PACK -> PackInfo(
            "Studio Pack", "7 professional studio presets",
            listOf("Tape", "Glass", "Deep", "Foggy", "Pulse", "Cosmic", "Glitch"),
        )
        ProductIds.PARTY_PACK -> PackInfo(
            "Party Pack", "9 high-energy party presets",
            listOf("EDM", "DnB", "Dubstep", "Rave", "Reggaeton", "Future Bass", "Techno", "Garage", "Phonk"),
        )
        ProductIds.KIT_808 -> PackInfo(
            "808 Kit", "8 hip-hop & urban drum patterns",
            listOf("Boom Bap", "Drill", "Lo-Fi Hip Hop", "R&B", "Afrobeat", "Bounce", "Jersey Club", "Memphis"),
        )
        ProductIds.KIT_ELECTRONIC -> PackInfo(
            "Electronic Kit", "8 electronic drum patterns",
            listOf("Techno", "Breakbeat", "IDM", "Jungle", "Ambient", "Industrial", "2-Step", "Synthwave"),
        )
        ProductIds.PRO -> pro
        else -> PackInfo("Pack", "Premium content", emptyList())
    }
}
