package com.handstrudel.ui.social.feed

import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.Row
import androidx.compose.material3.Icon
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.automirrored.outlined.Send
import androidx.compose.material.icons.filled.Sync
import com.handstrudel.ui.theme.StudioIcons
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Send
import androidx.compose.material.icons.filled.Bookmark
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.MoreHoriz
import androidx.compose.material.icons.filled.Repeat
import androidx.compose.material.icons.outlined.BookmarkBorder
import androidx.compose.material.icons.outlined.ChatBubbleOutline
import androidx.compose.material.icons.outlined.FavoriteBorder
import androidx.compose.material.icons.outlined.Visibility
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.handstrudel.social.model.Video
import com.handstrudel.social.model.VideoEngagement
import com.handstrudel.ui.social.FeedVideoIcon
import com.handstrudel.ui.social.SocialMaterialTheme
import com.handstrudel.ui.social.compactCount
import com.handstrudel.ui.theme.LocalStudioPalette

/** Callbacks for the feed's action rail and its More menu (iOS `FeedActionRail`). */
class FeedRailActions(
    val like: () -> Unit,
    val comments: () -> Unit,
    val showRemixes: () -> Unit,
    val repost: () -> Unit,
    val share: () -> Unit,
    val bookmark: () -> Unit,
    val downloadAudio: () -> Unit,
    val changeAudioPermission: () -> Unit,
    val revokeBacking: () -> Unit,
    val delete: () -> Unit,
    val report: () -> Unit,
    val block: () -> Unit,
)

@Composable
fun FeedActionRail(
    video: Video,
    clip: FeedClip?,
    engagement: VideoEngagement?,
    maxHeight: Dp,
    isMine: Boolean,
    isSaved: Boolean,
    canDownloadAudio: Boolean,
    canChangeAudioPermission: Boolean,
    actions: FeedRailActions,
    modifier: Modifier = Modifier,
) {
    val p = LocalStudioPalette.current
    val liveViews = clip?.viewCount?.collectAsState()?.value
    Column(
        modifier.width(52.dp).heightIn(max = maxHeight).verticalScroll(rememberScrollState()).testTag("feed-action-rail"),
        verticalArrangement = Arrangement.spacedBy(3.dp, Alignment.Bottom),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        val liked = video.likedByMe == true
        Glyph(if (liked) Icons.Filled.Favorite else Icons.Outlined.FavoriteBorder, video.likeCount,
            tint = if (liked) p.recording else Color.White, label = if (liked) "Unlike" else "Like",
            value = "${video.likeCount} likes", tag = "feed-like", onClick = actions.like)
        val commentsOn = video.commentsEnabled == true
        Glyph(StudioIcons.BubbleRect, video.commentCount ?: 0,
            label = if (commentsOn) "Comments, ${video.commentCount ?: 0}" else if (isMine) "Manage comments" else "Comments off",
            enabled = commentsOn || isMine, tag = "video-comments-button", onClick = actions.comments)
        Glyph(StudioIcons.WaveformBadgePlusCircle, engagement?.remixes, label = "Remixes", tag = "feed-remix-count", onClick = actions.showRemixes)
        val didRepost = engagement?.repostedByMe == true
        Glyph(StudioIcons.ArrowTriangle2Circlepath, engagement?.reposts, tint = if (didRepost) p.mediaAccent else Color.White,
            label = if (isMine) "Reposts" else if (didRepost) "Remove repost" else "Repost",
            enabled = !isMine, tag = "feed-repost", onClick = actions.repost)
        Glyph(StudioIcons.Paperplane, engagement?.shares, label = "Share video", tag = "feed-share", onClick = actions.share)
        Glyph(if (isSaved) Icons.Filled.Bookmark else Icons.Outlined.BookmarkBorder, engagement?.saves,
            tint = if (isSaved) p.mediaAccent else Color.White,
            label = if (isSaved) "Remove from Saved" else "Save privately", tag = "save-performance", onClick = actions.bookmark)
        val views = clip?.let { liveViews?.let { v -> maxOf(v, video.viewCount ?: 0) } ?: video.viewCount } ?: video.viewCount
        Glyph(StudioIcons.Eye, views, label = "Views", value = views?.toString() ?: "Not available", tag = "feed-views-count", onClick = null)
        MoreMenu(video, isMine, canDownloadAudio, canChangeAudioPermission, actions)
    }
}

@Composable
private fun MoreMenu(video: Video, isMine: Boolean, canDownloadAudio: Boolean, canChangeAudioPermission: Boolean, actions: FeedRailActions) {
    // The rail is shared by every page and follows the current clip. Close the menu when the clip
    // changes (auto-advance at the end of a clip), as iOS does when the cell scrolls away, so it
    // never offers Block/Report/Delete for a different post than the one it was opened on.
    var open by remember(video.id) { mutableStateOf(false) }
    Box {
        Glyph(StudioIcons.Ellipsis, null, label = "More", reservesCount = false, tag = "feed-more", onClick = { open = true })
        SocialMaterialTheme(dark = true) {
            // iOS presents the rail's `Menu` above the button as a translucent dark material
            // card (13 pt corners, 17 pt rows, trailing SF glyphs, hairline separators) and,
            // opening upward, lists the items in reverse so the first sits nearest the button.
            DropdownMenu(
                expanded = open, onDismissRequest = { open = false },
                modifier = Modifier.width(250.dp),
                shape = RoundedCornerShape(13.dp),
                containerColor = Color(0xFF2A2A2A).copy(alpha = 0.78f),
                tonalElevation = 0.dp, shadowElevation = 12.dp,
            ) {
                val red = Color(0xFFFF453A)
                val rows = buildList<Triple<String, Pair<Color?, ImageVector?>, () -> Unit>> {
                    if (canDownloadAudio) add(Triple("Download audio", null to StudioIcons.ArrowDownCircle, actions.downloadAudio))
                    if (canChangeAudioPermission) {
                        add(Triple(if (canDownloadAudio) "Turn off audio downloads" else "Allow audio downloads", null to StudioIcons.Waveform, actions.changeAudioPermission))
                    }
                    if (isMine) {
                        if (video.backingEnabled == true) add(Triple("Stop allowing play-along", null to null, actions.revokeBacking))
                        add(Triple("Delete post", red to null, actions.delete))
                    } else {
                        add(Triple("Report", null to StudioIcons.Flag, actions.report))
                        add(Triple("Block @${video.username ?: "user"}", red to StudioIcons.HandRaised, actions.block))
                    }
                }.reversed()
                val accent = LocalStudioPalette.current.accent
                rows.forEachIndexed { index, (text, style, action) ->
                    if (index > 0) Box(Modifier.fillMaxWidth().height(0.5.dp).background(Color.White.copy(alpha = 0.16f)))
                    Row(
                        Modifier.fillMaxWidth().height(44.dp).clickable { open = false; action() }.padding(horizontal = 16.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text(text, color = style.first ?: Color.White, fontSize = 17.sp, fontWeight = FontWeight.Normal, maxLines = 1,
                            modifier = Modifier.weight(1f))
                        style.second?.let { icon -> Icon(icon, null, tint = accent, modifier = Modifier.size(22.dp)) }
                    }
                }
            }
        }
    }
}

@Composable
private fun Glyph(
    icon: ImageVector,
    count: Int?,
    label: String,
    tint: Color = Color.White,
    value: String? = null,
    enabled: Boolean = true,
    reservesCount: Boolean = true,
    tag: String,
    onClick: (() -> Unit)?,
) {
    Column(
        Modifier.heightIn(min = 44.dp).alpha(if (enabled) 1f else 0.45f)
            .then(if (onClick != null) Modifier.clickable(enabled = enabled, onClick = onClick) else Modifier)
            .semantics(mergeDescendants = true) { contentDescription = label; if (value != null) stateDescription = value }
            .testTag(tag),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        FeedVideoIcon(icon, null, tint = tint, size = 34)
        if (count != null || reservesCount) {
            Text(compactCount(count ?: 0), color = Color.White.copy(alpha = if (count == null) 0f else 1f),
                fontSize = 11.sp, fontWeight = FontWeight.Bold, maxLines = 1)
        }
    }
}
