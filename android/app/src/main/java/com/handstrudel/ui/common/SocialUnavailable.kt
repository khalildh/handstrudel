package com.handstrudel.ui.common

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.AccountCircle
import androidx.compose.material.icons.outlined.SmartDisplay
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.handstrudel.ui.nav.Destination
import com.handstrudel.ui.theme.LocalStudioPalette

/**
 * Feed/Account placeholder when social isn't configured (iOS `socialUnavailable`):
 * the tab's icon and title, then "This section is unavailable in this build."
 */
@Composable
fun SocialUnavailable(destination: Destination, modifier: Modifier = Modifier) {
    val palette = LocalStudioPalette.current
    val icon = if (destination == Destination.Feed) Icons.Outlined.SmartDisplay else Icons.Outlined.AccountCircle
    Box(modifier.fillMaxSize().padding(24.dp).testTag("social-unavailable"), contentAlignment = Alignment.Center) {
        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Icon(icon, contentDescription = null, tint = palette.ink, modifier = Modifier.size(26.dp))
                Text(destination.name, fontSize = 22.sp, fontWeight = FontWeight.Bold, color = palette.ink)
            }
            Text("This section is unavailable in this build.", color = palette.muted, textAlign = TextAlign.Center)
        }
    }
}
