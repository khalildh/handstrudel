package com.handstrudel.engine

import com.handstrudel.models.LearnDegreeNote
import com.handstrudel.models.LearnSong
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** Port of iOS LearnModeManagerTests (core cases). 120 BPM: a beat is 0.5 s; first note at 2.0 s. */
class LearnModeManagerTest {
    private val cMajor = listOf(60, 62, 64, 65, 67, 69, 71)
    private val songStart = 2.0
    private fun song() = LearnSong("t", "Test", "T", 120.0, listOf(
        LearnDegreeNote(0, 0.0, 1.0), LearnDegreeNote(2, 1.0, 1.0), LearnDegreeNote(4, 2.0, 1.0),
    ))
    private fun loaded() = LearnModeManager().apply {
        loadSong(song(), cMajor, 120.0)
        tick(0.0, null, null, false, false)
    }

    @Test fun cameraLaneMatchesDisplayedRowAfterAspectFill() {
        for ((video, screen) in listOf(0.75 to 0.46, 0.46 to 0.75)) {
            val visible = minOf(1.0, video / screen)
            for (row in 0 until 7) {
                val yInView = LearnLaneLayout.TOP + (row + 0.5) * (1 - LearnLaneLayout.TOP - LearnLaneLayout.BOTTOM) / 7
                val cameraY = (1 - visible) / 2 + yInView * visible
                assertEquals(6 - row, LearnLaneLayout.cameraLane(cameraY, 7, video, screen))
            }
            assertNull(LearnLaneLayout.cameraLane(0.0, 7, video, screen))
        }
    }

    @Test fun touchTapScoresOnceAndUsesNearestWindow() {
        val m = loaded()
        assertNull(m.tapLane(1, songStart))
        assertEquals(60, m.tapLane(0, songStart + 0.01))
        assertNull(m.tapLane(0, songStart + 0.02))
        assertEquals(64, m.tapLane(2, songStart + 0.5 + 0.15))
        assertEquals(1, m.score.perfectHits)
        assertEquals(1, m.score.goodHits)
        assertEquals(0, m.score.misses)
    }

    @Test fun pausingDoesNotBurnCountdownOrMarkMisses() {
        val m = loaded()
        m.setPaused(true, 1.0)
        m.setPaused(true, 4.0)
        assertTrue(m.tick(6.0, 0, null, true, false).isEmpty())
        assertNull(m.tapLane(0, 6.0))
        m.setPaused(false, 6.0)
        assertEquals(0, m.score.misses)
        // 5 s paused: the first note moves to 7.0 s.
        assertEquals(listOf(LearnModeManager.Hit(60, 0)), m.tick(7.0, 0, null, true, false))
    }

    @Test fun loadSong_resetsAndCountsDown() {
        val m = LearnModeManager()
        m.loadSong(song(), cMajor, 120.0)
        assertEquals(3, m.countdownValue)
        assertTrue(m.isCountingDown)
        m.tick(0.0, null, null, false, false)
        assertEquals(3, m.countdownValue)
        m.tick(1.0, null, null, false, false)
        assertEquals(2, m.countdownValue)
        m.tick(1.6, null, null, false, false)
        assertEquals(1, m.countdownValue)
        m.tick(2.0, null, null, false, false)
        assertFalse(m.isCountingDown)
        assertEquals(0, m.countdownValue)
    }

    @Test fun hitWindowsAndStreaks() {
        val m = loaded()
        assertEquals(1, m.tick(songStart + 0.09, 0, null, true, false).size)         // perfect (90 ms)
        assertEquals(1, m.tick(songStart + 0.5 + 0.19, null, 2, false, true).size)   // good (190 ms)
        m.tick(songStart + 1.0 + 0.25, null, null, false, false)                     // third note missed
        assertEquals(1, m.score.perfectHits)
        assertEquals(1, m.score.goodHits)
        assertEquals(1, m.score.misses)
        assertEquals(0, m.score.currentStreak)
        assertEquals(2, m.score.bestStreak)
        assertTrue(m.songComplete)
    }

    @Test fun wrongLaneNeverHitsAndConsumedNotesCantRehit() {
        val m = loaded()
        assertTrue(m.tick(songStart, 3, null, true, false).isEmpty())
        assertEquals(1, m.tick(songStart + 0.05, 0, null, true, false).size)
        assertTrue(m.tick(songStart + 0.06, 0, null, true, false).isEmpty())
    }

    @Test fun visibleNotesAndEffects() {
        val m = loaded()
        m.tick(songStart, null, null, false, false)
        val first = m.visibleNotes.first { it.laneIndex == 0 }
        assertEquals(m.hitLineX, first.xFraction, 1e-9)
        assertEquals(LearnNoteState.ACTIVE, first.state)
        assertTrue(m.visibleNotes.first { it.laneIndex == 2 }.xFraction > m.hitLineX)
        m.tick(songStart + 0.05, 0, null, true, false)
        assertEquals(LearnNoteState.HIT_PERFECT, m.hitEffects.last().type)
        m.tick(songStart + 0.75, null, null, false, false) // note 2 missed (2.75 > 2.5 + 0.2)
        assertTrue(m.hitEffects.any { it.type == LearnNoteState.MISSED })
        m.tick(songStart + 2.0, null, null, false, false)
        assertTrue(m.hitEffects.none { it.type == LearnNoteState.HIT_PERFECT }) // expired after 0.5 s
    }

    @Test fun resetAndEmptySong() {
        val m = loaded()
        m.reset()
        assertTrue(m.tick(10.0, 0, 0, true, true).isEmpty())
        assertNull(m.currentSong)
        val empty = LearnModeManager().apply { loadSong(song(), emptyList(), 120.0) }
        assertTrue(empty.tick(0.0, 0, 0, true, true).isEmpty())
    }
}
