package com.handstrudel.ui.studio.stage

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.ui.platform.LocalContext
import com.handstrudel.engine.StudioEngine
import com.handstrudel.models.MusicKey
import com.handstrudel.models.Scale
import com.handstrudel.models.ScaleSelection
import com.handstrudel.models.WAVEFORMS
import com.handstrudel.store.StoreGate
import kotlin.math.sqrt
import kotlin.random.Random

/**
 * Shake detection tuned to feel like UIKit's `motionEnded(.motionShake)`, which needs a
 * short, vigorous back-and-forth shake rather than a single bump or a tilt.
 *
 * Gravity is removed with a low-pass filter (the filtered signal is the gravity estimate,
 * the remainder is the user's acceleration). A sample "accelerates" when that user
 * acceleration is at least [thresholdG] g. A shake is when, over a window of the last
 * [windowMs] that spans at least [minSpanMs], at least half of the samples accelerate.
 * After a shake fires, nothing fires for [cooldownMs]. Pure: fed samples in m/s²,
 * JVM-testable.
 */
class ShakeGate(
    private val thresholdG: Float = 1.0f,
    private val windowMs: Long = 500,
    private val minSpanMs: Long = 250,
    private val cooldownMs: Long = 1000,
) {
    private var gravity: FloatArray? = null
    private val samples = ArrayDeque<Pair<Long, Boolean>>()
    private var lastFire = Long.MIN_VALUE / 2

    fun onSample(x: Float, y: Float, z: Float, nowMs: Long): Boolean {
        val g = gravity ?: floatArrayOf(x, y, z).also { gravity = it }
        g[0] = ALPHA * g[0] + (1 - ALPHA) * x
        g[1] = ALPHA * g[1] + (1 - ALPHA) * y
        g[2] = ALPHA * g[2] + (1 - ALPHA) * z
        val lx = x - g[0]
        val ly = y - g[1]
        val lz = z - g[2]
        val userG = sqrt(lx * lx + ly * ly + lz * lz) / GRAVITY
        samples.addLast(nowMs to (userG >= thresholdG))
        while (samples.isNotEmpty() && nowMs - samples.first().first > windowMs) samples.removeFirst()

        if (nowMs - lastFire < cooldownMs) return false
        val span = nowMs - samples.first().first
        val accelerating = samples.count { it.second }
        if (span < minSpanMs || accelerating * 2 < samples.size) return false
        lastFire = nowMs
        samples.clear()
        return true
    }

    private companion object {
        /** Low-pass weight for the gravity estimate (about 0.2 s at 50 Hz). */
        const val ALPHA = 0.8f
        const val GRAVITY = SensorManager.GRAVITY_EARTH
    }
}

/** iOS `ShakeDetectorView`: calls [onShake] on a device shake while composed. */
@Composable
fun ShakeDetector(onShake: () -> Unit) {
    val context = LocalContext.current
    val callback = rememberUpdatedState(onShake)
    DisposableEffect(context) {
        val sm = context.getSystemService(Context.SENSOR_SERVICE) as? SensorManager
        val sensor = sm?.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
        val gate = ShakeGate()
        val listener = object : SensorEventListener {
            override fun onSensorChanged(e: SensorEvent) {
                if (gate.onSample(e.values[0], e.values[1], e.values[2], System.currentTimeMillis())) callback.value()
            }
            override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit
        }
        if (sensor != null) sm.registerListener(listener, sensor, SensorManager.SENSOR_DELAY_GAME)
        onDispose { sm?.unregisterListener(listener) }
    }
}

/** iOS `randomizeSettings`: random key, entitled scale, waveform, BPM 80–160. */
data class RandomSettings(val key: MusicKey, val scale: Scale, val waveform: String, val bpm: Int) {
    companion object {
        fun pick(store: StoreGate, random: Random = Random.Default): RandomSettings {
            val scales = Scale.entries.filter { store.isUnlocked(it.packId) }
            return RandomSettings(
                key = MusicKey.entries.random(random),
                scale = scales.randomOrNull(random) ?: Scale.PENTATONIC,
                waveform = WAVEFORMS.map { it.id }.randomOrNull(random) ?: "sawtooth",
                bpm = random.nextInt(80, 161),
            )
        }
    }

    fun apply(engine: StudioEngine) {
        engine.setKey(key)
        engine.setScale(ScaleSelection.BuiltIn(scale))
        engine.setWaveform(waveform)
        engine.setManualBPM(bpm.toDouble())
    }
}
