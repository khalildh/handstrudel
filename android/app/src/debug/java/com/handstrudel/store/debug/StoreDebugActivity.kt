package com.handstrudel.store.debug

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.ExperimentalComposeUiApi
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.testTagsAsResourceId
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.handstrudel.store.StoreDebugOverrides
import com.handstrudel.store.StoreGate
import com.handstrudel.store.StoreManager
import com.handstrudel.ui.store.PaywallSheet
import com.handstrudel.ui.store.ProBadge
import com.handstrudel.ui.store.ProBadgeStyle
import com.handstrudel.ui.store.StoreScreen

/**
 * Debug-only harness for the store (WS6). Drives the process-wide
 * [StoreManager] (the same instance `AppServices` gets) and the
 * [StoreDebugOverrides] from adb, e.g.:
 *
 * ```
 * adb shell am start -n com.handstrudel.app/com.handstrudel.store.debug.StoreDebugActivity \
 *     --es grant pro,plus_features --es subscriptions com.handstrudel.plus:monthly --es screen store
 * adb shell am start -n …/StoreDebugActivity --ez reset true --es screen paywall --es pack kit_808
 * ```
 * Extras: `reset` (clear overrides), `grant` (entitlement csv), `subscriptions`
 * (subscription id csv), `forceLocked` (bool), `screen` = gating | store | paywall,
 * `pack` (paywall packId, default `pro`). Overrides persist for the process, so
 * the real app screens see them too.
 */
class StoreDebugActivity : ComponentActivity() {

    private val screen = mutableStateOf("gating")
    private val pack = mutableStateOf("pro")

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        apply(intent)
        val store = StoreManager.create(applicationContext)
        setContent { Harness(store) }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        apply(intent)
    }

    private fun apply(intent: Intent) {
        val o = StoreDebugOverrides.shared
        if (intent.getBooleanExtra("reset", false)) o.reset()
        intent.getStringExtra("grant")?.let { o.grantedEntitlements.value = csv(it) }
        intent.getStringExtra("subscriptions")?.let { o.grantedSubscriptions.value = csv(it) }
        if (intent.hasExtra("forceLocked")) o.forceLocked.value = intent.getBooleanExtra("forceLocked", false)
        intent.getStringExtra("screen")?.let { screen.value = it }
        intent.getStringExtra("pack")?.let { pack.value = it }
    }

    private fun csv(s: String) = s.split(',').map { it.trim() }.filter { it.isNotEmpty() && it != "none" }.toSet()

    @OptIn(ExperimentalComposeUiApi::class)
    @Composable
    private fun Harness(store: StoreGate) {
        val state by store.state.collectAsState()
        var current by screen
        Column(
            Modifier
                .semantics { testTagsAsResourceId = true }
                .fillMaxSize()
                .background(Color.Black)
                .safeDrawingPadding()
                .padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Text("STORE DEBUG", fontSize = 22.sp, fontWeight = FontWeight.Black, color = Color.White)
            Line("configured", store.isConfigured)
            Line("hasProAccess", store.hasProAccess)
            Line("hasPlusFeatures", store.hasPlusFeatures)
            Line("hasSubscription", store.hasSubscription)
            Text("entitlements: ${state.activeEntitlements.sorted().joinToString().ifEmpty { "-" }}",
                color = Color.White.copy(alpha = 0.7f), fontSize = 13.sp, modifier = Modifier.testTag("debug-entitlements"))
            Spacer(Modifier.padding(4.dp))
            listOf(
                "Grand Piano" to null,
                "Pro instrument" to "pro",
                "808 Kit" to "kit_808",
                "Electronic Kit" to "kit_electronic",
                "Camera filter" to "filter_pack",
                "Hand theme" to "theme_pack",
                "Premium scale" to "scale_pack",
            ).forEach { (name, packId) ->
                val unlocked = store.isUnlocked(packId)
                Row(
                    Modifier.fillMaxWidth().testTag("gate-${packId ?: "free"}")
                        .clickable(enabled = packId != null && !unlocked) { pack.value = packId!!; current = "paywall" }
                        .padding(vertical = 6.dp),
                    horizontalArrangement = Arrangement.spacedBy(10.dp),
                ) {
                    Text(name, color = Color.White, fontSize = 15.sp, modifier = Modifier.weight(1f))
                    Text(if (unlocked) "unlocked" else "locked", color = Color.White.copy(alpha = 0.5f), fontSize = 13.sp)
                    if (!unlocked) ProBadge()
                }
            }
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Text("corner badge:", color = Color.White.copy(alpha = 0.5f), fontSize = 13.sp)
                ProBadge(style = ProBadgeStyle.CORNER)
            }
            Text("Open store", color = Color(0xFF30D158), fontWeight = FontWeight.Bold,
                modifier = Modifier.testTag("debug-open-store").clickable { current = "store" }.padding(vertical = 8.dp))
        }
        when (current) {
            "store" -> StoreScreen(onDismiss = { current = "gating" }, store = store)
            "paywall" -> PaywallSheet(packId = pack.value, onDismiss = { current = "gating" }, store = store)
        }
    }

    @Composable
    private fun Line(label: String, value: Boolean) {
        Text("$label: $value", color = Color.White, fontSize = 14.sp, modifier = Modifier.testTag("debug-$label"))
    }
}
