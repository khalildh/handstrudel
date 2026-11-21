package com.handstrudel.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import com.handstrudel.app.AppServices
import com.handstrudel.app.LocalAppServices
import com.handstrudel.social.SocialEntryPoints
import com.handstrudel.ui.nav.DefaultAppNavigator
import com.handstrudel.ui.nav.Destination
import com.handstrudel.ui.nav.LocalAppNavigator
import com.handstrudel.ui.studio.StudioEntryPoints
import com.handstrudel.ui.theme.LocalStudioPalette

/**
 * Composition root (iOS `ContentView` body). Owner: shell. Phase 0: three tabs,
 * the Stage takeover while running, the hidden Strudel WebView host, notices,
 * errors and deep-link sheets.
 */
@Composable
fun HandStrudelApp(services: AppServices, navigator: DefaultAppNavigator) {
    val theme by services.prefs.studioTheme.collectAsState()
    CompositionLocalProvider(
        LocalAppServices provides services,
        LocalAppNavigator provides navigator,
        LocalStudioPalette provides theme.palette,
    ) {
        val palette = theme.palette
        val destination by navigator.destination.collectAsState()
        val running by services.engine.isRunning.collectAsState()
        val webView by services.engine.strudelWebView.collectAsState()
        val socialConfigured = services.auth.isConfigured

        Box(Modifier.fillMaxSize().background(palette.background)) {
            // Strudel WebView stays attached for the app lifetime (iOS keeps it in the hierarchy).
            webView?.let { view -> AndroidView(factory = { view }, modifier = Modifier.size(1.dp)) }

            if (socialConfigured) {
                SocialEntryPoints.FeedTab(
                    isActive = destination == Destination.Feed && !running,
                    onFullscreenChanged = {},
                    tabBar = { overVideo -> DestinationTabs(destination, overVideo, navigator::select) },
                )
            }
            if (running) {
                StudioEntryPoints.Stage()
            } else {
                when (destination) {
                    Destination.Music -> StudioEntryPoints.MusicHome()
                    Destination.Account -> if (socialConfigured) SocialEntryPoints.AccountTab() else SocialUnavailable()
                    Destination.Feed -> if (!socialConfigured) SocialUnavailable()
                }
                if (destination != Destination.Feed || !socialConfigured) {
                    Box(Modifier.align(Alignment.BottomCenter)) {
                        DestinationTabs(destination, overVideo = false, onSelect = navigator::select)
                    }
                }
            }

            val notice by navigator.notice.collectAsState()
            notice?.let {
                Text(
                    it.text,
                    color = palette.ink,
                    modifier = Modifier.align(Alignment.TopCenter).padding(top = 56.dp)
                        .clip(RoundedCornerShape(12.dp)).background(palette.surface)
                        .padding(horizontal = 16.dp, vertical = 10.dp),
                )
            }
        }

        val sheet by navigator.sheet.collectAsState()
        when (val s = sheet) {
            is DefaultAppNavigator.Sheet.Post -> SocialEntryPoints.CreatorVideoSheet(s.video, navigator::dismissSheet)
            is DefaultAppNavigator.Sheet.Comments -> SocialEntryPoints.CommentsSheet(s.video, navigator::dismissSheet)
            null -> Unit
        }
        val error by navigator.error.collectAsState()
        error?.let { e ->
            AlertDialog(
                onDismissRequest = navigator::dismissError,
                confirmButton = { TextButton(onClick = navigator::dismissError) { Text("OK") } },
                title = { Text(e.title) },
                text = { Text(e.message) },
            )
        }
    }
}

/** Feed / Music / Account. Music gets the filled accent capsule (iOS `destinationTabs`). */
@Composable
fun DestinationTabs(selected: Destination, overVideo: Boolean, onSelect: (Destination) -> Unit) {
    val palette = LocalStudioPalette.current
    Row(
        Modifier.fillMaxWidth().padding(bottom = 32.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp, Alignment.CenterHorizontally),
    ) {
        Destination.entries.forEach { d ->
            val isSelected = d == selected
            val ink = if (overVideo) Color.White else palette.ink
            Text(
                d.name,
                fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal,
                color = if (isSelected) palette.onAccent else ink.copy(alpha = 0.7f),
                modifier = Modifier.clip(RoundedCornerShape(50))
                    .background(if (isSelected) palette.accent else Color.Transparent)
                    .clickable { onSelect(d) }
                    .padding(horizontal = 18.dp, vertical = 10.dp),
            )
        }
    }
}

/** Placeholder for Feed/Account when social is unconfigured. */
@Composable
fun SocialUnavailable() {
    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Text("Not available in this build.", color = LocalStudioPalette.current.muted)
    }
}
