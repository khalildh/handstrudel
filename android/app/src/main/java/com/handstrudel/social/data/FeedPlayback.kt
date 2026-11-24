package com.handstrudel.social.data

import java.util.UUID
import kotlin.math.max
import kotlin.math.min

/** iOS `FeedPlaybackPosition`: a clamped playhead inside a known duration. */
data class FeedPlaybackPosition(val duration: Double, val seconds: Double) {
    /** Seek just before the end so scrubbing doesn't immediately advance the feed. */
    val seekSeconds: Double get() = min(seconds, max(0.0, duration - 1.0 / 60))

    companion object {
        fun of(duration: Double, seconds: Double): FeedPlaybackPosition? {
            if (!duration.isFinite() || duration <= 0 || !seconds.isFinite()) return null
            return FeedPlaybackPosition(duration, min(duration, max(0.0, seconds)))
        }

        fun timeLabel(seconds: Double): String {
            if (!seconds.isFinite()) return "0:00"
            val whole = max(0.0, min(seconds, 86_399.0)).toInt()
            return "${whole / 60}:${"%02d".format(whole % 60)}"
        }
    }
}

/**
 * iOS `QualifiedClipWatch`: a view counts after `min(2 s, duration/2)` of real
 * playback. Jumps (> 0.6 s between samples, scrubbing) and paused samples don't count.
 */
class QualifiedClipWatch {
    private var previous: Double? = null
    private var watched = 0.0
    var qualified = false
        private set

    fun resetSample() { previous = null }

    /** True exactly once, on the sample that qualifies the view. */
    fun sample(position: FeedPlaybackPosition, playing: Boolean): Boolean {
        if (qualified) return false
        val last = previous
        previous = if (playing) position.seconds else null
        if (last == null || !playing) return false
        val advance = position.seconds - last
        if (advance <= 0 || advance > 0.6) return false
        watched += advance
        qualified = watched >= min(2.0, position.duration / 2)
        return qualified
    }
}

/** iOS `ClipViewReceipt`: one token per clip, shared between feed and detail for this app run. */
object ClipViewReceipt {
    private val receipts = mutableMapOf<UUID, UUID>()

    @Synchronized
    fun forVideo(video: UUID): UUID = receipts.getOrPut(video) { UUID.randomUUID() }
}
