package com.handstrudel.ui.capture

import androidx.annotation.OptIn
import androidx.media3.common.C
import androidx.media3.common.ForwardingPlayer
import androidx.media3.common.Player
import androidx.media3.common.Timeline
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.source.ForwardingTimeline

/**
 * The preview player as the draft's controls see it, in output time.
 *
 * A half-speed take is captured at half tempo and previewed at 2× (pitch kept). iOS plays a
 * composition scaled by `outputScale`, so its time bar reads output time (a 40 s capture shows
 * 0:20). This wrapper gives PlayerView the same view: positions and durations are multiplied by
 * [scale] and seeks divided by it. The editor keeps using the wrapped player in capture time.
 */
@OptIn(UnstableApi::class)
class TimeScaledPlayer(player: Player, private val scale: Double) : ForwardingPlayer(player) {
    init { require(scale > 0 && scale.isFinite()) }

    private fun toOutput(captureMs: Long): Long = if (captureMs == C.TIME_UNSET) captureMs else Math.round(captureMs * scale)
    private fun toCapture(outputMs: Long): Long = if (outputMs == C.TIME_UNSET) outputMs else Math.round(outputMs / scale)
    private fun toOutputUs(captureUs: Long): Long = if (captureUs == C.TIME_UNSET) captureUs else Math.round(captureUs * scale)

    override fun getCurrentPosition(): Long = toOutput(super.getCurrentPosition())
    override fun getContentPosition(): Long = toOutput(super.getContentPosition())
    override fun getBufferedPosition(): Long = toOutput(super.getBufferedPosition())
    override fun getContentBufferedPosition(): Long = toOutput(super.getContentBufferedPosition())
    override fun getDuration(): Long = toOutput(super.getDuration())
    override fun getContentDuration(): Long = toOutput(super.getContentDuration())
    override fun getTotalBufferedDuration(): Long = toOutput(super.getTotalBufferedDuration())

    override fun seekTo(positionMs: Long) = super.seekTo(toCapture(positionMs))
    override fun seekTo(mediaItemIndex: Int, positionMs: Long) = super.seekTo(mediaItemIndex, toCapture(positionMs))

    // Increments are in output time too, so "15 s" skips 15 s of what the viewer sees.
    override fun seekBack() = seekTo(maxOf(0, currentPosition - seekBackIncrement))
    override fun seekForward() {
        val target = currentPosition + seekForwardIncrement
        val end = duration
        seekTo(if (end == C.TIME_UNSET) target else minOf(end, target))
    }

    override fun getCurrentTimeline(): Timeline {
        val timeline = super.getCurrentTimeline()
        if (timeline.isEmpty) return timeline
        return object : ForwardingTimeline(timeline) {
            override fun getWindow(windowIndex: Int, window: Timeline.Window, defaultPositionProjectionUs: Long): Timeline.Window {
                super.getWindow(windowIndex, window, defaultPositionProjectionUs)
                window.durationUs = toOutputUs(window.durationUs)
                window.defaultPositionUs = toOutputUs(window.defaultPositionUs)
                return window
            }

            override fun getPeriod(periodIndex: Int, period: Timeline.Period, setIds: Boolean): Timeline.Period {
                super.getPeriod(periodIndex, period, setIds)
                period.durationUs = toOutputUs(period.durationUs)
                return period
            }
        }
    }
}
