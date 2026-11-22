package com.handstrudel.social.model

import com.handstrudel.common.UuidSerializer
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import java.time.Instant
import java.util.UUID

/** iOS `VideoComment`: a `video_comments` view row. */
@Serializable
data class VideoComment(
    @Serializable(with = UuidSerializer::class) val id: UUID,
    @SerialName("video_id") @Serializable(with = UuidSerializer::class) val videoId: UUID,
    @SerialName("user_id") @Serializable(with = UuidSerializer::class) val userId: UUID,
    @SerialName("parent_id") @Serializable(with = UuidSerializer::class) val parentId: UUID? = null,
    val body: String,
    @SerialName("created_at") val createdAt: String,
    val username: String,
    @SerialName("reply_count") val replyCount: Int,
    @SerialName("like_count") val likeCount: Int? = null,
    @SerialName("liked_by_me") val likedByMe: Boolean? = null,
) {
    val createdAtInstant: Instant? get() = Video.parseTimestamp(createdAt)

    /** iOS `applyLike`: no-op when counts are unknown or the state already matches. */
    fun applyingLike(liked: Boolean): VideoComment {
        val count = likeCount ?: return this
        if ((likedByMe == true) == liked) return this
        return copy(likeCount = maxOf(0, count + if (liked) 1 else -1), likedByMe = liked)
    }

    companion object {
        const val MAX_LENGTH = 300

        fun trimmed(input: String): String = input.trim { it.isWhitespace() || it == '\u0085' }

        /** Length in Unicode scalars (code points), like Swift's `unicodeScalars.count`. */
        fun scalarCount(input: String): Int = input.codePointCount(0, input.length)

        fun isValidBody(input: String): Boolean = scalarCount(trimmed(input)) in 1..MAX_LENGTH

        /** iOS `CommentsView.replyTargetAfterRefresh`. */
        fun replyTargetAfterRefresh(target: VideoComment?, firstPage: List<VideoComment>): VideoComment? {
            target ?: return null
            // The first page may omit older threads. Only the server can confirm a reply is unavailable.
            return firstPage.firstOrNull { it.id == target.id } ?: target
        }
    }
}
