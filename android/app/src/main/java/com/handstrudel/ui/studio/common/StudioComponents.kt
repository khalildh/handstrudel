package com.handstrudel.ui.studio.common

import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.material.icons.filled.Lock
import com.handstrudel.ui.theme.StudioFonts
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.Check
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Stable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.handstrudel.app.LocalAppServices
import com.handstrudel.store.StoreGate
import com.handstrudel.ui.store.PaywallSheet
import com.handstrudel.ui.theme.LocalStudioPalette

// Shared studio building blocks, ported from iOS `StartOverlayView.swift`
// (`StudioSettingsPanel`, `StudioSettingsDivider`, `StudioSettingRow`,
// `StudioActionStyle`, `pickerCategory`, `ProBadge`). Owner: studio-ui.

/** iOS `StudioSettingsPanel`: surface card, 21 pt corners, hairline border. */
@Composable
fun StudioSettingsPanel(modifier: Modifier = Modifier, content: @Composable ColumnScope.() -> Unit) {
    val palette = LocalStudioPalette.current
    val shape = RoundedCornerShape(21.dp)
    Column(
        modifier.fillMaxWidth().clip(shape).background(palette.surface).border(1.dp, palette.border, shape),
        content = content,
    )
}

/** Panel with 16 dp inner padding (iOS ControlSheet `settingsPanel`). */
@Composable
fun StudioPaddedPanel(modifier: Modifier = Modifier, content: @Composable ColumnScope.() -> Unit) =
    StudioSettingsPanel(modifier) { Column(Modifier.padding(16.dp), content = content) }

/** iOS `StudioSettingsDivider`: hairline inset 58 pt. */
@Composable
fun StudioSettingsDivider() {
    val palette = LocalStudioPalette.current
    Box(Modifier.padding(start = 58.dp).fillMaxWidth().height(1.dp).background(palette.border))
}

/** iOS `StudioSettingRow`: icon tile, title, monospaced value, chevron. */
@Composable
fun StudioSettingRow(
    title: String,
    icon: ImageVector,
    value: String? = null,
    modifier: Modifier = Modifier,
    trailing: ImageVector = Icons.AutoMirrored.Filled.KeyboardArrowRight,
    onClick: (() -> Unit)? = null,
) {
    val palette = LocalStudioPalette.current
    Row(
        modifier
            .fillMaxWidth()
            .heightIn(min = 54.dp)
            .then(if (onClick != null) Modifier.clickable(onClick = onClick) else Modifier)
            .padding(horizontal = 15.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(11.dp),
    ) {
        Box(
            Modifier.size(32.dp).clip(RoundedCornerShape(9.dp)).background(palette.accent.copy(alpha = 0.09f)),
            contentAlignment = Alignment.Center,
        ) { Icon(icon, null, tint = palette.accent, modifier = Modifier.size(17.dp)) }
        if (isAccessibilityTextSize()) {
            // iOS stacks title over value at accessibility sizes.
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                Text(title, fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = palette.ink)
                if (value != null) Text(value, fontSize = 14.sp, fontFamily = StudioFonts.Mono, color = palette.muted)
            }
        } else {
            Text(title, fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = palette.ink)
            Spacer(Modifier.weight(1f).widthIn(min = 4.dp))
            if (value != null) {
                Text(
                    value, fontSize = 14.sp, fontFamily = StudioFonts.Mono, color = palette.muted,
                    textAlign = TextAlign.End, maxLines = 2,
                )
            }
        }
        Icon(trailing, null, tint = palette.muted, modifier = Modifier.size(16.dp))
    }
}

/**
 * iOS `DynamicTypeSize.isAccessibilitySize`: the text scale is past the largest
 * standard size (iOS AX1 is about 1.6× the default), so layouts stack vertically.
 */
@Composable
fun isAccessibilityTextSize(): Boolean = LocalDensity.current.fontScale >= 1.5f

/** iOS `StudioActionStyle`: full-width accent button, 54 pt min height, 17 pt corners. */
@Composable
fun StudioActionButton(
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    onClick: () -> Unit,
    content: @Composable RowScope.() -> Unit,
) {
    val palette = LocalStudioPalette.current
    Row(
        modifier
            .fillMaxWidth()
            .heightIn(min = 54.dp)
            .clip(RoundedCornerShape(17.dp))
            .background(if (enabled) palette.accent else palette.accent.copy(alpha = 0.4f))
            .clickable(enabled = enabled, onClick = onClick)
            .padding(horizontal = 18.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
        content = content,
    )
}

/** iOS `pickerCategory`: capsule chip (accent when selected). */
@Composable
fun PickerCategoryChip(title: String, selected: Boolean, modifier: Modifier = Modifier, onClick: () -> Unit) {
    val palette = LocalStudioPalette.current
    Box(modifier.heightIn(min = 44.dp).clickable(onClick = onClick), contentAlignment = Alignment.Center) {
        Text(
            title,
            fontSize = 15.sp,
            fontWeight = FontWeight.Medium,
            color = if (selected) palette.onAccent else palette.ink,
            modifier = Modifier
                .clip(CircleShape)
                .background(if (selected) palette.accent else palette.ink.copy(alpha = 0.06f))
                .padding(horizontal = 13.dp, vertical = 7.dp),
        )
    }
}

/**
 * The lock pill on locked rows (iOS `ProBadge`: "PRO" capsule in the accent).
 * When the store isn't configured (no RevenueCat key) locked items read
 * "Not available yet" instead, per the WS3 rules.
 */
@Composable
fun LockBadge(modifier: Modifier = Modifier) {
    val palette = LocalStudioPalette.current
    val configured = LocalAppServices.current.store.isConfigured
    Text(
        if (configured) "PRO" else "Not available yet",
        fontSize = 11.sp,
        fontFamily = StudioFonts.Mono,
        fontWeight = FontWeight.SemiBold,
        color = palette.accent,
        maxLines = 1,
        modifier = modifier
            .testTag("pro-badge")
            .clip(CircleShape)
            .background(palette.accent.copy(alpha = 0.10f))
            .padding(horizontal = 8.dp, vertical = 3.dp),
    )
}

/**
 * Locked-content gate. [isLocked] asks the [StoreGate]; [open] shows the
 * store's `PaywallSheet` for a pack, or does nothing when the store isn't
 * configured ("Not available yet").
 */
@Stable
class PaywallHost internal constructor(val store: StoreGate) {
    var packId by mutableStateOf<String?>(null)
        internal set

    /** Mirrors `store.state`, so every composable that asks [isLocked] (lazy rows too) recomposes after a purchase or restore. */
    internal var storeState by mutableStateOf(store.state.value)

    fun isLocked(packId: String?): Boolean {
        storeState // snapshot read
        return !store.isUnlocked(packId)
    }

    fun open(packId: String) {
        if (store.isConfigured) this.packId = packId
    }

    /** Runs [action] when [packId] is unlocked, else opens the paywall. */
    inline fun gate(packId: String?, action: () -> Unit) {
        if (packId == null || !isLocked(packId)) action() else open(packId)
    }
}

/** Remembers a [PaywallHost] and hosts its paywall sheet in this composition. */
@Composable
fun rememberPaywallHost(): PaywallHost {
    val store = LocalAppServices.current.store
    val host = remember(store) { PaywallHost(store) }
    LaunchedEffect(host) { store.state.collect { host.storeState = it } }
    host.packId?.let { id -> PaywallSheet(packId = id, onDismiss = { host.packId = null }) }
    return host
}

/**
 * iOS sheet with a `NavigationStack` title bar: centred title, a leading and a
 * trailing text action (e.g. "Cancel" / "Done"), palette background, full
 * height.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun StudioSheet(
    title: String,
    onDismiss: () -> Unit,
    modifier: Modifier = Modifier,
    leadingAction: Pair<String, () -> Unit>? = null,
    trailingAction: Pair<String, () -> Unit>? = "Done" to onDismiss,
    trailingEnabled: Boolean = true,
    trailingTag: String? = null,
    header: (@Composable ColumnScope.() -> Unit)? = null,
    grabber: Boolean = true,
    mediumDetent: Boolean = false,
    content: @Composable ColumnScope.() -> Unit,
) {
    val palette = LocalStudioPalette.current
    // iOS `.presentationDetents([.large])` (or `[.medium, .large]` when [mediumDetent]): the
    // sheet is full height and opens fully expanded (or half way); [grabber] mirrors
    // `.presentationDragIndicator(.visible)`.
    val state = rememberModalBottomSheetState(skipPartiallyExpanded = !mediumDetent)
    ModalBottomSheet(
        modifier = Modifier.statusBarsPadding(),
        onDismissRequest = onDismiss,
        sheetState = state,
        containerColor = palette.background,
        contentColor = palette.ink,
        dragHandle = if (grabber) ({ SheetGrabber() }) else null,
    ) {
        Column(modifier.fillMaxWidth().fillMaxHeight().navigationBarsPadding()) {
            Box(Modifier.fillMaxWidth().height(52.dp).padding(horizontal = 8.dp)) {
                leadingAction?.let { (label, action) ->
                    SheetTextButton(label, Modifier.align(Alignment.CenterStart), onClick = action)
                }
                Text(
                    title, fontSize = 17.sp, fontWeight = FontWeight.SemiBold, color = palette.ink,
                    modifier = Modifier.align(Alignment.Center),
                )
                trailingAction?.let { (label, action) ->
                    SheetTextButton(
                        label, Modifier.align(Alignment.CenterEnd).then(if (trailingTag != null) Modifier.testTag(trailingTag) else Modifier),
                        enabled = trailingEnabled, bold = true, onClick = action,
                    )
                }
            }
            header?.invoke(this)
            content()
        }
    }
}

/** iOS sheet drag indicator: a 36x5 capsule at 30 % ink, 5 pt below the sheet's top edge. */
@Composable
fun SheetGrabber() {
    val palette = LocalStudioPalette.current
    Box(Modifier.fillMaxWidth().padding(top = 5.dp, bottom = 3.dp).testTag("sheet-grabber"), contentAlignment = Alignment.Center) {
        Box(Modifier.size(width = 36.dp, height = 5.dp).clip(CircleShape).background(palette.ink.copy(alpha = 0.3f)))
    }
}

@Composable
fun SheetTextButton(label: String, modifier: Modifier = Modifier, enabled: Boolean = true, bold: Boolean = false, onClick: () -> Unit) {
    val palette = LocalStudioPalette.current
    Box(
        modifier.heightIn(min = 44.dp).widthIn(min = 44.dp).clip(RoundedCornerShape(10.dp))
            .clickable(enabled = enabled, onClick = onClick).padding(horizontal = 10.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            label, fontSize = 17.sp,
            fontWeight = if (bold) FontWeight.SemiBold else FontWeight.Normal,
            color = if (enabled) palette.accent else palette.muted.copy(alpha = 0.5f),
        )
    }
}

/** iOS ControlSheet `sectionHeader`: small icon + tracked rounded caps. */
@Composable
fun SectionHeader(title: String, icon: ImageVector, modifier: Modifier = Modifier, notAvailable: Boolean = false) {
    val palette = LocalStudioPalette.current
    Row(modifier, verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        Icon(icon, null, tint = palette.accent.copy(alpha = 0.6f), modifier = Modifier.size(12.dp))
        Text(title, fontSize = 12.sp, fontWeight = FontWeight.Bold, fontFamily = StudioFonts.Rounded, color = palette.muted, letterSpacing = 1.5.sp)
        // Android-only (no store configured): the words for the lock glyphs on this
        // section's tiles, in the row-badge style, instead of a label on every tile.
        if (notAvailable && !LocalAppServices.current.store.isConfigured) {
            Spacer(Modifier.width(2.dp))
            Row(
                Modifier.testTag("section-not-available").clip(CircleShape).background(palette.ink.copy(alpha = 0.06f))
                    .padding(horizontal = 6.dp, vertical = 2.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(3.dp),
            ) {
                Icon(Icons.Filled.Lock, null, tint = palette.muted, modifier = Modifier.size(9.dp))
                Text("Not available yet", fontSize = 10.sp, fontWeight = FontWeight.SemiBold, fontFamily = StudioFonts.Rounded, color = palette.muted, maxLines = 1)
            }
        }
    }
}

/** A plain list row for picker sheets: title (+ subtitle), lock badge, checkmark. */
@Composable
fun PickerRow(
    title: String,
    selected: Boolean,
    locked: Boolean,
    modifier: Modifier = Modifier,
    subtitle: String? = null,
    onClick: () -> Unit,
) {
    val palette = LocalStudioPalette.current
    Row(
        modifier.fillMaxWidth().heightIn(min = 48.dp).clickable(onClick = onClick).padding(horizontal = 20.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Column {
            Text(title, fontSize = 15.sp, fontWeight = FontWeight.Medium, color = if (locked) palette.muted else palette.ink)
            if (subtitle != null) Text(subtitle, fontSize = 12.sp, color = palette.muted)
        }
        if (locked) LockBadge()
        Spacer(Modifier.weight(1f))
        if (selected && !locked) {
            Icon(Icons.Filled.Check, null, tint = palette.accent, modifier = Modifier.size(18.dp))
        }
    }
}

/** Width helper for the iOS `frame(maxWidth: 520/620)` content column. */
fun Modifier.studioContentWidth(max: Int = 620): Modifier = this.widthIn(max = max.dp).fillMaxWidth()

