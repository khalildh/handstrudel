package com.handstrudel.capture

import android.content.Context
import com.handstrudel.capture.drafts.Media
import com.handstrudel.capture.drafts.MediaInfo
import com.handstrudel.capture.upload.CaptureMessageException
import com.handstrudel.social.model.Video
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request
import java.io.File
import java.util.UUID
import java.util.concurrent.TimeUnit
import kotlin.coroutines.coroutineContext

/**
 * iOS `PerformanceAudio.export`: download a post's clip and extract its audio
 * to a temporary M4A for play-along.
 */
object PerformanceAudio {
    private val http by lazy {
        OkHttpClient.Builder().connectTimeout(20, TimeUnit.SECONDS).readTimeout(60, TimeUnit.SECONDS).build()
    }

    /** iOS `SocialConfig.mediaURL` (screened keys on the clip host, others on the legacy host). */
    fun mediaUrl(key: String): String = com.handstrudel.social.SocialConfig.mediaUrl(key)

    suspend fun export(context: Context, video: Video): File {
        val dir = File(context.cacheDir, "backing").apply { mkdirs() }
        val localVideo = File(dir, "Backing-${UUID.randomUUID()}.mp4")
        try {
            try {
                withContext(Dispatchers.IO) {
                    http.newCall(Request.Builder().url(mediaUrl(video.videoKey)).build()).execute().use { response ->
                        if (response.code != 200) throw CaptureMessageException("This clip couldn't be downloaded.")
                        localVideo.outputStream().use { out -> response.body!!.byteStream().copyTo(out) }
                    }
                }
            } catch (e: CaptureMessageException) {
                throw e
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                throw CaptureMessageException("This clip couldn't be downloaded. Try again.")
            }
            coroutineContext.ensureActive()
            val info = withContext(Dispatchers.IO) { MediaInfo.read(localVideo) }
            if (info == null || info.durationSeconds !in 0.1..61.0 || !info.hasAudio) {
                throw CaptureMessageException("This performance doesn't have playable backing audio.")
            }
            val url = File(dir, "HandStrudel-${UUID.randomUUID()}.m4a")
            try {
                Media.transform(context, localVideo, url, removeVideo = true)
            } catch (e: CancellationException) {
                url.delete()
                throw e
            } catch (e: Exception) {
                url.delete()
                throw CaptureMessageException("Couldn't extract the audio from this clip.")
            }
            return url
        } finally {
            localVideo.delete()
        }
    }
}
