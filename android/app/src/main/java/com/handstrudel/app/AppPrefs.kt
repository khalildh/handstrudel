package com.handstrudel.app

import android.content.Context
import com.handstrudel.engine.PlayInput
import com.handstrudel.ui.theme.StudioTheme
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

/**
 * App-level preferences, keyed exactly as iOS `@AppStorage`. Owner: shell.
 * Other workstreams read/write only through these typed accessors; add new keys
 * here (shell) rather than opening another preferences file. Engine keeps its
 * own `engine` namespace (iOS `PersistenceManager`).
 *
 * Phase 0 backs it with SharedPreferences; shell may move it to DataStore
 * without changing this interface.
 */
interface AppPrefs {
    val studioTheme: StateFlow<StudioTheme>
    fun setStudioTheme(value: StudioTheme)
    val hasSeenOnboarding: StateFlow<Boolean>
    fun setHasSeenOnboarding(value: Boolean)
    val studioPlayInput: StateFlow<PlayInput>
    fun setStudioPlayInput(value: PlayInput)
    val appUsageAnalyticsEnabled: StateFlow<Boolean>
    fun setAppUsageAnalyticsEnabled(value: Boolean)
    /** Opaque JSON owned by `ReviewPrompt` (iOS stores `CreatorReviewMilestones` as Data). */
    val creatorReviewMilestones: StateFlow<String?>
    fun setCreatorReviewMilestones(value: String?)
    val hideSkeletonWhenRecording: StateFlow<Boolean>
    fun setHideSkeletonWhenRecording(value: Boolean)
    val recordPerformanceMicrophone: StateFlow<Boolean>
    fun setRecordPerformanceMicrophone(value: Boolean)
    val recordAtHalfSpeed: StateFlow<Boolean>
    fun setRecordAtHalfSpeed(value: Boolean)
    /** 0…1, default 0.55 (iOS `BackingTrackVolume.defaultValue`). */
    val playAlongBackingVolume: StateFlow<Double>
    fun setPlayAlongBackingVolume(value: Double)
    /** Feed audio muted (iOS `feedMuted`), used by social. */
    val feedMuted: StateFlow<Boolean>
    fun setFeedMuted(value: Boolean)

    companion object {
        const val DEFAULT_BACKING_VOLUME = 0.55
    }
}

/** Minimal key-value backend so [StoreBackedAppPrefs] runs on SharedPreferences or in memory (tests). */
interface PrefsStore {
    fun getString(key: String): String?
    fun putString(key: String, value: String?)
}

class SharedPrefsStore(context: Context, name: String = "app") : PrefsStore {
    private val prefs = context.getSharedPreferences(name, Context.MODE_PRIVATE)
    override fun getString(key: String): String? = prefs.getString(key, null)
    override fun putString(key: String, value: String?) {
        prefs.edit().apply { if (value == null) remove(key) else putString(key, value) }.apply()
    }
}

class InMemoryPrefsStore(private val map: MutableMap<String, String> = mutableMapOf()) : PrefsStore {
    override fun getString(key: String): String? = map[key]
    override fun putString(key: String, value: String?) { if (value == null) map.remove(key) else map[key] = value }
}

class StoreBackedAppPrefs(private val store: PrefsStore) : AppPrefs {
    private fun <T> pref(key: String, decode: (String?) -> T, encode: (T) -> String?): Pair<MutableStateFlow<T>, (T) -> Unit> {
        val flow = MutableStateFlow(decode(store.getString(key)))
        return flow to { value: T -> flow.value = value; store.putString(key, encode(value)) }
    }
    private fun bool(key: String, default: Boolean) = pref(key, { it?.toBooleanStrictOrNull() ?: default }, { it.toString() })

    private val theme = pref(StudioTheme.STORAGE_KEY, StudioTheme::fromRaw) { it.raw }
    override val studioTheme: StateFlow<StudioTheme> = theme.first
    override fun setStudioTheme(value: StudioTheme) = theme.second(value)

    private val onboarding = bool("hasSeenOnboarding", false)
    override val hasSeenOnboarding: StateFlow<Boolean> = onboarding.first
    override fun setHasSeenOnboarding(value: Boolean) = onboarding.second(value)

    private val playInput = pref("studioPlayInput", PlayInput::fromRaw) { it.raw }
    override val studioPlayInput: StateFlow<PlayInput> = playInput.first
    override fun setStudioPlayInput(value: PlayInput) = playInput.second(value)

    private val analytics = bool("appUsageAnalyticsEnabled", false)
    override val appUsageAnalyticsEnabled: StateFlow<Boolean> = analytics.first
    override fun setAppUsageAnalyticsEnabled(value: Boolean) = analytics.second(value)

    private val review = pref<String?>("creatorReviewMilestones", { it }, { it })
    override val creatorReviewMilestones: StateFlow<String?> = review.first
    override fun setCreatorReviewMilestones(value: String?) = review.second(value)

    private val hideSkeleton = bool("hideSkeletonWhenRecording", true)
    override val hideSkeletonWhenRecording: StateFlow<Boolean> = hideSkeleton.first
    override fun setHideSkeletonWhenRecording(value: Boolean) = hideSkeleton.second(value)

    private val mic = bool("recordPerformanceMicrophone", false)
    override val recordPerformanceMicrophone: StateFlow<Boolean> = mic.first
    override fun setRecordPerformanceMicrophone(value: Boolean) = mic.second(value)

    private val halfSpeed = bool("recordAtHalfSpeed", false)
    override val recordAtHalfSpeed: StateFlow<Boolean> = halfSpeed.first
    override fun setRecordAtHalfSpeed(value: Boolean) = halfSpeed.second(value)

    private val backingVolume = pref("playAlongBackingVolume",
        { raw -> raw?.toDoubleOrNull()?.takeIf { it.isFinite() }?.coerceIn(0.0, 1.0) ?: AppPrefs.DEFAULT_BACKING_VOLUME },
        { it.toString() })
    override val playAlongBackingVolume: StateFlow<Double> = backingVolume.first
    override fun setPlayAlongBackingVolume(value: Double) =
        backingVolume.second(if (value.isFinite()) value.coerceIn(0.0, 1.0) else AppPrefs.DEFAULT_BACKING_VOLUME)

    private val muted = bool("feedMuted", false)
    override val feedMuted: StateFlow<Boolean> = muted.first
    override fun setFeedMuted(value: Boolean) = muted.second(value)
}
