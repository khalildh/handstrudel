package com.handstrudel.ui.social.feed

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Reply
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.outlined.ChatBubbleOutline
import androidx.compose.material.icons.outlined.PlayCircle
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.handstrudel.social.data.FeedService
import com.handstrudel.social.data.UnavailableException
import com.handstrudel.social.model.CreatorActivity
import com.handstrudel.social.model.Video
import com.handstrudel.ui.social.SocialScreen
import com.handstrudel.ui.social.rememberSocial
import com.handstrudel.ui.social.relativeTime
import com.handstrudel.ui.theme.LocalStudioPalette
import kotlinx.coroutines.launch
import java.time.Instant

/** iOS `ActivityInboxView`: likes, comments and replies with unread dots; opening an item marks it read. */
@Composable
fun ActivityInboxScreen(onDismiss: () -> Unit, onStart: (PerformanceStart) -> Unit) {
    val social = rememberSocial() ?: return
    val p = LocalStudioPalette.current
    val scope = rememberCoroutineScope()
    var items by remember { mutableStateOf<List<CreatorActivity>>(emptyList()) }
    var cursor by remember { mutableStateOf<CreatorActivity?>(null) }
    var loading by remember { mutableStateOf(false) }
    var more by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    var opened by remember { mutableStateOf<CreatorActivity?>(null) }

    suspend fun load(append: Boolean = false) {
        if (loading) return
        loading = true
        error = null
        try {
            val page = social.feed.activity(if (append) cursor else null)
            val base = if (append) items else emptyList()
            val existing = base.map { it.id }.toSet()
            items = base + page.filter { it.id !in existing }
            cursor = page.lastOrNull()
            more = page.size == FeedService.ACTIVITY_PAGE_SIZE
        } catch (e: UnavailableException) {
            error = e.message
        } catch (e: kotlinx.coroutines.CancellationException) {
            throw e
        } catch (e: Exception) {
            error = "Couldn't load notifications. Try again."
        } finally {
            loading = false
        }
    }
    LaunchedEffect(Unit) { load() }

    SocialScreen("Notifications", onDismiss) {
        LazyColumn(Modifier.weight(1f).fillMaxWidth()) {
            error?.let { e ->
                item {
                    Column(Modifier.padding(20.dp)) {
                        Text(e, color = p.muted, fontSize = 13.sp)
                        TextButton(onClick = { scope.launch { load() } }) { Text("Try again", color = p.accent) }
                    }
                }
            }
            if (items.isEmpty() && error == null) {
                item {
                    Box(Modifier.padding(20.dp)) {
                        if (loading) Row(verticalAlignment = Alignment.CenterVertically) {
                            CircularProgressIndicator(color = p.accent, modifier = Modifier.size(20.dp)); Text("  Loading activity", color = p.muted)
                        } else Text("New likes, comments, and replies will show up here.", color = p.muted)
                    }
                }
            }
            items(items, key = { it.id.toString() + it.timestamp }) { item ->
                Row(
                    Modifier.fillMaxWidth().clickable { opened = item }.padding(horizontal = 20.dp, vertical = 12.dp)
                        .testTag("notification-performance-row"),
                    verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    val icon = when (item.kind) {
                        CreatorActivity.Kind.COMMENT -> Icons.Outlined.ChatBubbleOutline
                        CreatorActivity.Kind.REPLY -> Icons.AutoMirrored.Filled.Reply
                        else -> Icons.Filled.Favorite
                    }
                    Icon(icon, null, tint = if (item.kind.isLike) p.recording else p.accent, modifier = Modifier.width(28.dp))
                    Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        Text(item.title, color = p.ink, fontSize = 15.sp, fontWeight = if (item.isUnread) FontWeight.Bold else FontWeight.Normal)
                        if (item.body.isNotEmpty()) Text(item.body, color = p.muted, maxLines = 2)
                        Text(relativeTime(item.createdAtInstant), color = p.muted, fontSize = 11.sp)
                    }
                    if (item.isUnread) Box(Modifier.size(7.dp).clip(CircleShape).background(p.accent).semantics { contentDescription = "Unread" })
                }
            }
            if (more) item { TextButton(onClick = { scope.launch { load(append = true) } }, enabled = !loading, modifier = Modifier.padding(12.dp)) { Text("Load more activity", color = p.accent) } }
        }
    }

    opened?.let { item ->
        NotificationPerformance(item, onDismiss = { opened = null }, onStart = onStart, onRead = {
            items = items.map { if (it.id == item.id && it.timestamp == item.timestamp) it.copy(readAt = Instant.now().toString()) else it }
        })
    }
}

/** iOS `NotificationPerformanceView`: resolves the post, then shows it with the notification card. */
@Composable
private fun NotificationPerformance(item: CreatorActivity, onDismiss: () -> Unit, onStart: (PerformanceStart) -> Unit, onRead: () -> Unit) {
    val social = rememberSocial() ?: return
    val p = LocalStudioPalette.current
    var video by remember { mutableStateOf<Video?>(null) }
    var failed by remember { mutableStateOf(false) }
    var unavailable by remember { mutableStateOf(false) }
    var attempt by remember { mutableStateOf(0) }
    LaunchedEffect(attempt) {
        failed = false
        try {
            val resolved = social.feed.video(item.videoId)
            if (resolved == null) unavailable = true else video = resolved
        } catch (e: kotlinx.coroutines.CancellationException) {
            throw e
        } catch (e: Exception) {
            failed = true
        }
    }
    val resolved = video
    if (resolved != null) {
        CreatorVideoSheet(resolved, onDismiss = onDismiss, notification = item, onNotificationRead = onRead,
            onTrySound = { onDismiss(); onStart(PerformanceStart.Preset(it)) })
    } else {
        SocialScreen("Performance", onDismiss, dismissOnLeading = true) {
            Column(Modifier.fillMaxSize(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center) {
                when {
                    unavailable -> Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Outlined.PlayCircle, null, tint = p.muted); Text("  This video is no longer available.", color = p.ink)
                    }
                    failed -> { Text("Couldn't open the video.", color = p.ink); TextButton(onClick = { attempt++ }) { Text("Try again", color = p.accent) } }
                    else -> { CircularProgressIndicator(color = p.accent); Text("Opening video", color = p.muted) }
                }
            }
        }
    }
}
