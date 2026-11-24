package com.handstrudel.engine

import com.handstrudel.models.AXIS_MAP
import com.handstrudel.models.MappingConfig
import com.handstrudel.models.PARAM_MAP

/** iOS `ParamSmoother`: EMA toward the target, α = 0.6; unseen keys snap. */
object ParamSmoother {
    const val ALPHA = 0.6

    fun smooth(target: Map<String, Double>, smoothed: MutableMap<String, Double>) {
        for ((k, v) in target) {
            val current = smoothed[k]
            smoothed[k] = if (current == null) v else current + (v - current) * ALPHA
        }
    }
}

/** iOS `HandMapper`: hand axes → music params through a [MappingConfig]. */
object HandMapper {
    fun scaleAxis(raw: Double, paramId: String, invert: Boolean): Double {
        val def = PARAM_MAP[paramId] ?: return 0.0
        val t = if (invert) 1 - raw else raw
        return def.min + t * (def.max - def.min)
    }

    fun mapHandsToParams(hands: HandsState, params: MutableMap<String, Double>, config: MappingConfig) {
        for ((hand, side) in listOf(hands.left to config.left, hands.right to config.right)) {
            hand ?: continue
            for ((axisKey, paramId) in side) {
                if (paramId == "none" || paramId == "save") continue
                val axis = AXIS_MAP[axisKey] ?: continue
                val raw = hand.value(axisKey) ?: continue
                params[paramId] = scaleAxis(raw, paramId, axis.invert)
            }
        }
    }
}

/**
 * iOS quantize clock (`quantizeBoundaryCrossed`): learns the quarter period
 * from the Strudel `onBeat` callbacks so the grid tracks the felt beat.
 * Times are in seconds from any monotonic clock.
 */
class QuantizeClock {
    var enabled: Boolean = false
        set(value) { field = value; lastGridStep = -1 }
    /** Subdivisions per cycle: 4 = ¼, 8 = ⅛, 16 = 1/16. */
    var div: Double = 8.0
        set(value) { field = value; lastGridStep = -1 }

    private var beatIndex = 0
    var beatWallTime: Double = 0.0
    var quarterPeriod: Double = 0.5
    private var lastGridStep = -1

    /** Call on each new beat (iOS `connectWebAudio` onBeat). */
    fun onBeat(now: Double, tempoScale: Double) {
        if (beatWallTime > 0) {
            val delta = now - beatWallTime
            if (delta > 0.05 && delta < 2.0 / tempoScale) quarterPeriod = delta
        }
        beatWallTime = now
        beatIndex += 1
    }

    /** Re-seed after a tempo change (iOS `setRecordingTempo`). */
    fun reset(quarter: Double) {
        quarterPeriod = quarter
        beatWallTime = 0.0
    }

    /** True at most once per grid step; the first observation only syncs. */
    fun boundaryCrossed(now: Double): Boolean {
        if (!enabled || beatWallTime <= 0 || quarterPeriod <= 0) return false
        val subsPerQuarter = maxOf(1.0, div / 4.0)
        val frac = ((now - beatWallTime) / quarterPeriod).coerceIn(0.0, 2.0)
        val step = Math.floor((beatIndex + frac) * subsPerQuarter).toInt()
        if (lastGridStep == -1) { lastGridStep = step; return false }
        if (step != lastGridStep) { lastGridStep = step; return true }
        return false
    }
}
