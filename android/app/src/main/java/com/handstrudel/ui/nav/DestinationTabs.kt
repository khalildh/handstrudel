package com.handstrudel.ui.nav

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.selection.selectableGroup
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Person
import androidx.compose.material.icons.outlined.SmartDisplay
import androidx.compose.material.icons.rounded.GraphicEq
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.handstrudel.ui.theme.LocalStudioPalette

/** iOS `Destination.rawValue` / `icon`. */
val Destination.title: String get() = name

private val Destination.icon: ImageVector
    get() = when (this) {
        Destination.Feed -> Icons.Outlined.SmartDisplay   // play.rectangle
        Destination.Music -> Icons.Rounded.GraphicEq      // waveform
        Destination.Account -> Icons.Outlined.Person      // person
    }

/**
 * Feed / Music / Account (iOS `ContentView.destinationTabs`). Owner: shell. Music always
 * carries the accent capsule (filled when selected, 16 % accent otherwise). [overVideo] is
 * the white-ink variant the Feed draws over its video (`tabBar(true)` slot). Disabled
 * while a session is starting. Test tags `tab-feed` / `tab-music` / `tab-account`.
 */
@Composable
fun DestinationTabs(
    selected: Destination,
    overVideo: Boolean,
    onSelect: (Destination) -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
) {
    val palette = LocalStudioPalette.current
    val ink = if (overVideo) Color.White else palette.ink
    val muted = if (overVideo) Color.White.copy(alpha = 0.78f) else palette.muted
    val accent = if (overVideo) palette.mediaAccent else palette.accent
    val onAccent = if (overVideo) palette.mediaOnAccent else palette.onAccent
    val border = palette.border

    val background = if (overVideo) {
        Modifier.background(Brush.verticalGradient(listOf(Color.Black.copy(alpha = 0.35f), Color.Black.copy(alpha = 0.92f))))
    } else {
        Modifier
            .background(palette.background)
            .drawBehind { drawLine(border, Offset(0f, 0f), Offset(size.width, 0f), strokeWidth = 1.dp.toPx()) }
    }

    Box(
        modifier
            .fillMaxWidth()
            .then(background)
            .windowInsetsPadding(WindowInsets.navigationBars)
            .semantics { contentDescription = "Main navigation" }
            .testTag("main-navigation"),
        contentAlignment = Alignment.Center,
    ) {
        Row(
            Modifier
                .widthIn(max = 520.dp)
                .fillMaxWidth()
                .padding(horizontal = 14.dp, vertical = 6.dp)
                .selectableGroup(),
            horizontalArrangement = Arrangement.SpaceEvenly,
        ) {
            Destination.entries.forEach { tab ->
                val isSelected = tab == selected
                val isMusic = tab == Destination.Music
                Column(
                    Modifier
                        .weight(1f)
                        .heightIn(min = 54.dp)
                        .selectable(selected = isSelected, enabled = enabled, role = Role.Tab) { onSelect(tab) }
                        .testTag("tab-${tab.title.lowercase()}"),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(5.dp, Alignment.CenterVertically),
                ) {
                    Box(
                        Modifier
                            .size(width = 56.dp, height = 31.dp)
                            .then(
                                if (isMusic) Modifier.clip(CircleShape).background(if (isSelected) accent else accent.copy(alpha = 0.16f))
                                else Modifier,
                            ),
                        contentAlignment = Alignment.Center,
                    ) {
                        Icon(
                            tab.icon,
                            contentDescription = null,
                            tint = when {
                                isMusic && isSelected -> onAccent
                                isSelected || isMusic -> accent
                                else -> muted
                            },
                            modifier = Modifier.size(22.dp),
                        )
                    }
                    Text(
                        tab.title,
                        fontSize = 11.sp,
                        fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Medium,
                        color = if (isSelected) ink else muted,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
            }
        }
    }
}
