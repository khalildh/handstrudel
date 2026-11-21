package com.handstrudel.app

import java.util.UUID

/**
 * In-app review milestones (iOS `CreatorReviewMilestones`). Owner: shell.
 * Capture reports each successful new take; shell decides when to ask
 * (3 new takes, once per app version, once per 90 days, Music tab idle).
 */
interface ReviewPrompt {
    fun recordSuccessfulTake(draftId: UUID)
}

class NoopReviewPrompt : ReviewPrompt {
    override fun recordSuccessfulTake(draftId: UUID) = Unit
}
