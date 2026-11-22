package com.handstrudel.ui.settings

import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.selection.toggleable
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.handstrudel.app.LocalAppServices
import com.handstrudel.ui.theme.LocalStudioPalette

/** iOS `UsageAnalyticsSettings` footer copy. */
const val USAGE_ANALYTICS_FOOTER =
    "Help improve HandStrudel by sharing counts of app use, first notes, and recordings. We don't send audio, " +
        "camera or gesture data, custom scale names, or account or device IDs. You can turn this off at any time."

/**
 * Account settings → Usage Analytics (iOS `UsageAnalyticsSettings`). Owner: shell; social
 * opens it. One toggle, default off; turning it on records today's active day.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun UsageAnalyticsScreen(onDismiss: () -> Unit) {
    val analytics = LocalAppServices.current.analytics
    val palette = LocalStudioPalette.current
    val optedIn by analytics.isEnabled.collectAsState()
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = palette.background,
        contentColor = palette.ink,
        dragHandle = null,
        modifier = Modifier.statusBarsPadding().testTag("usage-analytics-sheet"),
    ) {
        Column(Modifier.fillMaxWidth().navigationBarsPadding()) {
            Box(Modifier.fillMaxWidth().padding(horizontal = 8.dp, vertical = 6.dp)) {
                Text(
                    "Usage Analytics",
                    modifier = Modifier.align(Alignment.Center),
                    fontWeight = FontWeight.SemiBold,
                    fontSize = 17.sp,
                    color = palette.ink,
                )
                TextButton(onClick = onDismiss, modifier = Modifier.align(Alignment.CenterEnd).testTag("usage-analytics-done")) {
                    Text("Done", color = palette.accent, fontWeight = FontWeight.SemiBold, fontSize = 17.sp)
                }
            }
            Column(
                Modifier
                    .align(Alignment.CenterHorizontally)
                    .widthIn(max = 560.dp)
                    .fillMaxWidth()
                    .padding(horizontal = 20.dp, vertical = 16.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Row(
                    Modifier
                        .fillMaxWidth()
                        .heightIn(min = 52.dp)
                        .clip(RoundedCornerShape(12.dp))
                        .background(palette.surface)
                        .toggleable(value = optedIn, role = Role.Switch, onValueChange = analytics::setEnabled)
                        .testTag("usage-analytics-toggle")
                        .padding(horizontal = 16.dp, vertical = 8.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text("Share usage analytics", modifier = Modifier.weight(1f), color = palette.ink, fontSize = 17.sp)
                    Switch(
                        checked = optedIn,
                        onCheckedChange = null,
                        colors = SwitchDefaults.colors(
                            checkedTrackColor = palette.accent,
                            checkedThumbColor = palette.onAccent,
                        ),
                    )
                }
                Text(
                    USAGE_ANALYTICS_FOOTER,
                    fontSize = 13.sp,
                    color = palette.muted,
                    modifier = Modifier.padding(horizontal = 16.dp),
                )
            }
        }
    }
}
