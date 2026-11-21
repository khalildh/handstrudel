package com.handstrudel.social.model

import com.handstrudel.common.UuidSerializer
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import java.time.Instant
import java.util.UUID

/** iOS `WeeklyChallenge`: the current `weekly_challenges` row. */
@Serializable
data class WeeklyChallenge(
    @Serializable(with = UuidSerializer::class) val id: UUID,
    @SerialName("source_video_id") @Serializable(with = UuidSerializer::class) val sourceVideoId: UUID,
    val title: String,
    val prompt: String,
    @SerialName("ends_at") val endsAt: String,
) {
    val endsAtInstant: Instant? get() = Video.parseTimestamp(endsAt)
}
