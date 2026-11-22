package com.handstrudel.engine.loops

import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.PlaybackParams
import android.util.Log
import com.handstrudel.engine.SavedLoop
import com.handstrudel.engine.StudioEngine
import com.handstrudel.engine.persistence.EnginePersistence
import com.handstrudel.engine.persistence.cleanLoopName
import com.handstrudel.engine.persistence.clampedLoopGain
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import java.io.File
import java.util.UUID

/**
 * Captured-audio loops (iOS `RecordedLoop` with `hasCapturedAudio`, played by
 * `AVAudioPlayer`s in `EngineController`). Files live in [dir]; metadata in the
 * engine persistence. Layered playback: one looping [MediaPlayer] per loop.
 * Main thread.
 */
class AudioLoopStore(private val dir: File, private val persistence: EnginePersistence) {
    // Loop audio is kept out of cloud backup (res/xml/data_extraction_rules.xml), so after a
    // restore the metadata can outlive its file. Drop those rows instead of showing dead loops.
    private val _loops = MutableStateFlow(persistence.loadLoops(dir).filter { !it.hasCapturedAudio || it.file?.isFile == true })
    val loops: StateFlow<List<SavedLoop>> = _loops
    private val _playing = MutableStateFlow<Set<UUID>>(emptySet())
    val playing: StateFlow<Set<UUID>> = _playing
    private val players = mutableMapOf<UUID, MediaPlayer>()
    private var rate = 1.0f

    /** Moves [file] in and registers the loop ("Loop N"). Null when 20 loops exist or the move fails. */
    fun add(file: File, durationSeconds: Double, bpm: Double, mode: String): SavedLoop? {
        if (_loops.value.size >= StudioEngine.MAX_LOOPS) return null
        dir.mkdirs()
        val id = UUID.randomUUID()
        val ext = file.extension.ifEmpty { "m4a" }
        val dest = File(dir, "$id.$ext")
        val moved = file.renameTo(dest) || runCatching { file.copyTo(dest, overwrite = true); file.delete(); true }.getOrDefault(false)
        if (!moved) return null
        val loop = SavedLoop(
            id = id, name = "Loop ${_loops.value.size + 1}", durationSeconds = durationSeconds, bpm = bpm, mode = mode,
            createdAtMillis = System.currentTimeMillis(), hasCapturedAudio = true, file = dest,
        )
        _loops.value = _loops.value + loop
        persist()
        return loop
    }

    /**
     * Start or stop a loop. [prepareOnly] (iOS: the studio is paused) prepares
     * the player without starting it; [resumeAll] starts it later.
     */
    fun toggle(id: UUID, prepareOnly: Boolean): Boolean {
        if (id in _playing.value) {
            players.remove(id)?.release()
            _playing.value = _playing.value - id
            return true
        }
        val loop = _loops.value.firstOrNull { it.id == id } ?: return false
        val file = loop.file?.takeIf { it.isFile } ?: return false
        val player = try {
            MediaPlayer().apply {
                setAudioAttributes(
                    AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC).build(),
                )
                setDataSource(file.absolutePath)
                isLooping = true
                prepare()
                val g = loop.effectiveGain.toFloat()
                setVolume(g, g)
                if (rate != 1f) applyRate(this)
            }
        } catch (e: Exception) {
            Log.w(TAG, "loop ${loop.id} couldn't play", e)
            return false
        }
        if (!prepareOnly) player.start()
        players[id] = player
        _playing.value = _playing.value + id
        return true
    }

    fun rename(id: UUID, proposed: String): Boolean {
        val name = cleanLoopName(proposed)
        if (name.isEmpty() || _loops.value.none { it.id == id }) return false
        update(id) { it.copy(name = name) }
        persist()
        return true
    }

    /** iOS `setLoopGain`: live volume; persisted by the caller when the slider ends (here: immediately). */
    fun setGain(id: UUID, gain: Double) {
        update(id) { it.copy(gain = clampedLoopGain(gain)) }
        applyVolume(id)
        persist()
    }

    fun toggleMute(id: UUID) {
        update(id) { it.copy(muted = !it.muted) }
        applyVolume(id)
        persist()
    }

    fun delete(id: UUID) {
        players.remove(id)?.release()
        _playing.value = _playing.value - id
        _loops.value.firstOrNull { it.id == id }?.file?.delete()
        _loops.value = _loops.value.filterNot { it.id == id }
        persist()
    }

    fun stopAll() {
        players.values.forEach { it.release() }
        players.clear()
        _playing.value = emptySet()
    }

    fun pauseAll() = players.values.forEach { runCatching { if (it.isPlaying) it.pause() } }

    fun resumeAll() = players.values.forEach { runCatching { it.start() } }

    /** Half-speed recording: loops follow the engine tempo (pitch preserved, like AVAudioPlayer.rate). */
    fun setRate(scale: Double) {
        rate = scale.toFloat()
        players.values.forEach { applyRate(it) }
    }

    /** True when every playing loop is an audio loop (iOS `supportsHalfSpeedRecording`). */
    val allPlayingAreAudio: Boolean get() = _playing.value.all { it in players }

    private fun applyRate(p: MediaPlayer) {
        runCatching {
            val wasPlaying = p.isPlaying
            p.playbackParams = PlaybackParams().setSpeed(rate).setPitch(1f)
            if (!wasPlaying) p.pause()
        }
    }

    private fun applyVolume(id: UUID) {
        val g = _loops.value.firstOrNull { it.id == id }?.effectiveGain?.toFloat() ?: return
        players[id]?.setVolume(g, g)
    }

    private fun update(id: UUID, change: (SavedLoop) -> SavedLoop) {
        _loops.value = _loops.value.map { if (it.id == id) change(it) else it }
    }

    fun persist() = persistence.saveLoops(_loops.value)

    private companion object { const val TAG = "AudioLoopStore" }
}
