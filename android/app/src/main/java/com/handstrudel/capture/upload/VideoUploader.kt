package com.handstrudel.capture.upload

import com.handstrudel.capture.drafts.RecordingDrafts
import com.handstrudel.capture.graphemePrefix
import com.handstrudel.social.AccountChangedException
import com.handstrudel.social.SupabaseFunctionsInvoker
import com.handstrudel.social.model.BackingCredit
import com.handstrudel.models.SoundSetup
import com.handstrudel.social.model.Video
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import java.io.File
import java.util.UUID

/** A transcoded clip ready to upload (iOS `VideoUploader.Prepared`). */
data class PreparedClip(val video: File, val thumb: ByteArray, val width: Int, val height: Int, val durationSeconds: Double)

/** Platform pieces of the upload, injected so the state machine is unit-testable. */
interface UploadPlatform {
    /** iOS `FeedService.video(id:)`; null when missing or hidden. */
    suspend fun fetchVideo(id: UUID): Video?
    suspend fun hasAudio(clip: File): Boolean
    /** Transcode + thumbnail ([VideoTranscoder]). Throws [CaptureMessageException] with the iOS strings. */
    suspend fun prepare(clip: File): PreparedClip
    /** Edge functions pinned to [accountId]; throws [AccountChangedException] if the session user differs. */
    suspend fun functions(accountId: UUID): SupabaseFunctionsInvoker
    /** Presigned R2 PUT with exact Content-Type / Content-Length and `If-None-Match: *`. */
    suspend fun put(url: String, contentType: String, file: File?, bytes: ByteArray?)
}

/** A non-2xx function response (iOS `FunctionsError.httpError`). */
class FunctionHttpException(val status: Int, val body: String) : Exception("HTTP $status") {
    val detail: String? get() = runCatching { UploadJson.decodeFromString(FunctionErrorBody.serializer(), body).error }.getOrNull()
}

/**
 * Port of iOS `Social/VideoUploader.swift`: transcode, thumbnail, `sign-upload`,
 * PUT both files to R2, persist `pending`, `publish-upload submit`, then poll
 * `status` every 2 s for up to [pollTimeoutMillis].
 */
class VideoUploader(
    private val platform: UploadPlatform,
    private val pollTimeoutMillis: Long = 120_000,
    private val pollIntervalMillis: Long = 2_000,
    private val clock: () -> Long = { System.nanoTime() / 1_000_000 },
    /** Analytics `recording_posted`, once per newly published submission. */
    private val onPosted: () -> Unit = {},
) {
    sealed interface Phase {
        data object Idle : Phase
        data object Preparing : Phase
        data class Uploading(val fraction: Double) : Phase
        data object Checking : Phase
        data class Pending(val message: String) : Phase
        data object Done : Phase
        data class Failed(val message: String) : Phase
    }

    private val _phase = MutableStateFlow<Phase>(Phase.Idle)
    val phase: StateFlow<Phase> = _phase

    val isBusy: Boolean
        get() = when (_phase.value) {
            Phase.Preparing, is Phase.Uploading, Phase.Checking -> true
            else -> false
        }

    suspend fun post(
        clip: File,
        draftId: UUID,
        accountId: UUID,
        store: RecordingDrafts,
        caption: String,
        instrument: String?,
        mode: String?,
        soundSetup: SoundSetup?,
        commentsEnabled: Boolean,
        backingEnabled: Boolean,
        backingCredit: BackingCredit?,
        onScreeningStarted: () -> Unit = {},
    ): Boolean {
        if (isBusy) return false
        if (store.postSubmission(draftId, accountId) != null) {
            return resume(draftId, accountId, store, onScreeningStarted = onScreeningStarted)
        }
        var prepared: PreparedClip? = null
        try {
            _phase.value = Phase.Preparing
            if (backingCredit != null) {
                val source = platform.fetchVideo(backingCredit.videoId)
                if (source == null || source.backingEnabled != true) {
                    throw CaptureMessageException("The creator no longer allows new play-along posts. Your private draft is safe.")
                }
            }
            if (backingEnabled && !platform.hasAudio(clip)) {
                throw CaptureMessageException("This take has no audio to share. Turn off play-along to post it.")
            }
            val ready = platform.prepare(clip).also { prepared = it }
            _phase.value = Phase.Uploading(0.0)
            val functions = functions(accountId)
            val signed = decode(
                functions.invoke("sign-upload", UploadJson.encodeToJsonElement(
                    SignUploadRequest.serializer(), SignUploadRequest(ready.video.length(), ready.thumb.size.toLong()))),
                SignUploadResponse.serializer(),
            )
            platform.put(signed.videoUploadUrl, "video/mp4", ready.video, null)
            _phase.value = Phase.Uploading(0.9)
            platform.put(signed.thumbUploadUrl, "image/jpeg", null, ready.thumb)
            val fields = VideoPostFields(
                caption = caption.graphemePrefix(150), instrument = instrument, mode = mode,
                durationS = ready.durationSeconds, width = ready.width, height = ready.height,
                soundSetup = soundSetup, commentsEnabled = if (commentsEnabled) null else false,
                backingEnabled = if (backingEnabled) true else null, sourceVideoId = backingCredit?.videoId,
            )
            val pending = DraftPostSubmission.Pending(signed.id, fields)
            // Persist before submitting: even a lost HTTP response can mean the server accepted it.
            if (!store.replacePostSubmission(null, pending, draftId, accountId)) {
                _phase.value = Phase.Idle
                return resume(draftId, accountId, store, onScreeningStarted = onScreeningStarted)
            }
            return track(pending, draftId, accountId, store, submitImmediately = true, waitForResult = true,
                onScreeningStarted = onScreeningStarted)
        } catch (e: CancellationException) {
            _phase.value = Phase.Idle
            throw e
        } catch (e: FunctionHttpException) {
            _phase.value = Phase.Failed(e.detail ?: "Couldn't post this video. Your private draft is safe.")
            return false
        } catch (e: Exception) {
            // Our own messages are written for people; platform ones (a MediaCodec dump, an
            // OkHttp connect error) are not, so those get the generic copy.
            _phase.value = Phase.Failed((e as? CaptureMessageException)?.message ?: "Couldn't post this video. Your private draft is safe.")
            return false
        } finally {
            prepared?.video?.delete()
        }
    }

    suspend fun resume(
        draftId: UUID,
        accountId: UUID,
        store: RecordingDrafts,
        waitForResult: Boolean = true,
        onScreeningStarted: () -> Unit = {},
    ): Boolean {
        if (isBusy) return false
        val submission = store.postSubmission(draftId, accountId) ?: return false
        return track(submission, draftId, accountId, store, submitImmediately = false, waitForResult = waitForResult,
            onScreeningStarted = onScreeningStarted)
    }

    private suspend fun functions(accountId: UUID): SupabaseFunctionsInvoker = try {
        platform.functions(accountId)
    } catch (_: AccountChangedException) {
        throw CaptureMessageException("Sign back in to the account that started this post.")
    }

    private suspend fun publish(request: PublishUploadRequest, accountId: UUID): PublishStatus =
        decode(
            functions(accountId).invoke("publish-upload", UploadJson.encodeToJsonElement(PublishUploadRequest.serializer(), request)),
            PublishUploadResponse.serializer(),
        ).status

    private fun <T> decode(response: com.handstrudel.social.FunctionResponse, serializer: kotlinx.serialization.KSerializer<T>): T {
        if (!response.isSuccess) throw FunctionHttpException(response.status, response.body)
        return UploadJson.decodeFromString(serializer, response.body)
    }

    private suspend fun track(
        submission: DraftPostSubmission,
        draftId: UUID,
        accountId: UUID,
        store: RecordingDrafts,
        submitImmediately: Boolean,
        waitForResult: Boolean,
        onScreeningStarted: () -> Unit,
    ): Boolean {
        if (submission !is DraftPostSubmission.Pending) {
            _phase.value = Phase.Done
            return false
        }
        val id = submission.id
        val statusRequest = PublishUploadRequest("status", id)
        val submitRequest = PublishUploadRequest("submit", id, submission.fields)
        _phase.value = Phase.Checking
        try {
            var status = publish(if (submitImmediately) submitRequest else statusRequest, accountId)
            if (status == PublishStatus.RESERVED && !submitImmediately) status = publish(submitRequest, accountId)
            if (status == PublishStatus.CHECKING) onScreeningStarted()
            if (waitForResult) {
                val deadline = clock() + pollTimeoutMillis
                while (status == PublishStatus.CHECKING && clock() < deadline) {
                    delay(pollIntervalMillis)
                    status = publish(statusRequest, accountId)
                }
            }
            when (status) {
                PublishStatus.PUBLISHED -> {
                    val changed = store.replacePostSubmission(submission, DraftPostSubmission.Published(id), draftId, accountId)
                    if (changed) onPosted()
                    _phase.value = Phase.Done
                    return changed
                }
                PublishStatus.HELD, PublishStatus.FAILED -> {
                    store.replacePostSubmission(submission, null, draftId, accountId)
                    _phase.value = Phase.Failed(
                        if (status == PublishStatus.HELD) HELD_MESSAGE else FAILED_MESSAGE,
                    )
                }
                PublishStatus.CHECKING, PublishStatus.RESERVED -> _phase.value = Phase.Pending(STILL_CHECKING_MESSAGE)
            }
        } catch (e: CancellationException) {
            _phase.value = Phase.Pending(UNCONFIRMED_MESSAGE)
            throw e
        } catch (e: Exception) {
            // Only an explicit missing or expired reservation is safe to forget.
            val detail = (e as? FunctionHttpException)?.detail
            val forgettable = e is FunctionHttpException &&
                ((e.status == 404 && detail == "Upload not found.") ||
                    (e.status == 409 && detail == "This upload expired. Try again from Private drafts."))
            if (forgettable && runCatching { store.replacePostSubmission(submission, null, draftId, accountId) }.getOrDefault(false)) {
                _phase.value = Phase.Failed("This upload expired. It wasn't posted. You can post again from Private drafts.")
            } else {
                _phase.value = Phase.Pending(UNCONFIRMED_MESSAGE)
            }
        }
        return false
    }

    companion object {
        const val HELD_MESSAGE = "This clip didn't pass our public content check. Your private draft is safe."
        const val FAILED_MESSAGE = "We couldn't finish checking this clip. It wasn't posted. Your private draft is safe."
        const val STILL_CHECKING_MESSAGE = "This clip is still being checked. You can check its status in Private drafts."
        const val UNCONFIRMED_MESSAGE = "We couldn't confirm the post status yet. Check again here or in Private drafts."

        /** Output width for posted clips; height keeps the recording's aspect. */
        const val OUTPUT_WIDTH = 720
        const val VIDEO_BITRATE = 2_500_000
        const val AUDIO_BITRATE = 128_000
        const val MAX_UPLOAD_BYTES = 15L * 1024 * 1024

        /** iOS `renderSize`: 720 wide, height scaled to the aspect and rounded to an even number. */
        fun renderSize(naturalWidth: Int, naturalHeight: Int): Pair<Int, Int> {
            val w = OUTPUT_WIDTH.toDouble()
            // Swift `.rounded()` rounds half away from zero (Math.round for these positive values).
            val h = Math.round(naturalHeight.toDouble() / maxOf(naturalWidth, 1) * w / 2) * 2
            return OUTPUT_WIDTH to h.toInt()
        }

        /** iOS `targetVideoBitrate`: room below the 15 MiB limit for AAC, container and overshoot. */
        fun targetVideoBitrate(durationSeconds: Double): Int {
            val available = (12.0 * 1024 * 1024 * 8) / maxOf(durationSeconds, 1.0) - AUDIO_BITRATE
            return minOf(VIDEO_BITRATE.toDouble(), available).toInt()
        }
    }
}
