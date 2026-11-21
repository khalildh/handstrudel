package com.handstrudel.ui.store

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.ExperimentalComposeUiApi
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.testTagsAsResourceId
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.handstrudel.app.LocalAppServices
import com.handstrudel.store.PackCatalog
import com.handstrudel.store.ProductIds
import com.handstrudel.store.PurchaseResult
import com.handstrudel.store.StoreCopy
import com.handstrudel.store.StoreGate
import kotlinx.coroutines.launch

/**
 * Pack paywall sheet (iOS `Views/PaywallOverlay.swift`): name, description,
 * INCLUDES, price, UNLOCK, Restore, error. Copy comes from [PackCatalog]
 * (iOS `packInfo(for:)`). Dismisses itself once [packId] unlocks.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PaywallSheet(packId: String, onDismiss: () -> Unit, store: StoreGate = LocalAppServices.current.store) {
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        containerColor = Color.Black,
        contentColor = Color.White,
    ) {
        PaywallContent(packId, store, onDismiss)
    }
}

@OptIn(ExperimentalComposeUiApi::class)
@Composable
fun PaywallContent(packId: String, store: StoreGate, onDismiss: () -> Unit, modifier: Modifier = Modifier) {
    val state by store.state.collectAsState()
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var purchasing by remember { mutableStateOf(false) }
    var errorMessage by remember { mutableStateOf<String?>(null) }

    val info = PackCatalog.info(packId)
    val productId = ProductIds.productId(packId)
    val product = state.products.firstOrNull { it.id == productId }

    // Prices come from the store; load them if the store screen hasn't yet.
    LaunchedEffect(store) { if (store.isConfigured && state.products.isEmpty()) store.refresh() }

    Column(modifier.semantics { testTagsAsResourceId = true }.testTag("paywall").fillMaxWidth()) {
        Column(
            Modifier
                .weight(1f, fill = false)
                .verticalScroll(rememberScrollState())
                .padding(bottom = 16.dp),
            verticalArrangement = Arrangement.spacedBy(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Column(
                Modifier.padding(top = 24.dp).padding(horizontal = 24.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Text(info.name, fontSize = 28.sp, fontWeight = FontWeight.Black, color = Color.White, textAlign = TextAlign.Center,
                    modifier = Modifier.testTag("paywall-name"))
                Text(info.description, fontSize = 14.sp, fontWeight = FontWeight.Medium, color = Color.White.copy(alpha = 0.5f),
                    textAlign = TextAlign.Center)
            }

            Column(
                Modifier.fillMaxWidth().padding(horizontal = 24.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                SectionHeader("INCLUDES")
                info.items.forEach { item ->
                    Row(horizontalArrangement = Arrangement.spacedBy(10.dp), verticalAlignment = Alignment.CenterVertically) {
                        CheckCircle(size = 16.dp)
                        Text(item, fontSize = 15.sp, fontWeight = FontWeight.Medium, color = Color.White.copy(alpha = 0.9f))
                    }
                }
            }

            when {
                !store.isConfigured -> Text(
                    StoreCopy.UNAVAILABLE, fontSize = 14.sp, fontWeight = FontWeight.Medium,
                    color = Color.White.copy(alpha = 0.6f), textAlign = TextAlign.Center,
                    modifier = Modifier.testTag("paywall-unavailable").padding(horizontal = 24.dp),
                )
                product != null -> Text(
                    product.displayPrice, fontSize = 22.sp, fontWeight = FontWeight.Bold, fontFamily = FontFamily.Monospace,
                    color = StoreColors.green, modifier = Modifier.testTag("paywall-price").padding(top = 8.dp),
                )
                state.isLoading -> CircularProgressIndicator(Modifier.size(22.dp), color = StoreColors.green, strokeWidth = 2.dp)
                else -> Text("---", fontSize = 22.sp, fontWeight = FontWeight.Bold, fontFamily = FontFamily.Monospace,
                    color = StoreColors.green, modifier = Modifier.padding(top = 8.dp))
            }
        }

        // Pinned action area: always visible whatever the sheet height.
        Column(
            Modifier
                .fillMaxWidth()
                .background(Color.Black)
                .padding(horizontal = 24.dp)
                .padding(top = 12.dp, bottom = 16.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            val unlocked = store.isUnlocked(packId)
            GreenButton(
                testTag = "paywall-unlock",
                height = 56.dp,
                enabled = store.isConfigured && !unlocked && !purchasing && !state.isRestoring,
                onClick = {
                    val activity = context.findActivity() ?: return@GreenButton
                    purchasing = true
                    errorMessage = null
                    scope.launch {
                        when (val result = store.purchase(activity, productId)) {
                            is PurchaseResult.Failed -> errorMessage = result.message
                            PurchaseResult.Pending -> errorMessage = "Your purchase is pending. It will unlock once the payment completes."
                            else -> Unit
                        }
                        purchasing = false
                        if (store.isUnlocked(packId)) onDismiss()
                    }
                },
            ) {
                if (purchasing) {
                    CircularProgressIndicator(Modifier.size(22.dp), color = Color.Black, strokeWidth = 2.dp)
                } else {
                    Text(if (unlocked) "UNLOCKED" else "UNLOCK", fontSize = 18.sp, fontWeight = FontWeight.Black, color = Color.Black)
                }
            }

            if (store.isConfigured) {
                RestorePurchasesButton(
                    store = store,
                    packId = packId,
                    enabled = !purchasing,
                    onRestoreStarted = { errorMessage = null },
                    onRestored = onDismiss,
                )
            }

            errorMessage?.let {
                Text(it, fontSize = 12.sp, color = StoreColors.red.copy(alpha = 0.8f), textAlign = TextAlign.Center,
                    modifier = Modifier.testTag("paywall-error"))
            }
        }
    }
}
