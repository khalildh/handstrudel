package com.handstrudel.capture.drafts

import android.content.ContentValues
import android.content.Context
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.provider.MediaStore
import androidx.annotation.OptIn
import androidx.core.content.FileProvider
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.audio.SpeedProvider
import androidx.media3.common.util.UnstableApi
import androidx.media3.transformer.Composition
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.Effects
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.Transformer
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import java.io.File
import java.util.UUID
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

/**
 * iOS `RecordingDraftExport` + `RecordingDrafts.makeExport`: a temporary copy of
 * a draft under `cacheDir/exports/`, trimmed and (for half-speed takes) played
 * back ×2 with pitch kept. Owns only the copy, never the draft's source file.
 */
class DraftExport private constructor(val file: File, val audioOnly: Boolean) {
    val mimeType: String get() = if (audioOnly) "audio/mp4" else "video/mp4"

    fun uri(context: Context): Uri = FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", file)

    fun remove() { file.delete() }

    companion object {
        fun exportsDir(context: Context): File = File(context.cacheDir, "exports").apply { mkdirs() }

        /**
         * How long a copy handed to another app is kept. Android's share sheet returns as soon as
         * a target is picked, and the target may still be reading the `content://` URI, so copies
         * are not deleted on return (iOS deletes once the share sheet has gone, when the target has
         * already taken the file). They're removed by [sweep] once older than this.
         */
        const val SHARED_COPY_LIFETIME_MS: Long = 60 * 60 * 1000L

        /**
         * Removes copies older than [maxAgeMs]: at launch (copies left by a previous run) and
         * before each share. Newer copies may still be in use by another app or by this one.
         */
        fun sweep(context: Context, maxAgeMs: Long = SHARED_COPY_LIFETIME_MS, nowMs: Long = System.currentTimeMillis()) {
            sweepOlderThan(exportsDir(context), maxAgeMs, nowMs)
        }

        /** Deletes the files directly in [dir] last modified more than [maxAgeMs] before [nowMs]. */
        fun sweepOlderThan(dir: File, maxAgeMs: Long, nowMs: Long) {
            dir.listFiles()?.forEach { file ->
                if (file.isFile && nowMs - file.lastModified() > maxAgeMs) file.delete()
            }
        }

        suspend fun make(context: Context, store: RecordingDrafts, draft: RecordingDraft, audioOnly: Boolean = false): DraftExport {
            val source = store.videoFile(draft.id)
            val info = withContext(Dispatchers.IO) { MediaInfo.read(source) } ?: throw DraftException(DraftError.UNREADABLE)
            val trim = DraftTrimSelection.of(info.durationSeconds, draft.trimStart, draft.trimEnd)
                ?: throw DraftException(DraftError.INVALID_TRIM)
            if (audioOnly && !info.hasAudio) throw DraftException(DraftError.NO_AUDIO)
            val export = DraftExport(File(exportsDir(context), "HandStrudel-${UUID.randomUUID()}.${if (audioOnly) "m4a" else "mp4"}"), audioOnly)
            try {
                if (!audioOnly && draft.outputScale == 1.0 && trim.isFullLength) {
                    withContext(Dispatchers.IO) { source.copyTo(export.file, overwrite = true) }
                } else {
                    Media.transform(
                        context, source, export.file,
                        startSeconds = trim.start, endSeconds = trim.end,
                        speed = (1 / draft.outputScale).toFloat(), removeVideo = audioOnly,
                    )
                }
                if (!export.file.isFile || export.file.length() == 0L) throw DraftException(DraftError.UNREADABLE)
                return export
            } catch (e: Exception) {
                export.remove()
                throw e
            }
        }

        /** Android "Save to Photos": `Movies/HandStrudel` through MediaStore (no storage permission on API 29+). */
        suspend fun saveToGallery(context: Context, export: DraftExport) = withContext(Dispatchers.IO) {
            val resolver = context.contentResolver
            val values = ContentValues().apply {
                put(MediaStore.Video.Media.DISPLAY_NAME, export.file.name)
                put(MediaStore.Video.Media.MIME_TYPE, "video/mp4")
                put(MediaStore.Video.Media.RELATIVE_PATH, "Movies/HandStrudel")
                put(MediaStore.Video.Media.IS_PENDING, 1)
            }
            val collection = MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            val uri = resolver.insert(collection, values) ?: throw DraftException(DraftError.UNREADABLE)
            try {
                resolver.openOutputStream(uri)!!.use { out -> export.file.inputStream().use { it.copyTo(out) } }
                resolver.update(uri, ContentValues().apply { put(MediaStore.Video.Media.IS_PENDING, 0) }, null, null)
            } catch (e: Exception) {
                resolver.delete(uri, null, null)
                throw e
            }
        }
    }
}

/** Duration, size and tracks of a local media file. */
data class MediaInfo(val durationSeconds: Double, val width: Int, val height: Int, val hasAudio: Boolean, val hasVideo: Boolean) {
    companion object {
        fun read(file: File): MediaInfo? {
            if (!file.isFile) return null
            val retriever = MediaMetadataRetriever()
            return try {
                retriever.setDataSource(file.absolutePath)
                val ms = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull() ?: return null
                val w = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)?.toIntOrNull() ?: 0
                val h = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)?.toIntOrNull() ?: 0
                val rotation = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)?.toIntOrNull() ?: 0
                val upright = if (rotation % 180 != 0) h to w else w to h
                val hasVideo = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_HAS_VIDEO) == "yes"
                MediaInfo(ms / 1000.0, upright.first, upright.second, hasAudioTrack(file), hasVideo)
                    .takeIf { it.durationSeconds.isFinite() && it.durationSeconds > 0 }
            } catch (_: Exception) {
                null
            } finally {
                runCatching { retriever.release() }
            }
        }

        fun hasAudioTrack(file: File): Boolean {
            val extractor = MediaExtractor()
            return try {
                extractor.setDataSource(file.absolutePath)
                (0 until extractor.trackCount).any {
                    extractor.getTrackFormat(it).getString(MediaFormat.KEY_MIME)?.startsWith("audio/") == true
                }
            } catch (_: Exception) {
                false
            } finally {
                extractor.release()
            }
        }
    }
}

/** Media3 Transformer as a cancellable suspend call (runs on the main looper). */
@OptIn(UnstableApi::class)
object Media {
    suspend fun transform(
        context: Context,
        source: File,
        output: File,
        startSeconds: Double = 0.0,
        endSeconds: Double? = null,
        speed: Float = 1f,
        removeVideo: Boolean = false,
        videoEffects: List<androidx.media3.common.Effect> = emptyList(),
        configure: (Transformer.Builder) -> Unit = {},
    ) = com.handstrudel.capture.VideoDecoderDemand.hold { transformOnMain(context, source, output, startSeconds, endSeconds, speed, removeVideo, videoEffects, configure) }

    private suspend fun transformOnMain(
        context: Context,
        source: File,
        output: File,
        startSeconds: Double,
        endSeconds: Double?,
        speed: Float,
        removeVideo: Boolean,
        videoEffects: List<androidx.media3.common.Effect>,
        configure: (Transformer.Builder) -> Unit,
    ) = withContext(Dispatchers.Main) {
        val clipping = MediaItem.ClippingConfiguration.Builder()
            .setStartPositionMs((startSeconds * 1000).toLong())
            .apply { if (endSeconds != null) setEndPositionMs((endSeconds * 1000).toLong()) }
            .build()
        val item = MediaItem.Builder().setUri(Uri.fromFile(source)).setClippingConfiguration(clipping).build()
        val audioProcessors = mutableListOf<androidx.media3.common.audio.AudioProcessor>()
        val effects = videoEffects.toMutableList()
        if (speed != 1f) {
            // Pitch is kept (Sonic time-stretch), like iOS `.spectral`.
            val pair = Effects.createExperimentalSpeedChangingEffect(ConstantSpeed(speed))
            audioProcessors += pair.first
            if (!removeVideo) effects += pair.second
        }
        val edited = EditedMediaItem.Builder(item)
            .setRemoveVideo(removeVideo)
            .setEffects(Effects(audioProcessors, effects))
            .build()
        output.parentFile?.mkdirs()
        output.delete()
        suspendCancellableCoroutine { cont ->
            val builder = Transformer.Builder(context)
                // Encode portrait frames as portrait (720×H, no rotation flag), like iOS bakes the
                // transform into the pixels. Without it Media3 encodes H×720 with a 90° matrix.
                .setPortraitEncodingEnabled(true)
                .setVideoMimeType(MimeTypes.VIDEO_H264)
                .setAudioMimeType(MimeTypes.AUDIO_AAC)
                .addListener(object : Transformer.Listener {
                    override fun onCompleted(composition: Composition, exportResult: ExportResult) {
                        if (cont.isActive) cont.resume(exportResult)
                    }

                    override fun onError(composition: Composition, exportResult: ExportResult, exportException: ExportException) {
                        output.delete()
                        if (cont.isActive) cont.resumeWithException(exportException)
                    }
                })
            configure(builder)
            val transformer = builder.build()
            transformer.start(edited, output.absolutePath)
            cont.invokeOnCancellation {
                android.os.Handler(android.os.Looper.getMainLooper()).post {
                    transformer.cancel()
                    output.delete()
                }
            }
        }
    }

    private class ConstantSpeed(private val speed: Float) : SpeedProvider {
        override fun getSpeed(timeUs: Long): Float = speed
        override fun getNextSpeedChangeTimeUs(timeUs: Long): Long = androidx.media3.common.C.TIME_UNSET
    }
}
