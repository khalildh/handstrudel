package com.handstrudel.ui.store

import com.handstrudel.ui.theme.StudioFonts
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.handstrudel.ui.theme.LocalStudioPalette

/** The two iOS PRO pill styles. */
enum class ProBadgeStyle {
    /** Picker rows (iOS `StartOverlayView.ProBadge`): accent ink on a 10 % accent capsule. */
    ROW,
    /** Card corner overlay (iOS `ControlSheetView` tiles): small heavy ink on a translucent capsule. */
    CORNER,
}

/** The PRO badge on locked items. Shared: studio-ui imports it. */
@Composable
fun ProBadge(modifier: Modifier = Modifier, style: ProBadgeStyle = ProBadgeStyle.ROW) {
    val palette = LocalStudioPalette.current
    when (style) {
        ProBadgeStyle.ROW -> Text(
            "PRO",
            fontSize = 11.sp,
            fontFamily = StudioFonts.Mono,
            fontWeight = FontWeight.SemiBold,
            color = palette.accent,
            modifier = modifier
                .background(palette.accent.copy(alpha = 0.10f), CircleShape)
                .padding(horizontal = 8.dp, vertical = 3.dp),
        )
        ProBadgeStyle.CORNER -> Text(
            "PRO",
            fontSize = 8.sp,
            fontWeight = FontWeight.Black,
            color = palette.ink.copy(alpha = 0.8f),
            modifier = modifier
                .padding(5.dp)
                .background(palette.surface.copy(alpha = 0.75f), CircleShape)
                .padding(horizontal = 5.dp, vertical = 2.dp),
        )
    }
}
