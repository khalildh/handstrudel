package com.handstrudel.engine

import com.handstrudel.models.SoundSetupMode
import java.io.File
import java.util.UUID

// Value types used by the StudioEngine seam. Owner: engine.

/** iOS `StudioPlayInput`. `raw` is the `studioPlayInput` pref value. */
enum class PlayInput(val raw: String, val label: String) {
    AIR("air", "Air + touch"),
    TOUCH("touch", "Touch only");

    companion object {
        fun fromRaw(raw: String?): PlayInput = entries.firstOrNull { it.raw == raw } ?: AIR
    }
}

/** iOS `HandTrackingManager.CameraIssue`, with its user-facing messages. */
enum class CameraIssue(val message: String) {
    PERMISSION_DENIED("Camera access is off. You can still play by touch."),
    RESTRICTED("Camera use is restricted. You can still play by touch."),
    UNAVAILABLE("Camera unavailable. You can still play by touch."),
    INTERRUPTED("Camera in use. You can still play by touch."),
}

/** The 11 `SoundSetup.Mode` values plus Learn. `raw` is iOS `currentModeString`. */
enum class StudioMode(val raw: String, val setupMode: SoundSetupMode?) {
    MELODIC("melodic", SoundSetupMode.MELODIC),
    FLOW("flow", SoundSetupMode.FLOW),
    HYBRID("hybrid", SoundSetupMode.HYBRID),
    LEAD("lead", SoundSetupMode.LEAD),
    GRID("grid", SoundSetupMode.GRID),
    DRUM("drum", SoundSetupMode.DRUM),
    CHORD_MELODY("chordmelody", SoundSetupMode.CHORD_MELODY),
    RADIAL("radialchordmelody", SoundSetupMode.RADIAL_CHORD_MELODY),
    SPLIT("splitchordmelody", SoundSetupMode.SPLIT_CHORD_MELODY),
    SCALE("scalechordmelody", SoundSetupMode.SCALE_CHORD_MELODY),
    SOUNDFONT("soundfont", SoundSetupMode.SOUNDFONT),
    LEARN("learn", null);

    /** Split, Scale, Radial, Chord+Melody and SoundFont: the native chord+melody family. */
    val isChordMelodyFamily: Boolean
        get() = this == CHORD_MELODY || this == RADIAL || this == SPLIT || this == SCALE || this == SOUNDFONT

    /** Melodic, Flow, Hybrid, Lead: the Strudel pattern family (Weave visual). */
    val isMelodicFamily: Boolean get() = this == MELODIC || this == FLOW || this == HYBRID || this == LEAD

    companion object {
        fun fromRaw(raw: String?): StudioMode? = entries.firstOrNull { it.raw == raw }
        fun from(mode: SoundSetupMode): StudioMode = entries.first { it.setupMode == mode }
    }
}

/** One of the two drum-loop tracks (iOS `selectedDrumLoop`/`drumVolume`/`drumBPM`, and the `2` variants). */
data class DrumTrackState(
    val loopId: String,
    val volume: Double = 1.0,
    val bpm: Double = 120.0,
)

/** Chord+melody display state for the Split / Scale / Radial / Zones overlays. */
data class ChordMelodyDisplay(
    val currentDegree: Int? = null,
    val currentChordName: String = "",
    val chordHandLane: Int? = null,
    val chordZoneIndex: Int? = null,
    val melodyLane: Int? = null,
    val octaveShift: Int = 0,
    val zoneDegrees: List<Int> = emptyList(),
    val isChordHandPinching: Boolean = false,
    val isMelodyHandPinching: Boolean = false,
    val chordResting: Boolean = false,
    val melodyResting: Boolean = false,
    val touchedChordZones: Set<ChordSubzone> = emptySet(),
    val touchedMelodyLanes: Set<Int> = emptySet(),
)

/** Grid and drum lane display state. */
data class LaneDisplay(
    val gridLeftLane: Int? = null,
    val gridRightLane: Int? = null,
    val gridLeftPinching: Boolean = false,
    val gridRightPinching: Boolean = false,
    val lastGridNote: String = "",
    val drumLeftLane: Int? = null,
    val drumRightLane: Int? = null,
    val drumLeftPinching: Boolean = false,
    val drumRightPinching: Boolean = false,
    val lastDrumHit: String = "",
)

/** iOS `LearnScore`. */
data class LearnScore(
    val perfectHits: Int = 0,
    val goodHits: Int = 0,
    val misses: Int = 0,
    val currentStreak: Int = 0,
    val bestStreak: Int = 0,
) {
    val totalNotes: Int get() = perfectHits + goodHits + misses
    val accuracy: Double get() = if (totalNotes == 0) 0.0 else (perfectHits + goodHits).toDouble() / totalNotes
}

/** iOS `LearnModeManager.NoteState`. */
enum class LearnNoteState { UPCOMING, ACTIVE, HIT_PERFECT, HIT_GOOD, MISSED }

/** iOS `LearnModeManager.VisibleNote`. */
data class LearnVisibleNote(
    val id: UUID,
    val laneIndex: Int,
    val xFraction: Double,
    val widthFraction: Double,
    val state: LearnNoteState,
)

/** iOS `LearnModeManager.HitEffect`. */
data class LearnHitEffect(
    val id: UUID,
    val laneIndex: Int,
    val type: LearnNoteState,
    val timestamp: Double,
)

/** Learn overlay state. The song catalog type lives in `models/LearnSongs.kt` (engine); referenced by id here. */
data class LearnDisplay(
    val currentSongId: String? = null,
    val currentSongName: String? = null,
    val score: LearnScore = LearnScore(),
    val visibleNotes: List<LearnVisibleNote> = emptyList(),
    val hitEffects: List<LearnHitEffect> = emptyList(),
    val songComplete: Boolean = false,
)

/** iOS `RecordedLoop` (captured-audio loops only; event loops are unreachable in 1.0.1). */
data class SavedLoop(
    val id: UUID,
    val name: String,
    val durationSeconds: Double,
    val bpm: Double,
    val mode: String,
    val createdAtMillis: Long,
    val hasCapturedAudio: Boolean = true,
    val gain: Double = 1.0,
    val muted: Boolean = false,
    /** Audio file in the engine's loop store. */
    val file: File? = null,
) {
    val effectiveGain: Double get() = if (muted) 0.0 else gain.coerceIn(0.0, 1.0)
}

/**
 * Optional PCM tap of the engine's native mix (SoundFont/AudioTrack path), so
 * capture can record loops without a MediaProjection prompt. Owner: engine.
 */
interface AppAudioTap {
    val sampleRate: Int
    val channelCount: Int

    /** Starts delivering interleaved 16-bit frames to [sink] until the returned handle is closed. */
    fun open(sink: (pcm: ShortArray, frames: Int) -> Unit): AutoCloseable
}
