package com.handstrudel.ui.theme

import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.outlined.Circle
import androidx.compose.material.icons.rounded.GraphicEq
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.handstrudel.app.LocalAppServices

/**
 * iOS `StudioThemePicker` ("Appearance"). Owner: shell. Used by studio-ui (Music home
 * appearance button) and social (Account settings → Appearance). Selecting a card
 * applies the theme live (the sheet itself re-themes) and persists it under `studioTheme`.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun StudioThemePickerSheet(onDismiss: () -> Unit) {
    val prefs = LocalAppServices.current.prefs
    val current by prefs.studioTheme.collectAsState()
    // The sheet lives in its own window, so read the palette for the *selected* theme
    // rather than the caller's composition local: it updates live as the user picks.
    val palette = current.palette
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = palette.background,
        contentColor = palette.ink,
        dragHandle = null,
        modifier = Modifier.testTag("appearance-sheet"),
    ) {
        Column(Modifier.fillMaxWidth().fillMaxHeight().navigationBarsPadding()) {
            // Inline navigation bar: centered title, "Done" as the confirmation action.
            Box(Modifier.fillMaxWidth().padding(horizontal = 8.dp, vertical = 6.dp)) {
                Text(
                    "Appearance",
                    modifier = Modifier.align(Alignment.Center),
                    fontWeight = FontWeight.SemiBold,
                    fontSize = 17.sp,
                    color = palette.ink,
                )
                TextButton(
                    onClick = onDismiss,
                    modifier = Modifier.align(Alignment.CenterEnd).testTag("appearance-done"),
                ) { Text("Done", color = palette.accent, fontWeight = FontWeight.SemiBold, fontSize = 17.sp) }
            }
            Column(
                Modifier
                    .verticalScroll(rememberScrollState())
                    .align(Alignment.CenterHorizontally)
                    .widthIn(max = 520.dp)
                    .fillMaxWidth()
                    .padding(20.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                Text(
                    "Choose the look of your studio and feed.",
                    fontSize = 15.sp,
                    color = palette.muted,
                    modifier = Modifier.padding(bottom = 4.dp),
                )
                StudioTheme.entries.forEach { option ->
                    ThemeCard(option, selected = option == current, palette = palette) { prefs.setStudioTheme(option) }
                }
            }
        }
    }
}

@Composable
private fun ThemeCard(option: StudioTheme, selected: Boolean, palette: StudioPalette, onSelect: () -> Unit) {
    val sample = option.palette
    val shape = RoundedCornerShape(16.dp)
    Row(
        Modifier
            .fillMaxWidth()
            .heightIn(min = 76.dp)
            .clip(shape)
            .background(palette.surface)
            .border(1.dp, if (selected) palette.accent else palette.border, shape)
            .selectable(selected = selected, role = Role.RadioButton, onClick = onSelect)
            .semantics {
                contentDescription = "${option.title}. ${option.subtitle}"
                stateDescription = if (selected) "Selected" else "Not selected"
            }
            .testTag("theme-${option.raw}")
            .padding(11.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Box(
            Modifier
                .size(width = 58.dp, height = 54.dp)
                .clip(RoundedCornerShape(11.dp))
                .background(Brush.linearGradient(listOf(sample.glow, sample.background))),
            contentAlignment = Alignment.Center,
        ) {
            Icon(Icons.Rounded.GraphicEq, contentDescription = null, tint = sample.accent, modifier = Modifier.size(26.dp))
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(option.title, fontFamily = StudioFonts.Serif, fontSize = 20.sp, color = palette.ink)
            Text(option.subtitle, fontSize = 12.sp, color = palette.muted, textAlign = TextAlign.Start)
        }
        Spacer(Modifier.size(4.dp))
        Icon(
            if (selected) Icons.Filled.CheckCircle else Icons.Outlined.Circle,
            contentDescription = null,
            tint = if (selected) palette.accent else palette.muted,
            modifier = Modifier.size(24.dp),
        )
    }
}
