package com.handstrudel.social.data

import kotlin.random.Random

/**
 * iOS `FeedNavigation.destination`: the adjacent page, or past either edge a random
 * different clip (an edge never picks itself). Null for empty/single feeds.
 */
object FeedNavigation {
    fun destination(
        current: Int, step: Int, count: Int,
        choose: (IntRange) -> Int = { Random.nextInt(it.first, it.last + 1) },
    ): Int? {
        if (count <= 1 || current !in 0 until count || (step != -1 && step != 1)) return null
        val adjacent = current + step
        if (adjacent in 0 until count) return adjacent
        // Map a random slot around the current index so an edge never picks itself.
        val candidate = choose(0 until count - 1)
        return if (candidate >= current) candidate + 1 else candidate
    }
}
