package com.handstrudel.ui.social.feed

import com.handstrudel.ui.theme.StudioIcons
import com.handstrudel.ui.theme.iosLight
import com.handstrudel.ui.theme.IosGrouped
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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.outlined.PlayCircle
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil3.compose.AsyncImage
import com.handstrudel.social.model.Video
import com.handstrudel.ui.theme.LocalStudioPalette

/** iOS `PerformanceListRow`: thumbnail, @creator, caption, chevron. */
@Composable
fun PerformanceListRow(video: Video, onClick: () -> Unit, modifier: Modifier = Modifier) {
    val p = LocalStudioPalette.current
    Row(
        modifier.fillMaxWidth().clickable(onClick = onClick).padding(horizontal = 20.dp, vertical = 11.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Box(Modifier.size(width = 40.dp, height = 56.dp).clip(RoundedCornerShape(6.dp)).background(p.surface), contentAlignment = Alignment.Center) {
            Icon(Icons.Outlined.PlayCircle, null, tint = p.muted)
            AsyncImage(model = video.thumbUrl, contentDescription = null, contentScale = ContentScale.Crop, modifier = Modifier.fillMaxSize())
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text("@${video.username ?: "creator"}", color = p.ink, fontWeight = FontWeight.Bold, fontSize = 15.sp)
            Text(video.caption.ifEmpty { video.instrument ?: "Performance" }, color = IosGrouped.secondaryLabel(iosLight()), fontSize = 12.sp,
                maxLines = 2, overflow = TextOverflow.Ellipsis)
        }
        // iOS: `chevron.right` at `.caption` in the secondary label colour.
        Icon(StudioIcons.ChevronRight, null, tint = IosGrouped.secondaryLabel(iosLight()), modifier = Modifier.size(13.dp))
    }
}
