package com.handstrudel.ui.studio.stage

import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.input.pointer.PointerEventPass
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.unit.dp
import com.handstrudel.engine.PlayInput
import com.handstrudel.engine.StudioMode
import kotlin.math.abs

/** iOS stage swipe-to-change-filter rules (`ContentView.performanceView`'s chrome `DragGesture`). */
object FilterSwipe {
    /** Swipes need at least this much horizontal travel (iOS `DragGesture(minimumDistance: 50)`). */
    val MIN_DISTANCE = 50.dp

    /** iOS: Air input, not Drum or Grid (the XY pad and quick bar own drags), mixer closed. */
    fun isEnabled(mode: StudioMode, input: PlayInput, mixerOpen: Boolean): Boolean =
        input == PlayInput.AIR && mode != StudioMode.DRUM && mode != StudioMode.GRID && !mixerOpen

    /** A drag of ([dx], [dy]) px is a filter swipe when it is mostly horizontal and long enough. */
    fun isSwipe(dx: Float, dy: Float, minDistancePx: Float): Boolean = abs(dx) >= minDistancePx && abs(dx) > abs(dy)

    /** Swipe left → next filter, right → previous, wrapping. Null when [currentId] isn't in [ids]. */
    fun next(ids: List<String>, currentId: String, swipeLeft: Boolean): String? {
        val idx = ids.indexOf(currentId)
        if (idx < 0 || ids.isEmpty()) return null
        return ids[if (swipeLeft) (idx + 1) % ids.size else (idx - 1 + ids.size) % ids.size]
    }
}

/**
 * Watches a drag that starts on this chrome element and calls [onSwipe] (true = swiped
 * left) when it ends as a filter swipe. Observes in the Initial pass and consumes
 * nothing, so the element's own buttons still get their taps (iOS `.simultaneousGesture`).
 * Adds no hit area when [enabled] is false.
 */
fun Modifier.filterSwipe(enabled: Boolean, onSwipe: (swipeLeft: Boolean) -> Unit): Modifier =
    if (!enabled) this
    else pointerInput(Unit) {
        val minPx = FilterSwipe.MIN_DISTANCE.toPx()
        awaitEachGesture {
            val down = awaitFirstDown(requireUnconsumed = false, pass = PointerEventPass.Initial)
            var last: Offset = down.position
            while (true) {
                val event = awaitPointerEvent(PointerEventPass.Initial)
                val change = event.changes.firstOrNull { it.id == down.id } ?: break
                last = change.position
                if (!change.pressed) break
            }
            val dx = last.x - down.position.x
            val dy = last.y - down.position.y
            if (FilterSwipe.isSwipe(dx, dy, minPx)) onSwipe(dx < 0)
        }
    }
