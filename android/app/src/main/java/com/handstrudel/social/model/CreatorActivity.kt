package com.handstrudel.social.model

import com.handstrudel.common.UuidSerializer
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import java.time.Instant
import java.util.UUID

/** iOS `CreatorActivity`: an `activity_inbox(_v2)` row. [createdAt] is the raw timestamp (cursor). */
@Serializable
data class CreatorActivity(
    @Serializable(with = UuidSerializer::class) val id: UUID,
    @SerialName("video_id") @Serializable(with = UuidSerializer::class) val videoId: UUID,
    @SerialName("comment_id") @Serializable(with = UuidSerializer::class) val commentId: UUID? = null,
    val kind: Kind,
    @SerialName("created_at") val createdAt: String,
    @SerialName("read_at") val readAt: String? = null,
    val username: String,
    val body: String,
    @SerialName("like_count") val likeCount: Int? = null,
) {
    /** iOS `timestamp`: the exact server string, used for cursors and `seen_at`. */
    val timestamp: String get() = createdAt
    val createdAtInstant: Instant? get() = Video.parseTimestamp(createdAt)
    val isUnread: Boolean get() = readAt == null

    @Serializable
    enum class Kind {
        @SerialName("comment") COMMENT,
        @SerialName("reply") REPLY,
        @SerialName("video_like") VIDEO_LIKE,
        @SerialName("comment_like") COMMENT_LIKE,
        @SerialName("reply_like") REPLY_LIKE;

        val isLike: Boolean get() = this != COMMENT && this != REPLY
        val commentAction: String get() = if (this == REPLY || this == REPLY_LIKE) "View reply" else "View comment"
    }

    val title: String
        get() {
            val actor = "@$username"
            val others = maxOf(0, (likeCount ?: 1) - 1)
            val who = if (others == 0) actor else "$actor and $others ${if (others == 1) "other" else "others"}"
            return when (kind) {
                Kind.COMMENT -> "$actor commented on your video"
                Kind.REPLY -> "$actor replied to you"
                Kind.VIDEO_LIKE -> "$who liked your video"
                Kind.COMMENT_LIKE -> "$who liked your comment"
                Kind.REPLY_LIKE -> "$who liked your reply"
            }
        }
}
