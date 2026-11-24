package com.handstrudel.capture.upload

import android.content.Context
import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import androidx.annotation.OptIn
import androidx.media3.common.util.UnstableApi
import androidx.media3.effect.FrameDropEffect
import androidx.media3.effect.Presentation
import androidx.media3.transformer.DefaultEncoderFactory
import androidx.media3.transformer.VideoEncoderSettings
import com.handstrudel.capture.drafts.Media
import com.handstrudel.capture.drafts.MediaInfo
import com.handstrudel.capture.drafts.RecordingDrafts
import com.handstrudel.social.SupabaseFunctionsInvoker
import com.handstrudel.social.AuthSession
import com.handstrudel.social.SocialEntryPoints
import com.handstrudel.social.model.Video
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.asRequestBody
import okhttp3.RequestBody.Companion.toRequestBody
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.UUID
import java.util.concurrent.TimeUnit

/**
 * iOS `VideoUploader.prepare`: transcode a clip to 720-wide H.264 at 30 fps and
 * the computed bitrate (AAC audio is kept), cap it at 60 s and 15 MiB, and grab
 * a JPEG (q 0.75) thumbnail at `min(1 s, duration / 2)`.
 */
@OptIn(UnstableApi::class)
object VideoTranscoder {
    suspend fun prepare(context: Context, clip: File): PreparedClip {
        val info = withContext(Dispatchers.IO) { MediaInfo.read(clip) }
        if (info == null || !info.hasVideo) throw CaptureMessageException("The recording has no video.")
        val (width, height) = VideoUploader.renderSize(info.width, info.height)
        if (info.width < 1 || height < 2) throw CaptureMessageException("The recording could not be read.")
        if (info.durationSeconds > RecordingDrafts.RECORDING_LIMIT + 1) {
            throw CaptureMessageException("Trim the recording to 60 seconds or less to post it.")
        }
        val duration = minOf(info.durationSeconds, RecordingDrafts.RECORDING_LIMIT.toDouble())
        val out = File(context.cacheDir, "post_${UUID.randomUUID()}.mp4")
        var prepared = false
        try {
            val bitrate = VideoUploader.targetVideoBitrate(duration)
            Media.transform(
                context, clip, out,
                endSeconds = if (info.durationSeconds > duration) duration else null,
                videoEffects = listOf(
                    Presentation.createForWidthAndHeight(width, height, Presentation.LAYOUT_SCALE_TO_FIT),
                    FrameDropEffect.createDefaultFrameDropEffect(30f),
                ),
            ) { builder ->
                builder.setEncoderFactory(
                    DefaultEncoderFactory.Builder(context)
                        .setRequestedVideoEncoderSettings(VideoEncoderSettings.Builder().setBitrate(bitrate).setiFrameIntervalSeconds(2f).build())
                        .setEnableFallback(true)
                        .build(),
                )
            }
            if (out.length() > VideoUploader.MAX_UPLOAD_BYTES) {
                throw CaptureMessageException("This clip is too large to post. Trim it and try again.")
            }
            val thumb = withContext(Dispatchers.IO) { thumbnail(out, duration, width, height) }
                ?: throw CaptureMessageException("Couldn't make a thumbnail.")
            prepared = true
            return PreparedClip(out, thumb, width, height, duration)
        } finally {
            if (!prepared) out.delete()
        }
    }

    private fun thumbnail(file: File, duration: Double, width: Int, height: Int): ByteArray? {
        val retriever = MediaMetadataRetriever()
        return try {
            retriever.setDataSource(file.absolutePath)
            val atUs = (minOf(1.0, duration / 2) * 1_000_000).toLong()
            val frame = retriever.getScaledFrameAtTime(atUs, MediaMetadataRetriever.OPTION_CLOSEST_SYNC, width, height)
                ?: retriever.getFrameAtTime(atUs) ?: return null
            ByteArrayOutputStream().use { stream ->
                if (!frame.compress(Bitmap.CompressFormat.JPEG, 75, stream)) return null
                stream.toByteArray()
            }
        } catch (_: Exception) {
            null
        } finally {
            runCatching { retriever.release() }
        }
    }
}

/** The real [UploadPlatform]: social's feed lookup and auth, Media3, OkHttp to R2. */
class AndroidUploadPlatform(private val context: Context, private val auth: AuthSession) : UploadPlatform {
    private val http = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .writeTimeout(120, TimeUnit.SECONDS)
        .readTimeout(60, TimeUnit.SECONDS)
        .build()

    override suspend fun fetchVideo(id: UUID): Video? = SocialEntryPoints.fetchVideo(id)
    override suspend fun hasAudio(clip: File): Boolean = withContext(Dispatchers.IO) { MediaInfo.hasAudioTrack(clip) }
    override suspend fun prepare(clip: File): PreparedClip = VideoTranscoder.prepare(context, clip)
    override suspend fun functions(accountId: UUID): SupabaseFunctionsInvoker = auth.functionsFor(accountId)

    override suspend fun put(url: String, contentType: String, file: File?, bytes: ByteArray?) =
        withContext(Dispatchers.IO) { PresignedPut.put(http, url, contentType, file, bytes) }
}


/**
 * iOS `VideoUploader.put`: PUT to a presigned R2 URL with exactly the signed
 * headers (`Content-Type`, `Content-Length`, `If-None-Match: *`). Blocking.
 */
object PresignedPut {
    fun put(http: OkHttpClient, url: String, contentType: String, file: File?, bytes: ByteArray?) {
        val type = contentType.toMediaType()
        val body = file?.asRequestBody(type) ?: bytes!!.toRequestBody(type)
        val request = Request.Builder().url(url)
            .put(body)
            .header("Content-Type", contentType)
            .header("Content-Length", body.contentLength().toString())
            .header("If-None-Match", "*")
            .build()
        http.newCall(request).execute().use { response ->
            if (!response.isSuccessful) throw CaptureMessageException("Upload failed (${response.code}).")
        }
    }
}
