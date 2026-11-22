package com.handstrudel.ui.nav

import androidx.compose.runtime.ProvidableCompositionLocal
import androidx.compose.runtime.staticCompositionLocalOf
import com.handstrudel.models.SoundSetup
import com.handstrudel.social.model.PerformanceLink
import com.handstrudel.social.model.Video
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

/** The three tabs. Music is the default. */
enum class Destination { Feed, Music, Account }

/**
 * App-level navigation and session control (iOS `ContentView` actions). Owner:
 * shell. Studio-ui, social and capture call it; they never navigate directly.
 */
interface AppNavigator {
    val destination: StateFlow<Destination>
    fun select(d: Destination)

    /**
     * iOS `startingSession`: true from Start until the engine runs or errors, including
     * while the camera permission dialog is up. Music home disables Start meanwhile.
     */
    val isStartingSession: StateFlow<Boolean> get() = NOT_STARTING

    /**
     * iOS `startSession`. With [setup]: apply it (if entitled) and start in its mode; if it
     * can't be applied and [useCurrentSoundAsFallback] is true, start with the current sound,
     * else show an error. Without: clamp the scale to the entitlement and start in Scale mode.
     * Requests the camera (lazily) when play input is Air.
     */
    fun startSession(setup: SoundSetup? = null, useCurrentSoundAsFallback: Boolean = false)

    /** "Play this sound": errors if a session is running. */
    fun trySharedSound(setup: SoundSetup)

    /** "Play along": delegates to `capture.prepareBacking`, switches to Music. */
    fun prepareBacking(video: Video)

    /** Deep links and "View post": opens the post / comments / sound / play-along. */
    fun openPerformance(link: PerformanceLink)

    /** Global toast (iOS notices, 4 s default). */
    fun showNotice(text: String, millis: Long = 4000)

    /** Global alert. */
    fun showError(title: String, message: String)

    /**
     * Asks for a runtime permission (e.g. `RECORD_AUDIO` when capture turns on mic
     * recording) through the activity, and reports whether it is granted. Calls back
     * immediately with true when it already is. Fakes may keep the default.
     */
    fun requestPermission(permission: String, onResult: (granted: Boolean) -> Unit) = onResult(false)
}

private val NOT_STARTING: StateFlow<Boolean> = MutableStateFlow(false)

val LocalAppNavigator: ProvidableCompositionLocal<AppNavigator> =
    staticCompositionLocalOf { error("LocalAppNavigator not provided") }
