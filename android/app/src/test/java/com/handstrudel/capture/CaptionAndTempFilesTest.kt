package com.handstrudel.capture

import com.handstrudel.capture.drafts.DraftExport
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import java.nio.file.Files

class CaptionAndTempFilesTest {
    @Test fun graphemePrefixKeepsShortTextAsIs() {
        assertEquals("", "".graphemePrefix(150))
        assertEquals("hello", "hello".graphemePrefix(150))
        assertEquals("", "hello".graphemePrefix(0))
    }

    @Test fun graphemePrefixCountsCharactersLikeSwift() {
        assertEquals("x".repeat(150), "x".repeat(200).graphemePrefix(150))
        // A surrogate pair (one emoji) is one character and is never split.
        val caption = "a".repeat(149) + "🎹🎹"
        assertEquals("a".repeat(149) + "🎹", caption.graphemePrefix(150))
        // Combining marks stay with their letter.
        val accented = "é".repeat(151)
        assertEquals("é".repeat(150), accented.graphemePrefix(150))
    }

    @Test fun graphemePrefixNeverEndsInsideASurrogatePair() {
        val text = "🎶".repeat(200)
        val cut = text.graphemePrefix(150)
        assertEquals(300, cut.length)
        assertFalse(Character.isHighSurrogate(cut.last()))
    }

    @Test fun sweepRemovesOnlyOldCopies() {
        val dir = Files.createTempDirectory("exports").toFile()
        try {
            val now = 10_000_000_000L
            val old = File(dir, "HandStrudel-old.mp4").apply { writeText("x"); setLastModified(now - DraftExport.SHARED_COPY_LIFETIME_MS - 1_000) }
            val fresh = File(dir, "HandStrudel-new.mp4").apply { writeText("x"); setLastModified(now - 60_000) }
            DraftExport.sweepOlderThan(dir, DraftExport.SHARED_COPY_LIFETIME_MS, now)
            assertFalse(old.exists())
            assertTrue("a copy another app may still be reading is kept", fresh.exists())
        } finally {
            dir.deleteRecursively()
        }
    }

    @Test fun crashLeftoversAreCleared() {
        val dir = Files.createTempDirectory("loop-capture").toFile()
        try {
            File(dir, "a.wav").writeText("x")
            File(dir, "b.m4a").writeText("x")
            CaptureTempFiles.clear(dir)
            assertEquals(0, dir.listFiles()!!.size)
            CaptureTempFiles.clear(File(dir, "missing")) // No directory yet: nothing to do.
        } finally {
            dir.deleteRecursively()
        }
    }
}
