package com.handstrudel.app

import android.content.Context
import androidx.compose.runtime.ProvidableCompositionLocal
import androidx.compose.runtime.staticCompositionLocalOf
import com.handstrudel.capture.CaptureController
import com.handstrudel.capture.NoopCaptureController
import com.handstrudel.engine.EngineController
import com.handstrudel.engine.LegacyStudioEngine
import com.handstrudel.engine.StudioEngine
import com.handstrudel.social.AuthSession
import com.handstrudel.social.SignedOutAuthSession
import com.handstrudel.store.StoreGate
import com.handstrudel.store.UnconfiguredStoreGate

/**
 * The composition root's service bag. Owner: shell. Created once in
 * `MainActivity` and provided through [LocalAppServices]. Each field has one
 * owning workstream that supplies the real implementation:
 *
 * prefs/analytics/reviewPrompt → shell, engine → engine, store → store,
 * auth → social, capture → capture.
 */
class AppServices(
    val prefs: AppPrefs,
    val analytics: AppAnalytics,
    val engine: StudioEngine,
    val store: StoreGate,
    val auth: AuthSession,
    val capture: CaptureController,
    val reviewPrompt: ReviewPrompt,
) {
    companion object {
        /**
         * Phase 0 wiring: real prefs, stub everything else. At integration (3.8 step 2)
         * each WS's constructor replaces its stub here; keep one line per service.
         */
        fun create(context: Context): AppServices {
            val app = context.applicationContext
            val prefs = StoreBackedAppPrefs(SharedPrefsStore(app))
            val auth: AuthSession = SignedOutAuthSession()                 // social
            val store: StoreGate = UnconfiguredStoreGate()                  // store
            store.bind(auth.userId)
            return AppServices(
                prefs = prefs,
                analytics = NoopAppAnalytics(prefs),                        // shell
                engine = LegacyStudioEngine(EngineController(app)),         // engine
                store = store,
                auth = auth,
                capture = NoopCaptureController(),                          // capture
                reviewPrompt = NoopReviewPrompt(),                          // shell
            )
        }
    }
}

val LocalAppServices: ProvidableCompositionLocal<AppServices> =
    staticCompositionLocalOf { error("LocalAppServices not provided") }
