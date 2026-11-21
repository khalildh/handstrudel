package com.handstrudel.engine

import com.handstrudel.engine.audio.SamplerAccentReleases
import com.handstrudel.engine.audio.SamplerRouting
import com.handstrudel.engine.audio.SamplerRouting.ActiveNote
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** Ports of the iOS sampler tests in ChordMelodyModeManagerTests. */
class SamplerRoutingTest {
    @Test fun samplerDoesNotReuseBusyChannelForOverlappingPitch() {
        val touching = listOf(ActiveNote(60, 0), ActiveNote(64, 1), ActiveNote(67, 2), ActiveNote(71, 3))
        assertEquals(4, SamplerRouting.sustainedChannel(60, 0, touching))
        val full = SamplerRouting.SUSTAINED_CHANNELS.map { ActiveNote(if (it == 0) 60 else 64, it) }
        assertEquals(1, SamplerRouting.sustainedChannel(60, 0, full))
        assertEquals(0, SamplerRouting.sustainedChannel(64, 1, full))
        assertNull(SamplerRouting.sustainedChannel(60, null, full.map { ActiveNote(60, it.channel) }))
        assertFalse(8 in SamplerRouting.SUSTAINED_CHANNELS || 9 in SamplerRouting.SUSTAINED_CHANNELS)
    }

    @Test fun velocityAndMidiClamp() {
        assertEquals(1, SamplerRouting.clampVelocity(0.0))
        assertEquals(76, SamplerRouting.clampVelocity(0.6))
        assertEquals(127, SamplerRouting.clampVelocity(2.0))
        assertEquals(127, SamplerRouting.clampMidi(200))
    }

    @Test fun accentRetriggerOnlyNewestTimerReleases() {
        val r = SamplerAccentReleases()
        val first = r.strike(60)
        val other = r.strike(67)
        val second = r.strike(60)
        assertFalse(first.replacesEarlierStrike)
        assertTrue(second.replacesEarlierStrike)
        assertFalse(r.shouldRelease(60, first.token))
        assertTrue(r.shouldRelease(67, other.token))
        assertTrue(r.shouldRelease(60, second.token))
        assertFalse(r.shouldRelease(60, second.token))
    }

    @Test fun accentTimerBeforeSilenceCannotReleaseAfterResume() {
        val r = SamplerAccentReleases()
        val before = r.strike(60)
        r.clear()
        val after = r.strike(60)
        assertFalse(after.replacesEarlierStrike)
        assertFalse(r.shouldRelease(60, before.token))
        assertTrue(r.shouldRelease(60, after.token))
    }
}
