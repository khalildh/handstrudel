package com.handstrudel.ui.social.feed

import org.junit.Assert.assertEquals
import org.junit.Test

/** iOS ClipPlaybackSurface `.accessibilityActions` and the feed pager's Next/Previous video. */
class ClipAccessibilityActionsTest {

    private fun labels(controls: Boolean?, paused: Boolean, failed: Boolean, canMove: Boolean) =
        clipAccessibilityActions(controls, paused, failed, {}, {}, if (canMove) ({ _: Int -> true }) else null).map { it.label }

    @Test fun feedCell_hasPauseAndPaging() {
        assertEquals(listOf("Pause video", "Next video", "Previous video"), labels(null, paused = false, failed = false, canMove = true))
        assertEquals(listOf("Play video", "Next video", "Previous video"), labels(null, paused = true, failed = false, canMove = true))
    }

    @Test fun fullscreen_offersControlsToggleFirst() {
        assertEquals(listOf("Show playback controls", "Pause video"), labels(false, paused = false, failed = false, canMove = false))
        assertEquals(listOf("Hide playback controls", "Pause video"), labels(true, paused = false, failed = false, canMove = false))
    }

    @Test fun failedClip_dropsPlayPause() {
        assertEquals(listOf("Next video", "Previous video"), labels(null, paused = true, failed = true, canMove = true))
    }

    @Test fun actionsCallThrough() {
        val moves = mutableListOf<Int>()
        var toggles = 0
        var pauses = 0
        val actions = clipAccessibilityActions(false, paused = false, failed = false,
            toggleControls = { toggles++ }, togglePause = { pauses++ }, move = { moves += it; true })
        actions.forEach { it.action() }
        assertEquals(1, toggles)
        assertEquals(1, pauses)
        assertEquals(listOf(1, -1), moves)
    }
}
