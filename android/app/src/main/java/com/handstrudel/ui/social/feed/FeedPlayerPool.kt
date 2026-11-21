package com.handstrudel.ui.social.feed

import android.content.Context
import androidx.annotation.OptIn
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.okhttp.OkHttpDataSource
import androidx.media3.exoplayer.DefaultLoadControl
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import com.handstrudel.social.data.ClipViewReceipt
import com.handstrudel.social.data.FeedPlaybackPosition
import com.handstrudel.social.data.FeedService
import com.handstrudel.social.data.QualifiedClipWatch
import com.handstrudel.social.model.Video
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import okhttp3.OkHttpClient
import java.util.UUID

/**
 * A small pool of ExoPlayers for the feed (iOS `FeedVideoPreloader` +
 * `FeedPlaybackGate`). The pager composes the selected page and one page either
 * side; each gets a prepared, paused, silent player from here, so its first frame
 * is already decoded on screen when it becomes current (iOS a09c0631: warm the
 * first clip and preload actual frames). Players outside the window are released.
 * Only one clip plays at a time: [select] makes the gate's owner current.
 */
@OptIn(UnstableApi::class)
class FeedPlayerPool(
    private val context: Context,
    private val scope: CoroutineScope,
    http: OkHttpClient,
    private val service: FeedService?,
) {
    private val clips = LinkedHashMap<UUID, FeedClip>()
    private val refs = mutableMapOf<UUID, Int>()
    private val dataSource = OkHttpDataSource.Factory(http)

    /** iOS `FeedPlaybackGate.selectedVideoID`. */
    val selected = MutableStateFlow<UUID?>(null)
    /** True while the user is dragging between pages (end-of-clip must not auto-advance then). */
    var isPaging = false

    /** Bumps when players are rebuilt (after backgrounding), so cells re-bind. */
    val generation = MutableStateFlow(0)

    /**
     * A prepared player for [video], shared by every composable showing it (the pager cell,
     * the fixed rail and the progress strip). Pair each call with [release].
     */
    fun acquire(video: Video): FeedClip {
        val existing = clips[video.id]?.takeIf { it.url == video.videoUrl && !it.isReleased }
        val clip = existing ?: create(video).also { clips.remove(video.id)?.release(); clips[video.id] = it; refs[video.id] = 0 }
        refs[video.id] = (refs[video.id] ?: 0) + 1
        return clip
    }

    /** Drops a reference; the player is released once nothing on screen shows the clip. */
    fun release(clip: FeedClip) {
        val id = clip.video.id
        if (clips[id] !== clip) { clip.release(); return }
        val left = (refs[id] ?: 1) - 1
        if (left > 0) { refs[id] = left; return }
        refs.remove(id)
        clips.remove(id)
        if (selected.value == id) selected.value = null
        clip.release()
    }

    private fun create(video: Video): FeedClip {
        val loadControl = DefaultLoadControl.Builder()
            .setBufferDurationsMs(2_500, 10_000, 500, 1_000)
            .build()
        val player = ExoPlayer.Builder(context)
            .setMediaSourceFactory(DefaultMediaSourceFactory(dataSource))
            .setLoadControl(loadControl)
            .setAudioAttributes(
                AudioAttributes.Builder().setUsage(C.USAGE_MEDIA).setContentType(C.AUDIO_CONTENT_TYPE_MOVIE).build(),
                /* handleAudioFocus = */ false,
            )
            .build()
        player.repeatMode = Player.REPEAT_MODE_OFF
        player.volume = 0f
        player.playWhenReady = false
        player.setMediaItem(MediaItem.fromUri(video.videoUrl))
        player.prepare()
        return FeedClip(video, player, this, scope, service)
    }

    /** iOS `FeedPlaybackGate.select`: pauses the old owner. */
    fun select(id: UUID?) {
        if (selected.value == id) return
        selected.value?.let { clips[it]?.deselect() }
        selected.value = id
    }

    /** Backgrounding: free every decoder; cells re-acquire on the next generation. */
    fun releaseAll() {
        clips.values.forEach { it.release() }
        clips.clear()
        refs.clear()
        selected.value = null
        generation.value += 1
    }
}

/**
 * One clip's player and playback state (iOS `FeedClipPlayback` +
 * `FeedPlaybackController`): user pause, failure, playhead, scrubbing and the
 * qualified-view report.
 */
class FeedClip internal constructor(
    val video: Video,
    val player: ExoPlayer,
    private val pool: FeedPlayerPool?,
    private val scope: CoroutineScope,
    private val service: FeedService?,
) {
    val url: String = video.videoUrl
    val position = MutableStateFlow(FeedPlaybackPosition.of(video.durationS ?: 0.0, 0.0))
    val failed = MutableStateFlow(false)
    /** The viewer's pause (tap). Reset when the clip is revisited. */
    val paused = MutableStateFlow(false)
    val viewCount = MutableStateFlow<Int?>(null)
    var onViewCount: ((UUID, Int) -> Unit)? = null
    /** Called at the end of the clip while current; returns true if the feed advanced. */
    var onEnded: (() -> Boolean)? = null
    var isReleased = false
        private set

    private var isCurrent = false
    private var allowed = false
    private var muted = true
    private var tracking = false
    private val watch = QualifiedClipWatch()
    private val countsViews = video.viewCount != null && video.hidden != true
    private var poll: Job? = null

    private val listener = object : Player.Listener {
        override fun onPlaybackStateChanged(state: Int) {
            if (state == Player.STATE_ENDED) finished()
        }
        override fun onPlayerError(error: PlaybackException) {
            player.playWhenReady = false
            failed.value = true
        }
    }

    init { player.addListener(listener) }

    /** iOS `displayedViewCount(fetched:)`. */
    fun displayedViewCount(fetched: Int?): Int? = viewCount.value?.let { maxOf(it, fetched ?: 0) } ?: fetched

    /** Current page + whether playback is allowed (no sheet, tab visible, app foreground) + mute. */
    fun configure(isCurrent: Boolean, allowed: Boolean, muted: Boolean) {
        if (isReleased) return
        if (this.isCurrent != isCurrent) {
            this.isCurrent = isCurrent
            if (isCurrent) startPolling() else { poll?.cancel(); poll = null; watch.resetSample() }
        }
        if (!allowed) watch.resetSample()
        this.allowed = allowed
        this.muted = muted
        sync()
    }

    /** iOS `FeedPlaybackStore.select` → `prepareForVisit`: restart from the beginning, unpaused. */
    fun prepareForVisit() {
        if (isReleased) return
        paused.value = false
        if (failed.value) retry()
        tracking = false
        watch.resetSample()
        if (player.currentPosition > 0) player.seekTo(0)
        position.value = position.value?.let { FeedPlaybackPosition.of(it.duration, 0.0) }
            ?: FeedPlaybackPosition.of(video.durationS ?: 0.0, 0.0)
    }

    internal fun deselect() {
        if (isReleased) return
        player.playWhenReady = false
    }

    fun togglePause() { if (!failed.value) { paused.value = !paused.value; sync() } }
    fun setPaused(value: Boolean) { paused.value = value; sync() }

    fun retry() {
        failed.value = false
        paused.value = false
        player.prepare()
        player.seekTo(0)
        sync()
    }

    /** Scrubbing: pause while the thumb is held, seek on release. */
    fun setEditing(editing: Boolean) {
        if (!isCurrent || editing == tracking) return
        tracking = editing
        watch.resetSample()
        if (!editing) position.value?.let { player.seekTo((it.seekSeconds * 1000).toLong()) }
        sync()
    }

    fun setSeconds(seconds: Double) {
        if (!isCurrent) return
        val duration = position.value?.duration ?: video.durationS ?: return
        val next = FeedPlaybackPosition.of(duration, seconds) ?: return
        position.value = next
        if (!tracking) { watch.resetSample(); player.seekTo((next.seekSeconds * 1000).toLong()) }
    }

    private fun wantsPlayback() = isCurrent && allowed && !paused.value && !failed.value && !tracking

    private fun sync() {
        if (isReleased) return
        val play = wantsPlayback()
        if (play) pool?.select(video.id)
        player.volume = if (muted || !play) 0f else 1f
        player.playWhenReady = play && (pool == null || pool.selected.value == video.id)
    }

    private fun startPolling() {
        poll?.cancel()
        poll = scope.launch {
            while (isActive) {
                sample()
                delay(200)
            }
        }
    }

    private fun sample() {
        if (!isCurrent || tracking || isReleased) return
        val measured = player.duration
        val duration = if (measured != C.TIME_UNSET && measured > 0) measured / 1000.0 else video.durationS ?: 0.0
        val next = FeedPlaybackPosition.of(duration, player.currentPosition / 1000.0)
        if (next != null && position.value != next) position.value = next
        if (countsViews && next != null && wantsPlayback() && watch.sample(next, playing = player.isPlaying)) {
            val id = video.id
            val receipt = ClipViewReceipt.forVideo(id)
            val report = onViewCount
            scope.launch {
                val total = runCatching { service?.recordView(id, receipt) }.getOrNull() ?: return@launch
                report?.invoke(id, total)
                viewCount.value = maxOf(total, viewCount.value ?: 0)
            }
        }
    }

    private fun finished() {
        if (!isCurrent || !wantsPlayback()) return
        player.playWhenReady = false
        val advanced = pool?.isPaging != true && onEnded?.invoke() == true
        player.seekTo(0)
        position.value = position.value?.let { FeedPlaybackPosition.of(it.duration, 0.0) }
        if (!advanced) sync() // a single clip (or a refused advance) loops
    }

    fun release() {
        if (isReleased) return
        isReleased = true
        poll?.cancel()
        player.removeListener(listener)
        player.release()
    }

    companion object {
        /** A standalone clip for detail views (iOS `PerformanceDetail` owns its own controller). */
        @OptIn(UnstableApi::class)
        fun standalone(context: Context, http: OkHttpClient, video: Video, scope: CoroutineScope, service: FeedService?): FeedClip {
            val player = ExoPlayer.Builder(context)
                .setMediaSourceFactory(DefaultMediaSourceFactory(OkHttpDataSource.Factory(http)))
                .setAudioAttributes(AudioAttributes.Builder().setUsage(C.USAGE_MEDIA).setContentType(C.AUDIO_CONTENT_TYPE_MOVIE).build(), false)
                .build()
            player.volume = 0f
            player.setMediaItem(MediaItem.fromUri(video.videoUrl))
            player.prepare()
            return FeedClip(video, player, null, scope, service)
        }
    }
}
