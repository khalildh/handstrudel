package com.handstrudel.ui.store

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.size
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.handstrudel.store.RestoreOutcome
import com.handstrudel.store.StoreGate
import kotlinx.coroutines.launch

/**
 * iOS `RestorePurchasesButton`. When [onRestored] is given and access for
 * [packId] became available, it's called instead of showing the alert
 * (the paywall dismisses itself).
 */
@Composable
fun RestorePurchasesButton(
    store: StoreGate,
    modifier: Modifier = Modifier,
    packId: String? = null,
    enabled: Boolean = true,
    onRestoreStarted: (() -> Unit)? = null,
    onRestored: (() -> Unit)? = null,
) {
    val state by store.state.collectAsState()
    val scope = rememberCoroutineScope()
    var outcome by remember { mutableStateOf<RestoreOutcome?>(null) }
    val clickable = enabled && !state.isRestoring

    Row(
        modifier
            .fillMaxWidth()
            .heightIn(min = 44.dp)
            .testTag("store-restore-purchases")
            .clickable(enabled = clickable) {
                onRestoreStarted?.invoke()
                scope.launch {
                    val result = store.restore(packId) ?: return@launch
                    if (result == RestoreOutcome.ACCESS_AVAILABLE && onRestored != null) onRestored()
                    else outcome = result
                }
            },
        horizontalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterHorizontally),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (state.isRestoring) {
            CircularProgressIndicator(Modifier.size(16.dp), color = Color.White, strokeWidth = 2.dp)
        }
        Text(
            if (state.isRestoring) "Restoring Purchases…" else "Restore Purchases",
            fontSize = 15.sp,
            fontWeight = FontWeight.Medium,
            color = Color.White.copy(alpha = if (clickable || state.isRestoring) 0.75f else 0.35f),
        )
    }

    outcome?.let { result ->
        AlertDialog(
            onDismissRequest = { outcome = null },
            confirmButton = { TextButton(onClick = { outcome = null }) { Text("OK") } },
            title = { Text("Restore Purchases") },
            text = { Text(result.message) },
        )
    }
}
