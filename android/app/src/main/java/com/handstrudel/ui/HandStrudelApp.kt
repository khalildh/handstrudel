package com.handstrudel.ui

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.view.ViewGroup
import android.webkit.WebView
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.WindowInsetsSides
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.only
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.platform.LocalWindowInfo
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.compose.currentStateAsState
import com.handstrudel.app.AppServices
import com.handstrudel.app.LocalAppServices
import com.handstrudel.app.PlayReviewPrompt
import com.handstrudel.social.SocialEntryPoints
import com.handstrudel.ui.common.ErrorAlertHost
import com.handstrudel.ui.common.NoticeHost
import com.handstrudel.ui.common.SocialUnavailable
import com.handstrudel.ui.nav.DefaultAppNavigator
import com.handstrudel.ui.nav.Destination
import com.handstrudel.ui.nav.DestinationTabs
import com.handstrudel.ui.nav.LocalAppNavigator
import com.handstrudel.ui.studio.StudioEntryPoints
import com.handstrudel.ui.theme.StudioMaterialTheme
import kotlinx.coroutines.delay

/**
 * Composition root (iOS `ContentView` body). Owner: shell.
 *
 * Layers, bottom to top: the Feed (always composed when social is configured so it can
 * preload; visible and touchable only on the Feed tab with no session), the destinations
 * (Music home / Account / placeholders) with the tab bar, the Stage while the engine runs,
 * the hidden Strudel WebView, and the global notice. Deep-link sheets and the alert sit
 * above. Also drives the status bar, system back and the in-app review prompt.
 */
@Composable
fun HandStrudelApp(services: AppServices, navigator: DefaultAppNavigator) {
    val theme by services.prefs.studioTheme.collectAsState()
    val destination by navigator.destination.collectAsState()
    val running by services.engine.isRunning.collectAsState()
    val starting by navigator.isStartingSession.collectAsState()
    val feedFullscreen by navigator.feedFullscreen.collectAsState()
    val socialConfigured = services.auth.isConfigured
    // iOS forces .dark over feed video; otherwise the theme's scheme (Paper is light).
    val forceDark = destination == Destination.Feed && socialConfigured && !running

    StudioMaterialTheme(theme, forceDark = forceDark) {
        CompositionLocalProvider(
            LocalAppServices provides services,
            LocalAppNavigator provides navigator,
        ) {
            val palette = theme.palette
            SystemBars(hideStatusBar = running || feedFullscreen, lightBackground = theme.isLight && !forceDark && !running)
            BackHandler(enabled = running || destination != Destination.Music) { navigator.handleBack() }

            Box(Modifier.fillMaxSize().background(if (running || feedFullscreen) Color.Black else palette.background)) {
                if (socialConfigured) {
                    val feedVisible = destination == Destination.Feed && !running
                    Box(Modifier.fillMaxSize().alpha(if (feedVisible) 1f else 0f).then(if (feedVisible) Modifier else Modifier.clearAndSetSemantics {})) {
                        SocialEntryPoints.FeedTab(
                            isActive = feedVisible,
                            onFullscreenChanged = navigator::setFeedFullscreen,
                            tabBar = { overVideo ->
                                DestinationTabs(destination, overVideo, navigator::select, enabled = !starting)
                            },
                        )
                    }
                    // iOS `.allowsHitTesting(false)` for the hidden feed.
                    if (!feedVisible) Box(Modifier.fillMaxSize().pointerInput(Unit) { awaitPointerEventScope { while (true) awaitPointerEvent() } })
                }

                if (!running && (destination != Destination.Feed || !socialConfigured)) {
                    Column(Modifier.fillMaxSize()) {
                        Box(
                            Modifier
                                .weight(1f)
                                .fillMaxWidth()
                                .windowInsetsPadding(WindowInsets.safeDrawing.only(WindowInsetsSides.Top + WindowInsetsSides.Horizontal)),
                        ) {
                            when (destination) {
                                Destination.Music -> StudioEntryPoints.MusicHome()
                                Destination.Account ->
                                    if (socialConfigured) SocialEntryPoints.AccountTab() else SocialUnavailable(Destination.Account)
                                Destination.Feed -> SocialUnavailable(Destination.Feed)
                            }
                        }
                        DestinationTabs(destination, overVideo = false, onSelect = navigator::select, enabled = !starting)
                    }
                }

                if (running) StudioEntryPoints.Stage()

                StrudelWebViewHost(services)

                val notice by navigator.notice.collectAsState()
                NoticeHost(notice)
            }

            val sheet by navigator.sheet.collectAsState()
            when (val s = sheet) {
                is DefaultAppNavigator.Sheet.Post -> key(s.video.id) { SocialEntryPoints.CreatorVideoSheet(s.video, navigator::dismissSheet) }
                is DefaultAppNavigator.Sheet.Comments -> key(s.video.id) { SocialEntryPoints.CommentsSheet(s.video, navigator::dismissSheet) }
                null -> Unit
            }
            val error by navigator.error.collectAsState()
            ErrorAlertHost(error, navigator::dismissError)

            ReviewPromptEffect(services, navigator)
        }
    }
}

/**
 * The hidden Strudel WebView (iOS `WebViewContainer` at 1×1, opacity 0.01). It stays in the
 * hierarchy for the app's lifetime so audio and JS timers keep running; it takes no input.
 */
@Composable
private fun StrudelWebViewHost(services: AppServices) {
    val webView by services.engine.strudelWebView.collectAsState()
    val view = webView ?: return
    key(view) {
        AndroidView(
            factory = { _: Context ->
                (view.parent as? ViewGroup)?.removeView(view)
                view
            },
            modifier = Modifier.size(1.dp).alpha(0.01f).clearAndSetSemantics {}.pointerInput(Unit) {},
            onReset = null,
            onRelease = { released: WebView -> (released.parent as? ViewGroup)?.removeView(released) },
        )
    }
}

/** Status bar shown with theme-coloured icons, hidden while running or on full-screen feed; nav bar always hidden. */
@Composable
private fun SystemBars(hideStatusBar: Boolean, lightBackground: Boolean) {
    val view = LocalView.current
    if (view.isInEditMode) return
    SideEffect {
        val window = view.context.findActivity()?.window ?: return@SideEffect
        val controller = WindowCompat.getInsetsController(window, view)
        controller.systemBarsBehavior = WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
        controller.hide(WindowInsetsCompat.Type.navigationBars())
        if (hideStatusBar) controller.hide(WindowInsetsCompat.Type.statusBars())
        else controller.show(WindowInsetsCompat.Type.statusBars())
        controller.isAppearanceLightStatusBars = lightBackground
        controller.isAppearanceLightNavigationBars = lightBackground
    }
}

/**
 * iOS `.task(id: canShowReview)`: after 3 new takes, on an idle Music tab with nothing
 * presented, wait 2 s and ask Play for the review card. "Nothing presented" is checked
 * through window focus, since every sheet and dialog takes focus from the activity window.
 */
@Composable
private fun ReviewPromptEffect(services: AppServices, navigator: DefaultAppNavigator) {
    val prompt = services.reviewPrompt as? PlayReviewPrompt ?: return
    val ready by prompt.readyThisSession.collectAsState()
    val lifecycle by LocalLifecycleOwner.current.lifecycle.currentStateAsState()
    val destination by navigator.destination.collectAsState()
    val running by services.engine.isRunning.collectAsState()
    val starting by navigator.isStartingSession.collectAsState()
    val sheet by navigator.sheet.collectAsState()
    val error by navigator.error.collectAsState()
    val capture by services.capture.state.collectAsState()
    val windowFocused = LocalWindowInfo.current.isWindowFocused
    val activity = LocalContext.current.findActivity()

    val canShowReview = ready && lifecycle.isAtLeast(Lifecycle.State.RESUMED) && destination == Destination.Music &&
        !running && !starting && sheet == null && error == null && windowFocused &&
        !capture.isRecording && !capture.isBusy && capture.countdown == null && !capture.isLoopCapturing

    LaunchedEffect(canShowReview) {
        if (!canShowReview || activity == null) return@LaunchedEffect
        delay(2_000)
        prompt.requestIfDue(activity)
    }
}

private fun Context.findActivity(): Activity? {
    var context: Context? = this
    while (context is ContextWrapper) {
        if (context is Activity) return context
        context = context.baseContext
    }
    return null
}
