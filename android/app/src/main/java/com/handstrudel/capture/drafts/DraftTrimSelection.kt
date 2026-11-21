package com.handstrudel.capture.drafts

/**
 * iOS `DraftTrimSelection`: a trim range in captured-time seconds (half-speed
 * takes are trimmed in captured time and shown scaled by `outputScale`).
 */
data class DraftTrimSelection private constructor(val duration: Double, val start: Double, val end: Double) {
    enum class Edge { START, END }

    val minimumLength: Double get() = minOf(0.25, duration)
    val isFullLength: Boolean get() = start == 0.0 && end == duration

    fun moving(edge: Edge, to: Double): DraftTrimSelection {
        if (!to.isFinite()) return this
        return when (edge) {
            Edge.START -> of(duration, minOf(maxOf(0.0, end - minimumLength), maxOf(0.0, to)), end)
            Edge.END -> of(duration, start, maxOf(minOf(duration, start + minimumLength), minOf(duration, to)))
        } ?: this
    }

    companion object {
        /** iOS failable init: null unless `0 ≤ start < end ≤ duration`, all finite. */
        fun of(duration: Double, start: Double? = null, end: Double? = null): DraftTrimSelection? {
            val first = start ?: 0.0
            val last = end ?: duration
            if (!duration.isFinite() || !first.isFinite() || !last.isFinite()) return null
            if (first < 0 || first >= last || last > duration) return null
            return DraftTrimSelection(duration, first, last)
        }
    }
}
