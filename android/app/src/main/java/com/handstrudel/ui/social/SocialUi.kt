package com.handstrudel.ui.social

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.net.Uri
import android.text.format.DateUtils
import androidx.browser.customtabs.CustomTabsIntent
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.ColorScheme
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.testTagsAsResourceId
import androidx.compose.ui.platform.testTag
import kotlinx.coroutines.launch
import androidx.compose.foundation.layout.widthIn
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import com.handstrudel.social.SocialServices
import com.handstrudel.social.data.ProfileImageStore
import com.handstrudel.ui.theme.LocalStudioPalette
import com.handstrudel.ui.theme.StudioPalette
import java.time.Instant
import java.util.Locale

/** The process's social services; social UI only composes while they exist. */
@Composable
fun rememberSocial(): SocialServices? {
    val context = LocalContext.current
    return remember { SocialServices.getOrNull(context) }
}

/** Material colours derived from the studio palette, so dialogs/menus/fields match the theme. */
@Composable
fun SocialMaterialTheme(dark: Boolean? = null, content: @Composable () -> Unit) {
    val p = LocalStudioPalette.current
    val isDark = dark ?: (p.background.luminance() < 0.5f)
    val scheme: ColorScheme = if (isDark) darkColorScheme(
        primary = p.accent, onPrimary = p.onAccent, background = p.background, onBackground = p.ink,
        surface = p.surface, onSurface = p.ink, surfaceVariant = p.surface, onSurfaceVariant = p.muted,
        surfaceContainer = p.surface, surfaceContainerHigh = p.surface, surfaceContainerHighest = p.surface,
        surfaceContainerLow = p.background, outline = p.border, secondary = p.accent, error = p.recording,
    ) else lightColorScheme(
        primary = p.accent, onPrimary = p.onAccent, background = p.background, onBackground = p.ink,
        surface = p.surface, onSurface = p.ink, surfaceVariant = p.surface, onSurfaceVariant = p.muted,
        surfaceContainer = p.surface, surfaceContainerHigh = p.surface, surfaceContainerHighest = p.surface,
        surfaceContainerLow = p.background, outline = p.border, secondary = p.accent, error = p.recording,
    )
    MaterialTheme(colorScheme = scheme, content = content)
}

private fun Color.luminance(): Float = 0.2126f * red + 0.7152f * green + 0.0722f * blue

/**
 * Pull to refresh (iOS `.refreshable`). The spinner shows only while a pull-started
 * [onRefresh] runs; [enabled] false ignores the pull (iOS `if !busy { … }`). The
 * content must be scrollable (a `LazyColumn` or `verticalScroll`) and fill the box.
 */
@OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)
@Composable
fun SocialRefreshBox(
    onRefresh: suspend () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    content: @Composable BoxScope.() -> Unit,
) {
    val p = LocalStudioPalette.current
    val scope = androidx.compose.runtime.rememberCoroutineScope()
    val refresh by androidx.compose.runtime.rememberUpdatedState(onRefresh)
    val canRefresh by androidx.compose.runtime.rememberUpdatedState(enabled)
    var refreshing by remember { mutableStateOf(false) }
    val state = androidx.compose.material3.pulltorefresh.rememberPullToRefreshState()
    androidx.compose.material3.pulltorefresh.PullToRefreshBox(
        isRefreshing = refreshing,
        onRefresh = {
            if (!refreshing && canRefresh) {
                refreshing = true
                scope.launch { try { refresh() } finally { refreshing = false } }
            }
        },
        modifier = modifier.testTag("pull-to-refresh"),
        state = state,
        indicator = {
            androidx.compose.material3.pulltorefresh.PullToRefreshDefaults.Indicator(
                state = state, isRefreshing = refreshing, modifier = Modifier.align(Alignment.TopCenter),
                containerColor = p.surface, color = p.accent,
            )
        },
        content = content,
    )
}

/**
 * A full-screen modal page with a title bar (the iOS sheets with NavigationStack +
 * Done/Close). Back dismisses unless [dismissEnabled] is false.
 */
@OptIn(androidx.compose.ui.ExperimentalComposeUiApi::class)
@Composable
fun SocialScreen(
    title: String,
    onDismiss: () -> Unit,
    dismissLabel: String = "Done",
    dismissOnLeading: Boolean = false,
    dismissEnabled: Boolean = true,
    background: Color? = null,
    trailing: @Composable RowScope.() -> Unit = {},
    content: @Composable ColumnScope.() -> Unit,
) {
    Dialog(
        onDismissRequest = { if (dismissEnabled) onDismiss() },
        properties = DialogProperties(usePlatformDefaultWidth = false, decorFitsSystemWindows = false),
    ) {
        val p = LocalStudioPalette.current
        val keyboard = DialogResizesForKeyboard()
        SocialMaterialTheme {
            Column(
                Modifier.fillMaxSize().background(background ?: p.background)
                    .windowInsetsPadding(WindowInsets.statusBars).windowInsetsPadding(WindowInsets.navigationBars)
                    .padding(bottom = keyboard).semantics { testTagsAsResourceId = true },
            ) {
                Row(Modifier.fillMaxWidth().heightIn(min = 52.dp).padding(horizontal = 6.dp), verticalAlignment = Alignment.CenterVertically) {
                    if (dismissOnLeading) {
                        TextButton(onClick = onDismiss, enabled = dismissEnabled) { Text(dismissLabel, color = p.accent) }
                    } else {
                        Spacer(Modifier.width(64.dp))
                    }
                    Text(title, color = p.ink, fontWeight = FontWeight.SemiBold, fontSize = 17.sp, maxLines = 1,
                        overflow = TextOverflow.Ellipsis, textAlign = TextAlign.Center, modifier = Modifier.weight(1f))
                    Row(Modifier.widthIn(min = 64.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.End) {
                        trailing()
                        if (!dismissOnLeading) {
                            TextButton(onClick = onDismiss, enabled = dismissEnabled) { Text(dismissLabel, color = p.accent, fontWeight = FontWeight.SemiBold) }
                        }
                    }
                }
                content()
            }
        }
    }
}

/** iOS `ProfileActionStyle`: rounded 46 pt button, filled accent when [primary]. */
@Composable
fun ProfileActionButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    primary: Boolean = false,
    enabled: Boolean = true,
    icon: ImageVector? = null,
    contentDescription: String? = null,
) {
    val p = LocalStudioPalette.current
    val shape = RoundedCornerShape(13.dp)
    Row(
        modifier.heightIn(min = 46.dp).clip(shape)
            .background(if (primary) p.accent else p.background.copy(alpha = 0.6f))
            .then(if (primary) Modifier else Modifier.border(1.dp, p.border, shape))
            .clickable(enabled = enabled, onClick = onClick)
            .alpha(if (enabled) 1f else 0.5f)
            .padding(horizontal = 12.dp, vertical = 8.dp)
            .then(if (contentDescription != null) Modifier.semantics { this.contentDescription = contentDescription } else Modifier),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        val ink = if (primary) p.onAccent else p.ink
        if (icon != null) { Icon(icon, null, tint = ink, modifier = Modifier.size(18.dp)); Spacer(Modifier.width(6.dp)) }
        Text(text, color = ink, fontWeight = FontWeight.SemiBold, fontSize = 15.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
    }
}

/** iOS `StudioActionStyle`: the full-width accent capsule. */
@Composable
fun StudioActionButton(text: String, onClick: () -> Unit, modifier: Modifier = Modifier, icon: ImageVector? = null, enabled: Boolean = true) {
    val p = LocalStudioPalette.current
    Row(
        modifier.fillMaxWidth().heightIn(min = 50.dp).clip(RoundedCornerShape(50)).background(p.accent)
            .clickable(enabled = enabled, onClick = onClick).alpha(if (enabled) 1f else 0.5f).padding(horizontal = 18.dp, vertical = 12.dp),
        horizontalArrangement = Arrangement.Center, verticalAlignment = Alignment.CenterVertically,
    ) {
        if (icon != null) { Icon(icon, null, tint = p.onAccent, modifier = Modifier.size(18.dp)); Spacer(Modifier.width(6.dp)) }
        Text(text, color = p.onAccent, fontWeight = FontWeight.Bold, fontSize = 16.sp)
    }
}

/** iOS `ProfileEyebrow`: small accent monospaced caps label. */
@Composable
fun ProfileEyebrow(title: String) {
    val p = LocalStudioPalette.current
    Text("∿ $title", color = p.accent, fontFamily = FontFamily.Monospace, fontWeight = FontWeight.SemiBold,
        fontSize = 11.sp, letterSpacing = 1.35.sp)
}

/** A rounded surface card used by empty states. */
@Composable
fun EmptyCard(title: String, subtitle: String, icon: ImageVector? = null) {
    val p = LocalStudioPalette.current
    Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(p.surface).padding(16.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            if (icon != null) { Icon(icon, null, tint = p.ink, modifier = Modifier.size(18.dp)); Spacer(Modifier.width(6.dp)) }
            Text(title, color = p.ink, fontWeight = FontWeight.SemiBold, fontSize = 17.sp)
        }
        Spacer(Modifier.size(7.dp))
        Text(subtitle, color = p.muted, fontSize = 15.sp)
    }
}

/** A dim glyph in a black disc, iOS `FeedVideoIcon`. */
@Composable
fun FeedVideoIcon(icon: ImageVector, contentDescription: String?, tint: Color = Color.White, size: Int = 44, modifier: Modifier = Modifier) {
    Box(
        modifier.size(size.dp).clip(CircleShape).background(Color.Black.copy(alpha = 0.55f))
            .border(1.dp, Color.White.copy(alpha = 0.18f), CircleShape),
        contentAlignment = Alignment.Center,
    ) { Icon(icon, contentDescription, tint = tint, modifier = Modifier.size((size * 0.45f).dp)) }
}

/** iOS `.number.notation(.compactName)`: 999, 1.2K, 3.4M. */
fun compactCount(n: Int): String = when {
    n < 1_000 -> n.toString()
    n < 1_000_000 -> trimDecimal(n / 1_000.0) + "K"
    n < 1_000_000_000 -> trimDecimal(n / 1_000_000.0) + "M"
    else -> trimDecimal(n / 1_000_000_000.0) + "B"
}

private fun trimDecimal(v: Double): String {
    val rounded = if (v >= 100) Math.floor(v) else Math.floor(v * 10) / 10
    return if (rounded % 1.0 == 0.0) rounded.toLong().toString() else String.format(Locale.US, "%.1f", rounded)
}

/** `1 view` / `1,234 views`. */
fun viewsLabel(count: Int): String = if (count == 1) "1 view" else "${String.format(Locale.getDefault(), "%,d", count)} views"

/** iOS `Text(date, style: .relative)` equivalent. */
fun relativeTime(instant: Instant?): String {
    instant ?: return ""
    // Device and server clocks differ slightly; never show a fresh post as "in 0 minutes".
    val now = System.currentTimeMillis()
    if (instant.toEpochMilli() >= now - DateUtils.MINUTE_IN_MILLIS) return "Just now"
    return DateUtils.getRelativeTimeSpanString(instant.toEpochMilli(), System.currentTimeMillis(), DateUtils.MINUTE_IN_MILLIS).toString()
}

/** Terms, guidelines and help open in Custom Tabs (falls back to the browser). */
fun openUrl(context: Context, url: String) {
    try {
        CustomTabsIntent.Builder().setShowTitle(true).build().launchUrl(context, Uri.parse(url))
    } catch (e: Exception) {
        runCatching { context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)) }
    }
}

/** "Write a review": the Play listing (market app, then web). */
fun openPlayListing(context: Context) {
    try {
        context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(com.handstrudel.social.SocialConfig.PLAY_MARKET_URL)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
    } catch (e: ActivityNotFoundException) {
        openUrl(context, com.handstrudel.social.SocialConfig.PLAY_LISTING_URL)
    }
}

/** iOS `ProfileImage`: draws a cached/expiring profile image, or nothing while loading. */
@Composable
fun ProfileImage(resource: ProfileImageStore.Resource, modifier: Modifier = Modifier, contentScale: ContentScale = ContentScale.Crop) {
    val social = rememberSocial() ?: return
    val store = social.auth.images
    var resolved by remember(resource) { mutableStateOf<Pair<ProfileImageStore.Resource, Bitmap?>?>(null) }
    LaunchedEffect(resource) { resolved = resource to store.load(resource) }
    val image: Bitmap? = if (resolved?.first == resource) resolved?.second else store.displayedImage(resource)
    if (image != null) {
        val bitmap: ImageBitmap = remember(image) { image.asImageBitmap() }
        androidx.compose.foundation.Image(bitmap, null, modifier = modifier, contentScale = contentScale)
    }
}

/** A tiny pill toast drawn by social screens (iOS feed `toast`). */
@Composable
fun BoxScope.SocialToast(text: String?, topPadding: Int = 8) {
    if (text == null) return
    Text(
        text, color = Color.White, fontWeight = FontWeight.SemiBold, fontSize = 15.sp,
        modifier = Modifier.align(Alignment.TopCenter).padding(top = topPadding.dp, start = 16.dp, end = 16.dp)
            .clip(RoundedCornerShape(50)).background(Color(0xE6202020)).padding(horizontal = 16.dp, vertical = 10.dp),
    )
}

/** Colours for text on top of video. */
val StudioPalette.overVideoInk: Color get() = Color.White

/**
 * Full-screen social dialogs draw edge to edge, and Compose's `imePadding()` doesn't see the
 * keyboard inside a dialog window here, so read the IME inset from the dialog's decor view and
 * return the part of it above the navigation bar (callers already pad a visible navigation bar).
 * The window neither pans nor resizes (a pan on top of this padding pushed the comment
 * composer back under the keyboard).
 */
@Composable
fun DialogResizesForKeyboard(): androidx.compose.ui.unit.Dp {
    val view = androidx.compose.ui.platform.LocalView.current
    val density = androidx.compose.ui.platform.LocalDensity.current
    var imeBottom by remember { mutableStateOf(0) }
    val activityDecor = (androidx.compose.ui.platform.LocalContext.current.findActivity())?.window?.decorView
    androidx.compose.runtime.DisposableEffect(view) {
        val window = ((view as? androidx.compose.ui.window.DialogWindowProvider)
            ?: (view.parent as? androidx.compose.ui.window.DialogWindowProvider))?.window
        @Suppress("DEPRECATION")
        window?.setSoftInputMode(android.view.WindowManager.LayoutParams.SOFT_INPUT_ADJUST_NOTHING)
        val decor = window?.decorView
        decor?.let {
            androidx.core.view.ViewCompat.setOnApplyWindowInsetsListener(it) { v, insets ->
                val ime = insets.getInsets(androidx.core.view.WindowInsetsCompat.Type.ime()).bottom
                val navType = androidx.core.view.WindowInsetsCompat.Type.navigationBars()
                val nav = insets.getInsets(navType).bottom
                // The app hides the navigation bar. The keyboard still covers that strip, but the
                // dialog's IME inset is measured above it and the dialog gets no bar insets at
                // all, so take the strip's height from the activity window and add it back.
                val hiddenNav = if (ime > 0 && nav == 0) {
                    activityDecor?.let { d -> androidx.core.view.ViewCompat.getRootWindowInsets(d)?.getInsetsIgnoringVisibility(navType)?.bottom } ?: 0
                } else 0
                imeBottom = (ime + hiddenNav - nav).coerceAtLeast(0)
                androidx.core.view.ViewCompat.onApplyWindowInsets(v, insets)
            }
            androidx.core.view.ViewCompat.requestApplyInsets(it)
        }
        onDispose { decor?.let { androidx.core.view.ViewCompat.setOnApplyWindowInsetsListener(it, null) } }
    }
    return with(density) { imeBottom.toDp() }
}

private tailrec fun android.content.Context.findActivity(): android.app.Activity? = when (this) {
    is android.app.Activity -> this
    is android.content.ContextWrapper -> baseContext.findActivity()
    else -> null
}
