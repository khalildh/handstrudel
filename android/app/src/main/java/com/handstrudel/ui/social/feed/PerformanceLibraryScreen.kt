package com.handstrudel.ui.social.feed

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.GraphicEq
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
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.handstrudel.social.data.FeedService
import com.handstrudel.social.data.UnavailableException
import com.handstrudel.social.model.Video
import com.handstrudel.social.model.WeeklyChallenge
import com.handstrudel.ui.social.SocialScreen
import com.handstrudel.ui.social.rememberSocial
import com.handstrudel.ui.theme.LocalStudioPalette
import kotlinx.coroutines.launch
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle
import java.util.UUID

/** iOS `PerformanceLibraryView.Kind`. */
sealed interface LibraryKind {
    val title: String
    data object Saved : LibraryKind { override val title = "Saved performances" }
    data class Challenge(val challenge: WeeklyChallenge) : LibraryKind { override val title = "Weekly play-along" }
    data class Remixes(val video: Video) : LibraryKind { override val title = "Remixes" }
}

/** iOS `PerformanceLibraryView`: saved posts, the weekly challenge's takes, or a clip's remixes. */
@Composable
fun PerformanceLibraryScreen(kind: LibraryKind, onDismiss: () -> Unit, onRemove: (UUID) -> Unit = {}, onStart: (PerformanceStart) -> Unit) {
    val social = rememberSocial() ?: return
    val p = LocalStudioPalette.current
    val scope = rememberCoroutineScope()
    var items by remember { mutableStateOf<List<Video>>(emptyList()) }
    var source by remember { mutableStateOf<Video?>(null) }
    var selected by remember { mutableStateOf<Video?>(null) }
    var more by remember { mutableStateOf(false) }
    var loading by remember { mutableStateOf(false) }
    var removing by remember { mutableStateOf<UUID?>(null) }
    var error by remember { mutableStateOf<String?>(null) }

    suspend fun load(append: Boolean = false) {
        if (loading) return
        loading = true
        error = null
        try {
            val last = if (append) items.lastOrNull() else null
            val page: List<Video> = when (kind) {
                LibraryKind.Saved -> social.feed.bookmarks(last)
                is LibraryKind.Remixes -> {
                    if (!append) source = social.feed.video(kind.video.id)?.takeIf { it.backingEnabled == true }
                    social.feed.remixes(kind.video.id, last)
                }
                is LibraryKind.Challenge -> {
                    if (!append) {
                        val current = social.feed.weeklyChallenge()
                        if (current == null || current.id != kind.challenge.id) {
                            source = null; items = emptyList(); more = false; return
                        }
                        source = social.feed.video(kind.challenge.sourceVideoId)?.takeIf { it.backingEnabled == true }
                    }
                    social.feed.page(after = last, challenge = kind.challenge.id)
                }
            }
            val previous = if (append) items else emptyList()
            val seen = previous.map { it.id }.toSet()
            items = previous + page.filter { it.id !in seen }
            more = page.size == FeedService.PAGE_SIZE
        } catch (e: UnavailableException) {
            error = e.message
        } catch (e: kotlinx.coroutines.CancellationException) {
            throw e
        } catch (e: Exception) {
            error = "Couldn't load performances. Try again."
        } finally {
            loading = false
        }
    }

    fun remove(video: Video) {
        val uid = social.auth.userId.value ?: return
        if (removing != null) return
        removing = video.id
        scope.launch {
            try {
                social.feed.setBookmark(false, video.id, uid)
                items = items.filter { it.id != video.id }
                onRemove(video.id)
            } catch (e: UnavailableException) {
                error = e.message
            } catch (e: Exception) {
                error = "Couldn't remove that performance. Try again."
            } finally { removing = null }
        }
    }

    LaunchedEffect(Unit) { load() }

    SocialScreen(kind.title, onDismiss) {
        LazyColumn(Modifier.weight(1f).fillMaxWidth()) {
            if (kind is LibraryKind.Challenge) {
                item {
                    val c = kind.challenge
                    Column(Modifier.padding(20.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text(c.title, color = p.ink, fontSize = 24.sp, fontFamily = FontFamily.Serif)
                        Text(c.prompt, color = p.ink)
                        c.endsAtInstant?.let {
                            Text("Ends " + DateTimeFormatter.ofLocalizedDateTime(FormatStyle.MEDIUM, FormatStyle.SHORT)
                                .format(it.atZone(ZoneId.systemDefault())), color = p.muted, fontSize = 12.sp)
                        }
                        val s = source
                        if (s != null) {
                            TextButton(onClick = { selected = s }) { Icon(Icons.Outlined.PlayCircle, null, tint = p.accent); Text("  Watch the backing clip", color = p.accent) }
                            TextButton(onClick = { onStart(PerformanceStart.Backing(s)) }, modifier = Modifier.testTag("challenge-play-along")) {
                                Icon(Icons.Filled.GraphicEq, null, tint = p.accent); Text("  Play along", color = p.accent, fontWeight = FontWeight.SemiBold)
                            }
                        } else if (!loading && error == null) {
                            Text("This challenge is no longer available.", color = p.muted)
                        }
                    }
                    Text("COMMUNITY TAKES", color = p.muted, fontSize = 12.sp, fontWeight = FontWeight.SemiBold, modifier = Modifier.padding(horizontal = 20.dp))
                }
            } else if (kind is LibraryKind.Remixes) {
                source?.let { s ->
                    item {
                        TextButton(onClick = { onStart(PerformanceStart.Backing(s)) }, modifier = Modifier.padding(horizontal = 12.dp)) {
                            Icon(Icons.Filled.GraphicEq, null, tint = p.accent); Text("  Play along", color = p.accent, fontWeight = FontWeight.SemiBold)
                        }
                    }
                }
            }
            error?.let { e ->
                item {
                    Column(Modifier.padding(20.dp)) {
                        Text(e, color = p.muted)
                        TextButton(onClick = { scope.launch { load() } }) { Text("Try again", color = p.accent) }
                    }
                }
            }
            if (items.isEmpty()) {
                item {
                    Box(Modifier.padding(20.dp)) {
                        if (loading) Row(verticalAlignment = Alignment.CenterVertically) {
                            CircularProgressIndicator(color = p.accent, modifier = Modifier.size(20.dp)); Text("  Loading performances", color = p.muted)
                        } else if (error == null) Text(
                            when (kind) {
                                LibraryKind.Saved -> "Save a performance from its options menu to find it here later. Only you can see this list."
                                is LibraryKind.Challenge -> "No takes yet. Play along and post a take to join this week's challenge."
                                is LibraryKind.Remixes -> "No remixes yet. Published Play Along clips will appear here."
                            }, color = p.muted,
                        )
                    }
                }
            }
            items(items, key = { it.id }) { video ->
                Row(verticalAlignment = Alignment.CenterVertically) {
                    PerformanceListRow(video, onClick = { selected = video }, modifier = Modifier.weight(1f))
                    if (kind == LibraryKind.Saved) {
                        TextButton(onClick = { remove(video) }, enabled = removing == null) { Text("Remove", color = p.recording) }
                    }
                }
            }
            if (more) item { TextButton(onClick = { scope.launch { load(append = true) } }, enabled = !loading, modifier = Modifier.padding(12.dp)) { Text("Load more", color = p.accent) } }
        }
    }
    selected?.let { video ->
        CreatorVideoSheet(video, onDismiss = { selected = null },
            onPlayAlong = { selected = null; onStart(PerformanceStart.Backing(it)) },
            onTrySound = { selected = null; onStart(PerformanceStart.Preset(it)) })
    }
}
