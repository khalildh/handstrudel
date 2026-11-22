package com.handstrudel.ui.studio.sheet

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.PanTool
import androidx.compose.material.icons.filled.PhotoFilter
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.handstrudel.app.LocalAppServices
import com.handstrudel.ui.capture.CaptureEntryPoints
import com.handstrudel.ui.studio.common.PaywallHost
import com.handstrudel.ui.studio.common.SectionHeader
import com.handstrudel.ui.studio.common.StudioPaddedPanel
import com.handstrudel.ui.studio.visual.CAMERA_FILTERS
import com.handstrudel.ui.studio.visual.HAND_THEMES

/** iOS ControlSheet `.capture`: recording settings (capture's), filters, hand themes. */
@Composable
internal fun CaptureTab(paywall: PaywallHost) {
    LocalAppServices.current.store.state.collectAsState().value
    StudioPaddedPanel { CaptureEntryPoints.RecordingSettingsSection() }
    StudioPaddedPanel { FiltersSection(paywall) }
    StudioPaddedPanel { HandThemesSection(paywall) }
}

/** iOS `filterSection`. */
@Composable
internal fun FiltersSection(paywall: PaywallHost) {
    val engine = LocalAppServices.current.engine
    val selected by engine.selectedFilter.collectAsState()
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        SectionHeader("FILTERS", Icons.Filled.PhotoFilter, notAvailable = CAMERA_FILTERS.any { it.isPremium && paywall.isLocked(it.packId) })
        TileGrid(CAMERA_FILTERS, columns = 4) { filter ->
            val locked = filter.isPremium && paywall.isLocked(filter.packId)
            EmojiTile(
                emoji = filter.emoji, label = filter.name, selected = selected == filter.id, locked = locked,
                compact = true, emojiSize = 18.sp, modifier = Modifier.testTag("filter-${filter.id}"),
            ) {
                if (locked) filter.packId?.let(paywall::open) else engine.setFilter(filter.id)
            }
        }
    }
}

/** iOS `handThemeSection`. */
@Composable
internal fun HandThemesSection(paywall: PaywallHost) {
    val engine = LocalAppServices.current.engine
    val selected by engine.selectedHandTheme.collectAsState()
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        SectionHeader("HAND THEME", Icons.Filled.PanTool, notAvailable = HAND_THEMES.any { it.isPremium && paywall.isLocked(it.packId) })
        TileGrid(HAND_THEMES, columns = 4) { theme ->
            val locked = theme.isPremium && paywall.isLocked(theme.packId)
            EmojiTile(
                emoji = theme.emoji, label = theme.name, selected = selected == theme.id, locked = locked,
                compact = true, emojiSize = 18.sp, modifier = Modifier.testTag("hand-theme-${theme.id}"),
            ) {
                if (locked) theme.packId?.let(paywall::open) else engine.setHandTheme(theme.id)
            }
        }
    }
}
