package com.handstrudel.ui.social.feed

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Check
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.handstrudel.social.data.FeedService
import com.handstrudel.social.model.PublicCreator
import com.handstrudel.social.model.Video
import com.handstrudel.ui.social.ProfileActionButton
import com.handstrudel.ui.social.SocialScreen
import com.handstrudel.ui.social.account.CreatorPortfolio
import com.handstrudel.ui.social.account.CreatorProfileHeader
import com.handstrudel.ui.social.auth.SignInSheet
import com.handstrudel.ui.social.rememberSocial
import com.handstrudel.ui.theme.LocalStudioPalette
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.launch
import java.util.UUID

/** iOS `PublicCreatorView`: another creator's profile with Follow and their portfolio. */
@Composable
fun PublicCreatorScreen(creatorId: UUID, onDismiss: () -> Unit, onFollowChange: () -> Unit, onStart: (PerformanceStart) -> Unit) {
    val social = rememberSocial() ?: return
    val auth = social.auth
    val p = LocalStudioPalette.current
    val scope = rememberCoroutineScope()
    val userId by auth.userId.collectAsState()
    var creator by remember { mutableStateOf<PublicCreator?>(null) }
    var videos by remember { mutableStateOf<List<Video>>(emptyList()) }
    var counts by remember { mutableStateOf<FeedService.ProfileCounts?>(null) }
    var opened by remember { mutableStateOf<Video?>(null) }
    var following by remember { mutableStateOf(false) }
    var loading by remember { mutableStateOf(true) }
    var busy by remember { mutableStateOf(false) }
    var changingFollow by remember { mutableStateOf(false) }
    var more by remember { mutableStateOf(false) }
    var signIn by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    var postsFailed by remember { mutableStateOf(false) }

    suspend fun loadVideos(append: Boolean = false) {
        if (busy) return
        busy = true
        postsFailed = false
        try {
            val page = social.feed.page(after = if (append) videos.lastOrNull() else null, creator = creatorId)
            videos = if (append) videos + page.filter { v -> videos.none { it.id == v.id } } else page
            more = page.size == FeedService.PAGE_SIZE
        } catch (e: kotlinx.coroutines.CancellationException) {
            throw e
        } catch (e: Exception) {
            postsFailed = true
        } finally { busy = false }
    }

    suspend fun load() {
        loading = true
        error = null
        val viewer = auth.userId.value
        try {
            val profile = social.feed.creator(creatorId)
            if (viewer != auth.userId.value) return
            creator = profile
            if (profile == null) { videos = emptyList(); counts = null; return }
            coroutineScope {
                val metrics = async { social.feed.profileCounts(creatorId) }
                following = if (viewer != null) social.feed.isFollowing(creatorId, viewer).let { if (changingFollow) following else it } else false
                loadVideos()
                val result = metrics.await()
                if (viewer == auth.userId.value) counts = result
            }
        } catch (e: kotlinx.coroutines.CancellationException) {
            throw e
        } catch (e: Exception) {
            error = "Couldn't load this profile. Pull down to refresh."
        } finally { loading = false }
    }

    fun changeFollow() {
        val user = auth.userId.value
        if (user == null || auth.needsProfileSetup) { signIn = true; return }
        changingFollow = true
        error = null
        scope.launch {
            try {
                social.feed.setFollowing(!following, creatorId, user)
                if (auth.userId.value != user) return@launch
                following = !following
                onFollowChange()
                counts = social.feed.profileCounts(creatorId)
            } catch (e: kotlinx.coroutines.CancellationException) {
                throw e
            } catch (e: Exception) {
                error = "Couldn't update your follows."
            } finally { changingFollow = false }
        }
    }

    LaunchedEffect(userId) { load() }

    SocialScreen("Creator", onDismiss) {
        Column(
            Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 21.dp, vertical = 12.dp),
            verticalArrangement = Arrangement.spacedBy(20.dp),
        ) {
            val c = creator
            if (c != null) {
                CreatorProfileHeader(
                    username = c.username, displayName = c.displayName, avatarKey = c.avatarKey ?: videos.firstOrNull()?.avatarKey,
                    counts = counts, likesReceived = c.likesReceived, viewsReceived = c.viewsReceived, isOwner = userId == creatorId,
                ) {
                    if (userId != creatorId) {
                        ProfileActionButton(
                            if (following) "Following" else "Follow", primary = !following,
                            icon = if (following) Icons.Filled.Check else Icons.Filled.Add,
                            enabled = !changingFollow && !loading, onClick = ::changeFollow,
                            modifier = Modifier.fillMaxWidth().testTag("profile-follow"),
                        )
                    }
                }
                CreatorPortfolio(
                    videos = videos, loading = loading || busy, failed = postsFailed, more = more, isOwner = false,
                    open = { opened = it }, trySound = { onStart(PerformanceStart.Preset(it)) },
                    retry = { scope.launch { loadVideos(append = more) } }, loadMore = { scope.launch { loadVideos(append = true) } },
                )
            } else if (loading) {
                Row(Modifier.fillMaxWidth().padding(vertical = 40.dp), horizontalArrangement = Arrangement.Center, verticalAlignment = Alignment.CenterVertically) {
                    CircularProgressIndicator(color = p.accent, modifier = Modifier.size(20.dp)); Text("  Loading creator", color = p.muted)
                }
            } else if (error == null) {
                Text("This profile is unavailable.", color = p.muted)
            }
            error?.let {
                Text(it, color = p.muted, fontSize = 13.sp)
                ProfileActionButton("Try again", enabled = !loading && !changingFollow, onClick = { scope.launch { load() } }, modifier = Modifier.fillMaxWidth())
            }
        }
    }
    opened?.let { video ->
        CreatorVideoSheet(video, onDismiss = { opened = null }, playlist = videos,
            onPlayAlong = { opened = null; onStart(PerformanceStart.Backing(it)) },
            onTrySound = { opened = null; onStart(PerformanceStart.Preset(it)) })
    }
    if (signIn) SignInSheet(onDismiss = { signIn = false }, reason = "Sign in to follow this creator.")
}
