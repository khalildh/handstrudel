package com.handstrudel.ui.studio

import com.handstrudel.engine.PlayInput
import com.handstrudel.engine.StudioMode
import com.handstrudel.ui.studio.common.WheelGeometry
import com.handstrudel.ui.studio.common.WheelGeometry.ChordSubzone
import com.handstrudel.ui.studio.common.WheelGeometry.Zone
import com.handstrudel.ui.studio.stage.FilterSwipe
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class StageAccessibilityLogicTest {

    // ---- Split / Scale wheel accessibility elements (iOS SplitTouchUIView) ----

    private val chords = listOf("C", "Dm", "Em", "F", "G", "Am", "Bdim")
    private val notes = listOf("C4", "D4", "E4", "F4", "G4", "A4", "B4")

    @Test fun wedgesHaveIosLabelsAndIds() {
        val w = WheelGeometry.splitAccessibleWedges(1000f, 2000f, chords, notes, false, 55f, 110f)
        assertEquals(14, w.size)
        assertEquals("wheel-chord-0", w[0].id)
        assertEquals("Chord C", w[0].label)
        assertEquals(Zone.Chord(ChordSubzone(0, 0)), w[0].zone)
        assertEquals("wheel-note-6", w[13].id)
        assertEquals("Note B4", w[13].label)
        assertEquals(Zone.Melody(6), w[13].zone)
    }

    @Test fun wedgeCentresResolveToTheirOwnZone() {
        for (swap in listOf(false, true)) {
            val w = WheelGeometry.splitAccessibleWedges(1000f, 2000f, chords, notes, swap, 55f, 110f)
            for (e in w) {
                val zone = WheelGeometry.splitZoneForPoint(e.x, e.y, 1000f, 2000f, chords.size, notes.size, swap)
                assertEquals("${e.id} swap=$swap", e.zone, zone)
            }
        }
    }

    @Test fun wedgesSitOnTheBaseBandAndChordsOnTheChordSide() {
        val w = WheelGeometry.splitAccessibleWedges(1000f, 2000f, chords, notes, false, 55f, 110f)
        val outerR = WheelGeometry.splitOuterRadius(1000f, 2000f)
        for (e in w) {
            val r = Math.hypot((e.x - 500f).toDouble(), (e.y - 1000f).toDouble())
            assertEquals(outerR * 0.58, r, 0.5)
        }
        // Chords on the left without swap, melody on the right; lane 0 (lowest) at the bottom.
        assertTrue(w.take(7).all { it.x < 500f })
        assertTrue(w.drop(7).all { it.x > 500f })
        assertTrue(w[7].y > w[13].y)
    }

    @Test fun wedgeHitSizeIsClamped() {
        // π·290/7 ≈ 130 px → clamped to the 110 px max; with many lanes → the 55 px min.
        val few = WheelGeometry.splitAccessibleWedges(1000f, 2000f, chords, notes, false, 55f, 110f)
        assertEquals(110f, few[0].size, 0.01f)
        val many = WheelGeometry.splitAccessibleWedges(1000f, 2000f, chords, List(30) { "C4" }, false, 55f, 110f)
        assertEquals(55f, many.last().size, 0.01f)
        assertTrue(WheelGeometry.splitAccessibleWedges(0f, 0f, chords, notes, false, 55f, 110f).isEmpty())
    }

    // ---- Swipe to change filter (iOS chrome DragGesture) ----

    @Test fun filterSwipeModes() {
        assertTrue(FilterSwipe.isEnabled(StudioMode.SCALE, PlayInput.AIR, mixerOpen = false))
        assertTrue(FilterSwipe.isEnabled(StudioMode.SPLIT, PlayInput.AIR, mixerOpen = false))
        assertTrue(FilterSwipe.isEnabled(StudioMode.LEARN, PlayInput.AIR, mixerOpen = false))
        assertTrue(FilterSwipe.isEnabled(StudioMode.MELODIC, PlayInput.AIR, mixerOpen = false))
        assertFalse(FilterSwipe.isEnabled(StudioMode.GRID, PlayInput.AIR, mixerOpen = false))
        assertFalse(FilterSwipe.isEnabled(StudioMode.DRUM, PlayInput.AIR, mixerOpen = false))
        assertFalse(FilterSwipe.isEnabled(StudioMode.SCALE, PlayInput.TOUCH, mixerOpen = false))
        assertFalse(FilterSwipe.isEnabled(StudioMode.SCALE, PlayInput.AIR, mixerOpen = true))
    }

    @Test fun filterSwipeNeedsMostlyHorizontalTravel() {
        assertTrue(FilterSwipe.isSwipe(-60f, 10f, 50f))
        assertTrue(FilterSwipe.isSwipe(50f, 0f, 50f))
        assertFalse(FilterSwipe.isSwipe(49f, 0f, 50f))
        assertFalse(FilterSwipe.isSwipe(60f, 80f, 50f))
    }

    @Test fun filterSwipeCyclesAndWraps() {
        val ids = listOf("none", "warm", "cool")
        assertEquals("warm", FilterSwipe.next(ids, "none", swipeLeft = true))
        assertEquals("none", FilterSwipe.next(ids, "cool", swipeLeft = true))
        assertEquals("cool", FilterSwipe.next(ids, "none", swipeLeft = false))
        assertNull(FilterSwipe.next(ids, "acid", swipeLeft = true))
    }
}
