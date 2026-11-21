package com.handstrudel.engine.audio

import java.util.UUID

/**
 * Pure channel-routing logic of iOS `SoundFontEngine` (no audio), so it can be
 * unit-tested on the JVM. Sustained voices get their own MIDI channel (0–15
 * except 8 = one-shots and 9 = GM drums); a hard stop on one voice then can't
 * cut another voice's note.
 */
object SamplerRouting {
    val SUSTAINED_CHANNELS: List<Int> = (0..15).filter { it != 8 && it != 9 }
    const val ONE_SHOT_CHANNEL = 8

    data class ActiveNote(val midi: Int, val channel: Int)

    /** iOS `SoundFontEngine.sustainedChannel(for:preferred:active:)`. */
    fun sustainedChannel(note: Int, preferred: Int?, active: List<ActiveNote>): Int? {
        val busy = active.map { it.channel }.toSet()
        if (preferred != null && preferred in SUSTAINED_CHANNELS && preferred !in busy) return preferred
        SUSTAINED_CHANNELS.firstOrNull { it !in busy }?.let { return it }
        val samePitch = active.filter { it.midi == note }.map { it.channel }.toSet()
        if (preferred != null && preferred in SUSTAINED_CHANNELS && preferred !in samePitch) return preferred
        return SUSTAINED_CHANNELS.firstOrNull { it !in samePitch }
    }

    fun clampMidi(midi: Int): Int = midi.coerceIn(0, 127)

    /** iOS `clampVelocity`: MIDI 1…127 from 0…1. */
    fun clampVelocity(v: Double): Int = Math.round(v * 127).toInt().coerceIn(1, 127)
}

/**
 * iOS `SamplerAccentReleases`: a retriggered accent pitch must only be released
 * by the newest strike's timer.
 */
class SamplerAccentReleases {
    private val tokens = mutableMapOf<Int, UUID>()

    data class Strike(val token: UUID, val replacesEarlierStrike: Boolean)

    fun strike(note: Int): Strike {
        val token = UUID.randomUUID()
        return Strike(token, tokens.put(note, token) != null)
    }

    fun shouldRelease(note: Int, token: UUID): Boolean {
        if (tokens[note] != token) return false
        tokens.remove(note)
        return true
    }

    fun clear() = tokens.clear()
}
