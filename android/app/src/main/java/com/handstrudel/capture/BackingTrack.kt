package com.handstrudel.capture

import android.content.Context
import android.net.Uri
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackParameters
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import com.handstrudel.social.model.BackingCredit
import com.handstrudel.social.model.Video
import java.io.File

/**
 * iOS `BackingTrack`: a looping play-along source (credit + BPM + player).
 * Main thread only. The player mixes with the instrument (no audio focus) and
 * uses `USAGE_MEDIA`, so app-audio capture records it with the take.
 */
class BackingTrack private constructor(
    val credit: BackingCredit,
    val savedBPM: Double?,
    private val file: File,
    private val player: ExoPlayer,
) {
    val isPlaying: Boolean get() = player.playWhenReady && player.playbackState != Player.STATE_ENDED

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
                return BackingTrack(BackingCredit(video.id, username), video.soundSetup?.bpm, file, player)
            } catch (e: Exception) {
                file.delete()
                throw e
            }
        }
    }
}
