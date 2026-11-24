package com.handstrudel.social

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import com.handstrudel.social.data.FeedService
import com.handstrudel.social.data.PostgrestException
import com.handstrudel.social.data.ProfileImageStore
import com.handstrudel.social.data.RestJson
import com.handstrudel.social.data.SocialException
import com.handstrudel.social.data.SupabaseRest
import com.handstrudel.social.model.Profile
import com.handstrudel.social.model.Video
import io.github.jan.supabase.auth.Auth
import io.github.jan.supabase.auth.OtpType
import io.github.jan.supabase.auth.SignOutScope
import io.github.jan.supabase.auth.providers.Google
import io.github.jan.supabase.auth.providers.builtin.IDToken
import io.github.jan.supabase.auth.providers.builtin.OTP
import io.github.jan.supabase.auth.status.SessionStatus
import io.github.jan.supabase.auth.user.UserSession
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import okhttp3.CacheControl
import okhttp3.OkHttpClient
import okhttp3.Request
import java.time.Instant
import java.time.format.DateTimeFormatter
import java.util.UUID

/**
 * Owns the signed-in user and their profile (iOS `AuthManager`). Implements the
 * [AuthSession] seam that store (RevenueCat follows [userId]) and capture
 * (account-pinned uploads) use.
 */
class AuthManager(
    private val auth: Auth,
    private val rest: SupabaseRest,
    val feed: FeedService,
    private val scope: CoroutineScope,
    context: Context,
    http: OkHttpClient,
) : AuthSession {

    companion object {
        const val DISPLAY_NAME_LIMIT = 40

        /**
         * iOS `performAccountDeletion`: sign out only after the server confirmed. A lost
         * response doesn't establish whether the server completed deletion.
         */
        suspend fun performAccountDeletion(request: suspend () -> Unit, signOut: suspend () -> Unit): AccountDeletionResult {
            try { request() } catch (e: Exception) { return AccountDeletionResult.UNCONFIRMED }
            signOut()
            return AccountDeletionResult.DELETED
        }

        /** supabase-swift `Session.isExpired`: a token expiring within 30 s counts as expired. */
        const val EXPIRY_MARGIN_MILLIS = 30_000L

        fun isExpired(expiresAtMillis: Long, nowMillis: Long): Boolean = expiresAtMillis - nowMillis < EXPIRY_MARGIN_MILLIS

        /**
         * The session the UI treats as signed in, given a supabase-kt status (iOS `apply(_:)`
         * signs the UI out for a missing or expired session). [lastSession] is the last
         * Authenticated session: during [SessionStatus.RefreshFailure] (offline, server error)
         * supabase-kt keeps retrying, so the UI stays signed in until that token expires.
         */
        fun activeSession(status: SessionStatus, lastSession: UserSession?, nowMillis: Long): UserSession? {
            val session = when (status) {
                is SessionStatus.Authenticated -> status.session
                is SessionStatus.RefreshFailure -> lastSession
                is SessionStatus.NotAuthenticated, SessionStatus.Initializing -> null
            }
            return session?.takeUnless { isExpired(it.expiresAt.toEpochMilliseconds(), nowMillis) }
        }
    }

    enum class AccountDeletionResult { DELETED, UNCONFIRMED }

    /** A non-2xx Edge Function response (iOS `FunctionsError.httpError`). */
    class FunctionHttpException(val status: Int, val body: String) : Exception("Request failed ($status).")

    override val isConfigured: Boolean = true

    private val _userId = MutableStateFlow<UUID?>(null)
    override val userId: StateFlow<UUID?> = _userId
    private val _email = MutableStateFlow<String?>(null)
    val email: StateFlow<String?> = _email
    private val _profile = MutableStateFlow<Profile?>(null)
    override val profile: StateFlow<Profile?> = _profile
    private val _isLoadingProfile = MutableStateFlow(false)
    val isLoadingProfile: StateFlow<Boolean> = _isLoadingProfile
    /** True once supabase-kt restored (or failed to restore) the saved session. */
    private val _initialized = MutableStateFlow(false)
    val initialized: StateFlow<Boolean> = _initialized
    val errorMessage = MutableStateFlow<String?>(null)

    val isSignedIn: Boolean get() = _userId.value != null
    /** Signed in, but still needs a username and terms acceptance before posting. */
    override val needsProfileSetup: Boolean get() = needsSetup(_userId.value, _profile.value)
    val needsProfileSetupFlow: StateFlow<Boolean> =
        combine(_userId, _profile) { id, p -> needsSetup(id, p) }.stateIn(scope, SharingStarted.Eagerly, false)

    private fun needsSetup(id: UUID?, p: Profile?) = id != null && (p?.username == null || p.acceptedTermsAt == null)

    /** Profile photos and portfolio thumbnails (iOS `accountPortfolio.images`). */
    val images: ProfileImageStore<Bitmap> = ProfileImageStore(scope, fetch = { url -> fetchImage(http, url) })
    val accountPortfolio = AccountPortfolio(scope, images, feed)

    private var profileRequest = UUID.randomUUID()

    /** The last Authenticated session (kept through refresh failures to check its expiry). */
    private var lastSession: UserSession? = null
    private var expiryJob: kotlinx.coroutines.Job? = null

    init {
        scope.launch {
            auth.sessionStatus.collect { status ->
                if (status is SessionStatus.Initializing) return@collect
                _initialized.value = true
                lastSession = when (status) {
                    is SessionStatus.Authenticated -> status.session
                    is SessionStatus.NotAuthenticated -> null
                    else -> lastSession
                }
                applyStatus(status)
            }
        }
    }

    /**
     * iOS signs the UI out when the session has expired. While supabase-kt can't refresh
     * (offline, server error) it keeps retrying in RefreshFailure; once the old token runs
     * out, the UI shows signed out, and a later successful refresh signs it back in.
     */
    private fun applyStatus(status: SessionStatus) {
        expiryJob?.cancel()
        val session = activeSession(status, lastSession, System.currentTimeMillis())
        apply(session)
        if (session != null && status is SessionStatus.RefreshFailure) {
            val wait = session.expiresAt.toEpochMilliseconds() - EXPIRY_MARGIN_MILLIS - System.currentTimeMillis()
            expiryJob = scope.launch {
                kotlinx.coroutines.delay(wait.coerceAtLeast(0))
                if (auth.sessionStatus.value is SessionStatus.RefreshFailure) applyStatus(auth.sessionStatus.value)
            }
        }
    }

    private fun apply(session: UserSession?) {
        val user = session?.user
        val id = user?.id?.let { runCatching { UUID.fromString(it) }.getOrNull() }
        if (session == null || id == null) {
            profileRequest = UUID.randomUUID()
            _userId.value = null; _email.value = null; _profile.value = null
            _isLoadingProfile.value = false
            accountPortfolio.selectAccount(null)
            return
        }
        val changed = _userId.value != id
        if (changed) {
            profileRequest = UUID.randomUUID()
            _profile.value = null
            _isLoadingProfile.value = true
            accountPortfolio.selectAccount(id)
        }
        _userId.value = id
        _email.value = user.email
        if (changed) scope.launch { refreshProfile() }
    }

    suspend fun refreshProfile() {
        val userId = _userId.value ?: return
        val request = UUID.randomUUID()
        profileRequest = request
        _isLoadingProfile.value = true
        val refreshed = runCatching { rest.from("profiles").select().eq("id", userId).single().decodeSingle<Profile>() }.getOrNull()
        if (_userId.value != userId || profileRequest != request) return
        _isLoadingProfile.value = false
        if (refreshed != null && refreshed.id == userId) _profile.value = refreshed
    }

    // ---- AuthSession seam -------------------------------------------------------

    override suspend fun accessToken(): String? {
        val session = auth.currentSessionOrNull() ?: return null
        val expiresAt = session.expiresAt.toEpochMilliseconds()
        if (expiresAt - System.currentTimeMillis() < 60_000) runCatching { auth.refreshCurrentSession() }
        return auth.currentAccessTokenOrNull()
    }

    override suspend fun functionsFor(accountId: UUID): SupabaseFunctionsInvoker {
        if (_userId.value != accountId) throw AccountChangedException()
        return object : SupabaseFunctionsInvoker {
            override val accountId: UUID = accountId
            override suspend fun invoke(function: String, body: JsonElement): FunctionResponse {
                val sessionUser = auth.currentSessionOrNull()?.user?.id
                if (sessionUser == null || !sessionUser.equals(accountId.toString(), ignoreCase = true)) throw AccountChangedException()
                val token = accessToken() ?: throw AccountChangedException()
                val response = rest.function(function, body.toString().toByteArray(), token = token)
                return FunctionResponse(response.status, response.body)
            }
        }
    }

    // ---- Email one-time code ----------------------------------------------------

    suspend fun sendEmailCode(email: String): Boolean = try {
        auth.signInWith(OTP) { this.email = email.trim() }
        true
    } catch (e: Exception) {
        errorMessage.value = friendly(e)
        false
    }

    suspend fun verifyEmailCode(code: String, email: String) {
        try {
            auth.verifyEmailOtp(type = OtpType.Email.EMAIL, email = email.trim(), token = code.trim())
        } catch (e: Exception) {
            errorMessage.value = friendly(e)
        }
    }

    /** Google ID token from Credential Manager (the raw nonce whose SHA-256 was sent to Google). */
    suspend fun signInWithGoogle(idToken: String, rawNonce: String) {
        try {
            auth.signInWith(IDToken) {
                this.idToken = idToken
                provider = Google
                nonce = rawNonce
            }
        } catch (e: Exception) {
            errorMessage.value = friendly(e)
        }
    }

    // ---- Profile ----------------------------------------------------------------

    /** Sets the username and records terms acceptance. Returns false if the name is taken. */
    suspend fun completeProfile(username: String): Boolean {
        val userId = _userId.value ?: return false
        return try {
            rest.from("profiles").update(buildJsonObject {
                put("username", username)
                put("accepted_terms_at", DateTimeFormatter.ISO_INSTANT.format(Instant.now()))
            }).eq("id", userId).execute()
            refreshProfile()
            true
        } catch (e: Exception) {
            errorMessage.value = if ((e as? PostgrestException)?.code == "23505") "That username is taken." else friendly(e)
            false
        }
    }

    suspend fun updateDisplayName(displayName: String) {
        val userId = _userId.value
        val current = _profile.value
        if (userId == null || current == null || current.id != userId) throw SocialException("Sign in again to edit your profile.")
        val name = displayName.trim()
        if (name.codePointCount(0, name.length) > DISPLAY_NAME_LIMIT) throw SocialException("Use 40 characters or fewer.")
        val value = name.ifEmpty { null }
        rest.from("profiles").update(buildJsonObject {
            put("display_name", value?.let(::JsonPrimitive) ?: JsonNull)
        }).eq("id", userId).execute()
        val latest = _profile.value
        if (_userId.value != userId || latest == null || latest.id != userId) return
        _profile.value = latest.copy(displayName = value)
    }

    @Serializable private data class AvatarResult(val avatarKey: String? = null)

    /** Uploads a square JPEG (or removes the photo with null) through `profile-avatar`. */
    suspend fun updateAvatar(jpeg: ByteArray?) {
        val userId = _userId.value
        if (userId == null || _profile.value?.id != userId) throw SocialException("Sign in again to edit your profile.")
        val response = if (jpeg != null) rest.function("profile-avatar", jpeg, contentType = "image/jpeg")
        else rest.function("profile-avatar", method = "DELETE")
        if (response.status !in 200..299) throw FunctionHttpException(response.status, response.body)
        val result = RestJson.decodeFromString<AvatarResult>(response.body)
        val updated = _profile.value
        if (_userId.value != userId || updated == null || updated.id != userId) return
        val oldKey = updated.avatarKey
        if (oldKey != null && oldKey != result.avatarKey) {
            images.discard(ProfileImageStore.Resource(SocialConfig.mediaUrl(oldKey), ProfileImageStore.Kind.AVATAR))
        }
        _profile.value = updated.copy(avatarKey = result.avatarKey)
    }

    /** iOS `signOut()`: supabase-swift revokes every session (`.global`); supabase-kt defaults to LOCAL. */
    suspend fun signOut() {
        runCatching { auth.signOut(SignOutScope.GLOBAL) }
        if (auth.currentSessionOrNull() != null) runCatching { auth.clearSession() }
    }

    /** Permanently deletes the account, its videos and files (`delete-account`). */
    suspend fun deleteAccount(): AccountDeletionResult = performAccountDeletion(
        request = {
            val response = rest.function("delete-account")
            if (response.status !in 200..299) throw FunctionHttpException(response.status, response.body)
        },
        signOut = { signOut() },
    )

    private fun friendly(e: Exception): String {
        val raw = e.message?.lineSequence()?.firstOrNull { it.isNotBlank() }?.trim()
        return when {
            e is java.io.IOException -> "Check your connection and try again."
            raw.isNullOrBlank() -> "Something went wrong. Try again."
            raw.contains("expired", ignoreCase = true) || raw.contains("invalid", ignoreCase = true) && raw.contains("token", ignoreCase = true) ->
                "That code is invalid or has expired."
            else -> raw
        }
    }
}

/**
 * The signed-in creator's own posts and counts (iOS `AccountPortfolio`), kept as a
 * snapshot while refreshing so the Account tab doesn't blank on return.
 */
class AccountPortfolio(
    private val scope: CoroutineScope,
    val images: ProfileImageStore<Bitmap>?,
    private val feed: FeedService?,
    private val fetchPage: suspend (UUID, Video?) -> List<Video> = { id, last -> feed!!.ownerPage(id, last) },
    private val fetchCounts: suspend (UUID) -> FeedService.ProfileCounts = { id -> feed!!.profileCounts(id, owner = true) },
) {
    val videos = MutableStateFlow<List<Video>>(emptyList())
    val counts = MutableStateFlow<FeedService.ProfileCounts?>(null)
    val more = MutableStateFlow(false)
    val failed = MutableStateFlow(false)
    val isLoadingMore = MutableStateFlow(false)
    val hasLoadedPage = MutableStateFlow(false)
    private var account: UUID? = null
    private var requestId = UUID.randomUUID()
    private var loading = false

    fun selectAccount(id: UUID?) {
        if (account == id) return
        account = id
        images?.let { scope.launch { it.clear() } }
        requestId = UUID.randomUUID()
        loading = false
        videos.value = emptyList()
        counts.value = null
        more.value = false
        failed.value = false
        isLoadingMore.value = false
        hasLoadedPage.value = false
    }

    suspend fun load(id: UUID, append: Boolean = false) {
        if (id != account || (append && (!more.value || loading))) return
        val request = UUID.randomUUID()
        requestId = request
        loading = true
        isLoadingMore.value = append
        failed.value = false
        try {
            kotlinx.coroutines.coroutineScope {
                val metrics = async { if (!append) updateCounts(id, request) }
                try {
                    val page = fetchPage(id, if (append) videos.value.lastOrNull() else null)
                    if (request == requestId) {
                        if (append) {
                            val ids = videos.value.map { it.id }.toSet()
                            videos.value = videos.value + page.filter { it.id !in ids }
                        } else {
                            videos.value = page
                            hasLoadedPage.value = true
                        }
                        more.value = page.size == FeedService.PAGE_SIZE
                    }
                } catch (e: kotlinx.coroutines.CancellationException) {
                    throw e
                } catch (e: Exception) {
                    if (request == requestId) failed.value = true
                }
                metrics.await()
            }
        } finally {
            if (request == requestId) { loading = false; isLoadingMore.value = false }
        }
    }

    private suspend fun updateCounts(id: UUID, request: UUID) {
        val result = fetchCounts(id)
        if (request != requestId) return
        val cached = counts.value
        counts.value = FeedService.ProfileCounts(
            posts = result.posts ?: cached?.posts,
            followers = result.followers ?: cached?.followers,
            following = result.following ?: cached?.following,
            likesReceived = result.likesReceived ?: cached?.likesReceived,
            viewsReceived = result.viewsReceived ?: cached?.viewsReceived,
        )
    }

    fun remove(video: UUID, from: UUID) {
        if (from != account) return
        videos.value.firstOrNull { it.id == video }?.let { post ->
            images?.let { scope.launch { it.discard(ProfileImageStore.Resource(post.thumbUrl, ProfileImageStore.Kind.THUMBNAIL)) } }
        }
        videos.value = videos.value.filter { it.id != video }
    }
}

/** iOS `ProfileImageStore.fetchImage`: no cache, 401/403/404/410 → denied, downsampled to 600 px. */
internal suspend fun fetchImage(http: OkHttpClient, url: String): ProfileImageStore.FetchResult<Bitmap> = withContext(Dispatchers.IO) {
    try {
        val request = Request.Builder().url(url).cacheControl(CacheControl.FORCE_NETWORK).build()
        http.newCall(request).execute().use { response ->
            if (response.code in setOf(401, 403, 404, 410)) return@withContext ProfileImageStore.FetchResult.Denied
            if (response.code !in 200..299) return@withContext ProfileImageStore.FetchResult.Unavailable
            val bytes = response.body?.bytes() ?: return@withContext ProfileImageStore.FetchResult.Unavailable
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
            var sample = 1
            while (maxOf(bounds.outWidth, bounds.outHeight) / (sample * 2) >= 600) sample *= 2
            val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size, BitmapFactory.Options().apply { inSampleSize = sample })
                ?: return@withContext ProfileImageStore.FetchResult.Unavailable
            ProfileImageStore.FetchResult.Loaded(bitmap)
        }
    } catch (e: Exception) {
        ProfileImageStore.FetchResult.Unavailable
    }
}
