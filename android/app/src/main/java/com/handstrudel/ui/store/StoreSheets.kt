package com.handstrudel.ui.store

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

// Store UI entry points. Owner: store (WS6). Phase 0 stubs; WS6 may split this
// file into StoreScreen.kt / PaywallSheet.kt / ProBadge.kt (keep the signatures).

/** Pack paywall sheet (iOS `PaywallOverlay`): name, description, INCLUDES, price, buy, error. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PaywallSheet(packId: String, onDismiss: () -> Unit) {
    ModalBottomSheet(onDismissRequest = onDismiss) {
        Text("Purchases aren't available in this build", Modifier.padding(24.dp))
    }
}

/** Store screen (iOS `StoreView`). */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun StoreScreen(onDismiss: () -> Unit) {
    ModalBottomSheet(onDismissRequest = onDismiss) {
        Text("Purchases aren't available in this build", Modifier.padding(24.dp))
    }
}

/** The PRO badge on locked items. Shared: studio-ui imports it. */
@Composable
fun ProBadge(modifier: Modifier = Modifier) {
    Text(
        "PRO",
        fontSize = 9.sp,
        fontWeight = FontWeight.ExtraBold,
        color = Color.White.copy(alpha = 0.7f),
        modifier = modifier
            .clip(RoundedCornerShape(4.dp))
            .background(Color.White.copy(alpha = 0.15f))
            .padding(horizontal = 6.dp, vertical = 2.dp),
    )
}
