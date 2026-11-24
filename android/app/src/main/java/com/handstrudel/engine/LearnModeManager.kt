package com.handstrudel.engine

import com.handstrudel.models.LearnNote
import com.handstrudel.models.LearnSong
import java.util.UUID
import kotlin.math.abs
import kotlin.math.ceil

/** iOS `LearnLaneLayout`: camera pinch Y → lane, corrected for aspect-fill. */
object LearnLaneLayout {
    const val TOP = 0.15
    const val BOTTOM = 0.20

    fun cameraLane(y: Double, noteCount: Int, videoAspect: Double, viewportAspect: Double): Int? {
        if (!y.isFinite() || noteCount <= 0 || !videoAspect.isFinite() || videoAspect <= 0 ||
            !viewportAspect.isFinite() || viewportAspect <= 0
        ) return null
        val visible = minOf(1.0, videoAspect / viewportAspect)
        val screenY = (y - (1 - visible) / 2) / visible
        if (screenY < TOP || screenY > 1 - BOTTOM) return null
        val row = minOf(noteCount - 1, ((screenY - TOP) / (1 - TOP - BOTTOM) * noteCount).toInt())
        return noteCount - 1 - row
    }
}

/** Port of iOS `Engine/LearnModeManager.swift` (Guitar Hero-style scoring). */
class LearnModeManager {
    var currentSong: LearnSong? = null
        private set
    private var resolvedNotes: List<LearnNote> = emptyList()
    private var songStartTime = 0.0
    private var songBPM = 120.0
    var songComplete = false
        private set

    val scrollLeadBeats = 4.0
    val hitLineX = 0.25
    val countdownBeats = 4.0

    var countdownValue = 0
        private set
    var isCountingDown = false
        private set

    val hitWindowPerfect = 0.100
    val hitWindowGood = 0.200

    private val consumedNoteIds = mutableSetOf<UUID>()
    private var firstTick = true
    private var pausedAt: Double? = null

    var score = LearnScore()
        private set
    var visibleNotes: List<LearnVisibleNote> = emptyList()
        private set
    var hitEffects: List<LearnHitEffect> = emptyList()
        private set
    private val consumedStates = mutableMapOf<UUID, LearnNoteState>()

    /** A note the player just hit (so the caller can sound it). */
    data class Hit(val midi: Int, val laneIndex: Int)

    fun loadSong(song: LearnSong, scaleNotes: List<Int>, bpm: Double) {
        currentSong = song
        resolvedNotes = if (scaleNotes.isEmpty()) emptyList() else song.resolve(scaleNotes)
        songBPM = if (bpm.isFinite()) bpm.coerceIn(20.0, 400.0) else 120.0
        songStartTime = 0.0
        firstTick = true
        pausedAt = null
        songComplete = false
        isCountingDown = true
        countdownValue = 3
        consumedNoteIds.clear()
        consumedStates.clear()
        score = LearnScore()
        visibleNotes = emptyList()
        hitEffects = emptyList()
    }

    fun tick(elapsed: Double, leftLane: Int?, rightLane: Int?, leftPinching: Boolean, rightPinching: Boolean): List<Hit> {
        if (currentSong == null || resolvedNotes.isEmpty() || pausedAt != null) return emptyList()
        if (firstTick) {
            songStartTime = elapsed + countdownBeats * (60.0 / songBPM)
            firstTick = false
        }
        val secondsPerBeat = 60.0 / songBPM
        val currentBeat = (elapsed - songStartTime) / secondsPerBeat

        if (currentBeat < 0) {
            countdownValue = ceil(-currentBeat).toInt().coerceIn(0, 3)
            isCountingDown = true
        } else if (isCountingDown) {
            isCountingDown = false
            countdownValue = 0
        }

        val visibleStart = currentBeat - 1
        val visibleEnd = currentBeat + scrollLeadBeats
        visibleNotes = resolvedNotes.mapNotNull { note ->
            val end = note.startBeat + note.durationBeats
            if (end < visibleStart || note.startBeat > visibleEnd) return@mapNotNull null
            val x = hitLineX + (note.startBeat - currentBeat) / scrollLeadBeats * (1.0 - hitLineX)
            val w = maxOf(0.03, note.durationBeats / scrollLeadBeats * (1.0 - hitLineX))
            val state = consumedStates[note.id] ?: if (x <= hitLineX) LearnNoteState.ACTIVE else LearnNoteState.UPCOMING
            LearnVisibleNote(note.id, note.laneIndex, x, w, state)
        }

        val justHit = mutableListOf<Hit>()
        val effects = hitEffects.toMutableList()
        for (note in resolvedNotes) {
            if (note.id in consumedNoteIds) continue
            val noteTime = songStartTime + note.startBeat * secondsPerBeat
            val delta = abs(elapsed - noteTime)
            if (delta <= hitWindowGood) {
                val leftMatch = leftPinching && leftLane == note.laneIndex
                val rightMatch = rightPinching && rightLane == note.laneIndex
                if (leftMatch || rightMatch) {
                    recordHit(note, delta, elapsed, effects)
                    justHit += Hit(note.midi, note.laneIndex)
                }
            }
            if (note.id !in consumedNoteIds && elapsed > noteTime + hitWindowGood) {
                consumedNoteIds += note.id
                consumedStates[note.id] = LearnNoteState.MISSED
                score = score.copy(misses = score.misses + 1, currentStreak = 0)
                effects += LearnHitEffect(UUID.randomUUID(), note.laneIndex, LearnNoteState.MISSED, elapsed)
            }
        }
        hitEffects = effects.filter { elapsed - it.timestamp <= 0.5 }
        if (consumedNoteIds.size >= resolvedNotes.size) songComplete = true
        return justHit
    }

    /** One tap resolves one note (the closest unconsumed one in the lane, within the good window). */
    fun tapLane(lane: Int, elapsed: Double): Int? {
        if (firstTick || songComplete || pausedAt != null) return null
        fun distance(n: LearnNote) = abs(elapsed - songStartTime - n.startBeat * (60 / songBPM))
        val note = resolvedNotes.filter { it.laneIndex == lane && it.id !in consumedNoteIds }
            .minByOrNull(::distance) ?: return null
        if (distance(note) > hitWindowGood) return null
        val effects = hitEffects.toMutableList()
        recordHit(note, distance(note), elapsed, effects)
        hitEffects = effects
        songComplete = consumedNoteIds.size == resolvedNotes.size
        return note.midi
    }

    private fun recordHit(note: LearnNote, delta: Double, elapsed: Double, effects: MutableList<LearnHitEffect>) {
        val perfect = delta <= hitWindowPerfect
        val state = if (perfect) LearnNoteState.HIT_PERFECT else LearnNoteState.HIT_GOOD
        consumedNoteIds += note.id
        consumedStates[note.id] = state
        val streak = score.currentStreak + 1
        score = score.copy(
            perfectHits = score.perfectHits + if (perfect) 1 else 0,
            goodHits = score.goodHits + if (perfect) 0 else 1,
            currentStreak = streak,
            bestStreak = maxOf(score.bestStreak, streak),
        )
        effects += LearnHitEffect(UUID.randomUUID(), note.laneIndex, state, elapsed)
    }

    fun setPaused(paused: Boolean, elapsed: Double) {
        if (paused) {
            if (pausedAt == null) pausedAt = elapsed
        } else {
            val at = pausedAt ?: return
            if (!firstTick) songStartTime += maxOf(0.0, elapsed - at)
            pausedAt = null
        }
    }

    fun reset() {
        currentSong = null
        resolvedNotes = emptyList()
        songStartTime = 0.0
        songBPM = 120.0
        firstTick = true
        pausedAt = null
        isCountingDown = false
        countdownValue = 0
        songComplete = false
        consumedNoteIds.clear()
        consumedStates.clear()
        score = LearnScore()
        visibleNotes = emptyList()
        hitEffects = emptyList()
    }

    /** Test hook: resolved notes (iOS tests read them through the visible list). */
    internal val notes: List<LearnNote> get() = resolvedNotes
}
