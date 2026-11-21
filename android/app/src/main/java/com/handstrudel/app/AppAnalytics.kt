package com.handstrudel.app

import android.util.Log
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import java.net.HttpURLConnection
import java.net.URL
import kotlin.math.floor

/**
 * Opt-in usage analytics (iOS `App/AppAnalytics.swift`). Owner: shell. Default
 * off. Other workstreams call [record]; shell implements the POST to
 * `rest/v1/rpc/record_app_usage_event` and the once-per-day / once-per-install rules.
 */
interface AppAnalytics {
    val isEnabled: StateFlow<Boolean>

    /** Turning it on also records today's active day (iOS `UsageAnalyticsSettings.onChange`). */
    fun setEnabled(enabled: Boolean)

    /**
     * No-op when opted out. `first_note` is sent once per install. [AppAnalyticsEvent.ACTIVE_DAY]
     * is the same as [recordActiveDay]; [AppAnalyticsEvent.RETURN_DAY] is derived from it and
     * ignored here.
     */
    fun record(event: AppAnalyticsEvent)

    /**
     * iOS `recordActiveDay`: at most once per UTC day (`floor(epoch / 86400)`); also sends
     * `return_day` when an earlier day was recorded. Shell calls it whenever the app comes
     * to the foreground.
     */
    fun recordActiveDay() = record(AppAnalyticsEvent.ACTIVE_DAY)
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

/** Stores the opt-in, sends nothing (tests / previews). */
class NoopAppAnalytics(private val prefs: AppPrefs) : AppAnalytics {
    override val isEnabled: StateFlow<Boolean> get() = prefs.appUsageAnalyticsEnabled
    override fun setEnabled(enabled: Boolean) = prefs.setAppUsageAnalyticsEnabled(enabled)
    override fun record(event: AppAnalyticsEvent) = Unit
}

/**
 * The real analytics (iOS `AppAnalytics`). Dedupe state lives in [store] under the iOS
 * key names; the opt-in is the `appUsageAnalyticsEnabled` pref. [send] is called
 * synchronously for each event that passes the rules; it must not block (see
 * [UsageEventSender]). [enabled] = false disables everything (iOS `--uitesting`).
 */
class DefaultAppAnalytics(
    private val prefs: AppPrefs,
    private val store: PrefsStore,
    private val enabled: Boolean = true,
    private val nowMillis: () -> Long = System::currentTimeMillis,
    private val send: (AppAnalyticsEvent) -> Unit,
) : AppAnalytics {

    override val isEnabled: StateFlow<Boolean> get() = prefs.appUsageAnalyticsEnabled

    private val isOptedIn: Boolean get() = enabled && prefs.appUsageAnalyticsEnabled.value

    override fun setEnabled(enabled: Boolean) {
        val wasEnabled = prefs.appUsageAnalyticsEnabled.value
        prefs.setAppUsageAnalyticsEnabled(enabled)
        if (enabled && !wasEnabled) recordActiveDay()
    }

    @Synchronized
    override fun recordActiveDay() {
        if (!isOptedIn) return
        val day = floor(nowMillis() / 1000.0 / SECONDS_PER_DAY).toLong()
        val previous = store.getString(LAST_ACTIVE_DAY_KEY)?.toLongOrNull()
        if (previous != null && day <= previous) return
        store.putString(LAST_ACTIVE_DAY_KEY, day.toString())
        send(AppAnalyticsEvent.ACTIVE_DAY)
        if (previous != null) send(AppAnalyticsEvent.RETURN_DAY)
    }

    @Synchronized
    override fun record(event: AppAnalyticsEvent) {
        when (event) {
            AppAnalyticsEvent.ACTIVE_DAY -> return recordActiveDay()
            AppAnalyticsEvent.RETURN_DAY -> return
            else -> Unit
        }
        if (!isOptedIn) return
        if (event == AppAnalyticsEvent.FIRST_NOTE) {
            if (store.getString(FIRST_NOTE_KEY).toBoolean()) return
            store.putString(FIRST_NOTE_KEY, "true")
        }
        send(event)
    }

    companion object {
        const val OPT_IN_KEY = "appUsageAnalyticsEnabled"
        const val LAST_ACTIVE_DAY_KEY = "appUsageAnalyticsLastActiveDay"
        const val FIRST_NOTE_KEY = "appUsageAnalyticsFirstNote"
        private const val SECONDS_PER_DAY = 86_400.0
    }
}

/**
 * Best-effort POST of one event to `rest/v1/rpc/record_app_usage_event` with
 * `{"p_event": "<event>"}` and the anon `apikey` header: no auth header, no cookies,
 * 8 s timeout, no queue or retry (iOS `AppAnalytics.sendEvent`). Re-checks the opt-in
 * at send time like iOS. Does nothing when the backend isn't configured.
 */
class UsageEventSender(
    private val supabaseUrl: String,
    private val anonKey: String,
    private val isOptedIn: () -> Boolean,
    private val scope: CoroutineScope = CoroutineScope(SupervisorJob() + Dispatchers.IO),
) : (AppAnalyticsEvent) -> Unit {

    val isConfigured: Boolean get() = isBackendConfigured(supabaseUrl, anonKey)

    override fun invoke(event: AppAnalyticsEvent) {
        if (!isConfigured) return
        scope.launch {
            if (!isOptedIn()) return@launch
            try {
                val url = URL(supabaseUrl.trimEnd('/') + "/rest/v1/rpc/record_app_usage_event")
                val connection = url.openConnection() as HttpURLConnection
                try {
                    connection.requestMethod = "POST"
                    connection.connectTimeout = TIMEOUT_MS
                    connection.readTimeout = TIMEOUT_MS
                    connection.useCaches = false
                    connection.doOutput = true
                    connection.setRequestProperty("Content-Type", "application/json")
                    connection.setRequestProperty("apikey", anonKey)
                    connection.outputStream.use { it.write(payload(event).toByteArray()) }
                    val status = connection.responseCode
                    Log.i(TAG, "sent ${event.raw} ($status)")
                } finally {
                    connection.disconnect()
                }
            } catch (e: Exception) {
                Log.i(TAG, "dropped ${event.raw}: ${e.javaClass.simpleName}")
            }
        }
    }

    companion object {
        private const val TAG = "AppAnalytics"
        private const val TIMEOUT_MS = 8_000

        fun payload(event: AppAnalyticsEvent): String = """{"p_event":"${event.raw}"}"""

        /** iOS `SocialConfig.isConfigured`: a URL and a key that isn't a `YOUR-…` placeholder. */
        fun isBackendConfigured(url: String, key: String): Boolean =
            url.isNotBlank() && key.isNotBlank() && !key.startsWith("YOUR-")
    }
}
