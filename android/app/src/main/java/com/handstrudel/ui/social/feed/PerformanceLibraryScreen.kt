package com.handstrudel.ui.social.feed

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.lazy.itemsIndexed
import com.handstrudel.ui.theme.iosLight
import com.handstrudel.ui.theme.IosGrouped
import com.handstrudel.ui.theme.GroupedHeader
import com.handstrudel.ui.theme.GroupedCell
import com.handstrudel.ui.theme.StudioIcons

import com.handstrudel.ui.theme.StudioFonts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.handstrudel.social.data.FeedService
import com.handstrudel.social.data.UnavailableException
import com.handstrudel.social.model.Video
import com.handstrudel.social.model.WeeklyChallenge
import com.handstrudel.ui.social.SocialRefreshBox
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

    // iOS: a default inset grouped `List` (system sheet colours), one section for the challenge
    // card and one for the takes.
    val light = iosLight()
    val secondary = IosGrouped.secondaryLabel(light)
    val rowPad = Modifier.padding(horizontal = IosGrouped.CellInset, vertical = 11.dp)
    SocialScreen(kind.title, onDismiss, background = IosGrouped.background(light)) {
        SocialRefreshBox(onRefresh = { load() }, modifier = Modifier.weight(1f).fillMaxWidth()) {
        LazyColumn(Modifier.fillMaxSize(), contentPadding = PaddingValues(top = 35.dp, bottom = 24.dp)) {
            if (kind is LibraryKind.Challenge) {
                val c = kind.challenge
                val s = source
                val rows = buildList<@Composable () -> Unit> {
                    add { Text(c.title, color = p.ink, fontSize = 22.sp, fontFamily = StudioFonts.Serif, modifier = rowPad) }
                    add { Text(c.prompt, color = p.ink, fontSize = 17.sp, modifier = rowPad) }
                    c.endsAtInstant?.let { ends -> add { Text("Ends " + iosAbbreviatedDateTime(ends), color = secondary, fontSize = 12.sp, modifier = rowPad) } }
                    if (s != null) {
                        add { GroupedButtonRow(StudioIcons.PlayRectangle, "Watch the backing clip", p.accent) { selected = s } }
                        add {
                            GroupedButtonRow(StudioIcons.Waveform, "Play along", p.accent, bold = true, modifier = Modifier.testTag("challenge-play-along")) {
                                onStart(PerformanceStart.Backing(s))
                            }
                        }
                    } else if (!loading && error == null) {
                        add { Text("This challenge is no longer available.", color = secondary, fontSize = 17.sp, modifier = rowPad) }
                    }
                }
                itemsIndexed(rows) { i, row -> GroupedCell(i, rows.size) { row() } }
                item { Spacer(Modifier.height(35.dp)); GroupedHeader("Community takes") }
            } else if (kind is LibraryKind.Remixes) {
                source?.let { s ->
                    item {
                        GroupedCell(0, 1) { GroupedButtonRow(StudioIcons.Waveform, "Play along", p.accent, bold = true) { onStart(PerformanceStart.Backing(s)) } }
                        Spacer(Modifier.height(35.dp))
                    }
                }
            }
            val rows = buildList<@Composable () -> Unit> {
                error?.let { e ->
                    add { Text(e, color = secondary, fontSize = 17.sp, modifier = rowPad) }
                    add { Text("Try again", color = p.accent, fontSize = 17.sp, modifier = Modifier.fillMaxWidth().clickable { scope.launch { load() } }.then(rowPad)) }
                }
                if (items.isEmpty()) {
                    if (loading) add {
                        Row(rowPad, verticalAlignment = Alignment.CenterVertically) {
                            CircularProgressIndicator(color = p.accent, modifier = Modifier.size(20.dp)); Text("  Loading performances", color = secondary)
                        }
                    } else if (error == null) add {
                        Text(
                            when (kind) {
                                LibraryKind.Saved -> "Save a performance from its options menu to find it here later. Only you can see this list."
                                is LibraryKind.Challenge -> "No takes yet. Play along and post a take to join this week's challenge."
                                is LibraryKind.Remixes -> "No remixes yet. Published Play Along clips will appear here."
                            }, color = secondary, fontSize = 17.sp, modifier = rowPad,
                        )
                    }
                }
                items.forEach { video ->
                    add {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            PerformanceListRow(video, onClick = { selected = video }, modifier = Modifier.weight(1f))
                            if (kind == LibraryKind.Saved) {
                                TextButton(onClick = { remove(video) }, enabled = removing == null) { Text("Remove", color = p.recording) }
                            }
                        }
                    }
                }
                if (more) add {
                    Text("Load more", color = if (loading) secondary else p.accent, fontSize = 17.sp,
                        modifier = Modifier.fillMaxWidth().clickable(enabled = !loading) { scope.launch { load(append = true) } }.then(rowPad))
                }
            }
            itemsIndexed(rows) { i, row -> GroupedCell(i, rows.size) { row() } }
        }
        }
    }
    selected?.let { video ->
        CreatorVideoSheet(video, onDismiss = { selected = null },
            onPlayAlong = { selected = null; onStart(PerformanceStart.Backing(it)) },
            onTrySound = { selected = null; onStart(PerformanceStart.Preset(it)) })
    }
}

/** A `Button(title, systemImage:)` row in an inset grouped list: tinted glyph and 17 pt title. */
@Composable
internal fun GroupedButtonRow(icon: androidx.compose.ui.graphics.vector.ImageVector, title: String, tint: androidx.compose.ui.graphics.Color, bold: Boolean = false,
                              modifier: Modifier = Modifier, onClick: () -> Unit) {
    Row(
        modifier.fillMaxWidth().clickable(onClick = onClick).padding(horizontal = IosGrouped.CellInset, vertical = 11.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Icon(icon, null, tint = tint, modifier = Modifier.size(26.dp))
        Text(title, color = tint, fontSize = 17.sp, fontWeight = if (bold) FontWeight.SemiBold else FontWeight.Normal)
    }
}

/** Foundation `date.formatted(date: .abbreviated, time: .shortened)` in en: "Nov 28, 2026 at 2:22 PM". */
internal fun iosAbbreviatedDateTime(instant: java.time.Instant, zone: ZoneId = ZoneId.systemDefault(), locale: java.util.Locale = java.util.Locale.getDefault()): String {
    val t = instant.atZone(zone)
    val date = DateTimeFormatter.ofPattern("MMM d, yyyy", locale).format(t)
    val time = DateTimeFormatter.ofLocalizedTime(FormatStyle.SHORT).withLocale(locale).format(t)
    return "$date at $time"
}
