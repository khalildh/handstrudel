package com.handstrudel.ui

import android.content.Intent
import android.os.Bundle
import android.util.Log
import android.view.WindowManager
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import com.handstrudel.app.AppServices
import com.handstrudel.app.DebugFakeSocial
import com.handstrudel.app.DebugShellHooks
import com.handstrudel.app.DeepLinkRouter
import com.handstrudel.app.HandStrudelApplication
import com.handstrudel.ui.nav.DefaultAppNavigator

/**
 * Single activity. Owner: shell. Services and navigator are process-scoped
 * ([HandStrudelApplication]); the activity contributes the window (immersive, screen kept
 * on), runtime-permission prompts, deep-link intents and foreground/background lifecycle.
 */
class MainActivity : ComponentActivity() {

    private val app: HandStrudelApplication get() = application as HandStrudelApplication
    private val services: AppServices get() = app.services
    private val navigator: DefaultAppNavigator get() = app.navigator

    private val permissionLauncher = registerForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        navigator.onPermissionResult(granted)
    }
    private val permissionHost = DefaultAppNavigator.PermissionHost { permission -> permissionLauncher.launch(permission) }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Edge to edge; keep the screen on (iOS isIdleTimerDisabled); hide the navigation bar
        // (iOS persistentSystemOverlays(.hidden)). The status bar is managed by HandStrudelApp.
        WindowCompat.setDecorFitsSystemWindows(window, false)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        WindowInsetsControllerCompat(window, window.decorView).apply {
            systemBarsBehavior = WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
            hide(WindowInsetsCompat.Type.navigationBars())
        }

        navigator.permissionHost = permissionHost
        DebugFakeSocial.installIfRequested(intent, navigator)
        DebugShellHooks.handle(intent)

        setContent { HandStrudelApp(services, navigator) }
        // A recreated activity has already routed its launch intent.
        if (savedInstanceState == null) handleDeepLink(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        navigator.onPermissionFlowInterrupted()
        DebugFakeSocial.installIfRequested(intent, navigator)
        DebugShellHooks.handle(intent)
        handleDeepLink(intent)
    }

    override fun onStart() {
        super.onStart()
        val engine = services.engine
        engine.setSceneActive(true)
        services.analytics.recordActiveDay()
        // iOS: on becoming active with a camera issue, try the camera again (e.g. permission
        // granted in Settings, or another app released the camera).
        if (engine.isRunning.value && engine.cameraIssue.value != null) engine.startCameraIfRequested()
    }

    override fun onStop() {
        services.engine.setSceneActive(false)
        services.capture.onAppBackgrounded()
        super.onStop()
    }

    override fun onDestroy() {
        if (navigator.permissionHost === permissionHost) navigator.permissionHost = null
        super.onDestroy()
    }

    private fun handleDeepLink(intent: Intent?) {
        if (intent?.action != Intent.ACTION_VIEW) return
        val link = DeepLinkRouter.linkFrom(intent)
        if (link == null) {
            Log.i(TAG, "ignored unsupported link")
            return
        }
        navigator.openPerformance(link)
    }

    private companion object { const val TAG = "MainActivity" }
}
