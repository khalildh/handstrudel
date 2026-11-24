package com.handstrudel.ui.store

import androidx.compose.foundation.layout.statusBarsPadding
import com.handstrudel.ui.theme.StudioFonts
import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
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
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.testTagsAsResourceId
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.handstrudel.app.LocalAppServices
import com.handstrudel.store.ProductIds
import com.handstrudel.store.PurchaseResult
import com.handstrudel.store.StoreCopy
import com.handstrudel.store.StoreGate
import com.handstrudel.store.StoreProduct
import com.revenuecat.purchases.ui.revenuecatui.PaywallDialog
import com.revenuecat.purchases.ui.revenuecatui.PaywallDialogOptions
import kotlinx.coroutines.launch

/** iOS system colours the store screens use on black. */
internal object StoreColors {
    val green = Color(0xFF30D158)
    val red = Color(0xFFFF453A)
    val secondary = Color(0xFF98989F)
}

internal const val PRIVACY_URL = "https://handstrudel.com/privacy"
/** iOS links Apple's standard EULA; Android links our own terms (docs/android-parity.md 1.8). */
internal const val TERMS_URL = "https://handstrudel.com/terms"

/**
 * Store screen (iOS `Views/StoreView.swift`): drum kits, Pro, HandStrudel+,
 * Restore, Privacy + Terms. With no RevenueCat key it looks like iOS when
 * products fail to load: every row and button shows, without prices, and a
 * purchase reports the iOS "Product unavailable: <id>" error.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun StoreScreen(onDismiss: () -> Unit, store: StoreGate = LocalAppServices.current.store) {
    ModalBottomSheet(
        modifier = Modifier.statusBarsPadding(),
        onDismissRequest = onDismiss,
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        containerColor = Color.Black,
        contentColor = Color.White,
    ) {
        StoreContent(store)
    }
}

@OptIn(ExperimentalComposeUiApi::class)
@Composable
fun StoreContent(store: StoreGate, modifier: Modifier = Modifier) {
    val state by store.state.collectAsState()
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var showPaywall by remember { mutableStateOf(false) }
    var pendingNotice by remember { mutableStateOf<String?>(null) }
    var subscribeError by remember { mutableStateOf<String?>(null) }

    // Always reload: a previous failed load would leave products missing.
    LaunchedEffect(store) { store.refresh() }

    fun buy(productId: String) {
        val activity = context.findActivity() ?: return
        pendingNotice = null
        subscribeError = null
        scope.launch {
            // Play can leave a purchase pending; say so instead of looking like nothing happened.
            if (store.purchase(activity, productId) == PurchaseResult.Pending) pendingNotice = StoreCopy.PENDING
        }
    }
    fun product(id: String): StoreProduct? = state.products.firstOrNull { it.id == id }

    Column(
        modifier
            .semantics { testTagsAsResourceId = true }
            .testTag("store-screen")
            .fillMaxWidth()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 20.dp),
        verticalArrangement = Arrangement.spacedBy(28.dp),
    ) {
        Row(Modifier.padding(top = 16.dp), verticalAlignment = Alignment.CenterVertically) {
            Text("STORE", fontSize = 28.sp, fontWeight = FontWeight.Black, fontFamily = StudioFonts.Rounded, color = Color.White)
            Spacer(Modifier.weight(1f))
            if (state.isLoading) CircularProgressIndicator(Modifier.size(18.dp), color = Color.White, strokeWidth = 2.dp)
        }

        // Drum kits: always listed, like iOS; Buy shows the price once the product loaded.
        val kits = listOf(
            KitRow(ProductIds.KIT_808, "808 Kit", "🥁",
                listOf("Boom Bap", "Drill", "Lo-Fi Hip Hop", "R&B", "Afrobeat", "Bounce", "Jersey Club", "Memphis", "Bossa Nova", "Reggae")),
            KitRow(ProductIds.KIT_ELECTRONIC, "Electronic Kit", "⚡",
                listOf("Techno", "Breakbeat", "IDM", "Jungle", "Ambient", "Industrial", "2-Step", "Synthwave")),
        )
        Section("DRUM KITS") {
            kits.forEach { kit ->
                PackRow(kit, unlocked = store.isUnlocked(kit.id), product = product(kit.id), onBuy = { buy(kit.id) })
            }
        }

        Section("PRO") {
            ProRow(
                unlocked = store.hasProAccess,
                product = product(ProductIds.PRO),
                purchasing = state.purchasingProductId == ProductIds.PRO,
                onBuy = { buy(ProductIds.PRO) },
            )
        }

        Section("HANDSTRUDEL+") {
            SubscriptionRow(
                hasSubscription = store.hasSubscription,
                hasProAccess = store.hasProAccess,
                offeringAvailable = store.isConfigured && state.offeringAvailable,
                plans = ProductIds.plusPlans.mapNotNull(::product),
                onSubscribe = {
                    pendingNotice = null
                    // iOS opens RevenueCat's paywall; with no offering (no key, or nothing loaded)
                    // there is nothing to show, so report it the way a missing product is reported.
                    if (store.isConfigured && state.offeringAvailable) {
                        subscribeError = null
                        showPaywall = true
                    } else {
                        subscribeError = StoreCopy.productUnavailable(ProductIds.PLUS_SUBSCRIPTION)
                    }
                },
                onBuyPlan = ::buy,
                onManage = {
                    context.openUrl(
                        state.managementUrl
                            ?: "https://play.google.com/store/account/subscriptions?package=${context.packageName}",
                    )
                },
            )
        }

        (subscribeError ?: state.lastError)?.let {
            Text(it, fontSize = 12.sp, color = StoreColors.red.copy(alpha = 0.8f), modifier = Modifier.fillMaxWidth().testTag("store-error"))
        } ?: pendingNotice?.let {
            Text(it, fontSize = 12.sp, color = Color.White.copy(alpha = 0.7f), modifier = Modifier.fillMaxWidth().testTag("store-pending"))
        }

        RestorePurchasesButton(store)

        // Required policy links, always reachable from the store.
        Row(Modifier.fillMaxWidth().padding(top = 8.dp), horizontalArrangement = Arrangement.spacedBy(20.dp, Alignment.CenterHorizontally)) {
            LinkText("Privacy Policy", "store-privacy") { context.openUrl(PRIVACY_URL) }
            LinkText("Terms of Use", "store-terms") { context.openUrl(TERMS_URL) }
        }
        Spacer(Modifier.height(20.dp))
    }

    if (showPaywall && store.isConfigured && state.offeringAvailable) {
        PaywallDialog(
            PaywallDialogOptions.Builder()
                .setDismissRequest { showPaywall = false }
                .setShouldDisplayDismissButton(true)
                .build(),
        )
    }
}

private data class KitRow(val id: String, val name: String, val emoji: String, val contents: List<String>)

@Composable
private fun Section(title: String, content: @Composable ColumnScope.() -> Unit) {
    // iOS puts headers and rows straight in the screen's 28 pt VStack.
    Column(verticalArrangement = Arrangement.spacedBy(28.dp)) {
        SectionHeader(title)
        content()
    }
}

@Composable
internal fun SectionHeader(title: String) {
    Text(title, fontSize = 11.sp, fontWeight = FontWeight.Bold, fontFamily = StudioFonts.Rounded, color = StoreColors.secondary, letterSpacing = 1.5.sp)
}

@Composable
private fun PackRow(kit: KitRow, unlocked: Boolean, product: StoreProduct?, onBuy: () -> Unit) {
    Row(
        Modifier.testTag("store-kit-${kit.id}").card(unlocked).padding(14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Text(kit.emoji, fontSize = 28.sp, modifier = Modifier.width(44.dp))
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
            Text(kit.name, fontSize = 16.sp, fontWeight = FontWeight.Bold, fontFamily = StudioFonts.Rounded, color = Color.White)
            Text(
                kit.contents.joinToString(" · "), fontSize = 11.sp, color = Color.White.copy(alpha = 0.4f),
                maxLines = 1, overflow = TextOverflow.Ellipsis,
            )
        }
        if (unlocked) {
            CheckCircle()
        } else {
            Row(
                Modifier
                    .testTag("store-buy-${kit.id}")
                    .clip(RoundedCornerShape(10.dp))
                    .background(StoreColors.green)
                    .clickable(onClick = onBuy)
                    .padding(horizontal = 14.dp, vertical = 8.dp),
                horizontalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                Text("Buy", fontSize = 13.sp, fontWeight = FontWeight.ExtraBold, fontFamily = StudioFonts.Rounded, color = Color.Black)
                product?.let {
                    Text(it.displayPrice, fontSize = 13.sp, fontWeight = FontWeight.SemiBold, fontFamily = StudioFonts.Mono, color = Color.Black)
                }
            }
        }
    }
}

@Composable
private fun ProRow(unlocked: Boolean, product: StoreProduct?, purchasing: Boolean, onBuy: () -> Unit) {
    Column(
        Modifier.testTag("store-pro").card(unlocked).padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Text("⭐", fontSize = 28.sp)
            Text("HandStrudel Pro", fontSize = 18.sp, fontWeight = FontWeight.Black, fontFamily = StudioFonts.Rounded, color = Color.White, modifier = Modifier.weight(1f))
            if (unlocked) CheckCircle(Modifier.testTag("store-pro-owned"))
        }
        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            FeatureItem("120+ instruments")
            FeatureItem("Every scale — modes, harmonic minor, exotic")
            FeatureItem("Every chord progression")
            FeatureItem("One-time purchase")
        }
        // iOS always offers BUY PRO and fetches the product on demand; the price shows once it loaded.
        if (!unlocked) {
            GreenButton(testTag = "store-buy-pro", enabled = !purchasing, onClick = onBuy) {
                if (purchasing) {
                    CircularProgressIndicator(Modifier.size(20.dp), color = Color.Black, strokeWidth = 2.dp)
                } else {
                    Text("BUY PRO", fontSize = 16.sp, fontWeight = FontWeight.Black, fontFamily = StudioFonts.Rounded, color = Color.Black)
                    product?.let {
                        Text("  • ${it.displayPrice}", fontSize = 14.sp, fontWeight = FontWeight.Bold,
                            fontFamily = StudioFonts.Mono, color = Color.Black.copy(alpha = 0.7f))
                    }
                }
            }
        }
    }
}

@Composable
private fun SubscriptionRow(
    hasSubscription: Boolean,
    hasProAccess: Boolean,
    offeringAvailable: Boolean,
    plans: List<StoreProduct>,
    onSubscribe: () -> Unit,
    onBuyPlan: (String) -> Unit,
    onManage: () -> Unit,
) {
    Column(
        Modifier.testTag("store-plus").card(hasProAccess).padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            FeatureItem("Everything in Pro")
            FeatureItem("Premium camera filters")
            FeatureItem("Premium hand themes")
            FeatureItem("Early access to new content")
        }
        when {
            hasSubscription -> Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                StatusLine("Subscribed", "store-plus-subscribed")
                Box(
                    Modifier
                        .testTag("store-manage-subscription")
                        .fillMaxWidth()
                        .height(40.dp)
                        .clip(RoundedCornerShape(10.dp))
                        .background(Color.White.copy(alpha = 0.08f))
                        .border(1.dp, Color.White.copy(alpha = 0.15f), RoundedCornerShape(10.dp))
                        .clickable(onClick = onManage),
                    contentAlignment = Alignment.Center,
                ) {
                    Text("MANAGE SUBSCRIPTION", fontSize = 13.sp, fontWeight = FontWeight.Bold, fontFamily = StudioFonts.Rounded, color = Color.White)
                }
            }
            hasProAccess -> StatusLine("Pro — Lifetime Access", "store-plus-lifetime", Modifier.padding(vertical = 12.dp))
            offeringAvailable || plans.isEmpty() -> GreenButton(testTag = "store-subscribe", onClick = onSubscribe) {
                Text("SUBSCRIBE", fontSize = 16.sp, fontWeight = FontWeight.Black, fontFamily = StudioFonts.Rounded, color = Color.Black)
            }
            // No RevenueCat offering: plain buttons for whichever Plus plans loaded.
            else -> plans.forEach { plan ->
                GreenButton(testTag = "store-subscribe-${plan.id.substringAfter(':')}", onClick = { onBuyPlan(plan.id) }) {
                    Text(
                        if (plan.id == ProductIds.PLUS_YEARLY) "SUBSCRIBE YEARLY" else "SUBSCRIBE MONTHLY",
                        fontSize = 16.sp, fontWeight = FontWeight.Black, fontFamily = StudioFonts.Rounded, color = Color.Black,
                    )
                    Text("  • ${plan.displayPrice}", fontSize = 14.sp, fontWeight = FontWeight.Bold,
                        fontFamily = StudioFonts.Mono, color = Color.Black.copy(alpha = 0.7f))
                }
            }
        }
    }
}

@Composable
private fun StatusLine(text: String, tag: String, modifier: Modifier = Modifier) {
    Row(
        modifier.testTag(tag).fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterHorizontally),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        CheckCircle(size = 18.dp)
        Text(text, fontSize = 14.sp, fontWeight = FontWeight.Bold, fontFamily = StudioFonts.Rounded, color = Color.White)
    }
}

@Composable
private fun FeatureItem(text: String) {
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
        Text("✓", fontSize = 11.sp, fontWeight = FontWeight.Bold, fontFamily = StudioFonts.Rounded, color = StoreColors.green)
        Text(text, fontSize = 13.sp, fontWeight = FontWeight.Medium, fontFamily = StudioFonts.Rounded, color = Color.White.copy(alpha = 0.7f))
    }
}

/** Filled green circle with a check (SF `checkmark.circle.fill`). */
@Composable
internal fun CheckCircle(modifier: Modifier = Modifier, size: Dp = 22.dp) {
    Box(modifier.size(size).clip(RoundedCornerShape(50)).background(StoreColors.green), contentAlignment = Alignment.Center) {
        Text("✓", fontSize = (size.value * 0.6f).sp, fontWeight = FontWeight.Black, fontFamily = StudioFonts.Rounded, color = Color.Black)
    }
}

@Composable
internal fun GreenButton(
    testTag: String,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    height: Dp = 48.dp,
    onClick: () -> Unit,
    content: @Composable () -> Unit,
) {
    Row(
        modifier
            .testTag(testTag)
            .fillMaxWidth()
            .height(height)
            .clip(RoundedCornerShape(12.dp))
            .background(if (enabled) StoreColors.green else StoreColors.green.copy(alpha = 0.4f))
            .clickable(enabled = enabled, onClick = onClick),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically,
    ) { content() }
}

@Composable
private fun LinkText(text: String, tag: String, onClick: () -> Unit) {
    Text(
        text, fontSize = 12.sp, fontWeight = FontWeight.Medium, fontFamily = StudioFonts.Rounded, color = Color.White.copy(alpha = 0.5f),
        modifier = Modifier.testTag(tag).clickable(onClick = onClick).padding(vertical = 8.dp),
    )
}

/** The iOS card: 4 % white fill, 1 dp border, green-tinted when owned. */
private fun Modifier.card(highlighted: Boolean): Modifier = this
    .fillMaxWidth()
    .clip(RoundedCornerShape(14.dp))
    .background(Color.White.copy(alpha = 0.04f))
    .border(
        BorderStroke(1.dp, if (highlighted) StoreColors.green.copy(alpha = 0.3f) else Color.White.copy(alpha = 0.06f)),
        RoundedCornerShape(14.dp),
    )

internal fun Context.findActivity(): Activity? {
    var c: Context? = this
    while (c is ContextWrapper) {
        if (c is Activity) return c
        c = c.baseContext
    }
    return null
}

internal fun Context.openUrl(url: String) {
    runCatching { startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)) }
}
