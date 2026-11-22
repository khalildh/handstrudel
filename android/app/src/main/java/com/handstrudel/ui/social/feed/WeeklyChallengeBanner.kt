package com.handstrudel.ui.social.feed

import com.handstrudel.ui.theme.StudioIcons

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.handstrudel.social.model.WeeklyChallenge
import com.handstrudel.ui.theme.LocalStudioPalette

/** The feed header's "Weekly play-along" capsule (iOS `overlaidHeader` challenge button). */
@Composable
fun WeeklyChallengeBanner(challenge: WeeklyChallenge, overVideo: Boolean, onOpen: () -> Unit) {
    val p = LocalStudioPalette.current
    val tint = if (overVideo) p.mediaAccent else p.accent
    Row(
        Modifier.heightIn(min = 36.dp).clip(RoundedCornerShape(50))
            .background(if (overVideo) Color.Black.copy(alpha = 0.6f) else p.surface)
            .clickable(onClick = onOpen).padding(horizontal = 12.dp, vertical = 8.dp)
            .semantics { contentDescription = "Weekly play-along: ${challenge.title}" }.testTag("weekly-challenge"),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(StudioIcons.Waveform, null, tint = tint, modifier = Modifier.size(14.dp))
        Spacer(Modifier.width(6.dp))
        Text(challenge.title, color = tint, fontSize = 12.sp, fontWeight = FontWeight.SemiBold, maxLines = 1, overflow = TextOverflow.Ellipsis)
    }
}
