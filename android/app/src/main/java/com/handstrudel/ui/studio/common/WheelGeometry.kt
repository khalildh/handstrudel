package com.handstrudel.ui.studio.common

import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.min
import kotlin.math.sin
import kotlin.math.sqrt

/**
 * Pure geometry of the Split / Scale wheel, ported from iOS
 * `ChordMelodyModeManager` (`splitWedgeIndex`, `splitOctaveShift`) and
 * `SplitTouchOverlay.zoneForTouch`. Angles are degrees clockwise from
 * 12 o'clock, like iOS. Constants are copied from iOS (and equal the Rust
 * core's), so the drawn wheel lines up with the engine's hand math.
 * JVM-testable: no Android or UniFFI types.
 */
object WheelGeometry {
    const val SPLIT_DEADZONE = 0.36
    const val SPLIT_RADIUS_FRACTION = 1.0
    const val SPLIT_OCTAVE_BAND_THRESHOLD = 0.80
    const val RADIAL_DEADZONE = 0.24
    const val RADIAL_RADIUS_FRACTION = 0.92

    enum class Side { LEFT, RIGHT }

    data class ChordSubzone(val wedge: Int, val octave: Int)

    sealed interface Zone {
        data class Chord(val sub: ChordSubzone) : Zone
        data class Melody(val lane: Int) : Zone
    }

    fun chordSide(swapHands: Boolean) = if (swapHands) Side.RIGHT else Side.LEFT
    fun melodySide(swapHands: Boolean) = if (swapHands) Side.LEFT else Side.RIGHT

    private fun wrap(a: Double): Double { val x = a % 360.0; return if (x < 0) x + 360.0 else x }

    /** iOS `splitWedgeIndex`: wedges fan from the top of the arc (0) to the bottom (count-1); null on the other half. */
    fun splitWedgeIndex(side: Side, angle: Double, count: Int): Int? {
        if (count <= 0) return null
        val a = wrap(angle)
        val t = when (side) {
            Side.LEFT -> if (a >= 180 && a < 360) (360.0 - a) / 180.0 else return null
            Side.RIGHT -> if (a >= 0 && a < 180) a / 180.0 else return null
        }
        return (t * count).toInt().coerceIn(0, count - 1)
    }

    /** iOS `splitOctaveShift(side:angle:radius:wedgeIndex:count:)`. */
    fun splitOctaveShift(side: Side, angle: Double, radius: Double, wedgeIndex: Int, count: Int): Int {
        if (radius < SPLIT_OCTAVE_BAND_THRESHOLD || count <= 0) return 0
        val a = wrap(angle)
        val offsetFromTop = when (side) {
            Side.LEFT -> if (a >= 180 && a < 360) 360.0 - a else return 0
            Side.RIGHT -> if (a >= 0 && a < 180) a else return 0
        }
        val wedgeLen = 180.0 / count
        val within = offsetFromTop - wedgeIndex * wedgeLen
        return if (within < wedgeLen / 2) 1 else -1
    }

    /** Wheel radius in px for a view of [width]×[height] (iOS: shorter half-dimension × fraction). */
    fun splitOuterRadius(width: Float, height: Float): Float = min(width, height) / 2f * SPLIT_RADIUS_FRACTION.toFloat()

    /** Point → (angle clockwise from top, radius as a fraction of [outerR], unclamped). */
    fun polarOf(x: Float, y: Float, cx: Float, cy: Float, outerR: Float): Pair<Double, Double> {
        val dx = (x - cx).toDouble()
        val dy = (cy - y).toDouble()
        val r = sqrt(dx * dx + dy * dy) / outerR
        return wrap(90.0 - atan2(dy, dx) * 180.0 / Math.PI) to r
    }

    /** iOS `SplitTouchUIView.zoneForTouch`. Null inside the rest hole or with no geometry. */
    fun splitZoneForPoint(
        x: Float, y: Float, width: Float, height: Float,
        zoneCount: Int, melodyCount: Int, swapHands: Boolean,
    ): Zone? {
        val outerR = splitOuterRadius(width, height)
        if (outerR <= 0f) return null
        val (deg, raw) = polarOf(x, y, width / 2f, height / 2f, outerR)
        val radius = min(1.0, raw)
        if (radius < SPLIT_DEADZONE) return null
        val cs = chordSide(swapHands)
        splitWedgeIndex(cs, deg, zoneCount)?.let { wedge ->
            return Zone.Chord(ChordSubzone(wedge, splitOctaveShift(cs, deg, radius, wedge, zoneCount)))
        }
        splitWedgeIndex(melodySide(swapHands), deg, melodyCount)?.let { wedge ->
            return Zone.Melody(melodyCount - 1 - wedge)
        }
        return null
    }

    /** iOS overlay `chordCenterAngle`: chord wedge i, top of the arc → bottom. */
    fun chordCenterAngle(index: Int, count: Int, swapHands: Boolean): Double {
        val offset = (index + 0.5) * (180.0 / count)
        return if (swapHands) offset else wrap(360.0 - offset)
    }

    /** iOS overlay `melodyCenterAngle`: lane 0 = lowest pitch at the bottom of the arc. */
    fun melodyCenterAngle(lane: Int, count: Int, swapHands: Boolean): Double {
        val offset = (count - 1 - lane + 0.5) * (180.0 / count)
        return if (swapHands) wrap(360.0 - offset) else offset
    }

    /** Point at [angleDeg] (clockwise from top) and [radius] px around ([cx], [cy]). */
    fun polar(cx: Float, cy: Float, angleDeg: Double, radius: Float): Pair<Float, Float> {
        val r = Math.toRadians(angleDeg)
        return (cx + radius * sin(r).toFloat()) to (cy - radius * cos(r).toFloat())
    }

    /** One accessibility element of the Split/Scale wheel (iOS `SplitAccessibilityNote`). */
    data class AccessibleWedge(val zone: Zone, val id: String, val label: String, val x: Float, val y: Float, val size: Float)

    /**
     * iOS `SplitTouchUIView.layoutAccessibleNotes`: one element per chord wedge ("Chord X",
     * `wheel-chord-i`) then per melody lane ("Note Y", `wheel-note-i`), centred on the base
     * band at radius `outerR·(deadzone + octave band)/2`, sized `π·r/count` clamped to
     * [minSize]…[maxSize] (22…44 pt on iOS). Sizes and positions are in px.
     */
    fun splitAccessibleWedges(
        width: Float, height: Float, chordLabels: List<String>, melodyLabels: List<String>, swapHands: Boolean,
        minSize: Float, maxSize: Float,
    ): List<AccessibleWedge> {
        val outerR = splitOuterRadius(width, height)
        if (outerR <= 0f) return emptyList()
        val radius = outerR * ((SPLIT_DEADZONE + SPLIT_OCTAVE_BAND_THRESHOLD) / 2).toFloat()
        val cx = width / 2f
        val cy = height / 2f
        fun size(count: Int) = (Math.PI.toFloat() * radius / count).coerceIn(minSize, maxSize)
        val chords = chordLabels.mapIndexed { i, label ->
            val (x, y) = polar(cx, cy, chordCenterAngle(i, chordLabels.size, swapHands), radius)
            AccessibleWedge(Zone.Chord(ChordSubzone(i, 0)), "wheel-chord-$i", "Chord $label", x, y, size(chordLabels.size))
        }
        val notes = melodyLabels.mapIndexed { i, label ->
            val (x, y) = polar(cx, cy, melodyCenterAngle(i, melodyLabels.size, swapHands), radius)
            AccessibleWedge(Zone.Melody(i), "wheel-note-$i", "Note $label", x, y, size(melodyLabels.size))
        }
        return chords + notes
    }

    // ---- Radial (one wheel: chords outer ring, melody inner ring) ----

    /** iOS `radialWedgeIndex`: wedge 0 centred on the top. */
    fun radialWedgeIndex(angle: Double, count: Int): Int {
        if (count <= 0) return 0
        val wedge = 360.0 / count
        return (wrap(angle + wedge / 2) / wedge).toInt().coerceIn(0, count - 1)
    }

    /** Radial wheel radius (iOS: shorter half-dimension × 0.92). */
    fun radialOuterRadius(width: Float, height: Float): Float = min(width, height) / 2f * RADIAL_RADIUS_FRACTION.toFloat()

    /** Onboarding first-note target (iOS `OnboardingView.target`): middle melody lane on the wheel. */
    fun onboardingTarget(width: Float, height: Float, melodyLaneCount: Int, swapHands: Boolean): Pair<Float, Float> {
        val count = melodyLaneCount.coerceAtLeast(1)
        val lane = count / 2
        val theta = (count - 1 - lane + 0.5) * Math.PI / count
        val radius = min(width, height) * 0.31f
        return (width / 2f + (sin(theta) * radius).toFloat() * (if (swapHands) -1f else 1f)) to
            (height / 2f - (cos(theta) * radius).toFloat())
    }
}
