package com.handstrudel.capture.upload

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
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonDecoder
import kotlinx.serialization.json.JsonEncoder
import kotlinx.serialization.json.JsonNull
import java.util.UUID

// Ports of the upload types in iOS `Social/SocialModels.swift`. Owner: capture.

/** JSON for the upload functions and draft metadata: unknown keys ignored, nulls omitted (Swift `encodeIfPresent`). */
val UploadJson: Json = Json {
    ignoreUnknownKeys = true
    encodeDefaults = true
    explicitNulls = false
}

/** iOS `VideoPostFields`: the `fields` of `publish-upload` `submit` (snake_case keys). */
@Serializable
data class VideoPostFields(
    val caption: String,
    val instrument: String? = null,
    val mode: String? = null,
    @SerialName("duration_s") val durationS: Double,
    val width: Int,
    val height: Int,
    @SerialName("sound_setup") @Serializable(with = SoundSetupFieldSerializer::class) val soundSetup: SoundSetup? = null,
    /** Null means on (iOS sends `false` only when comments are off). */
    @SerialName("comments_enabled") val commentsEnabled: Boolean? = null,
    /** Null means off (iOS sends `true` only when play-along is allowed). */
    @SerialName("backing_enabled") val backingEnabled: Boolean? = null,
    @SerialName("source_video_id") @Serializable(with = UuidSerializer::class) val sourceVideoId: UUID? = null,
)

/** Encodes a [SoundSetup] through [SoundSetupJson] so the server gets the iOS wire shape. */
object SoundSetupFieldSerializer : KSerializer<SoundSetup?> {
    override val descriptor: SerialDescriptor = buildClassSerialDescriptor("handstrudel.SoundSetupField")

    override fun serialize(encoder: Encoder, value: SoundSetup?) {
        (encoder as JsonEncoder).encodeJsonElement(
            value?.let { SoundSetupJson.encodeToJsonElement(SoundSetup.serializer(), it) } ?: JsonNull,
        )
    }

    override fun deserialize(decoder: Decoder): SoundSetup? {
        val element = (decoder as JsonDecoder).decodeJsonElement()
        return if (element is JsonNull) null else runCatching {
            SoundSetupJson.decodeFromJsonElement(SoundSetup.serializer(), element)
        }.getOrNull()
    }
}

/**
 * iOS `DraftPostSubmission`, stored per account in the draft metadata. A pending
 * submission is persisted before `publish-upload submit` so a lost response can be resumed.
 */
@Serializable
sealed interface DraftPostSubmission {
    val id: UUID
    val isPending: Boolean get() = this is Pending

    @Serializable
    @SerialName("pending")
    data class Pending(
        @Serializable(with = UuidSerializer::class) override val id: UUID,
        val fields: VideoPostFields,
    ) : DraftPostSubmission

    @Serializable
    @SerialName("published")
    data class Published(@Serializable(with = UuidSerializer::class) override val id: UUID) : DraftPostSubmission
}

/** iOS `SignUploadRequest`; `moderationVersion: 2` is required by `sign-upload`. */
@Serializable
data class SignUploadRequest(val videoBytes: Long, val thumbBytes: Long, val moderationVersion: Int = 2)

/** iOS `SignUploadResponse`. */
@Serializable
data class SignUploadResponse(
    @Serializable(with = UuidSerializer::class) val id: UUID,
    val videoUploadUrl: String,
    val thumbUploadUrl: String,
)

/** iOS `PublishUploadRequest`. */
@Serializable
data class PublishUploadRequest(
    val action: String,
    @Serializable(with = UuidSerializer::class) val id: UUID,
    val fields: VideoPostFields? = null,
)

/** iOS `PublishUploadResponse.Status`. */
@Serializable
enum class PublishStatus {
    @SerialName("reserved") RESERVED,
    @SerialName("checking") CHECKING,
    @SerialName("published") PUBLISHED,
    @SerialName("held") HELD,
    @SerialName("failed") FAILED,
}

@Serializable
data class PublishUploadResponse(val status: PublishStatus)

/** The edge functions' error body `{ "error": "…" }`. */
@Serializable
data class FunctionErrorBody(val error: String)

/** iOS `DraftPostUpdate`: what the app-level notice shows after a composer hands off. */
sealed interface DraftPostUpdate {
    data object Checking : DraftPostUpdate
    data object Posted : DraftPostUpdate
    data class Failed(val detail: String) : DraftPostUpdate

    /** iOS `showDraftPostUpdate` notice text. */
    val notice: String
        get() = when (this) {
            Checking -> "Video submitted for checking."
            Posted -> "Video posted."
            is Failed -> detail
        }
}

/** iOS `PostSharingOptions`. */
data class PostSharingOptions(val sharePlayablePreset: Boolean = true, val allowPlayAlong: Boolean = true) {
    fun sharedPreset(setup: SoundSetup?): SoundSetup? =
        if (sharePlayablePreset && setup != null && setup.isValid) setup else null

    fun sharesBacking(hasAudio: Boolean, backingCredit: Any?): Boolean =
        allowPlayAlong && canShareBacking(hasAudio, backingCredit)

    companion object {
        fun canShareBacking(hasAudio: Boolean, backingCredit: Any?): Boolean = hasAudio && backingCredit == null
    }
}

/** A user-facing failure carrying the exact iOS message (iOS `SocialError.message`). */
class CaptureMessageException(message: String) : Exception(message)
