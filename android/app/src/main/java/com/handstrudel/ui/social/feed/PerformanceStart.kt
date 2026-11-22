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
