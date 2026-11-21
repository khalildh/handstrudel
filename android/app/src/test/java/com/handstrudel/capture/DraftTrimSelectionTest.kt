package com.handstrudel.capture

import com.handstrudel.capture.drafts.DraftTrimSelection
import com.handstrudel.capture.drafts.DraftTrimSelection.Edge
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test

class DraftTrimSelectionTest {
    @Test fun initValidation() {
        assertNotNull(DraftTrimSelection.of(10.0))
        assertTrue(DraftTrimSelection.of(10.0)!!.isFullLength)
        assertNull(DraftTrimSelection.of(10.0, 5.0, 5.0))
        assertNull(DraftTrimSelection.of(10.0, -1.0, 5.0))
        assertNull(DraftTrimSelection.of(10.0, 1.0, 11.0))
        assertNull(DraftTrimSelection.of(Double.NaN))
        assertNull(DraftTrimSelection.of(0.0))
        assertFalse(DraftTrimSelection.of(10.0, 1.0, 10.0)!!.isFullLength)
    }

    @Test fun movingStartIsClampedToZeroAndMinimumLength() {
        val t = DraftTrimSelection.of(10.0, 2.0, 6.0)!!
        assertEquals(0.0, t.moving(Edge.START, -3.0).start, 0.0)
        assertEquals(5.75, t.moving(Edge.START, 9.0).start, 1e-12)
        assertEquals(3.0, t.moving(Edge.START, 3.0).start, 0.0)
        assertEquals(6.0, t.moving(Edge.START, 3.0).end, 0.0)
    }

    @Test fun movingEndIsClampedToDurationAndMinimumLength() {
        val t = DraftTrimSelection.of(10.0, 2.0, 6.0)!!
        assertEquals(10.0, t.moving(Edge.END, 30.0).end, 0.0)
        assertEquals(2.25, t.moving(Edge.END, 0.0).end, 1e-12)
        assertEquals(7.0, t.moving(Edge.END, 7.0).end, 0.0)
    }

    @Test fun nonFiniteMoveKeepsSelection() {
        val t = DraftTrimSelection.of(10.0, 2.0, 6.0)!!
        assertSame(t, t.moving(Edge.START, Double.NaN))
        assertSame(t, t.moving(Edge.END, Double.POSITIVE_INFINITY))
    }

    @Test fun minimumLengthNeverExceedsDuration() {
        val t = DraftTrimSelection.of(0.1)!!
        assertEquals(0.1, t.minimumLength, 0.0)
        assertEquals(t, t.moving(Edge.START, 0.05))
    }
}
