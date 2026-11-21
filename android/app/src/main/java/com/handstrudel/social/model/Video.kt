package com.handstrudel.social.model

import com.handstrudel.common.UuidSerializer
import com.handstrudel.models.SoundSetup
import com.handstrudel.models.SoundSetupJson
import kotlinx.serialization.KSerializer
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.descriptors.SerialDescriptor
import kotlinx.serialization.descriptors.buildClassSerialDescriptor
import kotlinx.serialization.encoding.Decoder
import kotlinx.serialization.encoding.Encoder
import kotlinx.serialization.json.JsonDecoder
import kotlinx.serialization.json.JsonEncoder
import kotlinx.serialization.json.JsonNull
import java.time.Instant
import java.time.OffsetDateTime
import java.util.UUID

/**
 * iOS `Video` (`Social/SocialModels.swift`): a `videos` row, or a `feed_videos` /
 * `following_videos` / `saved_videos` … view row with the joined fields. Owner: social.
 *
 * Decoding is lenient like iOS: an undecodable or invalid `sound_setup` becomes
 * null instead of failing the row. Timestamps are kept as the raw server strings
 * (iOS keeps `rawCreatedAt` for feed cursors); use [createdAtInstant] for math.
 * Decode with a `Json { ignoreUnknownKeys = true }` instance.
 */
@Serializable
data class Video(
    @Serializable(with = UuidSerializer::class) val id: UUID,
    @SerialName("user_id") @Serializable(with = UuidSerializer::class) val userId: UUID,
    @SerialName("video_key") val videoKey: String,
    @SerialName("thumb_key") val thumbKey: String,
    val caption: String,
    val instrument: String? = null,
    val mode: String? = null,
    @SerialName("duration_s") val durationS: Double? = null,
    val width: Int? = null,
    val height: Int? = null,
    @SerialName("like_count") val likeCount: Int,
    @SerialName("view_count") val viewCount: Int? = null,
    val hidden: Boolean? = null,
    /** Raw timestamptz string (also the feed cursor, iOS `feedCursorTimestamp`). */
    @SerialName("created_at") val createdAt: String,
    // Joined in the feed views only.
    val username: String? = null,
    @SerialName("display_name") val displayName: String? = null,
    @SerialName("avatar_key") val avatarKey: String? = null,
    @SerialName("liked_by_me") val likedByMe: Boolean? = null,
    @SerialName("sound_setup") @Serializable(with = LenientSoundSetupSerializer::class)
    val soundSetup: SoundSetup? = null,
    @SerialName("comments_enabled") val commentsEnabled: Boolean? = null,
    @SerialName("comment_count") val commentCount: Int? = null,
    @SerialName("backing_enabled") val backingEnabled: Boolean? = null,
    @SerialName("source_video_id") @Serializable(with = UuidSerializer::class) val sourceVideoId: UUID? = null,
    @SerialName("source_username") val sourceUsername: String? = null,
    @SerialName("saved_at") val savedAt: String? = null,
    @SerialName("activity_at") val activityAt: String? = null,
    @SerialName("reposted_by") val repostedBy: String? = null,
    @SerialName("reposted_by_id") @Serializable(with = UuidSerializer::class) val repostedById: UUID? = null,
) {
    val createdAtInstant: Instant? get() = parseTimestamp(createdAt)
    val savedAtInstant: Instant? get() = savedAt?.let(::parseTimestamp)

    /** iOS `watchURL`. Media URLs (`videoURL`/`thumbURL`) come from social's `SocialConfig.mediaURL`. */
    val watchUrl: String get() = "https://handstrudel.com/watch?v=${id.toString().lowercase()}"

    companion object {
        fun parseTimestamp(raw: String): Instant? =
            runCatching { OffsetDateTime.parse(raw).toInstant() }.getOrNull()
                ?: runCatching { Instant.parse(raw) }.getOrNull()
    }
}

/** `sound_setup` → [SoundSetup.decodeValidOrNull]; never throws. */
object LenientSoundSetupSerializer : KSerializer<SoundSetup?> {
    override val descriptor: SerialDescriptor = buildClassSerialDescriptor("handstrudel.LenientSoundSetup")

    override fun serialize(encoder: Encoder, value: SoundSetup?) {
        val json = encoder as JsonEncoder
        json.encodeJsonElement(value?.let { SoundSetupJson.encodeToJsonElement(SoundSetup.serializer(), it) } ?: JsonNull)
    }

    override fun deserialize(decoder: Decoder): SoundSetup? {
        val element = (decoder as JsonDecoder).decodeJsonElement()
        return if (element is JsonNull) null else SoundSetup.decodeValidOrNull(element)
    }
}
