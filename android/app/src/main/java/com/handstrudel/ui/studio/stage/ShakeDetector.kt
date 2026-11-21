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
 * Shake = acceleration magnitude (minus gravity) above [thresholdG] g, with a
 * cooldown so one shake fires once. Pure: fed samples, JVM-testable.
 */
class ShakeGate(private val thresholdG: Float = 2.2f, private val cooldownMs: Long = 1000) {
    private var lastFire = Long.MIN_VALUE / 2

    fun onSample(x: Float, y: Float, z: Float, nowMs: Long): Boolean {
        val g = sqrt(x * x + y * y + z * z) / SensorManager.GRAVITY_EARTH
        if (g < thresholdG || nowMs - lastFire < cooldownMs) return false
        lastFire = nowMs
        return true
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
        if (sensor != null) sm.registerListener(listener, sensor, SensorManager.SENSOR_DELAY_UI)
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
