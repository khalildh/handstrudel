package com.handstrudel.social

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.handstrudel.social.model.Video
import java.util.UUID

/**
 * Social UI entry points used by shell and capture. Owner: social (WS5).
 * Phase 0 stubs render "not available" placeholders. Composables get services
 * from `LocalAppServices` / `LocalAppNavigator`.
 */
object SocialEntryPoints {

    /**
     * The Feed tab. Always composed while social is configured (so playback can preload);
     * [isActive] is true when it is the visible tab with no session running. The feed
     * draws shell's tab bar over video via [tabBar] (`overVideo = true`).
     */
    @Composable
    fun FeedTab(isActive: Boolean, onFullscreenChanged: (Boolean) -> Unit, tabBar: @Composable (overVideo: Boolean) -> Unit) {
        Box(Modifier.fillMaxSize().background(Color.Black)) {
            Placeholder("Feed isn't available yet.")
            Box(Modifier.align(Alignment.BottomCenter)) { tabBar(true) }
        }
    }

    /** The Account tab (profile, settings, sign-in). */
    @Composable
    fun AccountTab() = Placeholder("Accounts aren't available yet.")

    /** A single post (deep link `watch`, "view post"). */
    @Composable
    fun CreatorVideoSheet(video: Video, onDismiss: () -> Unit) = StubSheet("Post", onDismiss)

    /** Comments for a post (deep link `comments`). */
    @Composable
    fun CommentsSheet(video: Video, onDismiss: () -> Unit) = StubSheet("Comments", onDismiss)

    /** Sign-in / profile setup; capture shows it from the post composer. */
    @Composable
    fun SignInSheet(onDismiss: () -> Unit) = StubSheet("Sign in", onDismiss)

    /** iOS `FeedService.video(id:)`: one post, or null if missing/hidden/unavailable. */
    suspend fun fetchVideo(id: UUID): Video? = null
}

@Composable
private fun Placeholder(text: String) {
    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Text(text, color = Color.White.copy(alpha = 0.7f))
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun StubSheet(title: String, onDismiss: () -> Unit) {
    ModalBottomSheet(onDismissRequest = onDismiss) {
        Column(Modifier.padding(24.dp)) { Text("$title isn't available yet.") }
    }
}
