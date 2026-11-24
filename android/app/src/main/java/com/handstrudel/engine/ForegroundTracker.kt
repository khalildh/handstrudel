package com.handstrudel.engine

/**
 * Counts this app's started activities, so the engine treats the app as backgrounded
 * only when none is visible (iOS `scenePhase == .background`). A single activity's
 * `onStop` isn't enough: the "Share one app" picker relaunches the main activity, so one
 * instance stops while another is in front. Translucent system dialogs (permission,
 * MediaProjection consent) don't stop the activity at all.
 */
internal class ForegroundTracker(private val onChange: (foreground: Boolean) -> Unit) {
    var started = 0
        private set

    val isForeground: Boolean get() = started > 0

    fun activityStarted() {
        started += 1
        if (started == 1) onChange(true)
    }

    fun activityStopped() {
        if (started == 0) return
        started -= 1
        if (started == 0) onChange(false)
    }
}
