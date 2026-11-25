import SwiftUI

/// The store opened from a locked music item (instrument, scale, progression,
/// preset, drum pattern). Pro unlocks it; HandStrudel+ includes it too.
@MainActor
func proPaywall(storeManager: StoreManager, title: String = "Unlock every sound",
                detail: String = "Every instrument, scale, and chord progression is yours with Pro.") -> StoreView {
    StoreView(storeManager: storeManager, highlight: .pro, headline: title, detail: detail, unlocks: StoreManager.pro)
}

/// The store opened from any locked item, featuring the plan that unlocks it.
@MainActor
func upgradeSheet(storeManager: StoreManager, packId: String) -> StoreView {
    switch StoreManager.offer(for: packId) {
    case .plus:
        return StoreView(storeManager: storeManager, highlight: .plus, headline: "Make it look like you",
                         detail: "Premium camera filters and hand themes come with HandStrudel+, along with everything in Pro.",
                         unlocks: packId)
    case .pro:
        return StoreView(storeManager: storeManager, highlight: .pro, headline: "Unlock every sound",
                         detail: "This is part of Pro: every instrument, scale, progression, preset and drum pack.",
                         unlocks: packId)
    }
}
