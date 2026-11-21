package com.handstrudel.social.model

import com.handstrudel.common.SwiftUuidSerializer
import kotlinx.serialization.Serializable
import java.util.UUID

/**
 * iOS `BackingCredit`: the play-along source credited in drafts and posts.
 * Owner: social. Stored in draft metadata with Swift-style (camelCase, uppercase UUID) coding.
 */
@Serializable
data class BackingCredit(
    @Serializable(with = SwiftUuidSerializer::class) val videoId: UUID,
    val username: String,
)
