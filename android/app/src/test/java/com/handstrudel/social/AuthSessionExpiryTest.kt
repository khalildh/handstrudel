package com.handstrudel.social

import io.github.jan.supabase.auth.status.RefreshFailureCause
import io.github.jan.supabase.auth.status.SessionSource
import io.github.jan.supabase.auth.status.SessionStatus
import io.github.jan.supabase.auth.user.UserSession
import kotlinx.datetime.Instant
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.IOException

/** iOS `AuthManager.apply(_:)`: a missing or expired session shows as signed out. */
class AuthSessionExpiryTest {
    private val now = 1_800_000_000_000L

    private fun session(expiresAt: Long) = UserSession(
        accessToken = "a", refreshToken = "r", expiresIn = 3600, tokenType = "bearer",
        expiresAt = Instant.fromEpochMilliseconds(expiresAt),
    )

    @Test fun isExpired_usesSupabaseSwiftThirtySecondMargin() {
        assertTrue(AuthManager.isExpired(now - 1, now))
        assertTrue(AuthManager.isExpired(now + 29_999, now))
        assertFalse(AuthManager.isExpired(now + 30_000, now))
        assertFalse(AuthManager.isExpired(now + 3_600_000, now))
    }

    @Test fun authenticated_validSessionSignsIn_expiredSignsOut() {
        val valid = session(now + 3_600_000)
        assertEquals(valid, AuthManager.activeSession(SessionStatus.Authenticated(valid, SessionSource.Unknown), null, now))
        val expired = session(now - 1_000)
        assertNull(AuthManager.activeSession(SessionStatus.Authenticated(expired, SessionSource.Unknown), null, now))
    }

    @Test fun refreshFailure_keepsUnexpiredSession_signsOutOnceExpired() {
        val failure = SessionStatus.RefreshFailure(RefreshFailureCause.NetworkError(IOException("offline")))
        val last = session(now + 120_000)
        assertEquals(last, AuthManager.activeSession(failure, last, now))
        assertNull(AuthManager.activeSession(failure, last, now + 100_000))
        assertNull(AuthManager.activeSession(failure, null, now))
    }

    @Test fun notAuthenticated_signsOut() {
        assertNull(AuthManager.activeSession(SessionStatus.NotAuthenticated(isSignOut = true), session(now + 3_600_000), now))
    }
}
