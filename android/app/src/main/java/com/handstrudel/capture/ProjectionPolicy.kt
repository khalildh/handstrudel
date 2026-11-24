package com.handstrudel.capture

/**
 * When the studio may drop its MediaProjection between takes.
 *
 * iOS's ReplayKit shows no indicator once a take stops. Android shows one (the cast icon,
 * and on 15+ the red screen-share chip) for as long as a projection is held. Before
 * Android 14 the consent result can be passed to `getMediaProjection` again, so the
 * projection is released after each take and recreated silently for the next one. From
 * Android 14 (API 34) a consent token is single use: a released projection can't be
 * recreated without asking again, so the studio keeps one projection for the whole
 * session (one consent per session) and the indicator stays until the session ends.
 */
internal object ProjectionPolicy {
    const val SINGLE_USE_TOKEN_SDK = 34

    fun canReuseConsent(sdkInt: Int): Boolean = sdkInt < SINGLE_USE_TOKEN_SDK
}
