package com.handstrudel.ui.studio

import com.handstrudel.models.MusicKey
import com.handstrudel.ui.studio.common.WheelGeometry
import com.handstrudel.ui.studio.overlays.DrumGeometry
import com.handstrudel.ui.studio.overlays.DrumPadGeometry
import com.handstrudel.ui.studio.overlays.GridGeometry
import com.handstrudel.ui.studio.overlays.LearnGeometry
import com.handstrudel.ui.studio.overlays.RadialGeometry
import com.handstrudel.ui.studio.overlays.WeaveMath
import com.handstrudel.ui.studio.overlays.ZonesGeometry
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import kotlin.math.cos
import kotlin.math.sin

class OverlayGeometryTest {

    // ---- Radial ----------------------------------------------------------------

    private val w = 1000f
    private val h = 2000f
    private val outerR = WheelGeometry.radialOuterRadius(w, h) // 460

    /** Point at [angle]° clockwise from top and [fraction] of the wheel radius. */
    private fun radialPoint(angle: Double, fraction: Double): Pair<Float, Float> {
        val r = Math.toRadians(angle)
        return (w / 2 + (outerR * fraction * sin(r)).toFloat()) to (h / 2 - (outerR * fraction * cos(r)).toFloat())
    }

    @Test fun radialRestHoleIsNull() {
        val (x, y) = radialPoint(45.0, 0.1)
        assertNull(RadialGeometry.hitForPoint(x, y, w, h, 4, 9))
        val (cx, cy) = w / 2 to h / 2
        assertNull(RadialGeometry.hitForPoint(cx, cy, w, h, 4, 9))
    }

    @Test fun radialInnerRingIsMelodyWedge() {
        for (lane in 0 until 9) {
            val (x, y) = radialPoint(lane * 40.0, 0.42)
            assertEquals(RadialGeometry.Hit.Melody(lane), RadialGeometry.hitForPoint(x, y, w, h, 4, 9))
        }
    }

    @Test fun radialOuterRingIsChordWedgeCentredOnTop() {
        // 4 wedges: 0 = top, 1 = right, 2 = bottom, 3 = left.
        val cases = listOf(0.0 to 0, 30.0 to 0, 90.0 to 1, 180.0 to 2, 270.0 to 3, 330.0 to 0, 316.0 to 0, 314.0 to 3)
        for ((angle, zone) in cases) {
            val (x, y) = radialPoint(angle, 0.8)
            assertEquals("angle $angle", RadialGeometry.Hit.Chord(zone), RadialGeometry.hitForPoint(x, y, w, h, 4, 9))
        }
    }

    @Test fun radialRingBoundaries() {
        val (mx, my) = radialPoint(0.0, 0.59)
        assertEquals(RadialGeometry.Hit.Melody(0), RadialGeometry.hitForPoint(mx, my, w, h, 7, 9))
        val (cx, cy) = radialPoint(0.0, 0.61)
        assertEquals(RadialGeometry.Hit.Chord(0), RadialGeometry.hitForPoint(cx, cy, w, h, 7, 9))
        val (dx, dy) = radialPoint(0.0, 0.25)
        assertEquals(RadialGeometry.Hit.Melody(0), RadialGeometry.hitForPoint(dx, dy, w, h, 7, 9))
        // Beyond the rim clamps to the chord ring.
        val (ox, oy) = radialPoint(180.0, 1.5)
        assertEquals(RadialGeometry.Hit.Chord(2), RadialGeometry.hitForPoint(ox, oy, w, h, 4, 9))
    }

    @Test fun radialWedgeBoundsMatchHitTesting() {
        for (count in listOf(2, 3, 4, 5, 6, 7, 8)) {
            for (i in 0 until count) {
                val (start, end) = RadialGeometry.wedgeBounds(i, count)
                val mid = (start + end) / 2
                val (x, y) = radialPoint(mid, 0.8)
                assertEquals(RadialGeometry.Hit.Chord(i), RadialGeometry.hitForPoint(x, y, w, h, count, 9))
                assertEquals(360.0 / count, end - start, 1e-9)
            }
        }
    }

    @Test fun radialMelodyNamesAreTriadOverThreeOctaves() {
        // C major, degree 0 → C E G ×3.
        val major = listOf(0, 2, 4, 5, 7, 9, 11)
        assertEquals(listOf("C", "E", "G", "C", "E", "G", "C", "E", "G"), RadialGeometry.melodyNames(MusicKey.C, major, 0))
        assertEquals(listOf(57, 60, 64, 69, 72, 76, 81, 84, 88), RadialGeometry.melodyMidis(MusicKey.C, major, 5))
    }

    // ---- Chord+Melody zones ------------------------------------------------------

    @Test fun zonesChordHalfColumns() {
        // 4 zones on the left half (0…500) with a 6 px inset → 122 px columns.
        assertEquals(ZonesGeometry.Zone.Chord(0), ZonesGeometry.zoneForPoint(10f, 500f, 1000f, 2000f, 4, 9, false, 6f))
        assertEquals(ZonesGeometry.Zone.Chord(1), ZonesGeometry.zoneForPoint(200f, 100f, 1000f, 2000f, 4, 9, false, 6f))
        assertEquals(ZonesGeometry.Zone.Chord(3), ZonesGeometry.zoneForPoint(499f, 1900f, 1000f, 2000f, 4, 9, false, 6f))
        // Inside the inset clamps.
        assertEquals(ZonesGeometry.Zone.Chord(0), ZonesGeometry.zoneForPoint(1f, 500f, 1000f, 2000f, 4, 9, false, 6f))
    }

    @Test fun zonesMelodyLanesHighestOnTop() {
        // Lanes span 300…1700 (15 % inset), 9 rows; top row = lane 8.
        assertEquals(ZonesGeometry.Zone.Melody(8), ZonesGeometry.zoneForPoint(750f, 310f, 1000f, 2000f, 4, 9, false))
        assertEquals(ZonesGeometry.Zone.Melody(0), ZonesGeometry.zoneForPoint(750f, 1690f, 1000f, 2000f, 4, 9, false))
        assertEquals(ZonesGeometry.Zone.Melody(4), ZonesGeometry.zoneForPoint(750f, 1000f, 1000f, 2000f, 4, 9, false))
        // Above/below the lanes clamp.
        assertEquals(ZonesGeometry.Zone.Melody(8), ZonesGeometry.zoneForPoint(750f, 10f, 1000f, 2000f, 4, 9, false))
        assertEquals(ZonesGeometry.Zone.Melody(0), ZonesGeometry.zoneForPoint(750f, 1990f, 1000f, 2000f, 4, 9, false))
    }

    @Test fun zonesSwapHandsMirrorsHalves() {
        assertEquals(ZonesGeometry.Zone.Melody(4), ZonesGeometry.zoneForPoint(100f, 1000f, 1000f, 2000f, 4, 9, true))
        assertEquals(ZonesGeometry.Zone.Chord(0), ZonesGeometry.zoneForPoint(510f, 1000f, 1000f, 2000f, 4, 9, true, 6f))
        assertEquals(ZonesGeometry.Zone.Chord(3), ZonesGeometry.zoneForPoint(990f, 1000f, 1000f, 2000f, 4, 9, true, 6f))
        assertNull(ZonesGeometry.zoneForPoint(1f, 1f, 0f, 0f, 4, 9, false))
    }

    @Test fun zonesLabels() {
        assertEquals(listOf("I", "ii", "iii", "IV", "V", "vi", "vii°", "8"), (0..7).map(ZonesGeometry::romanNumeral))
        assertEquals(listOf("TONIC", "", "", "SUB", "DOM", "", ""), (0..6).map(ZonesGeometry::degreeLabel))
    }

    // ---- Grid ----------------------------------------------------------------

    @Test fun gridLaneForYClampsBetweenPads() {
        // h = 1000: lanes span 150…800, 10 lanes of 65 px.
        assertEquals(0, GridGeometry.laneForY(150f, 1000f, 10))
        assertEquals(0, GridGeometry.laneForY(10f, 1000f, 10))
        assertEquals(1, GridGeometry.laneForY(216f, 1000f, 10))
        assertEquals(9, GridGeometry.laneForY(799f, 1000f, 10))
        assertEquals(9, GridGeometry.laneForY(990f, 1000f, 10))
        assertNull(GridGeometry.laneForY(500f, 1000f, 0))
    }

    @Test fun gridCorrectedYAspectFill() {
        // Phone portrait (0.5) is narrower than the 0.75 video: video fills the height, y passes through.
        assertEquals(500f, GridGeometry.correctedY(0.5, 1000f, 2000f, 0.75f) / 2f, 1e-3f)
        assertEquals(200f, GridGeometry.correctedY(0.1, 1000f, 2000f, 0.75f), 1e-3f)
        // Tablet landscape (1.5) is wider: video fills the width, visible fraction 0.5 centred.
        assertEquals(0f, GridGeometry.correctedY(0.25, 1500f, 1000f, 0.75f), 1e-3f)
        assertEquals(500f, GridGeometry.correctedY(0.5, 1500f, 1000f, 0.75f), 1e-3f)
        assertEquals(1000f, GridGeometry.correctedY(0.75, 1500f, 1000f, 0.75f), 1e-3f)
    }

    @Test fun gridVisualLaneForPinch() {
        // Portrait: pinch at 0.5 of 1000 px → 500 − 150 = 350 / 65 = lane 5.
        assertEquals(5, GridGeometry.visualLaneForPinch(0.5, 500f, 1000f, 0.75f, 10))
        assertEquals(0, GridGeometry.visualLaneForPinch(0.0, 500f, 1000f, 0.75f, 10))
        assertEquals(9, GridGeometry.visualLaneForPinch(1.0, 500f, 1000f, 0.75f, 10))
        // Landscape crop: camera y 0.25 is the top edge of the screen → clamps to lane 0.
        assertEquals(0, GridGeometry.visualLaneForPinch(0.25, 1500f, 1000f, 0.75f, 10))
        // Camera y 0.5 → screen 500 → lane 5.
        assertEquals(5, GridGeometry.visualLaneForPinch(0.5, 1500f, 1000f, 0.75f, 10))
    }

    // ---- Drums -----------------------------------------------------------------

    @Test fun drumPadForPoint() {
        // h = 1000: lanes span 150…800, 6 lanes.
        assertNull(DrumGeometry.padForPoint(100f, 100f, 1000f, 1000f))
        assertNull(DrumGeometry.padForPoint(100f, 850f, 1000f, 1000f))
        assertEquals(DrumGeometry.Pad(0, left = true), DrumGeometry.padForPoint(100f, 160f, 1000f, 1000f))
        assertEquals(DrumGeometry.Pad(0, left = false), DrumGeometry.padForPoint(600f, 160f, 1000f, 1000f))
        assertEquals(DrumGeometry.Pad(5, left = false), DrumGeometry.padForPoint(900f, 799f, 1000f, 1000f))
        assertEquals(DrumGeometry.Pad(2, left = true), DrumGeometry.padForPoint(499f, 150f + 650f * 2.5f / 6f, 1000f, 1000f))
    }

    @Test fun drumXYPadAxes() {
        // x → complexity, y → intensity (top = 1).
        assertEquals(0.25 to 1.0, DrumPadGeometry.valuesForPoint(50f, 0f, 200f, 80f))
        assertEquals(1.0 to 0.0, DrumPadGeometry.valuesForPoint(400f, 120f, 200f, 80f))
        assertEquals(0.0 to 0.5, DrumPadGeometry.valuesForPoint(-10f, 40f, 200f, 80f))
        assertEquals(50f to 0f, DrumPadGeometry.dotForValues(0.25, 1.0, 200f, 80f))
    }

    // ---- Learn -----------------------------------------------------------------

    @Test fun learnCameraLaneMatchesIos() {
        // Portrait (viewport 0.5, video 0.75 → visible = 1): lanes span 0.15…0.80.
        assertNull(LearnGeometry.cameraLane(0.1, 10, 0.75, 0.5))
        assertNull(LearnGeometry.cameraLane(0.85, 10, 0.75, 0.5))
        assertEquals(9, LearnGeometry.cameraLane(0.15, 10, 0.75, 0.5))
        assertEquals(0, LearnGeometry.cameraLane(0.79, 10, 0.75, 0.5))
        assertEquals(4, LearnGeometry.cameraLane(0.5, 10, 0.75, 0.5))
        // Landscape (viewport 1.5 → visible 0.5): camera 0.5 is screen 0.5.
        assertEquals(4, LearnGeometry.cameraLane(0.5, 10, 0.75, 1.5))
        assertNull(LearnGeometry.cameraLane(0.3, 10, 0.75, 1.5))
        assertNull(LearnGeometry.cameraLane(Double.NaN, 10, 0.75, 0.5))
        assertNull(LearnGeometry.cameraLane(0.5, 0, 0.75, 0.5))
    }

    @Test fun learnCorrectedX() {
        // Portrait 500×1000 (0.5 < 0.75): video wider → cropped sides, visible 2/3.
        assertEquals(250f, LearnGeometry.correctedX(0.5, 500f, 1000f, 0.75f), 1e-3f)
        assertEquals(0f, LearnGeometry.correctedX(1.0 / 6.0, 500f, 1000f, 0.75f), 1e-2f)
        // Landscape: passes through.
        assertEquals(375f, LearnGeometry.correctedX(0.25, 1500f, 1000f, 0.75f), 1e-3f)
    }

    // ---- Weave -----------------------------------------------------------------

    @Test fun weavePetalsAndHue() {
        assertEquals(2, WeaveMath.petals(0.0))
        assertEquals(4, WeaveMath.petals(0.5))
        assertEquals(6, WeaveMath.petals(1.0))
        assertEquals(0.1, WeaveMath.layerHue(0.0, 2), 1e-9)
        assertEquals(0.95, WeaveMath.layerHue(-0.1, 1), 1e-9)
        assertEquals(0.02, WeaveMath.layerHue(0.97, 1), 1e-9)
        var n = 0
        WeaveMath.forEachPoint(0, 1.0, 100.0, 0.5, 0.5, 0.5) { _, _, _ -> n++ }
        assertEquals(WeaveMath.STEPS + 1, n)
    }
}
