package com.handstrudel.app

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.UUID

/** Ports iOS `CreatorReviewMilestones` behaviour (ContentView.swift). */
class CreatorReviewMilestonesTest {
    private val day = 24L * 60 * 60 * 1000
    private val now = 1_800_000_000_000L

    private fun takes(n: Int, start: CreatorReviewMilestones = CreatorReviewMilestones()) =
        (1..n).fold(start) { m, _ -> m.record(UUID.randomUUID())!! }

    @Test fun duplicateTakesAreIgnored() {
        val id = UUID.randomUUID()
        val once = CreatorReviewMilestones().record(id)
        assertNotNull(once)
        assertEquals(1, once!!.newTakes)
        assertNull(once.record(id))
    }

    @Test fun needsThreeNewTakes() {
        assertFalse(takes(2).canRequest("1.0.1", now))
        assertTrue(takes(3).canRequest("1.0.1", now))
        assertEquals(3, takes(7).newTakes) // capped like iOS min(newTakes + 1, 3)
    }

    @Test fun oncePerVersion() {
        val asked = takes(3).requested("1.0.1", now)
        assertEquals(0, asked.newTakes)
        val again = takes(3, asked)
        assertFalse(again.canRequest("1.0.1", now + 365 * day))
        assertTrue(again.canRequest("1.0.2", now + 365 * day))
    }

    @Test fun ninetyDayGate() {
        val again = takes(3, takes(3).requested("1.0.1", now))
        assertFalse(again.canRequest("1.0.2", now + 89 * day))
        assertTrue(again.canRequest("1.0.2", now + 90 * day))
    }

    @Test fun remembersAtMostHundredTakes() {
        val first = UUID.randomUUID()
        val m = takes(100, CreatorReviewMilestones().record(first)!!)
        assertEquals(100, m.completedTakes.size)
        assertNotNull(m.record(first)) // evicted, so it counts again
    }

    @Test fun encodingRoundTripsAndToleratesGarbage() {
        val m = takes(2).requested("1.0.0", now)
        assertEquals(m, CreatorReviewMilestones.decode(m.encode()))
        assertEquals(CreatorReviewMilestones(), CreatorReviewMilestones.decode("not json"))
        assertEquals(CreatorReviewMilestones(), CreatorReviewMilestones.decode(null))
    }

    @Test fun playReviewPromptConsumesOnceWhenDue() {
        val prefs = StoreBackedAppPrefs(InMemoryPrefsStore())
        var clock = now
        val prompt = PlayReviewPrompt(prefs, "1.0.1", nowMillis = { clock })
        val id = UUID.randomUUID()
        prompt.recordSuccessfulTake(id)
        prompt.recordSuccessfulTake(id)
        assertTrue(prompt.readyThisSession.value)
        assertFalse(prompt.consumeIfDue()) // only one distinct take
        prompt.recordSuccessfulTake(UUID.randomUUID())
        prompt.recordSuccessfulTake(UUID.randomUUID())
        assertTrue(prompt.consumeIfDue())
        assertFalse(prompt.readyThisSession.value)
        repeat(3) { prompt.recordSuccessfulTake(UUID.randomUUID()) }
        clock += 200 * day
        assertFalse(prompt.consumeIfDue()) // same version
        // Persisted across instances.
        assertFalse(PlayReviewPrompt(prefs, "1.0.1", nowMillis = { clock }).consumeIfDue())
        assertTrue(PlayReviewPrompt(prefs, "1.0.2", nowMillis = { clock }).consumeIfDue())
    }

    @Test fun disabledPromptRecordsNothing() {
        val prefs = StoreBackedAppPrefs(InMemoryPrefsStore())
        val prompt = PlayReviewPrompt(prefs, "1.0.1", enabled = false)
        repeat(3) { prompt.recordSuccessfulTake(UUID.randomUUID()) }
        assertFalse(prompt.readyThisSession.value)
        assertNull(prefs.creatorReviewMilestones.value)
    }
}
