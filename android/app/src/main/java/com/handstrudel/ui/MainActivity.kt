package com.handstrudel.ui

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import android.view.WindowManager
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.ContextCompat
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import androidx.lifecycle.lifecycleScope
import com.handstrudel.app.AppServices
import com.handstrudel.social.model.PerformanceLink
import com.handstrudel.ui.nav.DefaultAppNavigator

/** Single activity. Owner: shell. */
class MainActivity : ComponentActivity() {

    private lateinit var services: AppServices
    private lateinit var navigator: DefaultAppNavigator
    private var pendingCameraResult: ((Boolean) -> Unit)? = null

    private val cameraPermission = registerForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        pendingCameraResult?.invoke(granted)
        pendingCameraResult = null
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Full screen, keep screen on.
        WindowCompat.setDecorFitsSystemWindows(window, false)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        val controller = WindowInsetsControllerCompat(window, window.decorView)
        controller.hide(WindowInsetsCompat.Type.systemBars())
        controller.systemBarsBehavior = WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE

        services = AppServices.create(this)
        // Camera is requested lazily at session start (Air input), never at launch.
        navigator = DefaultAppNavigator(
            services = services,
            scope = lifecycleScope,
            hasCameraPermission = {
                ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED
            },
            requestCameraPermission = { onResult ->
                pendingCameraResult = onResult
                cameraPermission.launch(Manifest.permission.CAMERA)
            },
        )

        setContent { HandStrudelApp(services, navigator) }
        handleDeepLink(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleDeepLink(intent)
    }

    override fun onStart() {
        super.onStart()
        services.engine.setSceneActive(true)
    }

    override fun onStop() {
        services.engine.setSceneActive(false)
        services.capture.onAppBackgrounded()
        super.onStop()
    }

    private fun handleDeepLink(intent: Intent?) {
        val url = intent?.takeIf { it.action == Intent.ACTION_VIEW }?.dataString ?: return
        PerformanceLink.parse(url)?.let(navigator::openPerformance)
    }
}
