package com.handstrudel.capture

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.nio.ByteBuffer
import java.nio.ByteOrder

class RecordingCountInTest {
    @Test fun withoutBpmCountsThreeSeconds() {
        val c = RecordingCountIn(null, halfSpeed = false)
        assertEquals(3, c.steps)
        assertEquals(1.0, c.secondsPerStep, 0.0)
        assertFalse(c.usesBeats)
        assertNull(c.clickTrack())
        assertNull(c.clickSamples())
    }

    @Test fun outOfRangeBpmFallsBackToSeconds() {
        assertEquals(3, RecordingCountIn(19.9, false).steps)
        assertEquals(3, RecordingCountIn(400.1, false).steps)
        assertEquals(3, RecordingCountIn(Double.NaN, false).steps)
        assertEquals(4, RecordingCountIn(20.0, false).steps)
        assertEquals(4, RecordingCountIn(400.0, false).steps)
    }

    @Test fun sourceBpmCountsFourBeats() {
        val c = RecordingCountIn(120.0, halfSpeed = false)
        assertEquals(4, c.steps)
        assertTrue(c.usesBeats)
        assertEquals(0.5, c.secondsPerStep, 1e-12)
        assertEquals(1.0, RecordingCountIn(120.0, halfSpeed = true).secondsPerStep, 1e-12)
    }

    @Test fun clickTrackHasSampleCountAndOnsets() {
        val c = RecordingCountIn(100.0, halfSpeed = false) // 0.6 s per beat
        val samples = c.clickSamples()!!
        assertEquals(Math.round(4 * 0.6 * 22_050).toInt(), samples.size)
        assertEquals(listOf(0, 13_230, 26_460, 39_690), c.clickOnsets())
        // Silence just before each onset, sound shortly after it.
        for (onset in c.clickOnsets().drop(1)) {
            assertEquals(0, samples[onset - 1].toInt())
            assertNotEquals(0, samples[onset + 20].toInt())
        }
        val wav = c.clickTrack()!!
        assertEquals(44 + samples.size * 2, wav.size)
        val header = ByteBuffer.wrap(wav).order(ByteOrder.LITTLE_ENDIAN)
        assertArrayEquals("RIFF".toByteArray(), wav.copyOfRange(0, 4))
        assertEquals(36 + samples.size * 2, header.getInt(4))
        assertEquals(22_050, header.getInt(24))
        assertEquals(samples.size * 2, header.getInt(40))
    }

    @Test fun backingVolumeClamps() {
        assertEquals(0.55, BackingTrackVolume.clamped(Double.NaN), 0.0)
        assertEquals(1.0, BackingTrackVolume.clamped(3.0), 0.0)
        assertEquals(0.0, BackingTrackVolume.clamped(-1.0), 0.0)
    }
}
