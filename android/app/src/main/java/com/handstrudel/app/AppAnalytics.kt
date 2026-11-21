package com.handstrudel.app

import kotlinx.coroutines.flow.StateFlow

/**
 * Opt-in usage analytics (iOS `App/AppAnalytics.swift`). Owner: shell. Default
 * off. Other workstreams call [record]; shell implements the POST to
 * `rest/v1/rpc/record_app_usage_event` and the once-per-day / once-per-install rules.
 */
interface AppAnalytics {
    val isEnabled: StateFlow<Boolean>
    fun setEnabled(enabled: Boolean)
    /** No-op when opted out. `active_day`/`return_day`/`first_note` dedupe is handled inside. */
    fun record(event: AppAnalyticsEvent)
}

/** `p_event` values. */
enum class AppAnalyticsEvent(val raw: String) {
    ACTIVE_DAY("active_day"),
    RETURN_DAY("return_day"),
    FIRST_NOTE("first_note"),
    RECORDING_STARTED("recording_started"),
    RECORDING_SAVED("recording_saved"),
    RECORDING_POSTED("recording_posted"),
}

/** Phase 0 stub: stores the opt-in, sends nothing. */
class NoopAppAnalytics(private val prefs: AppPrefs) : AppAnalytics {
    override val isEnabled: StateFlow<Boolean> get() = prefs.appUsageAnalyticsEnabled
    override fun setEnabled(enabled: Boolean) = prefs.setAppUsageAnalyticsEnabled(enabled)
    override fun record(event: AppAnalyticsEvent) = Unit
}
