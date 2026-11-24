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

/**
 * The Rust-side copy of these hands. Hands change at the camera's tracking rate
 * (a few times a second on slow phones) while modes tick every display frame, so
 * convert each [HandsState] once (main thread only).
 */
internal fun HandsState.core(): uniffi.handstrudel_core.HandsState {
    if (this === CoreHandsMemo.hands) CoreHandsMemo.core?.let { return it }
    return toCoreHands().also { CoreHandsMemo.hands = this; CoreHandsMemo.core = it }
}

private object CoreHandsMemo {
    var hands: HandsState? = null
    var core: uniffi.handstrudel_core.HandsState? = null
}
