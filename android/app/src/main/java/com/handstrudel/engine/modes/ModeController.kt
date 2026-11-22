package com.handstrudel.engine.modes

import com.handstrudel.engine.HandStrudelEngine
import com.handstrudel.engine.HandsState
import com.handstrudel.engine.toCoreHands

/**
 * One playable mode (iOS `ModeController`). [HandStrudelEngine.tick] runs the
 * active controller once per display frame.
 */
internal interface ModeController {
    fun tick(engine: HandStrudelEngine)
}

internal fun HandsState.core() = toCoreHands()
