package com.handstrudel.social.data

import com.handstrudel.social.model.Video
import java.time.Instant
import java.util.UUID
import kotlin.math.ln1p
import kotlin.math.max
import kotlin.math.min

/**
 * iOS `DiscoveryFeedRanking`: client re-ranking of a Discover page. Freshness
 * `3/(1+h/72)` plus engagement `min(log1p(likes),4)*0.65/(1+h/168)`; ties keep
 * server order; never the same creator twice in a row when another is available.
 */
object DiscoveryFeedRanking {
    fun order(videos: List<Video>, now: Instant, after: UUID? = null): List<Video> {
        fun score(video: Video): Double {
            val created = video.createdAtInstant ?: now
            val hoursOld = max(0.0, (now.toEpochMilli() - created.toEpochMilli()) / 3_600_000.0)
            val freshness = 3 / (1 + hoursOld / 72)
            val engagement = min(ln1p(max(0, video.likeCount).toDouble()), 4.0) * 0.65 / (1 + hoursOld / 168)
            return freshness + engagement
        }

        val candidates = videos.mapIndexed { index, video -> Triple(index, video, score(video)) }
            .sortedWith { l, r -> if (l.third == r.third) l.first.compareTo(r.first) else r.third.compareTo(l.third) }
            .toMutableList()
        val result = ArrayList<Video>(videos.size)
        var last = after
        while (candidates.isNotEmpty()) {
            val pick = candidates.indexOfFirst { it.second.userId != last }.takeIf { it >= 0 } ?: 0
            val video = candidates.removeAt(pick).second
            result += video
            last = video.userId
        }
        return result
    }
}
