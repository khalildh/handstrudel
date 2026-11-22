package com.handstrudel.ui.social.account

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.GraphicEq
import androidx.compose.material.icons.filled.GridView
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Repeat
import androidx.compose.material.icons.filled.VisibilityOff
import androidx.compose.material.icons.outlined.PlayCircle
import androidx.compose.material.icons.outlined.Visibility
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.handstrudel.models.SoundSetup
import com.handstrudel.social.data.FeedService
import com.handstrudel.social.data.ProfileImageStore
import com.handstrudel.social.data.UnavailableException
import com.handstrudel.social.model.Video
import com.handstrudel.ui.social.EmptyCard
import com.handstrudel.ui.social.ProfileActionButton
import com.handstrudel.ui.social.ProfileEyebrow
import com.handstrudel.ui.social.ProfileImage
import com.handstrudel.ui.social.compactCount
import com.handstrudel.ui.social.rememberSocial
import com.handstrudel.ui.social.viewsLabel
import com.handstrudel.ui.theme.LocalStudioPalette
import kotlinx.coroutines.launch

private enum class PortfolioTab(val title: String, val icon: ImageVector) {
    CLIPS("Performances", Icons.Filled.GridView), SOUNDS("Sounds", Icons.Filled.GraphicEq), REPOSTS("Reposts", Icons.Filled.Repeat);
    val tag: String get() = "profile-${title.lowercase()}"
}

/** iOS `CreatorPortfolio`: Performances (spotlight + grid), Sounds, and (own profile) Reposts. */
@OptIn(ExperimentalFoundationApi::class)
@Composable
fun CreatorPortfolio(
    videos: List<Video>,
    loading: Boolean,
    failed: Boolean,
    more: Boolean,
    isOwner: Boolean,
    open: (Video) -> Unit,
    trySound: (SoundSetup) -> Unit,
    retry: () -> Unit,
    loadMore: () -> Unit,
    makeMusic: (() -> Unit)? = null,
    delete: ((Video) -> Unit)? = null,
) {
    val social = rememberSocial() ?: return
    val p = LocalStudioPalette.current
    val scope = rememberCoroutineScope()
    var tab by remember { mutableStateOf(PortfolioTab.CLIPS) }
    var reposts by remember { mutableStateOf<List<Video>>(emptyList()) }
    var loadingReposts by remember { mutableStateOf(true) }
    var moreReposts by remember { mutableStateOf(false) }
    var repostError by remember { mutableStateOf<String?>(null) }
    var repostRemovalFailed by remember { mutableStateOf(false) }
    var repostRequest by remember { mutableStateOf(0) }

    suspend fun loadReposts(append: Boolean = false) {
        if (!isOwner || (append && (loadingReposts || !moreReposts || reposts.isEmpty()))) return
        val request = ++repostRequest
        loadingReposts = true
        repostError = null
        try {
            val page = social.feed.myReposts(if (append) reposts.lastOrNull() else null)
            if (repostRequest != request) return
            reposts = if (append) reposts + page.filter { v -> reposts.none { it.id == v.id } } else page
            moreReposts = page.size == FeedService.PAGE_SIZE
        } catch (e: kotlinx.coroutines.CancellationException) {
            throw e
        } catch (e: Exception) {
            if (repostRequest == request) repostError = (e as? UnavailableException)?.message ?: "Couldn't load your reposts."
        } finally {
            if (repostRequest == request) loadingReposts = false
        }
    }
    LaunchedEffect(tab) { if (tab == PortfolioTab.REPOSTS) loadReposts() }

    Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
        Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(13.dp)).background(p.surface.copy(alpha = 0.42f)).padding(3.dp),
            horizontalArrangement = Arrangement.spacedBy(4.dp)) {
            for (option in if (isOwner) PortfolioTab.entries else listOf(PortfolioTab.CLIPS, PortfolioTab.SOUNDS)) {
                val selected = tab == option
                Row(
                    Modifier.weight(1f).heightIn(min = 44.dp).clip(RoundedCornerShape(10.dp))
                        .background(if (selected) p.surface else Color.Transparent)
                        .then(if (selected) Modifier.border(1.dp, p.border, RoundedCornerShape(10.dp)) else Modifier)
                        .clickable { tab = option }.testTag(option.tag),
                    horizontalArrangement = Arrangement.Center, verticalAlignment = Alignment.CenterVertically,
                ) {
                    val ink = if (selected) p.ink else p.muted
                    Icon(option.icon, null, tint = ink, modifier = Modifier.size(15.dp)); Spacer(Modifier.width(4.dp))
                    Text(option.title, color = ink, fontWeight = FontWeight.SemiBold, fontSize = 13.sp, maxLines = 1)
                }
            }
        }

        if (tab == PortfolioTab.CLIPS) videos.firstOrNull { it.hidden != true }?.let { Spotlight(it) { open(it) } }

        if (tab == PortfolioTab.REPOSTS) {
            if (reposts.isNotEmpty()) {
                Grid(reposts) { video ->
                    var menu by remember { mutableStateOf(false) }
                    Box {
                        Tile(video, creditCreator = true, onClick = { open(video) }, onLongClick = { menu = true })
                        DropdownMenu(expanded = menu, onDismissRequest = { menu = false }) {
                            DropdownMenuItem(text = { Text("Remove repost") }, onClick = {
                                menu = false
                                scope.launch {
                                    try {
                                        social.feed.setReposted(false, video.id)
                                        reposts = reposts.filter { it.id != video.id }
                                        loadReposts()
                                    } catch (e: Exception) { repostRemovalFailed = true }
                                }
                            })
                        }
                    }
                }
            } else if (!loadingReposts && repostError == null) {
                EmptyCard("No reposts yet", "Repost a clip from the feed to share it with your followers and find it here.", Icons.Filled.Repeat)
            }
            when {
                repostError != null -> {
                    Text(repostError!!, color = p.muted, fontSize = 13.sp)
                    ProfileActionButton("Try again", onClick = { scope.launch { loadReposts() } }, modifier = Modifier.fillMaxWidth())
                }
                loadingReposts -> Loading("Loading reposts")
                moreReposts -> ProfileActionButton("Load more reposts", onClick = { scope.launch { loadReposts(append = true) } }, modifier = Modifier.fillMaxWidth())
            }
        } else {
            if (tab == PortfolioTab.CLIPS) {
                if (videos.isEmpty() && !loading && !failed) {
                    EmptyCard("No performances yet",
                        if (isOwner) "Record a clip and post it to give people a first listen." else "Check back when this artist shares a clip.",
                        Icons.Outlined.PlayCircle)
                    if (makeMusic != null) ProfileActionButton("Make music", primary = true, onClick = makeMusic, modifier = Modifier.fillMaxWidth())
                } else {
                    Grid(videos) { video ->
                        var menu by remember { mutableStateOf(false) }
                        Box {
                            Tile(video, onClick = { open(video) }, onLongClick = if (delete != null) ({ menu = true }) else null)
                            if (delete != null) {
                                DropdownMenu(expanded = menu, onDismissRequest = { menu = false }) {
                                    DropdownMenuItem(text = { Text("Delete post", color = p.recording) }, onClick = { menu = false; delete(video) })
                                }
                            }
                        }
                    }
                }
            } else {
                Sounds(videos, loading, failed, trySound)
            }
            when {
                failed -> {
                    Text("Couldn't load performances.", color = p.muted, fontSize = 13.sp)
                    ProfileActionButton("Try again", onClick = retry, modifier = Modifier.fillMaxWidth())
                }
                loading -> Loading("Loading performances")
                more -> ProfileActionButton("Load more performances", onClick = loadMore, modifier = Modifier.fillMaxWidth())
            }
        }
    }
    if (repostRemovalFailed) {
        AlertDialog(onDismissRequest = { repostRemovalFailed = false }, title = { Text("Couldn't remove repost") },
            confirmButton = { TextButton(onClick = { repostRemovalFailed = false }) { Text("OK") } })
    }
}

@Composable
private fun Loading(text: String) {
    val p = LocalStudioPalette.current
    Row(Modifier.fillMaxWidth().padding(vertical = 16.dp), horizontalArrangement = Arrangement.Center, verticalAlignment = Alignment.CenterVertically) {
        CircularProgressIndicator(color = p.accent, modifier = Modifier.size(18.dp)); Text("  $text", color = p.muted)
    }
}

private fun clipTitle(video: Video): String = video.caption.trim().ifEmpty { video.instrument ?: "Performance" }

@Composable
private fun Spotlight(video: Video, onClick: () -> Unit) {
    val p = LocalStudioPalette.current
    Row(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(p.surface).border(1.dp, p.border, RoundedCornerShape(16.dp))
            .clickable(onClick = onClick).padding(10.dp).testTag("profile-latest-performance")
            .semantics(mergeDescendants = true) { contentDescription = "Watch latest performance: ${clipTitle(video)}" },
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(13.dp),
    ) {
        Box(Modifier.size(width = 60.dp, height = 69.dp).clip(RoundedCornerShape(9.dp))) { Thumbnail(video) }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            ProfileEyebrow("LATEST PERFORMANCE")
            Text(clipTitle(video), color = p.ink, fontSize = 20.sp, fontFamily = FontFamily.Serif, maxLines = 2)
            (video.soundSetup?.instrumentName ?: video.instrument)?.takeIf { it.isNotEmpty() }?.let { Text(it, color = p.muted, fontSize = 12.sp, maxLines = 1) }
            video.viewCount?.let { Text(viewsLabel(it), color = p.muted, fontSize = 12.sp) }
        }
        Box(Modifier.size(36.dp).clip(CircleShape).background(p.accent.copy(alpha = 0.12f)), contentAlignment = Alignment.Center) {
            Icon(Icons.Filled.PlayArrow, null, tint = p.accent, modifier = Modifier.size(16.dp))
        }
    }
}

@Composable
private fun Grid(videos: List<Video>, cell: @Composable (Video) -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(5.dp)) {
        videos.chunked(3).forEach { row ->
            Row(horizontalArrangement = Arrangement.spacedBy(5.dp)) {
                row.forEach { v -> Box(Modifier.weight(1f)) { cell(v) } }
                repeat(3 - row.size) { Spacer(Modifier.weight(1f)) }
            }
        }
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun Tile(video: Video, creditCreator: Boolean = false, onClick: () -> Unit, onLongClick: (() -> Unit)?) {
    Box(
        Modifier.fillMaxWidth().aspectRatio(3f / 4f).clip(RoundedCornerShape(8.dp))
            .combinedClickable(onClick = onClick, onLongClick = onLongClick)
            .semantics { contentDescription = "Watch ${clipTitle(video)}" + if (creditCreator) video.username?.let { " by @$it" }.orEmpty() else "" }
            .testTag("profile-tile"),
    ) {
        Thumbnail(video)
        if (video.hidden == true) {
            Box(Modifier.align(Alignment.TopEnd).padding(5.dp).clip(RoundedCornerShape(50)).background(Color.Black.copy(alpha = 0.65f)).padding(6.dp)) {
                Icon(Icons.Filled.VisibilityOff, "Hidden", tint = Color.White, modifier = Modifier.size(12.dp))
            }
        }
        Column(Modifier.align(Alignment.BottomStart).padding(5.dp).clip(RoundedCornerShape(7.dp)).background(Color.Black.copy(alpha = 0.72f)).padding(5.dp)) {
            if (creditCreator && video.username != null) Text("@${video.username}", color = Color.White, fontSize = 11.sp, fontWeight = FontWeight.SemiBold, maxLines = 1)
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Filled.Favorite, null, tint = Color.White, modifier = Modifier.size(10.dp))
                Text(" ${compactCount(video.likeCount)}", color = Color.White, fontSize = 11.sp, fontWeight = FontWeight.SemiBold)
                video.viewCount?.let {
                    Spacer(Modifier.width(6.dp)); Icon(Icons.Outlined.Visibility, null, tint = Color.White, modifier = Modifier.size(10.dp))
                    Text(" ${compactCount(it)}", color = Color.White, fontSize = 11.sp, fontWeight = FontWeight.SemiBold)
                }
            }
        }
    }
}

/** iOS `ProfileThumbnail`: artwork + waveform glyph, the thumbnail on top unless hidden. */
@Composable
private fun Thumbnail(video: Video) {
    val p = LocalStudioPalette.current
    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        ProfileArtwork()
        Icon(Icons.Filled.GraphicEq, null, tint = p.accent.copy(alpha = 0.8f))
        if (video.hidden != true) {
            ProfileImage(ProfileImageStore.Resource(video.thumbUrl, ProfileImageStore.Kind.THUMBNAIL), Modifier.fillMaxSize())
        }
    }
}

@Composable
private fun Sounds(videos: List<Video>, loading: Boolean, failed: Boolean, trySound: (SoundSetup) -> Unit) {
    val p = LocalStudioPalette.current
    val seen = mutableListOf<SoundSetup>()
    val clips = videos.filter { v ->
        val sound = v.soundSetup
        if (v.hidden == true || sound == null || sound in seen) false else { seen += sound; true }
    }
    if (clips.isEmpty() && !loading && !failed) {
        EmptyCard("No playable sounds yet", "When a performance includes a sound setup, you can play it here.", Icons.Filled.GraphicEq)
    }
    clips.forEach { video ->
        val sound = video.soundSetup ?: return@forEach
        Row(
            Modifier.fillMaxWidth().clip(RoundedCornerShape(13.dp)).background(p.surface).border(1.dp, p.border, RoundedCornerShape(13.dp))
                .clickable { trySound(sound) }.padding(11.dp).testTag("profile-play-sound"),
            verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(11.dp),
        ) {
            Box(Modifier.size(42.dp).clip(RoundedCornerShape(10.dp)).background(p.accent.copy(alpha = 0.09f)), contentAlignment = Alignment.Center) {
                Icon(Icons.Filled.GraphicEq, null, tint = p.accent)
            }
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                Text(sound.instrumentName ?: "Performance sound", color = p.ink, fontWeight = FontWeight.SemiBold, fontSize = 16.sp)
                Text(sound.presetDetails, color = p.muted, fontSize = 12.sp)
            }
            Icon(Icons.Filled.PlayArrow, null, tint = p.accent, modifier = Modifier.size(16.dp))
        }
    }
}
