package com.handstrudel.ui.studio

import com.handstrudel.models.MusicKey
import com.handstrudel.models.Scale
import com.handstrudel.store.UnconfiguredStoreGate
import com.handstrudel.ui.studio.common.StudioMusic
import com.handstrudel.ui.studio.common.WheelGeometry
import com.handstrudel.ui.studio.common.WheelGeometry.ChordSubzone
import com.handstrudel.ui.studio.common.WheelGeometry.Side
import com.handstrudel.ui.studio.common.WheelGeometry.Zone
import com.handstrudel.ui.studio.onboarding.OnboardingCopy
import com.handstrudel.ui.studio.pickers.CustomScaleDraft
import com.handstrudel.ui.studio.pickers.GMCategory
import com.handstrudel.ui.studio.stage.RandomSettings
import com.handstrudel.ui.studio.stage.ShakeGate
import com.handstrudel.ui.studio.visual.CAMERA_FILTERS
import com.handstrudel.ui.studio.visual.FilterMatrix
import com.handstrudel.ui.studio.visual.HAND_THEMES
import com.handstrudel.ui.studio.visual.cameraFilter
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.math.abs
import kotlin.random.Random

class StudioCoreLogicTest {
    private val major = Scale.MAJOR.intervals

    // ---- Split / Scale wheel geometry (iOS ChordMelodyModeManager) ----

    @Test fun splitWedgeIndexFansFromTopOfEachHalf() {
        assertEquals(0, WheelGeometry.splitWedgeIndex(Side.RIGHT, 1.0, 7))
        assertEquals(6, WheelGeometry.splitWedgeIndex(Side.RIGHT, 179.0, 7))
        assertEquals(0, WheelGeometry.splitWedgeIndex(Side.LEFT, 359.0, 7))
        assertEquals(6, WheelGeometry.splitWedgeIndex(Side.LEFT, 181.0, 7))
        assertNull(WheelGeometry.splitWedgeIndex(Side.LEFT, 90.0, 7))
        assertNull(WheelGeometry.splitWedgeIndex(Side.RIGHT, 270.0, 7))
    }

    @Test fun splitOctaveShiftOnlyInOuterBand() {
        // Right side, 4 wedges of 45°: wedge 1 spans 45–90; top half (45–67.5) → +1.
        assertEquals(0, WheelGeometry.splitOctaveShift(Side.RIGHT, 50.0, 0.7, 1, 4))
        assertEquals(1, WheelGeometry.splitOctaveShift(Side.RIGHT, 50.0, 0.9, 1, 4))
        assertEquals(-1, WheelGeometry.splitOctaveShift(Side.RIGHT, 80.0, 0.9, 1, 4))
        // Left side mirrors: wedge 0 spans 360→315; nearer the top (> 337.5) → +1.
        assertEquals(1, WheelGeometry.splitOctaveShift(Side.LEFT, 350.0, 0.9, 0, 4))
        assertEquals(-1, WheelGeometry.splitOctaveShift(Side.LEFT, 320.0, 0.9, 0, 4))
    }

    @Test fun splitZoneForPointMatchesTouchOverlay() {
        val w = 1000f; val h = 2000f // outer radius 500 around (500, 1000)
        // Rest hole.
        assertNull(WheelGeometry.splitZoneForPoint(500f, 1000f, w, h, 4, 9, swapHands = false))
        // Chord half (left by default), inner band, just left of 12 o'clock → wedge 0 base octave.
        assertEquals(Zone.Chord(ChordSubzone(0, 0)), WheelGeometry.splitZoneForPoint(480f, 700f, w, h, 4, 9, false))
        // Same spot in the outer band nearer the top → +1.
        assertEquals(Zone.Chord(ChordSubzone(0, 1)), WheelGeometry.splitZoneForPoint(490f, 540f, w, h, 4, 9, false))
        // Melody half: just right of the top → highest lane.
        assertEquals(Zone.Melody(8), WheelGeometry.splitZoneForPoint(520f, 700f, w, h, 4, 9, false))
        // Bottom of the right half → lowest lane.
        assertEquals(Zone.Melody(0), WheelGeometry.splitZoneForPoint(520f, 1300f, w, h, 4, 9, false))
        // Swapped: chords on the right.
        assertEquals(Zone.Chord(ChordSubzone(0, 0)), WheelGeometry.splitZoneForPoint(520f, 700f, w, h, 4, 9, true))
    }

    @Test fun drawnWedgeCentresHitTheirOwnZone() {
        val w = 800f; val h = 1600f
        val outer = WheelGeometry.splitOuterRadius(w, h)
        val r = outer * ((WheelGeometry.SPLIT_DEADZONE + WheelGeometry.SPLIT_OCTAVE_BAND_THRESHOLD) / 2).toFloat()
        for (swap in listOf(false, true)) {
            for (count in listOf(2, 4, 7)) for (i in 0 until count) {
                val (x, y) = WheelGeometry.polar(w / 2, h / 2, WheelGeometry.chordCenterAngle(i, count, swap), r)
                assertEquals(Zone.Chord(ChordSubzone(i, 0)), WheelGeometry.splitZoneForPoint(x, y, w, h, count, 7, swap))
            }
            for (count in listOf(5, 7, 9)) for (lane in 0 until count) {
                val (x, y) = WheelGeometry.polar(w / 2, h / 2, WheelGeometry.melodyCenterAngle(lane, count, swap), r)
                assertEquals(Zone.Melody(lane), WheelGeometry.splitZoneForPoint(x, y, w, h, 4, count, swap))
            }
        }
    }

    @Test fun radialWedgeZeroIsCentredOnTop() {
        assertEquals(0, WheelGeometry.radialWedgeIndex(350.0, 4))
        assertEquals(0, WheelGeometry.radialWedgeIndex(40.0, 4))
        assertEquals(1, WheelGeometry.radialWedgeIndex(50.0, 4))
    }

    // ---- Music display helpers (iOS MusicTheory) ----

    @Test fun chordsAndNames() {
        assertEquals(listOf(48, 52, 55), StudioMusic.chordNotes(MusicKey.C, major, 0))
        assertEquals(listOf(48, 52, 55, 59), StudioMusic.chordNotesWithSeventh(MusicKey.C, major, 0))
        assertEquals("Cmaj", StudioMusic.chordDisplayName(MusicKey.C, major, 0))
        assertEquals("Dmin", StudioMusic.chordDisplayName(MusicKey.C, major, 1))
        assertEquals("Bdim", StudioMusic.chordDisplayName(MusicKey.C, major, 6))
        assertEquals(listOf("Cmaj⁷", "Gmaj⁷"), StudioMusic.splitChordNames(MusicKey.C, major, listOf(0, 4), scaleMode = true))
        assertEquals("Eb4", StudioMusic.midiNoteName(63))
    }

    @Test fun splitAndScaleMelodyTargets() {
        val split = StudioMusic.splitMelodyMidis(MusicKey.C, major, 0, scaleMode = false)
        assertEquals(9, split.size)
        assertEquals(listOf(48, 52, 55), split.take(3))
        val scale = StudioMusic.splitMelodyMidis(MusicKey.C, major, 0, scaleMode = true)
        assertEquals(listOf(60, 62, 64, 65, 67, 69, 71), scale)
        // Chord tones of Cmaj7 in one octave of C major: C E G B → lanes 0, 2, 4, 6.
        assertEquals(setOf(0, 2, 4, 6), StudioMusic.splitChordToneLanes(MusicKey.C, major, scale, 0, true))
        assertTrue(StudioMusic.splitChordToneLanes(MusicKey.C, major, split, 0, false).isEmpty())
    }

    @Test fun previewNotesFollowIos() {
        assertEquals(listOf(60, 62, 64, 65), StudioMusic.previewNotes(MusicKey.C, major, "free", (0..6).toList()))
        assertEquals(listOf(48, 52, 55, 60), StudioMusic.previewNotes(MusicKey.C, major, "pop", listOf(0, 4, 5, 3)))
    }

    // ---- Camera filters (iOS CameraFilterTests + matrix) ----

    @Test fun filterCatalogMatchesIos() {
        assertEquals(23, CAMERA_FILTERS.size)
        assertEquals(CAMERA_FILTERS.size, CAMERA_FILTERS.map { it.id }.toSet().size)
        assertEquals(10, CAMERA_FILTERS.count { !it.isPremium })
        assertTrue(CAMERA_FILTERS.filter { it.isPremium }.all { it.packId == "filter_pack" })
        assertTrue(CAMERA_FILTERS.filter { !it.isPremium }.all { it.packId == null })
        for (f in CAMERA_FILTERS) {
            assertTrue(f.saturation in 0f..3f && f.contrast in 0f..2f && f.brightness in -0.1f..0.1f)
            assertTrue(f.hueRotation in 0f..360f && f.overlayOpacity in 0f..1f)
        }
        assertEquals(0f, cameraFilter("noir").saturation)
        assertEquals("none", cameraFilter("missing").id)
    }

    @Test fun noneFilterIsIdentityMatrix() {
        val m = cameraFilter("none").colorMatrix
        FilterMatrix.identity().forEachIndexed { i, v -> assertEquals(v, m[i], 1e-5f) }
    }

    @Test fun noirIsGreyAndContrastPivotsOnMidGrey() {
        val noir = cameraFilter("noir").colorMatrix
        val out = FilterMatrix.apply(noir, 0.8f, 0.2f, 0.1f)
        assertEquals(out.r, out.g, 1e-5f); assertEquals(out.g, out.b, 1e-5f)
        val c = FilterMatrix.contrast(1.3f)
        assertEquals(0.5f, FilterMatrix.apply(c, 0.5f, 0.5f, 0.5f).r, 1e-5f)
        assertEquals(0.5f + 0.3f * 1.3f, FilterMatrix.apply(c, 0.8f, 0.8f, 0.8f).r, 1e-4f)
        // Brightness adds; a 360° hue turn is the identity; grey survives any hue turn.
        assertEquals(0.52f, FilterMatrix.apply(FilterMatrix.brightness(0.02f), 0.5f, 0.5f, 0.5f).g, 1e-5f)
        val h = FilterMatrix.apply(FilterMatrix.hueRotation(137f), 0.4f, 0.4f, 0.4f)
        assertEquals(0.4f, h.r, 2e-3f); assertEquals(0.4f, h.b, 2e-3f)
    }

    @Test fun everyFilterLooksDifferent() {
        val probe = listOf(Triple(0.8f, 0.3f, 0.2f), Triple(0.2f, 0.6f, 0.9f), Triple(0.5f, 0.5f, 0.5f))
        val looks = CAMERA_FILTERS.map { f ->
            val m = f.colorMatrix
            probe.flatMap { (r, g, b) -> FilterMatrix.apply(m, r, g, b).let { listOf(it.r, it.g, it.b) } } +
                listOf(f.overlayColor?.r ?: -1f, f.overlayOpacity, f.blendMode.ordinal.toFloat())
        }
        for (i in looks.indices) for (j in i + 1 until looks.size) {
            assertTrue("${CAMERA_FILTERS[i].id} vs ${CAMERA_FILTERS[j].id}", looks[i].zip(looks[j]).any { (a, b) -> abs(a - b) > 1e-3f })
        }
    }

    @Test fun handThemesMatchIos() {
        assertEquals(listOf("default", "mono", "fire_ice", "purple_gold", "matrix", "sunset", "ocean"), HAND_THEMES.map { it.id })
        assertEquals(5, HAND_THEMES.count { it.isPremium && it.packId == "visual_pack" })
    }

    // ---- Onboarding, pickers, shake ----

    @Test fun onboardingSteps() {
        assertEquals("Play your first note", OnboardingCopy.title(false, true))
        assertEquals("Now try a pinch", OnboardingCopy.title(true, true))
        assertEquals("Tap or slide to play", OnboardingCopy.title(true, false))
        assertEquals("Skip", OnboardingCopy.button(false))
        assertEquals("Keep playing", OnboardingCopy.button(true))
        // Target sits on the melody (right) half, mirrored when hands swap.
        val (x, _) = WheelGeometry.onboardingTarget(1000f, 2000f, 7, swapHands = false)
        val (xs, _) = WheelGeometry.onboardingTarget(1000f, 2000f, 7, swapHands = true)
        assertTrue(x > 500f && xs < 500f)
        assertEquals(1000f - x, xs, 1e-3f)
    }

    @Test fun customScaleDraftKeepsRootAndNeedsThreeNotes() {
        val draft = CustomScaleDraft.from(null, listOf(0, 4))
        draft.name = "Mine"
        draft.toggle(0)
        assertTrue(0 in draft.notes)
        assertNull(draft.scale)
        draft.toggle(7)
        assertNotNull(draft.scale)
        assertEquals(listOf(0, 4, 7), draft.scale!!.intervals)
        draft.name = "  "
        assertNull(draft.scale)
    }

    @Test fun gmCategoryByProgramFamily() {
        assertEquals(GMCategory.PIANO, GMCategory.of(0))
        assertEquals(GMCategory.GUITAR, GMCategory.of(27))
        assertEquals(GMCategory.SOUND_FX, GMCategory.of(127))
    }

    @Test fun shakeFiresOncePerCooldown() {
        val gate = ShakeGate()
        assertFalse(gate.onSample(0f, 0f, 9.8f, 0))
        assertTrue(gate.onSample(30f, 0f, 9.8f, 100))
        assertFalse(gate.onSample(30f, 0f, 9.8f, 500))
        assertTrue(gate.onSample(30f, 0f, 9.8f, 1200))
    }

    @Test fun randomizeUsesEntitledScalesAndBpmRange() {
        val store = UnconfiguredStoreGate()
        repeat(200) {
            val r = RandomSettings.pick(store, Random(it))
            assertTrue(r.scale.packId == null)
            assertTrue(r.bpm in 80..160)
        }
    }
}
