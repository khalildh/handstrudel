package com.handstrudel.social.data

import com.handstrudel.social.model.CommentReportReason
import com.handstrudel.social.model.CreatorActivity
import com.handstrudel.social.model.PostSearch
import com.handstrudel.social.model.Profile
import com.handstrudel.social.model.PublicCreator
import com.handstrudel.social.model.ReportReason
import com.handstrudel.social.model.Video
import com.handstrudel.social.model.VideoComment
import com.handstrudel.social.model.VideoEngagement
import com.handstrudel.social.model.WeeklyChallenge
import com.handstrudel.common.UuidSerializer
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.ensureActive
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import java.time.Instant
import java.util.UUID
import kotlin.coroutines.coroutineContext

/** iOS `SocialError.message`: a user-facing message. */
class SocialException(message: String) : Exception(message)

/** iOS `FeedService.Unavailable`: a backend feature that isn't deployed yet. */
class UnavailableException(val kind: Kind) : Exception(kind.message) {
    enum class Kind(val message: String) {
        BOOKMARKS("Saving posts isn't available yet."),
        ACTIVITY("Notifications aren't available yet."),
        REPOSTS("Reposting isn't available yet."),
    }
}

/**
 * Reads the public feed and performs the social actions on it (iOS `FeedService`).
 * Social writes act as the caller; public view reports use an anonymous receipt.
 */
class FeedService(private val rest: SupabaseRest) {

    companion object {
        const val PAGE_SIZE = 10
        const val COMMENT_PAGE_SIZE = 20
        const val ACTIVITY_PAGE_SIZE = 25

        fun isMissingView(e: Throwable): Boolean = e is PostgrestException && (e.code == "PGRST205" || e.code == "42P01")
        fun isMissingFunction(e: Throwable): Boolean = e is PostgrestException && (e.code == "PGRST202" || e.code == "42883")
        private fun isUniqueViolation(e: Throwable) = e is PostgrestException && e.code == "23505"

        private fun id(u: UUID) = u.toString().lowercase()

        /** Keyset cursor on (`dateColumn`, id), matching `videos_feed_idx`. */
        fun cursor(last: Video, dateColumn: String = "created_at"): String {
            val ts = (if (dateColumn == "activity_at") last.activityAt else null) ?: last.feedCursorTimestamp
            return "$dateColumn.lt.$ts,and($dateColumn.eq.$ts,id.lt.${id(last.id)})"
        }
    }

    private fun target(video: UUID) = buildJsonObject { put("target_video", id(video)) }

    // ---- Engagement --------------------------------------------------------------

    suspend fun engagement(video: UUID): VideoEngagement? {
        suspend fun load(rpc: String): VideoEngagement? =
            RestJson.decodeFromString<List<VideoEngagement>>(rest.rpc(rpc, target(video))).firstOrNull()
        return try { load("video_engagement_v2") } catch (e: PostgrestException) {
            if (isMissingFunction(e)) load("video_engagement") else throw e
        }
    }

    suspend fun setReposted(repost: Boolean, video: UUID): VideoEngagement? = try {
        val body = rest.rpc("set_video_repost", buildJsonObject { put("target_video", id(video)); put("repost", repost) })
        RestJson.decodeFromString<List<VideoEngagement>>(body).firstOrNull()
    } catch (e: PostgrestException) {
        if (isMissingFunction(e)) throw UnavailableException(UnavailableException.Kind.REPOSTS) else throw e
    }

    suspend fun recordShare(video: UUID) { rest.rpc("record_video_share", target(video)) }

    /** Returns the new total, or null if the server returned nothing usable. */
    suspend fun recordView(video: UUID, receipt: UUID): Int? {
        val body = rest.rpc("record_video_view", buildJsonObject {
            put("target_video", id(video)); put("watch_receipt", id(receipt))
        })
        return body.trim().toIntOrNull()
    }

    // ---- Activity inbox ----------------------------------------------------------

    suspend fun activity(after: CreatorActivity? = null): List<CreatorActivity> {
        suspend fun load(view: String): List<CreatorActivity> {
            val q = rest.from(view).select()
            if (after != null) {
                val date = after.timestamp
                q.or("created_at.lt.$date,and(created_at.eq.$date,id.lt.${id(after.id)})")
            }
            return q.order("created_at", false).order("id", false).limit(ACTIVITY_PAGE_SIZE).decodeList()
        }
        return try { load("activity_inbox_v2") } catch (e: PostgrestException) {
            if (!isMissingView(e)) throw e
            try { load("activity_inbox") } catch (legacy: PostgrestException) {
                if (isMissingView(legacy)) throw UnavailableException(UnavailableException.Kind.ACTIVITY) else throw legacy
            }
        }
    }

    @Serializable private data class IdRow(@Serializable(with = UuidSerializer::class) val id: UUID)

    suspend fun hasUnreadActivity(): Boolean {
        suspend fun check(view: String) = rest.from(view).select("id").isNull("read_at").limit(1).decodeList<IdRow>().isNotEmpty()
        return try { check("activity_inbox_v2") } catch (e: PostgrestException) {
            if (isMissingView(e)) check("activity_inbox") else throw e
        }
    }

    suspend fun markActivityRead(item: CreatorActivity) {
        val rpc = if (item.kind.isLike) "mark_like_activity_read" else "mark_creator_activity_read"
        rest.rpc(rpc, buildJsonObject {
            put("target_item", id(item.id))
            // Swift omits a nil `seen_at`; the comment/reply RPC takes only the item.
            if (item.kind.isLike) put("seen_at", item.timestamp)
        })
    }

    // ---- Lookups -----------------------------------------------------------------

    suspend fun creator(id: UUID): PublicCreator? = try {
        rest.from("public_creators").select().eq("id", id).limit(1).decodeList<PublicCreator>().firstOrNull()
    } catch (e: PostgrestException) {
        if (!isMissingView(e)) throw e
        // Older deployments only expose creator identity on visible feed rows.
        rest.from("feed_videos").select().eq("user_id", id).order("created_at", false).limit(1)
            .decodeList<Video>().firstOrNull()?.let(PublicCreator::fromVisibleVideo)
    }

    suspend fun comment(id: UUID, video: UUID): VideoComment? =
        rest.from("video_comments").select().eq("id", id).eq("video_id", video).limit(1).decodeList<VideoComment>().firstOrNull()

    suspend fun video(id: UUID): Video? =
        rest.from("feed_videos").select().eq("id", id).limit(1).decodeList<Video>().firstOrNull()

    // ---- Bookmarks ---------------------------------------------------------------

    suspend fun bookmarks(after: Video? = null): List<Video> {
        val q = rest.from("saved_videos").select()
        val ts = after?.savedAt
        if (after != null && ts != null) q.or("saved_at.lt.$ts,and(saved_at.eq.$ts,id.lt.${id(after.id)})")
        return try {
            q.order("saved_at", false).order("id", false).limit(PAGE_SIZE).decodeList()
        } catch (e: PostgrestException) {
            if (isMissingView(e)) throw UnavailableException(UnavailableException.Kind.BOOKMARKS) else throw e
        }
    }

    @Serializable private data class VideoIdRow(@SerialName("video_id") @Serializable(with = UuidSerializer::class) val videoId: UUID)

    suspend fun savedVideoIds(ids: List<UUID>): Set<UUID> {
        if (ids.isEmpty()) return emptySet()
        return rest.from("video_bookmarks").select("video_id").inList("video_id", ids.map(::id))
            .decodeList<VideoIdRow>().map { it.videoId }.toSet()
    }

    suspend fun setBookmark(saved: Boolean, video: UUID, user: UUID) {
        try {
            rest.rpc("set_video_bookmark", buildJsonObject { put("target_video", id(video)); put("save", saved) })
            return
        } catch (e: PostgrestException) {
            if (e.code != "PGRST202") throw e
        }
        try {
            if (saved) rest.from("video_bookmarks").insert(buildJsonObject { put("video_id", id(video)) }).execute()
            else rest.from("video_bookmarks").delete().eq("user_id", user).eq("video_id", video).execute()
        } catch (e: PostgrestException) {
            if (saved && isUniqueViolation(e)) return // An existing bookmark is already saved.
            if (isMissingView(e)) throw UnavailableException(UnavailableException.Kind.BOOKMARKS)
            throw e
        }
    }

    // ---- Audio downloads / play-along controls ----------------------------------

    suspend fun audioDownloadsAllowed(ids: List<UUID>): Set<UUID> {
        if (ids.isEmpty()) return emptySet()
        return rest.from("video_audio_downloads").select("video_id").inList("video_id", ids.map(::id))
            .decodeList<VideoIdRow>().map { it.videoId }.toSet()
    }

    suspend fun setAudioDownloadsAllowed(allowed: Boolean, video: UUID) {
        if (allowed) {
            try { rest.from("video_audio_downloads").insert(buildJsonObject { put("video_id", id(video)) }).execute() }
            catch (e: PostgrestException) { if (!isUniqueViolation(e)) throw e }
        } else {
            rest.from("video_audio_downloads").delete().eq("video_id", video).execute()
        }
    }

    suspend fun weeklyChallenge(): WeeklyChallenge? =
        rest.from("weekly_challenges").select().limit(1).decodeList<WeeklyChallenge>().firstOrNull()

    suspend fun setCommentsEnabled(enabled: Boolean, video: UUID, user: UUID) {
        rest.from("videos").update(buildJsonObject { put("comments_enabled", enabled) })
            .eq("id", video).eq("user_id", user).execute()
    }

    suspend fun stopAllowingBacking(video: UUID) {
        rest.from("videos").update(buildJsonObject { put("backing_enabled", false) }).eq("id", video).execute()
    }

    // ---- Comments ----------------------------------------------------------------

    suspend fun comments(video: UUID, parent: UUID? = null, offset: Int = 0): List<VideoComment> {
        val q = rest.from("video_comments").select().eq("video_id", video)
        if (parent != null) q.eq("parent_id", parent) else q.isNull("parent_id")
        return q.order("created_at", parent != null).order("id", parent != null)
            .range(offset, offset + COMMENT_PAGE_SIZE - 1).decodeList()
    }

    suspend fun addComment(video: UUID, parent: UUID?, text: String) {
        try {
            rest.from("comments").insert(buildJsonObject {
                put("video_id", id(video))
                put("parent_id", parent?.let { JsonPrimitive(id(it)) } ?: JsonNull)
                put("body", text)
            }).execute()
        } catch (e: PostgrestException) {
            when (e.message) {
                "COMMENT_FILTERED" -> throw SocialException("This comment was filtered. Remove links or harmful language and try again.")
                "COMMENT_RATE_LIMITED" -> throw SocialException("You're commenting quickly. Wait a minute and try again.")
                "COMMENT_THREAD_UNAVAILABLE" -> throw SocialException("This reply thread is no longer available.")
            }
            if (e.code == "42501") throw SocialException("You can't comment on this video right now.")
            throw e
        }
    }

    suspend fun deleteComment(id: UUID) {
        rest.rpc("delete_video_comment", buildJsonObject { put("target_comment", id(id)) })
    }

    suspend fun setCommentLiked(liked: Boolean, comment: UUID, user: UUID) {
        try {
            if (liked) rest.from("comment_likes").insert(buildJsonObject { put("comment_id", id(comment)) }).execute()
            else rest.from("comment_likes").delete().eq("comment_id", comment).eq("user_id", user).execute()
        } catch (e: PostgrestException) {
            if (liked && isUniqueViolation(e)) return // An existing reaction already matches the requested state.
            if (isMissingView(e)) throw SocialException("Comment likes aren't available yet.")
            if (e.code == "42501" || e.code == "23503") throw SocialException("You can't like this comment right now.")
            throw e
        }
    }

    suspend fun reportComment(id: UUID, reason: CommentReportReason) {
        try {
            rest.from("comment_reports").insert(buildJsonObject { put("comment_id", id(id)); put("reason", reason.raw) }).execute()
        } catch (e: PostgrestException) { if (!isUniqueViolation(e)) throw e }
    }

    // ---- Feed pages --------------------------------------------------------------

    /**
     * Newest-first page of `feed_videos` (hidden posts and blocked users are already
     * excluded by the view), or `weekly_challenge_entries` for a challenge.
     */
    suspend fun page(
        after: Video? = null, creator: UUID? = null, challenge: UUID? = null,
        search: PostSearch? = null, limit: Int = PAGE_SIZE,
    ): List<Video> {
        val table = if (challenge == null) "feed_videos" else "weekly_challenge_entries"
        return orderedPage(rest.from(table).select(), after, creator, challenge, search, limit)
    }

    suspend fun remixes(source: UUID, after: Video? = null): List<Video> =
        orderedPage(rest.from("feed_videos").select().eq("source_video_id", source), after)

    data class FollowingPage(val videos: List<Video>, val confirmedNoFollows: Boolean = false)

    @Serializable private data class Follow(@SerialName("followee_id") @Serializable(with = UuidSerializer::class) val followeeId: UUID)

    private fun followsQuery(user: UUID) = rest.from("follows").select("followee_id").eq("follower_id", id(user))

    suspend fun followingPage(user: UUID, after: Video? = null): FollowingPage {
        val page = try {
            orderedPage(rest.from("following_activity_videos").select(), after, dateColumn = "activity_at")
        } catch (e: PostgrestException) {
            if (isMissingView(e)) return legacyFollowingPage(user, after) else throw e
        }
        if (after != null || page.isNotEmpty()) return FollowingPage(page)
        val follows = runCatching { followsQuery(user).limit(1).decodeList<Follow>() }.getOrNull()
        return FollowingPage(page, confirmedNoFollows = follows?.isEmpty() == true)
    }

    private suspend fun legacyFollowingPage(user: UUID, after: Video?): FollowingPage {
        val page = try {
            orderedPage(rest.from("following_videos").select(), after)
        } catch (e: PostgrestException) {
            if (!isMissingView(e)) throw e
            // Query visible feed rows in bounded batches on deployments without the joined view.
            val batchSize = 100
            var afterAuthor: UUID? = null
            var newest = emptyList<Video>()
            var hasFollows = false
            do {
                coroutineContext.ensureActive()
                val q = followsQuery(user)
                afterAuthor?.let { q.gt("followee_id", id(it)) }
                val follows = q.order("followee_id", true).limit(batchSize).decodeList<Follow>()
                if (follows.isEmpty()) break
                hasFollows = true
                val videos = rest.from("feed_videos").select().inList("user_id", follows.map { id(it.followeeId) })
                newest = newestFollowedPosts(newest, orderedPage(videos, after))
                afterAuthor = if (follows.size == batchSize) follows.last().followeeId else null
            } while (afterAuthor != null)
            return FollowingPage(newest, confirmedNoFollows = after == null && !hasFollows)
        }
        if (after != null || page.isNotEmpty()) return FollowingPage(page)
        // An empty view can also mean followed creators have no visible posts.
        val follows = runCatching { followsQuery(user).limit(1).decodeList<Follow>() }.getOrNull()
        return FollowingPage(page, confirmedNoFollows = follows?.isEmpty() == true)
    }

    private fun newestFollowedPosts(first: List<Video>, second: List<Video>): List<Video> =
        (first + second).sortedWith { a, b ->
            val ta = a.createdAtInstant ?: Instant.EPOCH
            val tb = b.createdAtInstant ?: Instant.EPOCH
            if (ta == tb) b.id.toString().uppercase().compareTo(a.id.toString().uppercase()) else tb.compareTo(ta)
        }.take(PAGE_SIZE)

    private suspend fun orderedPage(
        base: SupabaseRest.Query, after: Video?, creator: UUID? = null, challenge: UUID? = null,
        search: PostSearch? = null, limit: Int = PAGE_SIZE, dateColumn: String = "created_at",
    ): List<Video> {
        creator?.let { base.eq("user_id", it) }
        challenge?.let { base.eq("challenge_id", it) }
        val cursor = after?.let { cursor(it, dateColumn) }
        if (search != null) base.or(search.filter(cursor)) else if (cursor != null) base.or(cursor)
        return base.order(dateColumn, false).order("id", false).limit(limit).decodeList()
    }

    // ---- Likes, follows ----------------------------------------------------------

    suspend fun setLiked(liked: Boolean, video: UUID, user: UUID) {
        if (liked) rest.from("likes").insert(buildJsonObject { put("user_id", id(user)); put("video_id", id(video)) }).execute()
        else rest.from("likes").delete().eq("user_id", user).eq("video_id", video).execute()
    }

    suspend fun isFollowing(target: UUID, user: UUID): Boolean = runCatching {
        rest.from("follows").select("followee_id").eq("follower_id", user).eq("followee_id", target).decodeList<Follow>()
    }.getOrDefault(emptyList()).isNotEmpty()

    data class ProfileCounts(
        val posts: Int?, val followers: Int?, val following: Int?,
        val likesReceived: Int?, val viewsReceived: Int?,
    )

    suspend fun profileCounts(id: UUID, owner: Boolean = false): ProfileCounts = coroutineScope {
        val posts = async { runCatching { rest.from(if (owner) "videos" else "feed_videos").select("id").eq("user_id", id).count() }.getOrNull() }
        val followers = async { runCatching { rest.from("follows").select("follower_id").eq("followee_id", id).count() }.getOrNull() }
        val following = async { runCatching { rest.from("follows").select("followee_id").eq("follower_id", id).count() }.getOrNull() }
        val totals = async { if (owner) runCatching { creator(id) }.getOrNull() else null }
        val t = totals.await()
        ProfileCounts(posts.await(), followers.await(), following.await(), t?.likesReceived, t?.viewsReceived)
    }

    suspend fun myReposts(after: Video? = null): List<Video> = try {
        orderedPage(rest.from("my_reposted_videos").select(), after, dateColumn = "activity_at")
    } catch (e: PostgrestException) {
        if (isMissingView(e)) throw UnavailableException(UnavailableException.Kind.REPOSTS) else throw e
    }

    suspend fun ownerPage(user: UUID, after: Video? = null): List<Video> =
        orderedPage(rest.from("videos").select(), after, creator = user)

    suspend fun followedAuthors(authors: Set<UUID>, user: UUID): Set<UUID> {
        if (authors.isEmpty()) return emptySet()
        return rest.from("follows").select("followee_id").eq("follower_id", user)
            .inList("followee_id", authors.map(::id)).decodeList<Follow>().map { it.followeeId }.toSet()
    }

    suspend fun setFollowing(follow: Boolean, target: UUID, user: UUID) {
        if (follow) rest.from("follows").insert(buildJsonObject { put("follower_id", id(user)); put("followee_id", id(target)) }).execute()
        else rest.from("follows").delete().eq("follower_id", user).eq("followee_id", target).execute()
    }

    // ---- Moderation --------------------------------------------------------------

    /** Reports a post. Three reports hide it automatically (DB trigger). */
    suspend fun report(video: UUID, reason: ReportReason, user: UUID) {
        try {
            rest.from("reports").insert(buildJsonObject {
                put("reporter_id", id(user)); put("video_id", id(video)); put("reason", reason.raw)
            }).execute()
        } catch (e: PostgrestException) { if (!isUniqueViolation(e)) throw e } // Already reported by this user.
    }

    /** Blocks a user: neither side sees the other's posts afterwards. */
    suspend fun block(target: UUID, user: UUID) {
        try {
            rest.from("blocks").insert(buildJsonObject { put("blocker_id", id(user)); put("blocked_id", id(target)) }).execute()
        } catch (e: PostgrestException) { if (!isUniqueViolation(e)) throw e }
        runCatching { setFollowing(false, target, user) }
    }

    suspend fun unblock(target: UUID, user: UUID) {
        rest.from("blocks").delete().eq("blocker_id", user).eq("blocked_id", target).execute()
    }

    @Serializable
    data class BlockedUser(
        @SerialName("blocked_id") @Serializable(with = UuidSerializer::class) val blockedId: UUID,
        @SerialName("profiles") val profile: Profile? = null,
    )

    suspend fun blockedUsers(user: UUID): List<BlockedUser> =
        rest.from("blocks").select("blocked_id, profiles!blocks_blocked_id_fkey(id, username)")
            .eq("blocker_id", user).decodeList()

    /** `delete-video` Edge Function; throws on any non-2xx. */
    suspend fun deleteVideo(video: UUID) {
        val response = rest.function("delete-video", buildJsonObject { put("videoId", video.toString().uppercase()) }.toString().toByteArray())
        if (response.status !in 200..299) throw SocialException("Couldn't delete this post.")
    }
}
