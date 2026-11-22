package com.handstrudel.capture

import android.content.Context
import android.net.Uri
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.PlaybackParameters
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import com.handstrudel.social.model.BackingCredit
import com.handstrudel.social.model.Video
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withTimeoutOrNull
import java.io.File
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

/**
 * iOS `BackingTrack`: a looping play-along source (credit + BPM + player).
 * Main thread only. The player mixes with the instrument (no audio focus) and
 * uses `USAGE_MEDIA`, so app-audio capture records it with the take.
 *
 * iOS `AVAudioPlayer.play()` fails synchronously; ExoPlayer reports failures later
 * through `onPlayerError`, so [load] waits until the player is ready and [onError]
 * reports anything that goes wrong afterwards.
 */
class BackingTrack private constructor(
    val credit: BackingCredit,
    val savedBPM: Double?,
    private val file: File,
    private val player: ExoPlayer,
) {
    val isPlaying: Boolean get() = player.playWhenReady && player.playbackState != Player.STATE_ENDED && player.playerError == null

    /** Called on the main thread when playback fails after [load] (iOS has no equivalent callback). */
    var onError: ((PlaybackException) -> Unit)? = null

    init {
        player.addListener(object : Player.Listener {
            override fun onPlayerError(error: PlaybackException) {
                player.playWhenReady = false
                onError?.invoke(error)
            }
        })
    }

    fun setVolume(volume: Double) { player.volume = BackingTrackVolume.clamped(volume).toFloat() }

    /** iOS `player.rate` (0.5 while recording at half speed). Pitch is kept. */
    fun setRate(rate: Double) { player.playbackParameters = PlaybackParameters(rate.toFloat()) }

    /** Returns false when playback couldn't start (iOS `play()` result). */
    fun play(): Boolean {
        if (player.playerError != null) {
            player.prepare()
        }
        player.play()
        return player.playerError == null
    }

    fun pause() { player.pause() }

    fun rewind() { player.seekTo(0) }

    fun remove() {
        player.release()
        file.delete()
    }

    companion object {
        suspend fun load(context: Context, video: Video, username: String): BackingTrack {
            val file = PerformanceAudio.export(context, video)
            try {
                val player = ExoPlayer.Builder(context).build().apply {
                    setAudioAttributes(
                        AudioAttributes.Builder().setUsage(C.USAGE_MEDIA).setContentType(C.AUDIO_CONTENT_TYPE_MUSIC).build(),
                        /* handleAudioFocus = */ false,
                    )
                    repeatMode = Player.REPEAT_MODE_ONE
                    setMediaItem(MediaItem.fromUri(Uri.fromFile(file)))
                    prepare()
                }
                try {
                    awaitReady(player)
                } catch (e: Throwable) {
                    player.release()
                    throw e
                }
                return BackingTrack(BackingCredit(video.id, username), video.soundSetup?.bpm, file, player)
            } catch (e: Exception) {
                file.delete()
                throw e
            }
        }

        /** Like `AVAudioPlayer(contentsOf:)` throwing: an unplayable file fails the load. */
        private suspend fun awaitReady(player: ExoPlayer) {
            // A timeout is a load failure, not a cancellation (the caller ignores cancellations).
            withTimeoutOrNull(10_000) { awaitReadyOrError(player) } ?: throw IllegalStateException("The backing audio didn't load in time.")
        }

        private suspend fun awaitReadyOrError(player: ExoPlayer): Unit =
            suspendCancellableCoroutine { cont ->
                val listener = object : Player.Listener {
                    override fun onPlaybackStateChanged(playbackState: Int) {
                        if (playbackState == Player.STATE_READY) finish(null)
                    }
                    override fun onPlayerError(error: PlaybackException) = finish(error)
                    fun finish(error: PlaybackException?) {
                        player.removeListener(this)
                        if (!cont.isActive) return
                        if (error == null) cont.resume(Unit) else cont.resumeWithException(error)
                    }
                }
                when {
                    player.playerError != null -> cont.resumeWithException(player.playerError!!)
                    player.playbackState == Player.STATE_READY -> cont.resume(Unit)
                    else -> {
                        player.addListener(listener)
                        cont.invokeOnCancellation { player.removeListener(listener) }
                    }
                }
            }
    }
}
