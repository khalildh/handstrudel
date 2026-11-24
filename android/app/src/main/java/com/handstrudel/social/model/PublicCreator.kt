package com.handstrudel.social.model

import com.handstrudel.common.UuidSerializer
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import java.util.UUID

/** iOS `PublicCreator`: a `public_creators` row (older rows lack the totals). */
@Serializable
data class PublicCreator(
    @Serializable(with = UuidSerializer::class) val id: UUID,
    val username: String,
    @SerialName("display_name") val displayName: String? = null,
    @SerialName("avatar_key") val avatarKey: String? = null,
    @SerialName("likes_received") val likesReceived: Int? = null,
    @SerialName("views_received") val viewsReceived: Int? = null,
) {
    companion object {
        /** iOS `init?(visibleVideo:)`: identity from a visible feed row on older deployments. */
        fun fromVisibleVideo(video: Video): PublicCreator? {
            val username = video.username ?: return null
            return PublicCreator(video.userId, username, video.displayName, video.avatarKey)
        }
    }
}
