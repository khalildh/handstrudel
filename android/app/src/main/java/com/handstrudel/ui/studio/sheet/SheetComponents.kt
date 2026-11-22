package com.handstrudel.ui.studio.sheet

import androidx.compose.ui.platform.testTag
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.Icons
import com.handstrudel.ui.theme.StudioFonts
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.handstrudel.app.LocalAppServices
import com.handstrudel.ui.theme.LocalStudioPalette

// Small building blocks shared by the control-sheet tabs (iOS ControlSheet
// toggles, emoji tiles with PRO badges, capsule choices, circle steppers).

/** iOS `Toggle` with the 11 pt rounded label used throughout `modeSection`. */
@Composable
internal fun SheetToggle(label: String, checked: Boolean, modifier: Modifier = Modifier, onChange: (Boolean) -> Unit) {
    val palette = LocalStudioPalette.current
    Row(
        modifier.fillMaxWidth().heightIn(min = 44.dp).clickable { onChange(!checked) },
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(label, fontSize = 13.sp, fontWeight = FontWeight.Medium, fontFamily = StudioFonts.Rounded, color = palette.ink.copy(alpha = 0.8f), modifier = Modifier.weight(1f))
        Switch(
            checked = checked,
            onCheckedChange = onChange,
            colors = SwitchDefaults.colors(
                checkedTrackColor = palette.accent,
                checkedThumbColor = palette.onAccent,
                uncheckedTrackColor = palette.ink.copy(alpha = 0.08f),
                uncheckedThumbColor = palette.muted,
                uncheckedBorderColor = palette.border,
            ),
        )
    }
}

@Composable
internal fun SheetSlider(
    value: Float,
    range: ClosedFloatingPointRange<Float>,
    modifier: Modifier = Modifier,
    steps: Int = 0,
    tint: Color = LocalStudioPalette.current.accent,
    onValueChangeFinished: (() -> Unit)? = null,
    onChange: (Float) -> Unit,
) {
    val palette = LocalStudioPalette.current
    Slider(
        value = value.coerceIn(range.start, range.endInclusive),
        onValueChange = onChange,
        valueRange = range,
        steps = steps,
        onValueChangeFinished = onValueChangeFinished,
        modifier = modifier,
        colors = SliderDefaults.colors(
            thumbColor = tint,
            activeTrackColor = tint,
            inactiveTrackColor = palette.ink.copy(alpha = 0.1f),
            activeTickColor = Color.Transparent,
            inactiveTickColor = Color.Transparent,
        ),
    )
}

/**
 * iOS waveform / drum-loop card: emoji over a label in a 48 pt rounded tile,
 * accent gradient when selected, "PRO" capsule and 50 % opacity when locked.
 */
@Composable
internal fun EmojiTile(
    emoji: String,
    label: String,
    selected: Boolean,
    locked: Boolean,
    modifier: Modifier = Modifier,
    compact: Boolean = false,
    emojiSize: TextUnit = 20.sp,
    onClick: () -> Unit,
) {
    val palette = LocalStudioPalette.current
    val radius: Dp = if (compact) 10.dp else 12.dp
    val shape = RoundedCornerShape(radius)
    val background = if (compact) {
        Modifier.background(if (selected) palette.accent.copy(alpha = 0.12f) else palette.ink.copy(alpha = 0.04f), shape)
    } else {
        Modifier.background(
            if (selected) Brush.verticalGradient(listOf(palette.accent.copy(alpha = 0.2f), palette.accent.copy(alpha = 0.08f)))
            else Brush.verticalGradient(listOf(palette.ink.copy(alpha = 0.04f), palette.ink.copy(alpha = 0.02f))),
            shape,
        )
    }
    val border = when {
        compact && selected -> Modifier.border(1.5.dp, palette.accent.copy(alpha = 0.4f), shape)
        compact -> Modifier
        selected -> Modifier.border(1.5.dp, palette.accent.copy(alpha = 0.5f), shape)
        else -> Modifier.border(0.5.dp, palette.ink.copy(alpha = 0.06f), shape)
    }
    Box(
        modifier
            .fillMaxWidth()
            .then(if (compact) Modifier else Modifier.height(48.dp))
            .clip(shape)
            .then(background)
            .then(border)
            .clickable(onClick = onClick),
    ) {
        Column(
            Modifier.fillMaxWidth().alpha(if (locked) 0.5f else 1f).align(Alignment.Center)
                .then(if (compact) Modifier.padding(vertical = 8.dp) else Modifier),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(if (compact) 2.dp else 4.dp, Alignment.CenterVertically),
        ) {
            Text(emoji, fontSize = emojiSize)
            Text(
                label,
                fontSize = if (compact) 8.sp else 10.sp,
                fontWeight = FontWeight.SemiBold,
                fontFamily = StudioFonts.Rounded,
                color = if (selected) palette.accent else palette.ink.copy(alpha = 0.6f),
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.padding(horizontal = 2.dp),
            )
        }
        if (locked) TileProBadge(Modifier.align(Alignment.TopEnd).padding(5.dp))
    }
}

/**
 * iOS's tiny "PRO" capsule on locked tiles (8 pt heavy rounded, ink 80 % on
 * `.ultraThinMaterial`, 5 pt inset from the top-trailing corner). When the store isn't
 * configured the WS3 rules say locked items read "Not available yet": the phrase doesn't
 * fit a PRO-sized capsule on a 48 pt tile without covering the emoji, so the capsule shows
 * a lock glyph (announced as "Not available yet") and the section header carries the
 * words ([com.handstrudel.ui.studio.common.SectionHeader] `notAvailable`).
 */
@Composable
internal fun TileProBadge(modifier: Modifier = Modifier) {
    val palette = LocalStudioPalette.current
    val configured = LocalAppServices.current.store.isConfigured
    val capsule = modifier.clip(CircleShape).background(palette.ink.copy(alpha = 0.12f))
    if (configured) {
        Text(
            "PRO",
            fontSize = 8.sp,
            fontWeight = FontWeight.ExtraBold,
            fontFamily = StudioFonts.Rounded,
            color = palette.ink.copy(alpha = 0.8f),
            maxLines = 1,
            softWrap = false,
            modifier = capsule.padding(horizontal = 5.dp, vertical = 2.dp),
        )
    } else {
        Box(capsule.padding(horizontal = 4.dp, vertical = 2.dp).testTag("tile-not-available")) {
            Icon(Icons.Filled.Lock, contentDescription = "Not available yet", tint = palette.ink.copy(alpha = 0.8f), modifier = Modifier.size(9.dp))
        }
    }
}

/** iOS capsule choice (quantize ¼ ⅛ 1/16, loop length): accent text + 15 % fill when selected. */
@Composable
internal fun CapsuleChoice(label: String, selected: Boolean, modifier: Modifier = Modifier, monospaced: Boolean = false, onClick: () -> Unit) {
    val palette = LocalStudioPalette.current
    Box(modifier.heightIn(min = 36.dp).clip(CircleShape).clickable(onClick = onClick), contentAlignment = Alignment.Center) {
        Text(
            label,
            fontSize = 11.sp,
            fontWeight = FontWeight.Bold,
            fontFamily = if (monospaced) StudioFonts.Mono else StudioFonts.Rounded,
            color = if (selected) palette.accent else palette.muted,
            modifier = Modifier.clip(CircleShape)
                .background(if (selected) palette.accent.copy(alpha = 0.15f) else palette.ink.copy(alpha = 0.04f))
                .padding(horizontal = 9.dp, vertical = 6.dp),
        )
    }
}

/** iOS minus / plus circle stepper buttons. */
@Composable
internal fun CircleIconButton(
    icon: ImageVector,
    contentDescription: String,
    modifier: Modifier = Modifier,
    size: Dp = 32.dp,
    iconSize: Dp = 14.dp,
    tint: Color = LocalStudioPalette.current.ink.copy(alpha = 0.6f),
    background: Color = LocalStudioPalette.current.ink.copy(alpha = 0.06f),
    enabled: Boolean = true,
    onClick: () -> Unit,
) {
    Box(
        modifier.size(maxOf(size, 40.dp)).clip(CircleShape).clickable(enabled = enabled, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Box(Modifier.size(size).clip(CircleShape).background(background), contentAlignment = Alignment.Center) {
            Icon(icon, contentDescription, tint = tint, modifier = Modifier.size(iconSize))
        }
    }
}

/** Label + slider + trailing value row (iOS drum VOL / BPM rows). */
@Composable
internal fun LabeledSliderRow(
    label: String,
    valueText: String,
    value: Float,
    range: ClosedFloatingPointRange<Float>,
    steps: Int = 0,
    onChange: (Float) -> Unit,
) {
    val palette = LocalStudioPalette.current
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(label, fontSize = 9.sp, fontWeight = FontWeight.Bold, fontFamily = StudioFonts.Rounded, color = palette.muted.copy(alpha = 0.6f), modifier = Modifier.width(28.dp))
        SheetSlider(value, range, Modifier.weight(1f), steps = steps, onChange = onChange)
        Text(valueText, fontSize = 11.sp, fontFamily = StudioFonts.Mono, color = palette.muted, maxLines = 1, textAlign = TextAlign.End, modifier = Modifier.width(40.dp))
    }
}

/** Non-lazy fixed-column grid (iOS `LazyVGrid` of flexible columns, 8 pt spacing) for use inside a scrolling column. */
@Composable
internal fun <T> TileGrid(items: List<T>, columns: Int, modifier: Modifier = Modifier, cell: @Composable (T) -> Unit) {
    Column(modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        items.chunked(columns).forEach { row ->
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                row.forEach { item -> Box(Modifier.weight(1f)) { cell(item) } }
                repeat(columns - row.size) { Spacer(Modifier.weight(1f)) }
            }
        }
    }
}
