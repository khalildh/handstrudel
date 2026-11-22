package com.handstrudel.app

import android.content.Context
import androidx.compose.runtime.ProvidableCompositionLocal
import androidx.compose.runtime.staticCompositionLocalOf
import com.handstrudel.BuildConfig
import com.handstrudel.capture.CaptureController
import com.handstrudel.capture.CaptureControllerImpl
import com.handstrudel.engine.EngineController
import com.handstrudel.engine.LegacyStudioEngine
import com.handstrudel.engine.StudioEngine
import com.handstrudel.social.AuthSession
import com.handstrudel.social.SignedOutAuthSession
import com.handstrudel.store.StoreGate
import com.handstrudel.store.StoreManager

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
         * Called once per process by `HandStrudelApplication` (services outlive the activity).
         * Shell's prefs/analytics/review prompt are real; at integration (3.8 step 2) each
         * other WS's constructor replaces its stub here; keep one line per service.
         */
        fun create(context: Context): AppServices {
            val app = context.applicationContext
            val prefsStore = SharedPrefsStore(app)
            val prefs = StoreBackedAppPrefs(prefsStore)
            val auth: AuthSession =                                        // social
                com.handstrudel.social.SocialServices.getOrNull(app)?.auth ?: SignedOutAuthSession()
            val store: StoreGate = StoreManager.create(app)                // store
            store.bind(auth.userId)
            val analytics = createAnalytics(prefs, prefsStore)              // shell
            val engine: StudioEngine = LegacyStudioEngine(EngineController(app)) // engine
            engine.onFirstNote = { analytics.record(AppAnalyticsEvent.FIRST_NOTE) }
            val reviewPrompt = PlayReviewPrompt(prefs, BuildConfig.VERSION_NAME) // shell
            val capture: CaptureController =                                  // capture
                CaptureControllerImpl(app, prefs, engine, store, auth, analytics, reviewPrompt)
            return AppServices(
                prefs = prefs,
                analytics = analytics,
                engine = engine,
                store = store,
                auth = auth,
                capture = capture,
                reviewPrompt = reviewPrompt,
            )
        }

        private fun createAnalytics(prefs: AppPrefs, prefsStore: PrefsStore): AppAnalytics {
            val sender = UsageEventSender(
                supabaseUrl = BuildConfig.SUPABASE_URL,
                anonKey = BuildConfig.SUPABASE_ANON_KEY,
                isOptedIn = { prefs.appUsageAnalyticsEnabled.value },
            )
            return DefaultAppAnalytics(prefs, prefsStore, send = sender)
        }
    }
}

val LocalAppServices: ProvidableCompositionLocal<AppServices> =
    staticCompositionLocalOf { error("LocalAppServices not provided") }
