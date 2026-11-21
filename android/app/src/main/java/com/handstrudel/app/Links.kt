package com.handstrudel.app

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.util.Log
import androidx.browser.customtabs.CustomTabColorSchemeParams
import androidx.browser.customtabs.CustomTabsIntent
import androidx.compose.ui.graphics.toArgb
import com.handstrudel.ui.theme.StudioPalette

/**
 * Opens a web page in a Custom Tab (iOS opens Safari / `SFSafariViewController` for
 * terms, community guidelines, support, privacy). Owner: shell; social and store use it.
 * Falls back to any browser, and returns false when nothing can open [url].
 */
fun openExternalLink(context: Context, url: String, palette: StudioPalette? = null): Boolean {
    val uri = runCatching { Uri.parse(url) }.getOrNull() ?: return false
    try {
        val builder = CustomTabsIntent.Builder().setShowTitle(true)
        if (palette != null) {
            builder.setDefaultColorSchemeParams(
                CustomTabColorSchemeParams.Builder()
                    .setToolbarColor(palette.background.toArgb())
                    .setNavigationBarColor(palette.background.toArgb())
                    .build(),
            )
        }
        val tab = builder.build()
        if (context !is android.app.Activity) tab.intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        tab.launchUrl(context, uri)
        return true
    } catch (_: ActivityNotFoundException) {
        // No Custom Tabs provider; try a plain VIEW below.
    }
    return try {
        context.startActivity(Intent(Intent.ACTION_VIEW, uri).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        true
    } catch (e: ActivityNotFoundException) {
        Log.i("Links", "no app can open a link: ${e.javaClass.simpleName}")
        false
    }
}

/** The Play listing (replaces iOS `SocialConfig.reviewURL`; used by Account → Write a review). */
fun openPlayListing(context: Context): Boolean {
    val pkg = context.packageName
    return try {
        context.startActivity(
            Intent(Intent.ACTION_VIEW, Uri.parse("market://details?id=$pkg")).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
        )
        true
    } catch (_: ActivityNotFoundException) {
        openExternalLink(context, "https://play.google.com/store/apps/details?id=$pkg")
    }
}
