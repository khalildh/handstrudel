package com.handstrudel.ui.social.feed

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMuxer
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import com.handstrudel.app.shareFile
import com.handstrudel.social.data.SocialException
import com.handstrudel.social.model.Video
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request
import java.io.File
import java.nio.ByteBuffer
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap
import kotlin.coroutines.coroutineContext

/**
 * iOS `VideoShareSheet`: shares the post's watch URL and records the share
 * (`record_video_share`) only once the viewer picked a target, like the iOS
 * activity sheet's completion handler.
 */
object VideoShareSheet {
    private const val ACTION = "com.handstrudel.social.SHARE_CHOSEN"
    private const val EXTRA_TOKEN = "token"
    private val pending = ConcurrentHashMap<String, () -> Unit>()
    @Volatile private var registered = false

    fun share(context: Context, video: Video, onShared: () -> Unit) {
        val app = context.applicationContext
        register(app)
        val token = UUID.randomUUID().toString()
        pending[token] = onShared
        val callback = PendingIntent.getBroadcast(
            app, token.hashCode(),
            Intent(ACTION).setPackage(app.packageName).putExtra(EXTRA_TOKEN, token),
            PendingIntent.FLAG_MUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val send = Intent(Intent.ACTION_SEND).apply {
            type = "text/plain"
            putExtra(Intent.EXTRA_TEXT, video.watchUrl)
        }
        context.startActivity(Intent.createChooser(send, null, callback.intentSender).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
    }

    private fun register(app: Context) {
        if (registered) return
        synchronized(this) {
            if (registered) return
            ContextCompat.registerReceiver(app, object : BroadcastReceiver() {
                override fun onReceive(context: Context, intent: Intent) {
                    intent.getStringExtra(EXTRA_TOKEN)?.let { pending.remove(it)?.invoke() }
                }
            }, IntentFilter(ACTION), ContextCompat.RECEIVER_NOT_EXPORTED)
            registered = true
        }
    }
}

/**
 * iOS `PerformanceAudio.export`: downloads the clip and extracts its AAC track to an
 * `.m4a` (no re-encode), then hands it to the share sheet through the FileProvider.
 */
object PerformanceAudio {
    suspend fun export(context: Context, http: OkHttpClient, video: Video): File = withContext(Dispatchers.IO) {
        val dir = File(context.cacheDir, "exports").apply { mkdirs() }
        // Shared files can't report when the share sheet closes; sweep old exports instead.
        dir.listFiles()?.filter { it.name.startsWith("HandStrudel-") && System.currentTimeMillis() - it.lastModified() > 3_600_000 }
            ?.forEach { it.delete() }
        val download = File(dir, "Backing-${UUID.randomUUID()}.mp4")
        try {
            try {
                http.newCall(Request.Builder().url(video.videoUrl).build()).execute().use { response ->
                    if (response.code != 200) throw SocialException("This clip couldn't be downloaded.")
                    download.outputStream().use { out -> response.body!!.byteStream().copyTo(out) }
                }
            } catch (e: SocialException) {
                throw e
            } catch (e: Exception) {
                coroutineContext.ensureActive()
                throw SocialException("This clip couldn't be downloaded. Try again.")
            }
            coroutineContext.ensureActive()
            val output = File(dir, "HandStrudel-${UUID.randomUUID()}.m4a")
            try {
                extractAudio(download, output)
            } catch (e: SocialException) {
                output.delete(); throw e
            } catch (e: Exception) {
                output.delete(); throw SocialException("Couldn't extract the audio from this clip.")
            }
            output
        } finally {
            download.delete()
        }
    }

    private fun extractAudio(input: File, output: File) {
        val extractor = MediaExtractor()
        try {
            extractor.setDataSource(input.absolutePath)
            val track = (0 until extractor.trackCount).firstOrNull {
                extractor.getTrackFormat(it).getString(MediaFormat.KEY_MIME)?.startsWith("audio/") == true
            }
            val format = track?.let { extractor.getTrackFormat(it) }
            val durationUs = format?.takeIf { it.containsKey(MediaFormat.KEY_DURATION) }?.getLong(MediaFormat.KEY_DURATION)
            if (track == null || format == null || durationUs == null || durationUs / 1e6 !in 0.1..61.0) {
                throw SocialException("This performance doesn't have playable backing audio.")
            }
            extractor.selectTrack(track)
            val muxer = MediaMuxer(output.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
            try {
                val out = muxer.addTrack(format)
                muxer.start()
                val buffer = ByteBuffer.allocate(1 shl 20)
                val info = MediaCodec.BufferInfo()
                while (true) {
                    val size = extractor.readSampleData(buffer, 0)
                    if (size < 0) break
                    info.set(0, size, extractor.sampleTime, if (extractor.sampleFlags and MediaExtractor.SAMPLE_FLAG_SYNC != 0) MediaCodec.BUFFER_FLAG_KEY_FRAME else 0)
                    muxer.writeSampleData(out, buffer, info)
                    extractor.advance()
                }
                muxer.stop()
            } finally {
                muxer.release()
            }
        } finally {
            extractor.release()
        }
    }

    fun share(context: Context, file: File) {
        val uri = FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", file)
        shareFile(context, uri, "audio/mp4")
    }
}
