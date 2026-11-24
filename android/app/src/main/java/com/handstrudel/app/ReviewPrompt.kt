package com.handstrudel.app

import android.app.Activity
import android.util.Log
import com.google.android.play.core.ktx.launchReview
import com.google.android.play.core.ktx.requestReview
import com.google.android.play.core.review.ReviewManagerFactory
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import java.util.UUID

/**
 * In-app review milestones (iOS `CreatorReviewMilestones`). Owner: shell.
 * Capture reports each successful new take; shell decides when to ask
 * (3 new takes, once per app version, once per 90 days, Music tab idle).
 */
interface ReviewPrompt {
    fun recordSuccessfulTake(draftId: UUID)
}

class NoopReviewPrompt : ReviewPrompt {
    override fun recordSuccessfulTake(draftId: UUID) = Unit
}

/**
 * iOS `CreatorReviewMilestones`, ported exactly. Immutable: the mutating Swift methods
 * return the updated value. [lastRequestMillis] is epoch milliseconds.
 */
@Serializable
data class CreatorReviewMilestones(
    val completedTakes: List<String> = emptyList(),
    val newTakes: Int = 0,
    val lastRequestMillis: Long? = null,
    val lastVersion: String? = null,
) {
    /** Returns the updated milestones, or null when [id] was already recorded (iOS returns false). */
    fun record(id: UUID): CreatorReviewMilestones? {
        val key = id.toString().lowercase()
        if (key in completedTakes) return null
        return copy(
            completedTakes = (completedTakes + key).takeLast(MAX_REMEMBERED_TAKES),
            newTakes = minOf(newTakes + 1, TAKES_BEFORE_ASKING),
        )
    }

    fun canRequest(version: String, nowMillis: Long): Boolean =
        newTakes >= TAKES_BEFORE_ASKING && lastVersion != version &&
            (lastRequestMillis?.let { nowMillis - it >= MIN_INTERVAL_MILLIS } ?: true)

    fun requested(version: String, nowMillis: Long): CreatorReviewMilestones =
        copy(newTakes = 0, lastRequestMillis = nowMillis, lastVersion = version)

    fun encode(): String = json.encodeToString(serializer(), this)

    companion object {
        const val TAKES_BEFORE_ASKING = 3
        const val MAX_REMEMBERED_TAKES = 100
        const val MIN_INTERVAL_MILLIS = 90L * 24 * 60 * 60 * 1000
        private val json = Json { ignoreUnknownKeys = true }

        fun decode(raw: String?): CreatorReviewMilestones =
            raw?.let { runCatching { json.decodeFromString(serializer(), it) }.getOrNull() } ?: CreatorReviewMilestones()
    }
}

/**
 * Real [ReviewPrompt]: persists milestones in the `creatorReviewMilestones` pref and
 * raises [readyThisSession] (iOS `reviewReadyThisSession`) on a new take. The root
 * composable waits for an idle Music tab, 2 s, then calls [requestIfDue].
 */
class PlayReviewPrompt(
    private val prefs: AppPrefs,
    private val appVersion: String,
    private val enabled: Boolean = true,
    private val nowMillis: () -> Long = System::currentTimeMillis,
) : ReviewPrompt {

    private val _readyThisSession = MutableStateFlow(false)
    val readyThisSession: StateFlow<Boolean> = _readyThisSession

    @Synchronized
    override fun recordSuccessfulTake(draftId: UUID) {
        if (!enabled) return
        val updated = CreatorReviewMilestones.decode(prefs.creatorReviewMilestones.value).record(draftId) ?: return
        prefs.setCreatorReviewMilestones(updated.encode())
        _readyThisSession.value = true
    }

    /**
     * Consumes the milestone if a review is due (iOS `.task(id: canShowReview)` body).
     * Returns true when the caller should show the review flow.
     */
    @Synchronized
    fun consumeIfDue(): Boolean {
        val now = nowMillis()
        val milestones = CreatorReviewMilestones.decode(prefs.creatorReviewMilestones.value)
        if (!milestones.canRequest(appVersion, now)) return false
        prefs.setCreatorReviewMilestones(milestones.requested(appVersion, now).encode())
        _readyThisSession.value = false
        return true
    }

    /** Runs the Play In-App Review flow. Play decides whether a card actually shows. */
    suspend fun requestIfDue(activity: Activity) {
        if (!consumeIfDue()) return
        try {
            val manager = ReviewManagerFactory.create(activity)
            val info = manager.requestReview()
            manager.launchReview(activity, info)
        } catch (e: Exception) {
            // No Play Store / not installed from Play: nothing to show (StoreKit may also decline).
            Log.i("ReviewPrompt", "review flow unavailable: ${e.javaClass.simpleName}")
        }
    }
}
