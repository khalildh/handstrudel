package com.handstrudel.capture

import com.handstrudel.capture.drafts.RecordingDraft
import com.handstrudel.capture.drafts.RecordingDrafts
import com.handstrudel.capture.upload.DraftPostSubmission
import com.handstrudel.capture.upload.PreparedClip
import com.handstrudel.capture.upload.UploadPlatform
import com.handstrudel.capture.upload.VideoUploader
import com.handstrudel.social.AccountChangedException
import com.handstrudel.social.FunctionResponse
import com.handstrudel.social.SupabaseFunctionsInvoker
import com.handstrudel.social.model.BackingCredit
import com.handstrudel.social.model.Video
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.runTest
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File
import java.util.UUID

class VideoUploaderStateTest {
    @get:Rule val tmp = TemporaryFolder()

    private val account = UUID.randomUUID()
    private val uploadId = UUID.randomUUID()

    /** Scripted backend: `publish` answers come from [statuses] (a status string, or an HTTP error). */
    private inner class Fake(
        val statuses: ArrayDeque<Pair<Int, String>>,
        var functionsAccount: UUID = account,
        val source: Video? = null,
        val prepareError: Exception? = null,
    ) : UploadPlatform {
        val calls = mutableListOf<String>()
        var store: RecordingDrafts? = null
        var draftId: UUID? = null
        var pendingSeenAtSubmit: DraftPostSubmission? = null
        val puts = mutableListOf<Pair<String, String>>()

        override suspend fun fetchVideo(id: UUID) = source
        override suspend fun hasAudio(clip: File) = true
        override suspend fun prepare(clip: File) = prepareError?.let { throw it } ?:
            PreparedClip(tmp.newFile().apply { writeBytes(ByteArray(100)) }, ByteArray(10), 720, 1280, 7.0)
        override suspend fun put(url: String, contentType: String, file: File?, bytes: ByteArray?) {
            puts += url to contentType
        }
        override suspend fun functions(accountId: UUID): SupabaseFunctionsInvoker {
            if (accountId != functionsAccount) throw AccountChangedException()
            return object : SupabaseFunctionsInvoker {
                override val accountId = accountId
                override suspend fun invoke(function: String, body: JsonElement): FunctionResponse {
                    val obj = body as JsonObject
                    if (function == "sign-upload") {
                        calls += "sign"
                        assertEquals("2", obj["moderationVersion"]!!.jsonPrimitive.content)
                        return FunctionResponse(200, """{"id":"$uploadId","videoUploadUrl":"https://r2/v","thumbUploadUrl":"https://r2/t"}""")
                    }
                    val action = obj["action"]!!.jsonPrimitive.content
                    calls += action
                    if (action == "submit") pendingSeenAtSubmit = store?.postSubmission(draftId!!, account)
                    val (code, value) = statuses.removeFirst()
                    return if (code == 200) FunctionResponse(200, """{"status":"$value"}""")
                    else FunctionResponse(code, """{"error":"$value"}""")
                }
            }
        }
    }

    private fun setup(fake: Fake): Pair<RecordingDrafts, RecordingDraft> {
        val store = RecordingDrafts(tmp.newFolder())
        val draft = store.begin("Piano", "scale")
        store.videoFile(draft.id).writeBytes(byteArrayOf(1))
        store.complete(draft)
        fake.store = store
        fake.draftId = draft.id
        return store to draft
    }

    private fun TestScope.uploader(fake: Fake, posted: () -> Unit = {}) =
        VideoUploader(fake, clock = { testScheduler.currentTime }, onPosted = posted)

    private suspend fun VideoUploader.postDraft(store: RecordingDrafts, draft: RecordingDraft, credit: BackingCredit? = null, onScreening: () -> Unit = {}) =
        post(File("clip.mp4"), draft.id, account, store, "caption", "Piano", "scale", null,
            commentsEnabled = true, backingEnabled = false, backingCredit = credit, onScreeningStarted = onScreening)

    private fun q(vararg s: Pair<Int, String>) = ArrayDeque(s.toList())

    @Test fun checkingThenPublished() = runTest {
        val fake = Fake(q(200 to "checking", 200 to "checking", 200 to "published"))
        val (store, draft) = setup(fake)
        var posted = 0
        var screening = 0
        val uploader = uploader(fake) { posted++ }
        assertTrue(uploader.postDraft(store, draft) { screening++ })
        assertEquals(listOf("sign", "submit", "status", "status"), fake.calls)
        assertEquals(listOf("https://r2/v" to "video/mp4", "https://r2/t" to "image/jpeg"), fake.puts)
        assertTrue("pending persisted before submit", fake.pendingSeenAtSubmit is DraftPostSubmission.Pending)
        assertEquals(DraftPostSubmission.Published(uploadId), store.postSubmission(draft.id, account))
        assertEquals(VideoUploader.Phase.Done, uploader.phase.value)
        assertEquals(1, posted)
        assertEquals(1, screening)
        assertEquals(4_000L, testScheduler.currentTime)
    }

    @Test fun heldClearsSubmission() = runTest {
        val fake = Fake(q(200 to "checking", 200 to "held"))
        val (store, draft) = setup(fake)
        val uploader = uploader(fake)
        assertFalse(uploader.postDraft(store, draft))
        assertEquals(VideoUploader.Phase.Failed(VideoUploader.HELD_MESSAGE), uploader.phase.value)
        assertNull(store.postSubmission(draft.id, account))
    }

    @Test fun failedClearsSubmission() = runTest {
        val fake = Fake(q(200 to "failed"))
        val (store, draft) = setup(fake)
        val uploader = uploader(fake)
        assertFalse(uploader.postDraft(store, draft))
        assertEquals(VideoUploader.Phase.Failed(VideoUploader.FAILED_MESSAGE), uploader.phase.value)
        assertNull(store.postSubmission(draft.id, account))
    }

    @Test fun notFoundForgetsSubmission() = runTest {
        val fake = Fake(q(404 to "Upload not found."))
        val (store, draft) = setup(fake)
        val uploader = uploader(fake)
        assertFalse(uploader.postDraft(store, draft))
        assertEquals(VideoUploader.Phase.Failed("This upload expired. It wasn't posted. You can post again from Private drafts."), uploader.phase.value)
        assertNull(store.postSubmission(draft.id, account))
    }

    @Test fun expiredForgetsSubmission() = runTest {
        val fake = Fake(q(409 to "This upload expired. Try again from Private drafts."))
        val (store, draft) = setup(fake)
        assertFalse(uploader(fake).postDraft(store, draft))
        assertNull(store.postSubmission(draft.id, account))
    }

    @Test fun otherErrorKeepsPending() = runTest {
        val fake = Fake(q(500 to "boom"))
        val (store, draft) = setup(fake)
        val uploader = uploader(fake)
        assertFalse(uploader.postDraft(store, draft))
        assertEquals(VideoUploader.Phase.Pending(VideoUploader.UNCONFIRMED_MESSAGE), uploader.phase.value)
        assertTrue(store.postSubmission(draft.id, account) is DraftPostSubmission.Pending)
    }

    @Test fun timeoutLeavesPendingAndResumeFinishes() = runTest {
        val checking = Array(70) { 200 to "checking" }
        val fake = Fake(ArrayDeque(checking.toList() + listOf(200 to "published")))
        val (store, draft) = setup(fake)
        val uploader = uploader(fake)
        assertFalse(uploader.postDraft(store, draft))
        assertEquals(VideoUploader.Phase.Pending(VideoUploader.STILL_CHECKING_MESSAGE), uploader.phase.value)
        assertTrue(store.postSubmission(draft.id, account) is DraftPostSubmission.Pending)
        assertTrue("about 120 s of polling", testScheduler.currentTime in 120_000L..122_000L)

        // App restarted: a new uploader resumes from the persisted submission with `status`.
        fake.calls.clear()
        while (fake.statuses.size > 1) fake.statuses.removeFirst()
        val resumed = RecordingDrafts(store.videoFile(draft.id).parentFile!!.parentFile!!)
        fake.store = resumed
        assertTrue(uploader(fake).resume(draft.id, account, resumed))
        assertEquals(listOf("status"), fake.calls)
        assertEquals(DraftPostSubmission.Published(uploadId), resumed.postSubmission(draft.id, account))
    }

    @Test fun resumeSubmitsAReservedUpload() = runTest {
        val fake = Fake(q(200 to "reserved", 200 to "checking", 200 to "published"))
        val (store, draft) = setup(fake)
        val pending = DraftPostSubmission.Pending(uploadId,
            com.handstrudel.capture.upload.VideoPostFields("c", null, null, 3.0, 720, 1280))
        store.replacePostSubmission(null, pending, draft.id, account)
        assertTrue(uploader(fake).resume(draft.id, account, store))
        assertEquals(listOf("status", "submit", "status"), fake.calls)
    }

    @Test fun postWithExistingSubmissionResumes() = runTest {
        val fake = Fake(q(200 to "published"))
        val (store, draft) = setup(fake)
        store.replacePostSubmission(null, DraftPostSubmission.Pending(uploadId,
            com.handstrudel.capture.upload.VideoPostFields("c", null, null, 3.0, 720, 1280)), draft.id, account)
        assertTrue(uploader(fake).postDraft(store, draft))
        assertEquals(listOf("status"), fake.calls)
    }

    @Test fun accountSwitchIsRefused() = runTest {
        val fake = Fake(q(), functionsAccount = UUID.randomUUID())
        val (store, draft) = setup(fake)
        val uploader = uploader(fake)
        assertFalse(uploader.postDraft(store, draft))
        assertEquals(VideoUploader.Phase.Failed("Sign back in to the account that started this post."), uploader.phase.value)
        assertNull(store.postSubmission(draft.id, account))
    }

    @Test fun signUploadErrorShowsServerDetail() = runTest {
        val fake = object : UploadPlatform by Fake(q()) {
            override suspend fun functions(accountId: UUID) = object : SupabaseFunctionsInvoker {
                override val accountId = accountId
                override suspend fun invoke(function: String, body: JsonElement) =
                    FunctionResponse(503, """{"error":"Posting is temporarily unavailable."}""")
            }
        }
        val store = RecordingDrafts(tmp.newFolder())
        val draft = store.begin(null, null).also { store.videoFile(it.id).writeBytes(byteArrayOf(1)); store.complete(it) }
        val uploader = VideoUploader(fake)
        assertFalse(uploader.postDraft(store, draft))
        assertEquals(VideoUploader.Phase.Failed("Posting is temporarily unavailable."), uploader.phase.value)
    }

    @Test fun playAlongSourceMustStillAllowBacking() = runTest {
        val fake = Fake(q(), source = null)
        val (store, draft) = setup(fake)
        val uploader = uploader(fake)
        assertFalse(uploader.postDraft(store, draft, BackingCredit(UUID.randomUUID(), "maker")))
        assertEquals(VideoUploader.Phase.Failed("The creator no longer allows new play-along posts. Your private draft is safe."), uploader.phase.value)
        assertTrue(fake.calls.isEmpty())
    }

    @Test fun platformErrorsGetTheGenericCopy() = runTest {
        val fake = Fake(q(), prepareError = IllegalStateException("Codec exception: CodecInfo{type=VideoDecoder}"))
        val (store, draft) = setup(fake)
        val uploader = uploader(fake)
        assertFalse(uploader.postDraft(store, draft))
        assertEquals(VideoUploader.Phase.Failed("Couldn't post this video. Your private draft is safe."), uploader.phase.value)
    }

    @Test fun ownMessagesAreShownAsIs() = runTest {
        val fake = Fake(q(), prepareError = com.handstrudel.capture.upload.CaptureMessageException("Trim the recording to 60 seconds or less to post it."))
        val (store, draft) = setup(fake)
        val uploader = uploader(fake)
        assertFalse(uploader.postDraft(store, draft))
        assertEquals(VideoUploader.Phase.Failed("Trim the recording to 60 seconds or less to post it."), uploader.phase.value)
    }
}
