package com.handstrudel.ui.theme

import androidx.compose.foundation.clickable
import androidx.compose.ui.Alignment
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.foundation.layout.size

/**
 * The system colours SwiftUI uses for a default `Form` / `List` (inset grouped) presented in a
 * sheet, where iOS 1.0.1 does not override them with the studio palette: the elevated grouped
 * background, the cell fill, hairline separators and secondary label colour.
 */
object IosGrouped {
    /** `systemGroupedBackground` in an elevated sheet: #1C1C1E dark (measured), #F2F2F7 light. */
    fun background(light: Boolean): Color = if (light) Color(0xFFF2F2F7) else Color(0xFF1C1C1E)

    /** `secondarySystemGroupedBackground` elevated: #2C2C2E dark (measured), white light. */
    fun cell(light: Boolean): Color = if (light) Color.White else Color(0xFF2C2C2E)

    /** `separator`: rgba(84,84,88,0.65) dark, rgba(60,60,67,0.29) light. */
    fun separator(light: Boolean): Color = if (light) Color(0xFF3C3C43).copy(alpha = 0.29f) else Color(0xFF545458).copy(alpha = 0.65f)

    /** `secondaryLabel`: rgba(235,235,245,0.6) dark, rgba(60,60,67,0.6) light. */
    fun secondaryLabel(light: Boolean): Color = if (light) Color(0xFF3C3C43).copy(alpha = 0.6f) else Color(0xFFEBEBF5).copy(alpha = 0.6f)

    /** `tertiarySystemFill` used by the search field: rgba(118,118,128,0.24) dark, 0.12 light. */
    fun searchFill(light: Boolean): Color = Color(0xFF767680).copy(alpha = if (light) 0.12f else 0.24f)

    /** Inset grouped geometry: 20 pt side margins, 10 pt corners, 20 pt cell insets. */
    val Margin = 20.dp
    val CellInset = 20.dp
    val Corner = 10.dp

    /** The rounded card segment for row [index] of [count] in one section. */
    fun cellShape(index: Int, count: Int): Shape {
        val top = if (index == 0) Corner else 0.dp
        val bottom = if (index == count - 1) Corner else 0.dp
        return RoundedCornerShape(topStart = top, topEnd = top, bottomStart = bottom, bottomEnd = bottom)
    }
}

/** True when the active studio theme is light (Paper), i.e. iOS `colorScheme == .light`. */
@Composable
fun iosLight(): Boolean = LocalStudioTheme.current.isLight

/**
 * One row of an inset grouped section: side margins, the cell fill with corners on the first and
 * last rows, and a hairline separator above every row but the first, inset to the content
 * leading edge like UIKit.
 */
@Composable
fun GroupedCell(index: Int, count: Int, modifier: Modifier = Modifier, content: @Composable ColumnScope.() -> Unit) {
    val light = iosLight()
    Box(Modifier.fillMaxWidth().padding(horizontal = IosGrouped.Margin)) {
        Column(
            Modifier.fillMaxWidth().clip(IosGrouped.cellShape(index, count)).background(IosGrouped.cell(light)).then(modifier),
            content = content,
        )
        if (index > 0) {
            Box(
                Modifier.fillMaxWidth().padding(start = IosGrouped.CellInset).height(0.5.dp)
                    .background(IosGrouped.separator(light)),
            )
        }
    }
}

/** Section header: footnote caps in the secondary label colour, aligned with the cell content. */
@Composable
fun GroupedHeader(text: String, modifier: Modifier = Modifier) {
    Text(
        text.uppercase(), color = IosGrouped.secondaryLabel(iosLight()), fontSize = 13.sp,
        modifier = modifier.fillMaxWidth().padding(start = IosGrouped.Margin + IosGrouped.CellInset, end = IosGrouped.Margin, bottom = 7.dp),
    )
}

/** Section footer: footnote in the secondary label colour under the card. */
@Composable
fun GroupedFooter(text: String, modifier: Modifier = Modifier) {
    Text(
        text, color = IosGrouped.secondaryLabel(iosLight()), fontSize = 13.sp,
        modifier = modifier.fillMaxWidth().padding(start = IosGrouped.Margin + IosGrouped.CellInset, end = IosGrouped.Margin + IosGrouped.CellInset, top = 7.dp),
    )
}

/** The disclosure chevron a `NavigationLink` row shows (13 pt semibold, tertiary label). */
@Composable
fun GroupedChevron(modifier: Modifier = Modifier) {
    val light = iosLight()
    Icon(
        Icons.AutoMirrored.Filled.KeyboardArrowRight, null,
        tint = if (light) Color(0xFF3C3C43).copy(alpha = 0.3f) else Color(0xFFEBEBF5).copy(alpha = 0.3f),
        modifier = modifier.size(22.dp),
    )
}

/** iOS `systemRed` in dark appearance (destructive buttons and menu items). */
val IosRed: Color = Color(0xFFFF453A)

/**
 * SwiftUI `.buttonStyle(.bordered)` tinted with the accent: a 10 pt rounded rectangle filled with
 * the tint at ~25 % (measured), tinted 17 pt label; disabled turns the fill and content grey.
 */
@Composable
fun IosBorderedButton(
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    tint: Color = LocalStudioPalette.current.accent,
    contentPadding: PaddingValues = PaddingValues(horizontal = 14.dp, vertical = 7.dp),
    content: @Composable RowScope.(Color) -> Unit,
) {
    val light = iosLight()
    val shape = RoundedCornerShape(10.dp)
    val fill = if (enabled) tint.copy(alpha = 0.25f) else Color(0xFF767680).copy(alpha = if (light) 0.12f else 0.3f)
    val ink = if (enabled) tint else (if (light) Color(0xFF3C3C43) else Color(0xFFEBEBF5)).copy(alpha = 0.3f)
    Row(
        modifier.heightIn(min = 34.dp).clip(shape).background(fill).clickable(enabled = enabled, onClick = onClick).padding(contentPadding),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterHorizontally),
    ) { content(ink) }
}
