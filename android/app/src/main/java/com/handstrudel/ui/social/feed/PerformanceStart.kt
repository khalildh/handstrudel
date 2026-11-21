package com.handstrudel.ui.social.feed

import com.handstrudel.models.SoundSetup
import com.handstrudel.social.model.Video
import com.handstrudel.ui.nav.AppNavigator

/** iOS `PerformanceStart`: what to open in the Music tab after a sheet closes. */
sealed interface PerformanceStart {
    data class Backing(val video: Video) : PerformanceStart
    data class Preset(val sound: SoundSetup) : PerformanceStart
}

/** "Play this sound" → `trySharedSound`; "Play along" → `prepareBacking` (shell/capture seams). */
fun AppNavigator.start(start: PerformanceStart) = when (start) {
    is PerformanceStart.Backing -> prepareBacking(start.video)
    is PerformanceStart.Preset -> trySharedSound(start.sound)
}

/**
 * iOS `SoundSetup.presetDetails`: "C Major · 120 BPM · Pop Anthem".
 * TODO(engine): move onto `SoundSetup` next to `keyAndScale` (iOS keeps it in PersistenceManager).
 */
val SoundSetup.presetDetails: String
    get() {
        val parts = mutableListOf(keyAndScale)
        if (bpm in 20.0..400.0) parts += "${Math.round(bpm)} BPM"
        resolvedProgression?.let { progression ->
            parts += when {
                progression.id == "free" -> "Free layout"
                progression.isCustom -> progression.degrees.joinToString("-") { (it + 1).toString() }
                else -> progression.name
            }
        }
        return parts.joinToString(" · ")
    }
