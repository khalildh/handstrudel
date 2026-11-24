package com.handstrudel.ui

import android.app.ActivityManager
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
import java.lang.ref.WeakReference

/**
 * Single activity. Owner: shell. Services and navigator are process-scoped
 * ([HandStrudelApplication]); the activity contributes the window (immersive, screen kept
 * on), runtime-permission prompts, deep-link intents and foreground/background lifecycle.
 *
 * Launch mode is `singleTop`, not `singleTask`: `singleTask` clears whatever sits above the
 * activity when the launcher intent comes back, and the MediaProjection "Share one app"
 * picker relaunches the launcher intent while its consent activity is still on top, so the
 * consent returned RESULT_CANCELED. With `singleTop`, an intent that arrives while another
 * activity is on top (the camera permission dialog, the consent dialog) creates a second
 * instance; that duplicate hands its intent to the live instance and finishes before it
 * starts, so there is still one activity and the system dialog keeps its result.
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

        val existing = live?.get()
        if (savedInstanceState == null && existing != null && existing !== this && !existing.isFinishing && !existing.isDestroyed) {
            Log.i(TAG, "duplicate instance; relaying ${intent?.action} to the live activity")
            existing.relay(intent)
            if (existing.taskId != taskId) {
                (getSystemService(ACTIVITY_SERVICE) as? ActivityManager)?.moveTaskToFront(existing.taskId, 0)
            }
            finish()
            return
        }
        live = WeakReference(this)

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
        relay(intent)
    }

    /** A new intent for this instance (directly, or from a duplicate instance). */
    private fun relay(intent: Intent?) {
        if (intent == null) return
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
        if (live?.get() === this) live = null
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

    private companion object {
        const val TAG = "MainActivity"
        /** The instance that owns the UI (see the class comment). Main thread only. */
        var live: WeakReference<MainActivity>? = null
    }
}
