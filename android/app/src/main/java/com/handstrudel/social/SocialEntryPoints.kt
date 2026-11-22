package com.handstrudel.social

import androidx.compose.runtime.Composable
import com.handstrudel.social.model.Video
import com.handstrudel.ui.nav.LocalAppNavigator
import com.handstrudel.ui.social.SocialMaterialTheme
import com.handstrudel.ui.social.account.AccountTab as AccountScreen
import com.handstrudel.ui.social.auth.SignInSheet as SignInScreen
import com.handstrudel.ui.social.comments.CommentsSheet as CommentsScreen
import com.handstrudel.ui.social.feed.CreatorVideoSheet as CreatorVideoScreen
import com.handstrudel.ui.social.feed.FeedTab as FeedScreen
import com.handstrudel.ui.social.feed.PerformanceStart
import com.handstrudel.ui.social.feed.start
import java.util.UUID

/**
 * Social UI entry points used by shell and capture. Owner: social (WS5).
 * Composables get services from `LocalAppServices` / `LocalAppNavigator`; the
 * Supabase-backed services come from [SocialServices] (created on first use).
 * When social is unconfigured they render nothing (shell shows its placeholder).
 */
object SocialEntryPoints {

    /**
     * The Feed tab. Always composed while social is configured (so playback can preload);
     * [isActive] is true when it is the visible tab with no session running. The feed
     * draws shell's tab bar over video via [tabBar] (`overVideo = true`).
     */
    @Composable
    fun FeedTab(isActive: Boolean, onFullscreenChanged: (Boolean) -> Unit, tabBar: @Composable (overVideo: Boolean) -> Unit) {
        SocialMaterialTheme { FeedScreen(isActive, onFullscreenChanged, tabBar) }
    }

    /** The Account tab (profile, settings, sign-in). */
    @Composable
    fun AccountTab() = SocialMaterialTheme { AccountScreen() }

    /** A single post (deep link `watch`, "view post"). Play this sound / Play along hand off to Music. */
    @Composable
    fun CreatorVideoSheet(video: Video, onDismiss: () -> Unit) {
        val navigator = LocalAppNavigator.current
        SocialMaterialTheme {
            CreatorVideoScreen(
                video, onDismiss = onDismiss,
                onPlayAlong = { onDismiss(); navigator.start(PerformanceStart.Backing(it)) },
                onTrySound = { onDismiss(); navigator.start(PerformanceStart.Preset(it)) },
                allowsSharing = video.hidden != true,
            )
        }
    }

    /** Comments for a post (deep link `comments`). */
    @Composable
    fun CommentsSheet(video: Video, onDismiss: () -> Unit) = SocialMaterialTheme { CommentsScreen(video, onDismiss) }

    /** Sign-in / profile setup; capture shows it from the post composer. */
    @Composable
    fun SignInSheet(onDismiss: () -> Unit) = SocialMaterialTheme { SignInScreen(onDismiss) }

    /** iOS `FeedService.video(id:)`: one post, or null if missing/hidden/unavailable. */
    suspend fun fetchVideo(id: UUID): Video? =
        SocialServices.current?.feed?.let { runCatching { it.video(id) }.getOrNull() }
}
