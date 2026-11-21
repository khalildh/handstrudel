package com.handstrudel.capture

import com.handstrudel.capture.drafts.DraftException
import com.handstrudel.capture.drafts.RecordingDrafts
import com.handstrudel.capture.upload.DraftPostSubmission
import com.handstrudel.capture.upload.VideoPostFields
import com.handstrudel.social.model.BackingCredit
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.util.UUID

class DraftStoreTest {
    @get:Rule val tmp = TemporaryFolder()

    private fun takeOf(store: RecordingDrafts, bytes: Int = 16) =
        store.begin("Piano", "scale", backingCredit = BackingCredit(UUID.randomUUID(), "maker"), halfSpeed = true).also {
            store.videoFile(it.id).writeBytes(ByteArray(bytes) { 1 })
            store.complete(it)
        }

    @Test fun beginWritesMetadataBeforeCompletion() {
        val dir = tmp.newFolder("drafts")
        val store = RecordingDrafts(dir)
        val draft = store.begin("Piano", "scale")
        assertTrue(store.drafts.value.isEmpty())
        // Without a take file the folder isn't listed after a restart either.
        assertTrue(RecordingDrafts(dir).drafts.value.isEmpty())
        store.videoFile(draft.id).writeBytes(byteArrayOf(1))
        assertEquals(listOf(draft), RecordingDrafts(dir).drafts.value)
    }

    @Test fun completeRejectsEmptyTake() {
        val store = RecordingDrafts(tmp.newFolder("drafts"))
        val draft = store.begin(null, null)
        store.videoFile(draft.id).writeBytes(ByteArray(0))
        try { store.complete(draft); throw AssertionError("expected failure") } catch (_: DraftException) {}
        store.discardUnfinished(draft)
        assertFalse(store.videoFile(draft.id).parentFile!!.exists())
    }

    @Test fun pendingAndPublishedRoundTrip() {
        val dir = tmp.newFolder("drafts")
        val store = RecordingDrafts(dir)
        val draft = takeOf(store)
        val account = UUID.randomUUID()
        val other = UUID.randomUUID()
        val pending = DraftPostSubmission.Pending(UUID.randomUUID(),
            VideoPostFields("hi", "Piano", "scale", 7.5, 720, 1280, commentsEnabled = false, sourceVideoId = UUID.randomUUID()))
        assertTrue(store.replacePostSubmission(null, pending, draft.id, account))
        assertFalse("compare-and-swap", store.replacePostSubmission(null, pending, draft.id, account))

        val reloaded = RecordingDrafts(dir)
        assertEquals(pending, reloaded.postSubmission(draft.id, account))
        assertNull("per-account isolation", reloaded.postSubmission(draft.id, other))

        val published = DraftPostSubmission.Published(pending.id)
        assertTrue(reloaded.replacePostSubmission(pending, published, draft.id, account))
        assertEquals(published, RecordingDrafts(dir).postSubmission(draft.id, account))

        assertTrue(reloaded.replacePostSubmission(published, null, draft.id, account))
        assertNull(RecordingDrafts(dir).draft(draft.id)!!.postSubmissions)
    }

    @Test fun renameTrimAndDelete() {
        val dir = tmp.newFolder("drafts")
        val store = RecordingDrafts(dir)
        val draft = takeOf(store)
        assertEquals("Take one", store.rename(draft.id, "  Take\none ").title)
        assertNull(store.rename(draft.id, "   ").title)
        store.saveTrim(draft.copy(trimStart = 1.0, trimEnd = 2.5))
        val reloaded = RecordingDrafts(dir).draft(draft.id)!!
        assertEquals(1.0, reloaded.trimStart!!, 0.0)
        assertEquals(2.5, reloaded.trimEnd!!, 0.0)
        assertEquals(true, reloaded.recordedAtHalfSpeed)
        assertEquals("maker", reloaded.backingCredit!!.username)
        store.delete(draft)
        assertTrue(store.drafts.value.isEmpty())
        assertTrue(RecordingDrafts(dir).drafts.value.isEmpty())
        try { store.rename(draft.id, "x"); throw AssertionError("expected failure") } catch (_: DraftException) {}
    }

    @Test fun newestFirst() {
        var t = 1000L
        val store = RecordingDrafts(tmp.newFolder("drafts")) { t++ }
        val a = takeOf(store)
        val b = takeOf(store)
        assertEquals(listOf(b.id, a.id), store.drafts.value.map { it.id })
    }
}
