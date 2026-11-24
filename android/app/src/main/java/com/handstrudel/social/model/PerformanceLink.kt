package com.handstrudel.social.model

import java.net.URI
import java.net.URLDecoder
import java.util.UUID

/**
 * iOS `PerformanceLink`: deep links to a post. Owner: social.
 *
 * * `https://handstrudel.com/watch?v=<uuid>` (path `/watch` or `/watch/`, exactly one `v`) → [Watch]
 * * `handstrudel://watch|comments|sound|play/<uuid>` → [Watch] / [Comments] / [Sound] / [PlayAlong]
 *
 * URLs with user info or a port are rejected. Pure JVM (java.net.URI) so it is unit-testable.
 */
sealed interface PerformanceLink {
    val videoId: UUID

    data class Watch(override val videoId: UUID) : PerformanceLink
    data class Comments(override val videoId: UUID) : PerformanceLink
    data class Sound(override val videoId: UUID) : PerformanceLink
    data class PlayAlong(override val videoId: UUID) : PerformanceLink

    companion object {
        const val WATCH_HOST = "handstrudel.com"

        fun parse(url: String): PerformanceLink? {
            val uri = try { URI(url) } catch (_: Exception) { return null }
            if (uri.rawUserInfo != null || uri.port != -1) return null
            if (uri.scheme == "https" && uri.host == WATCH_HOST && (uri.path == "/watch" || uri.path == "/watch/")) {
                val ids = (uri.rawQuery ?: "").split('&')
                    .map { it.split('=', limit = 2) }
                    .filter { URLDecoder.decode(it[0], "UTF-8") == "v" }
                if (ids.size != 1) return null
                val value = ids[0].getOrNull(1)?.let { URLDecoder.decode(it, "UTF-8") } ?: return null
                return uuid(value)?.let(::Watch)
            }
            if (uri.scheme != "handstrudel") return null
            val segments = (uri.rawPath ?: "").split('/').filter { it.isNotEmpty() }
            if (segments.size != 1) return null
            val id = uuid(segments[0]) ?: return null
            return when (uri.host) {
                "watch" -> Watch(id)
                "comments" -> Comments(id)
                "sound" -> Sound(id)
                "play" -> PlayAlong(id)
                else -> null
            }
        }

        /** Swift `UUID(uuidString:)` accepts only the canonical 36-char form. */
        private fun uuid(s: String): UUID? =
            if (s.length == 36) runCatching { UUID.fromString(s) }.getOrNull() else null
    }
}
