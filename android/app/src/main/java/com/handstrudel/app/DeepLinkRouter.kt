package com.handstrudel.app

import android.content.Intent
import com.handstrudel.models.SoundSetup
import com.handstrudel.social.model.PerformanceLink
import com.handstrudel.social.model.Video

/**
 * Deep links (iOS `ContentView.onOpenURL` / `onContinueUserActivity` → `openSocialLink`
 * → `openPerformance`). Owner: shell. Parsing is social's `PerformanceLink.parse`;
 * this file extracts the URL from an intent and decides what a resolved link does.
 */
object DeepLinkRouter {

    /** The performance link carried by a VIEW intent (custom scheme or App Link), or null. */
    fun linkFrom(intent: Intent?): PerformanceLink? {
        if (intent?.action != Intent.ACTION_VIEW) return null
        return linkFromUrl(intent.dataString)
    }

    fun linkFromUrl(url: String?): PerformanceLink? = url?.let(PerformanceLink::parse)

    /** What opening [link] does once the post has been fetched (iOS `openPerformance` switch). */
    sealed interface Outcome {
        data class ShowPost(val video: Video) : Outcome
        data class ShowComments(val video: Video) : Outcome
        data class PlayAlong(val video: Video) : Outcome
        data class TrySound(val setup: SoundSetup) : Outcome
        data class Error(val message: String) : Outcome
    }

    const val POST_UNAVAILABLE = "This performance is no longer available."
    const val COMMENTS_UNAVAILABLE = "Comments are not available for this performance."
    const val BACKING_UNAVAILABLE = "This backing track is no longer available."
    const val SOUND_UNAVAILABLE =
        "The creator hasn't shared a sound setup for this clip, or it is no longer available."
    const val LINK_FAILED = "Couldn't open this link. Check your connection and try again."

    /** [video] is the fetch result (null = missing/hidden). Exact iOS strings. */
    fun resolve(link: PerformanceLink, video: Video?): Outcome = when (link) {
        is PerformanceLink.Watch -> video?.let(Outcome::ShowPost) ?: Outcome.Error(POST_UNAVAILABLE)
        is PerformanceLink.Comments ->
            if (video != null && video.commentsEnabled != null) Outcome.ShowComments(video)
            else Outcome.Error(COMMENTS_UNAVAILABLE)
        is PerformanceLink.PlayAlong -> video?.let(Outcome::PlayAlong) ?: Outcome.Error(BACKING_UNAVAILABLE)
        is PerformanceLink.Sound -> video?.soundSetup?.let(Outcome::TrySound) ?: Outcome.Error(SOUND_UNAVAILABLE)
    }
}
