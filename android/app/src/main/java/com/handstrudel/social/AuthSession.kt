package com.handstrudel.social

import com.handstrudel.social.model.Profile
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.serialization.json.JsonElement
import java.util.UUID

/**
 * Signed-in account seam. Owner: social (WS5). Ports the parts of iOS
 * `AuthManager` other workstreams need. Store follows [userId] (RevenueCat
 * logIn/logOut); capture pins uploads to [functionsFor].
 */
interface AuthSession {
    /** False when the Supabase key is blank or starts with `YOUR-` (iOS `SocialConfig.isConfigured`). */
    val isConfigured: Boolean
    val userId: StateFlow<UUID?>
    val profile: StateFlow<Profile?>
    /** True while signed in without a username / accepted terms (posting, commenting, … require false). */
    val needsProfileSetup: Boolean

    /** Current session JWT, refreshed if needed; null when signed out. */
    suspend fun accessToken(): String?

    /** Edge-function caller pinned to [accountId]. Throws [AccountChangedException] if the session user differs. */
    suspend fun functionsFor(accountId: UUID): SupabaseFunctionsInvoker
}

/** Calls Supabase Edge Functions (`sign-upload`, `publish-upload`, `delete-video`, …) as one account. */
interface SupabaseFunctionsInvoker {
    val accountId: UUID

    /**
     * POSTs [body] as JSON to `functions/v1/<function>` with the account's JWT and the anon `apikey`.
     * Returns the HTTP status and raw body for every status (callers map 404/409 etc. like iOS);
     * throws only on transport failure or [AccountChangedException].
     */
    suspend fun invoke(function: String, body: JsonElement): FunctionResponse
}

data class FunctionResponse(val status: Int, val body: String) {
    val isSuccess: Boolean get() = status in 200..299
}

class AccountChangedException(message: String = "The signed-in account changed.") : IllegalStateException(message)

/** Phase 0 stub: social unconfigured / signed out. Social WS replaces it with `AuthManager`. */
class SignedOutAuthSession : AuthSession {
    override val isConfigured: Boolean = false
    override val userId: StateFlow<UUID?> = MutableStateFlow(null)
    override val profile: StateFlow<Profile?> = MutableStateFlow(null)
    override val needsProfileSetup: Boolean = false
    override suspend fun accessToken(): String? = null
    override suspend fun functionsFor(accountId: UUID): SupabaseFunctionsInvoker = throw AccountChangedException()
}
