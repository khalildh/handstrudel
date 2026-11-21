package com.handstrudel.social.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/** iOS `VideoEngagement`: `video_engagement(_v2)` / `set_video_repost` row. */
@Serializable
data class VideoEngagement(
    val saves: Int,
    val shares: Int,
    val remixes: Int,
    val reposts: Int? = null,
    @SerialName("reposted_by_me") val repostedByMe: Boolean? = null,
)
