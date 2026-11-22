package com.handstrudel.capture

import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update

/**
 * Who else needs hardware video codecs right now: draft previews, the post composer, and
 * exports/transcodes. Devices have only a few decoder instances (the emulator's goldfish
 * H.264 pool ran out and a post failed with `NO_MEMORY`), so the feed gives up its
 * pre-warmed players while [active] is true and warms them again on the next Feed visit.
 */
object VideoDecoderDemand {
    private val holds = MutableStateFlow(0)
    private val _active = MutableStateFlow(false)
    val active: StateFlow<Boolean> = _active.asStateFlow()

    fun acquire() {
        holds.update { it + 1 }
        _active.value = holds.value > 0
    }

    fun release() {
        holds.update { maxOf(0, it - 1) }
        _active.value = holds.value > 0
    }

    /** Holds the demand for the duration of [block] (an export or transcode). */
    suspend fun <T> hold(block: suspend () -> T): T {
        acquire()
        try {
            return block()
        } finally {
            release()
        }
    }
}

/** Holds [VideoDecoderDemand] while this composable is on screen (a screen with its own player). */
@Composable
fun HoldVideoDecoders() {
    DisposableEffect(Unit) {
        VideoDecoderDemand.acquire()
        onDispose { VideoDecoderDemand.release() }
    }
}
