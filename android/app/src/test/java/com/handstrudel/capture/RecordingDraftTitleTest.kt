package com.handstrudel.capture

import com.handstrudel.capture.drafts.RecordingDraft
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import java.util.UUID

class RecordingDraftTitleTest {
    @Test fun collapsesWhitespaceAndControls() {
        assertEquals("Late night jam", RecordingDraft.normalizedTitle("  Late\n\tnight\u0007  jam  "))
    }

    @Test fun blankBecomesNull() {
        assertNull(RecordingDraft.normalizedTitle(""))
        assertNull(RecordingDraft.normalizedTitle(" \n\t "))
    }

    @Test fun keepsSixtyCharacters() {
        val long = "a".repeat(59) + " bcdef"
        assertEquals("a".repeat(59), RecordingDraft.normalizedTitle(long))
        assertEquals("x".repeat(60), RecordingDraft.normalizedTitle("x".repeat(80)))
        // Grapheme clusters count as one character, like Swift.
        val emoji = "👍🏽".repeat(61)
        assertEquals("👍🏽".repeat(60), RecordingDraft.normalizedTitle(emoji))
    }

    @Test fun displayTitleFallsBack() {
        val id = UUID.randomUUID()
        assertEquals("Performance", RecordingDraft(id, 0).displayTitle)
        assertEquals("Piano", RecordingDraft(id, 0, instrument = "Piano").displayTitle)
        assertEquals("Mine", RecordingDraft(id, 0, instrument = "Piano", title = "Mine").displayTitle)
        assertEquals(0.5, RecordingDraft(id, 0, recordedAtHalfSpeed = true).outputScale, 0.0)
        assertEquals(1.0, RecordingDraft(id, 0).outputScale, 0.0)
    }
}
