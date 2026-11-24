import Foundation

/// Growth-funnel events for 1.0.2. Thin, named wrappers over `AppAnalytics` so feature code calls
/// one line (`Funnel.storeViewed()`) and the opt-in, allow-list and once-only rules live in one place.
/// Nothing is sent unless the player turned on Usage Analytics; totals are daily counts per event.
@MainActor
enum Funnel {
    static var analytics: AppAnalytics = .shared

    // Store
    static func storeViewed() { analytics.record(.storeViewed) }
    static func purchaseStarted(productId: String) { purchase(.purchaseStarted, productId) }
    static func purchaseCompleted(productId: String) { purchase(.purchaseCompleted, productId) }
    static func restoreTapped() { analytics.record(.restoreTapped) }

    // Invites
    static func inviteLinkShared() { analytics.record(.inviteLinkShared) }
    /// Call once the server accepted the code. Also remembers (on the device only) that this install
    /// was invited, so its first post also counts as `invited_first_post`.
    static func inviteCodeRedeemed() {
        analytics.setMarker(invitedMarker)
        analytics.record(.inviteCodeRedeemed)
    }

    // Replies and challenges
    static func replyStarted() { analytics.record(.replyStarted) }
    static func replyPosted() { analytics.record(.replyPosted) }
    static func challengeLinkShared() { analytics.record(.challengeLinkShared) }
    static func challengeLinkOpened() { analytics.record(.challengeLinkOpened) }

    // Daily sound
    static func dailySoundOpened() { analytics.record(.dailySoundOpened) }
    static func dailyTakePosted() { analytics.record(.dailyTakePosted) }
    static func streakExtended() { analytics.record(.streakExtended) }

    // Sounds
    static func soundPageOpened() { analytics.record(.soundPageOpened) }
    static func playThisSoundTapped() { analytics.record(.playThisSoundTapped) }

    // Push
    /// `pushType` is the payload's type string; unknown types are counted as `other`.
    static func notificationOpened(pushType: String) {
        analytics.record(.notificationOpened, detail: AppAnalytics.NotificationKind(pushType: pushType).rawValue)
    }

    // Activation
    /// Once per install (shares the existing `first_note` counter).
    static func firstNotePlayed() { analytics.record(.firstNote) }
    /// Call on every confirmed public post; only the install's first one counts, and it also counts
    /// as `invited_first_post` when this install redeemed an invite.
    static func postPublished() {
        analytics.recordOnce(.firstPostPublished, key: "first_post_published")
        if analytics.hasMarker(invitedMarker) {
            analytics.recordOnce(.invitedFirstPost, key: "invited_first_post")
        }
    }

    private static let invitedMarker = "invite_code_redeemed"

    private static func purchase(_ event: AppAnalytics.Event, _ productId: String) {
        guard let product = AppAnalytics.PurchaseProduct(productId: productId) else { return }
        analytics.record(event, detail: product.rawValue)
    }
}
