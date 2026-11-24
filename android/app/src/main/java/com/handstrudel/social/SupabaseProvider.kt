package com.handstrudel.social

import android.content.Context
import com.handstrudel.social.data.FeedService
import com.handstrudel.social.data.OkHttpTransport
import com.handstrudel.social.data.SupabaseRest
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.Auth
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.createSupabaseClient
import io.github.jan.supabase.logging.LogLevel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import okhttp3.OkHttpClient
import java.util.concurrent.TimeUnit

/**
 * Process-wide social services (iOS's global `supabase` client plus the one
 * `AuthManager`). supabase-kt owns sessions (persistence, refresh, OTP, ID
 * tokens); [SupabaseRest] issues the PostgREST/Functions calls with the
 * session's JWT.
 *
 * Shell wires `AppServices.auth = SocialServices.get(context).auth` (see the
 * TODO in `AppServices.create`); social UI reads the same instance.
 */
class SocialServices private constructor(context: Context) {
    val scope: CoroutineScope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    val http: OkHttpClient = OkHttpClient.Builder()
        .connectTimeout(15, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .build()

    val client: SupabaseClient = createSupabaseClient(SocialConfig.supabaseUrl, SocialConfig.supabaseAnonKey) {
        defaultLogLevel = LogLevel.NONE // never log tokens or the key
        install(Auth)
    }

    val rest: SupabaseRest = SupabaseRest(
        baseUrl = SocialConfig.supabaseUrl,
        anonKey = SocialConfig.supabaseAnonKey,
        transport = OkHttpTransport(http),
        accessToken = { auth.accessToken() },
    )

    val feed: FeedService = FeedService(rest)

    val auth: AuthManager = AuthManager(client.auth, rest, feed, scope, context.applicationContext, http)

    companion object {
        @Volatile private var instance: SocialServices? = null

        /** Null when social is unconfigured (blank key): every entry point degrades to its placeholder. */
        fun getOrNull(context: Context): SocialServices? {
            if (!SocialConfig.isConfigured) return null
            return instance ?: synchronized(this) { instance ?: SocialServices(context.applicationContext).also { instance = it } }
        }

        /** The instance once created (UI code runs after `AppServices.create`). */
        val current: SocialServices? get() = instance
    }
}
