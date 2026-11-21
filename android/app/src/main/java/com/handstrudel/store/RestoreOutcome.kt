package com.handstrudel.store

/** iOS `StoreManager.RestoreOutcome`. */
enum class RestoreOutcome {
    ACCESS_AVAILABLE, NO_ACTIVE_PURCHASES, REQUESTED_ITEM_UNAVAILABLE, CANCELLED, FAILED;

    /** iOS `RestorePurchasesButton.message(for:)`, with the Google account in place of the Apple Account. */
    val message: String
        get() = when (this) {
            ACCESS_AVAILABLE -> "Your available purchases are up to date."
            NO_ACTIVE_PURCHASES -> "No active HandStrudel purchases were found. Check that you’re using the Google account you bought them with."
            REQUESTED_ITEM_UNAVAILABLE -> "Your available purchases are up to date, but they don’t include this item."
            CANCELLED -> "Restore was canceled. You can try again whenever you’re ready."
            FAILED -> "We couldn’t restore your purchases. Please try again."
        }
}
