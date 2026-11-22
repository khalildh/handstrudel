package com.handstrudel.ui.social.account

import com.handstrudel.ui.theme.StudioFonts
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Share
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.handstrudel.app.shareText
import com.handstrudel.social.SocialConfig
import com.handstrudel.social.data.FeedService
import com.handstrudel.social.data.ProfileImageStore
import com.handstrudel.ui.social.ProfileEyebrow
import com.handstrudel.ui.social.ProfileImage
import com.handstrudel.ui.social.compactCount
import com.handstrudel.ui.theme.LocalStudioPalette

/** iOS `ProfileArtwork`: surface + top-right glow + concentric overtone rings. */
@Composable
fun BoxScope.ProfileArtwork() {
    val p = LocalStudioPalette.current
    Box(Modifier.matchParentSize().background(p.surface))
    Canvas(Modifier.matchParentSize()) {
        val center = Offset(size.width * 0.85f, size.height * 0.12f)
        drawRect(Brush.radialGradient(listOf(p.glow, p.surface.copy(alpha = 0.2f), Color.Transparent), center, 265.dp.toPx()))
        for (index in 0 until 15) {
            val radius = (15 + index * 11).dp.toPx()
            val alpha = if (index % 4 == 0) 0.24f else 0.10f
            val fade = (center.x - radius).coerceAtLeast(0f) / size.width
            drawCircle(p.overtone.copy(alpha = alpha * (0.3f + fade.coerceIn(0f, 1f) * 0.7f)), radius, center, style = Stroke(0.75.dp.toPx()))
        }
    }
}

/** iOS `CreatorProfileHeader`: eyebrow, avatar, artist name, @handle, stats, actions + share. */
@Composable
fun CreatorProfileHeader(
    username: String,
    displayName: String?,
    avatarKey: String?,
    counts: FeedService.ProfileCounts?,
    likesReceived: Int?,
    viewsReceived: Int?,
    isOwner: Boolean,
    actions: @Composable RowScope.() -> Unit,
) {
    val p = LocalStudioPalette.current
    val context = LocalContext.current
    val artistName = displayName?.trim().orEmpty().ifEmpty { username }
    val shape = RoundedCornerShape(23.dp)
    Box(Modifier.fillMaxWidth().clip(shape).border(1.dp, p.border, shape)) {
        ProfileArtwork()
        Column(Modifier.fillMaxWidth().padding(17.dp), verticalArrangement = Arrangement.spacedBy(15.dp)) {
            ProfileEyebrow(if (isOwner) "YOUR ARTIST PROFILE" else "HANDSTRUDEL ARTIST")
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(13.dp)) {
                Box(Modifier.size(68.dp).border(1.dp, p.accent.copy(alpha = 0.45f), CircleShape).padding(3.dp)) {
                    Box(Modifier.size(62.dp).clip(CircleShape).background(p.background), contentAlignment = Alignment.Center) {
                        Text(artistName.take(1).uppercase(), color = p.accent, fontSize = 30.sp, fontFamily = StudioFonts.Serif)
                        if (!avatarKey.isNullOrEmpty()) {
                            ProfileImage(ProfileImageStore.Resource(SocialConfig.mediaUrl(avatarKey), ProfileImageStore.Kind.AVATAR), Modifier.size(62.dp))
                        }
                    }
                }
                Column {
                    Text(artistName, color = p.ink, fontSize = 30.sp, fontFamily = StudioFonts.Serif, lineHeight = 34.sp)
                    Text("@$username", color = p.muted, fontSize = 15.sp, fontFamily = StudioFonts.Mono)
                }
            }
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Stat("Posts", counts?.posts)
                Stat("Followers", counts?.followers)
                Stat("Following", counts?.following)
                Stat("Likes", likesReceived, "Likes received", "profile-likes-received")
                Stat("Views", viewsReceived, "Total video views", "profile-views-received")
            }
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                Row(Modifier.weight(1f), content = actions)
                Box(
                    Modifier.size(46.dp).clip(RoundedCornerShape(13.dp)).background(p.background.copy(alpha = 0.65f))
                        .border(1.dp, p.border, RoundedCornerShape(13.dp))
                        .clickable { shareText(context, SocialConfig.creatorUrl(username)) }
                        .semantics { contentDescription = "Share profile" },
                    contentAlignment = Alignment.Center,
                ) { Icon(Icons.Filled.Share, null, tint = p.ink) }
            }
        }
    }
}

@Composable
private fun RowScope.Stat(name: String, count: Int?, spokenName: String? = null, tag: String? = null) {
    val p = LocalStudioPalette.current
    Column(
        Modifier.weight(1f).semantics(mergeDescendants = true) {
            contentDescription = spokenName ?: name
            stateDescription = count?.toString() ?: "Unavailable"
        }.then(if (tag != null) Modifier.testTag(tag) else Modifier),
    ) {
        Text(count?.let(::compactCount) ?: "–", color = p.ink, fontSize = 19.sp, fontFamily = StudioFonts.Mono, fontWeight = FontWeight.SemiBold, maxLines = 1)
        Text(name, color = p.muted, fontSize = 11.sp, maxLines = 1)
    }
}
