package com.handstrudel.social.model

import com.handstrudel.common.UuidSerializer
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import java.util.UUID

/** iOS `Profile` (`Social/SocialModels.swift`), a `profiles` row. Owner: social. */
@Serializable
data class Profile(
    @Serializable(with = UuidSerializer::class) val id: UUID,
    val username: String? = null,
    @SerialName("display_name") val displayName: String? = null,
    @SerialName("avatar_key") val avatarKey: String? = null,
    /** ISO-8601 timestamptz; non-null means the EULA was accepted. */
    @SerialName("accepted_terms_at") val acceptedTermsAt: String? = null,
) {
    companion object {
        private val USERNAME = Regex("^[a-z0-9_]{3,20}$")

        /** Lowercase letters, digits and underscores, 3–20 characters (matches the DB check). */
        fun isValidUsername(s: String): Boolean = USERNAME.matches(s)

        /** Normalizes what the user typed into a candidate username. */
        fun normalizeUsername(s: String): String =
            s.lowercase().filter { it.code < 128 && (it.isLetter() || it.isDigit() || it == '_') }.take(20)
    }
}
