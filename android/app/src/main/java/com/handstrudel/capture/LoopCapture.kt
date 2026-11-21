package com.handstrudel.capture

import java.io.File
import java.io.RandomAccessFile
import java.nio.ByteBuffer
import java.nio.ByteOrder

/**
 * iOS `CapturedLoopFile`: writes captured app audio to a 16-bit PCM WAV on a
 * worker thread. The duration is the number of frames written, so a truncated
 * file can still be validated against it ([WavFile.isComplete]).
 */
class LoopCapture(val file: File, private val audio: AppAudioCapture) {
    @Volatile private var stopRequested = false
    @Volatile var framesWritten = 0L
        private set
    @Volatile var failure: Exception? = null
        private set
    private var thread: Thread? = null

    fun start() {
        file.parentFile?.mkdirs()
        audio.start()
        thread = Thread({ run() }, "hs-loop-capture").apply { start() }
    }

    private fun run() {
        try {
            RandomAccessFile(file, "rw").use { out ->
                out.setLength(0)
                out.write(WavFile.header(0, AppAudioCapture.SAMPLE_RATE, AppAudioCapture.CHANNELS))
                val frames = 1024
                val pcm = ShortArray(frames * AppAudioCapture.CHANNELS)
                val bytes = ByteBuffer.allocate(pcm.size * 2).order(ByteOrder.LITTLE_ENDIAN)
                while (!stopRequested) {
                    val read = audio.read(pcm, frames)
                    if (read < 0) throw IllegalStateException("Audio capture failed ($read).")
                    bytes.clear()
                    bytes.asShortBuffer().put(pcm, 0, read * AppAudioCapture.CHANNELS)
                    out.write(bytes.array(), 0, read * AppAudioCapture.CHANNELS * 2)
                    framesWritten += read
                }
                out.seek(0)
                out.write(WavFile.header(framesWritten, AppAudioCapture.SAMPLE_RATE, AppAudioCapture.CHANNELS))
            }
        } catch (e: Exception) {
            failure = e
        }
    }

    /** Stops and closes the file. Blocking; returns the duration in seconds (iOS `finish()`). */
    fun finish(): Double {
        stopRequested = true
        thread?.join(3_000)
        audio.close()
        failure?.let { throw it }
        if (framesWritten <= 0) throw IllegalStateException("No audio was captured.")
        return framesWritten.toDouble() / AppAudioCapture.SAMPLE_RATE
    }

    fun discard() {
        stopRequested = true
        thread?.join(3_000)
        audio.close()
        file.delete()
    }
}

/** Minimal PCM WAV helpers (header + iOS `shareCaptured` completeness check). */
object WavFile {
    fun header(frames: Long, sampleRate: Int, channels: Int): ByteArray {
        val dataSize = frames * channels * 2
        return ByteBuffer.allocate(44).order(ByteOrder.LITTLE_ENDIAN).apply {
            put("RIFF".toByteArray()); putInt((36 + dataSize).toInt()); put("WAVEfmt ".toByteArray())
            putInt(16); putShort(1); putShort(channels.toShort())
            putInt(sampleRate); putInt(sampleRate * channels * 2); putShort((channels * 2).toShort()); putShort(16)
            put("data".toByteArray()); putInt(dataSize.toInt())
        }.array()
    }

    /** Frames in a 16-bit PCM WAV and its sample rate, or null when it isn't one. */
    fun info(file: File): Pair<Long, Int>? = runCatching {
        RandomAccessFile(file, "r").use { f ->
            val head = ByteArray(44)
            f.readFully(head)
            val b = ByteBuffer.wrap(head).order(ByteOrder.LITTLE_ENDIAN)
            if (String(head, 0, 4) != "RIFF" || String(head, 8, 4) != "WAVE") return null
            val channels = b.getShort(22).toInt()
            val rate = b.getInt(24)
            val bits = b.getShort(34).toInt()
            val dataSize = b.getInt(40).toLong() and 0xffffffffL
            val available = f.length() - 44
            if (channels <= 0 || bits != 16) return null
            minOf(dataSize, available) / (channels * 2) to rate
        }
    }.getOrNull()

    /** iOS `shareCaptured`: the file's frame count must match the saved duration. */
    fun isComplete(file: File, durationSeconds: Double): Boolean {
        val (frames, rate) = info(file) ?: return false
        return frames > 0 && Math.round(durationSeconds * rate) == frames
    }
}
