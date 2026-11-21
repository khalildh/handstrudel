package com.handstrudel.social

import com.handstrudel.BuildConfig
import java.net.URLEncoder

/**
 * Backend endpoints for accounts and the video feed (iOS `SocialConfig`).
 *
 * The Supabase anon key is public by design (row-level security protects the
 * data). Values come from `BuildConfig`, which Gradle parses from the iOS
 * `SocialConfig.swift` or takes from `-Phandstrudel.*` overrides (local stacks).
 * Never log the key.
 */
object SocialConfig {
    val supabaseUrl: String get() = BuildConfig.SUPABASE_URL.trimEnd('/')
    val supabaseAnonKey: String get() = BuildConfig.SUPABASE_ANON_KEY
    val mediaBaseUrl: String get() = BuildConfig.MEDIA_BASE_URL.trimEnd('/')
    val clipMediaBaseUrl: String get() = BuildConfig.CLIP_MEDIA_BASE_URL.trimEnd('/')

    /** False until real credentials are filled in, so the UI can hide social entry points. */
    val isConfigured: Boolean get() = isConfigured(supabaseAnonKey)

    fun isConfigured(key: String): Boolean = key.isNotBlank() && !key.startsWith("YOUR-")

    /** Email-code sign-in (Resend SMTP with the 6-digit `otp.html` template). */
    const val EMAIL_SIGN_IN_ENABLED = true

    /** Google sign-in shows only when a Web OAuth client id was passed to the build (Risk R4). */
    val googleWebClientId: String get() = BuildConfig.GOOGLE_WEB_CLIENT_ID

    const val TERMS_URL = "https://handstrudel.com/terms"
    const val GUIDELINES_URL = "https://handstrudel.com/community"
    const val WATCH_URL = "https://handstrudel.com/watch"
    const val SUPPORT_URL = "https://handstrudel.com/support"

    /** Android replacement for iOS `reviewURL` (App Store write-review link). */
    const val PLAY_LISTING_URL = "https://play.google.com/store/apps/details?id=com.handstrudel.app"
    const val PLAY_MARKET_URL = "market://details?id=com.handstrudel.app"

    /**
     * iOS `mediaURL`: keys shaped `videos|thumbs/<user>/screened/<file>` are served by the
     * clips domain; everything else (legacy clips, avatars) by the media domain.
     */
    fun mediaUrl(key: String, mediaBase: String = mediaBaseUrl, clipBase: String = clipMediaBaseUrl): String {
        val parts = key.split('/')
        val screened = parts.size == 4 && (parts[0] == "videos" || parts[0] == "thumbs") && parts[2] == "screened"
        val base = if (screened) clipBase else mediaBase
        return base.trimEnd('/') + "/" + key.split('/').joinToString("/") { encodePathSegment(it) }
    }

    /** iOS `creatorURL`: `https://handstrudel.com/creator?u=<username>`. */
    fun creatorUrl(username: String): String =
        "https://handstrudel.com/creator?u=" + URLEncoder.encode(username, "UTF-8").replace("+", "%20")

    /** Matches Foundation's `appendingPathComponent` escaping for the characters keys use. */
    private fun encodePathSegment(segment: String): String = buildString {
        for (byte in segment.toByteArray(Charsets.UTF_8)) {
            val c = byte.toInt() and 0xff
            val ch = c.toChar()
            if (ch.isLetterOrDigit() && c < 128 || ch in "-._~!$&'()*+,;=:@") append(ch)
            else append('%').append("%02X".format(c))
        }
    }
}
