package com.handstrudel.ui.social.feed

import com.handstrudel.social.data.DiscoveryFeedRanking
import com.handstrudel.social.data.FeedService
import com.handstrudel.social.data.UnavailableException
import com.handstrudel.social.model.ReportReason
import com.handstrudel.social.model.Video
import com.handstrudel.social.model.VideoEngagement
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.isActive
import java.time.Instant
import java.util.UUID

/** iOS `FeedMode`. Discover fetches 24 to re-rank; the others page by 10. */
enum class FeedMode(val title: String) {
    DISCOVER("Discover"), LATEST("Latest"), FOLLOWING("Following");

    val fetchLimit: Int get() = if (this == DISCOVER) 24 else FeedService.PAGE_SIZE
}

/**
 * iOS `FeedModel`: the feed pages, the selected index and per-viewer state
 * (follows, saves, audio permissions, engagement). Requests carry a generation
 * so a slow response from an older refresh never lands in a newer list.
 */
class FeedModel(
    private val service: FeedService?,
    private val writeLike: suspend (Boolean, UUID, UUID) -> Unit = { liked, video, user -> service!!.setLiked(liked, video, user) },
    private val loadPublicPage: suspend (Video?, Int) -> List<Video> = { last, limit -> service!!.page(after = last, limit = limit) },
    private val loadFollowingPage: suspend (UUID, Video?) -> FeedService.FollowingPage = { user, last -> service!!.followingPage(user, last) },
    private val loadAudioDownloadIds: suspend (List<UUID>) -> Set<UUID> = { service!!.audioDownloadsAllowed(it) },
    private val now: () -> Instant = Instant::now,
) {
    val videos = MutableStateFlow<List<Video>>(emptyList())
    val current = MutableStateFlow(0)
    val following = MutableStateFlow<Set<UUID>>(emptySet())
    val loading = MutableStateFlow(false)
    val error = MutableStateFlow<String?>(null)
    val mode = MutableStateFlow(FeedMode.DISCOVER)
    val confirmedNoFollows = MutableStateFlow(false)
    val savedIds = MutableStateFlow<Set<UUID>>(emptySet())
    val audioDownloadIds = MutableStateFlow<Set<UUID>>(emptySet())
    val engagement = MutableStateFlow<Map<UUID, VideoEngagement>>(emptyMap())

    private val engagementRequests = mutableMapOf<UUID, UUID>()
    private var reachedEnd = false
    private var pageCursor: Video? = null
    private val seenVideoIds = mutableSetOf<UUID>()
    private var loadedMode: FeedMode? = null
    private var rankingDate = now()
    private var generation = 0
    private var viewer: UUID? = null
    private val pendingLikes = mutableSetOf<UUID>()
    private val pendingFollows = mutableSetOf<UUID>()
    private val pendingBookmarks = mutableSetOf<UUID>()
    private val pendingReposts = mutableSetOf<UUID>()
    private var bookmarkRevision = 0

    val followingOnly: Boolean get() = mode.value == FeedMode.FOLLOWING
    val currentVideoId: UUID? get() = videos.value.getOrNull(current.value)?.id

    private fun update(id: UUID, transform: (Video) -> Video) {
        videos.value = videos.value.map { if (it.id == id) transform(it) else it }
    }

    fun recordViewCount(count: Int, videoId: UUID) {
        val video = videos.value.firstOrNull { it.id == videoId } ?: return
        if (count < 0 || count <= (video.viewCount ?: -1)) return
        update(videoId) { it.copy(viewCount = count) }
    }

    suspend fun refreshVideoControls(id: UUID) {
        val fresh = runCatching { service?.video(id) }.getOrNull() ?: return
        if (videos.value.none { it.id == id }) return
        update(id) { it.copy(commentCount = fresh.commentCount, commentsEnabled = fresh.commentsEnabled, backingEnabled = fresh.backingEnabled) }
    }

    suspend fun refreshEngagement(id: UUID) {
        val service = service ?: return
        val request = UUID.randomUUID()
        engagementRequests[id] = request
        try {
            val counts = runCatching { service.engagement(id) }.getOrNull() ?: return
            if (!currentCoroutineContext().isActive || engagementRequests[id] != request || videos.value.none { it.id == id }) return
            if (engagement.value[id] != counts) engagement.value = engagement.value + (id to counts)
        } finally {
            if (engagementRequests[id] == request) engagementRequests.remove(id)
        }
    }

    /** Returns the new reposted state, or null when nothing changed. */
    suspend fun toggleRepost(video: Video, user: UUID): Boolean? {
        val service = service ?: return null
        if (viewer != user || video.userId == user || !pendingReposts.add(video.id)) return null
        try {
            if (engagement.value[video.id]?.repostedByMe == null) refreshEngagement(video.id)
            val reposted = engagement.value[video.id]?.repostedByMe
            if (viewer != user || reposted == null) throw UnavailableException(UnavailableException.Kind.REPOSTS)
            val updated = service.setReposted(!reposted, video.id) ?: return null
            if (viewer != user) return null
            engagementRequests.remove(video.id)
            if (videos.value.any { it.id == video.id }) engagement.value = engagement.value + (video.id to updated)
            return updated.repostedByMe
        } finally {
            pendingReposts.remove(video.id)
        }
    }

    suspend fun refresh(user: UUID?) {
        generation += 1
        val request = generation
        val selectedMode = mode.value
        val followingOnly = selectedMode == FeedMode.FOLLOWING
        if (viewer != user) { savedIds.value = emptySet(); bookmarkRevision += 1 }
        viewer = user
        loading.value = true; error.value = null; reachedEnd = false
        pageCursor = null
        seenVideoIds.clear()
        loadedMode = selectedMode
        rankingDate = now()
        confirmedNoFollows.value = false
        audioDownloadIds.value = emptySet()
        engagement.value = emptyMap()
        engagementRequests.clear()
        videos.value = emptyList(); current.value = 0; following.value = emptySet()
        try {
            if (followingOnly && user == null) return
            try {
                var noFollows = false
                val page = if (followingOnly && user != null) {
                    val result = loadFollowingPage(user, null)
                    noFollows = result.confirmedNoFollows
                    result.videos
                } else {
                    loadPublicPage(null, selectedMode.fetchLimit)
                }
                if (!currentCoroutineContext().isActive || request != generation || mode.value != selectedMode) return
                val displayed = appendVisiblePage(page, selectedMode)
                confirmedNoFollows.value = noFollows
                loadPageDetails(displayed, request)
                while (currentCoroutineContext().isActive && request == generation && !reachedEnd && current.value >= videos.value.size - 3) {
                    if (runCatching { appendPage(request) }.getOrDefault(false) != true) break
                }
            } catch (e: kotlinx.coroutines.CancellationException) {
                throw e
            } catch (e: Exception) {
                if (request == generation) {
                    error.value = if (followingOnly) "Couldn't load posts from creators you follow." else "Couldn't load the feed. Try again."
                }
            }
        } finally {
            if (request == generation) loading.value = false
        }
    }

    suspend fun loadMore() {
        if (loading.value || reachedEnd || loadedMode != mode.value || current.value < videos.value.size - 3) return
        val request = generation
        loading.value = true
        try {
            while (currentCoroutineContext().isActive && request == generation && !reachedEnd && current.value >= videos.value.size - 3) {
                if (runCatching { appendPage(request) }.getOrDefault(false) != true) break
            }
        } finally {
            if (request == generation) loading.value = false
        }
    }

    private suspend fun appendPage(request: Int): Boolean {
        val selectedMode = mode.value
        val last = pageCursor
        if (loadedMode != selectedMode || last == null) return false
        val page = fetchPage(last, selectedMode, viewer)
        if (request != generation || mode.value != selectedMode) return false
        val fresh = appendVisiblePage(page, selectedMode)
        loadPageDetails(fresh, request)
        return fresh.isNotEmpty()
    }

    private fun appendVisiblePage(page: List<Video>, mode: FeedMode): List<Video> {
        val fresh = page.filter { seenVideoIds.add(it.id) }
        // The cursor follows the server's order, not the order viewers see.
        pageCursor = page.lastOrNull()
        reachedEnd = page.size < mode.fetchLimit || fresh.isEmpty()
        val displayed = if (mode == FeedMode.DISCOVER) DiscoveryFeedRanking.order(fresh, rankingDate, videos.value.lastOrNull()?.userId) else fresh
        videos.value = videos.value + displayed
        return displayed
    }

    private suspend fun loadPageDetails(page: List<Video>, request: Int) = coroutineScope {
        val a = async { loadBookmarks(page, request) }
        val b = async { loadFollowing(page, request) }
        val c = async { loadAudioPermissions(page, request) }
        a.await(); b.await(); c.await()
    }

    private suspend fun fetchPage(after: Video, mode: FeedMode, user: UUID?): List<Video> {
        if (mode == FeedMode.FOLLOWING) {
            user ?: return emptyList()
            return loadFollowingPage(user, after).videos
        }
        return loadPublicPage(after, mode.fetchLimit)
    }

    private suspend fun loadFollowing(page: List<Video>, request: Int) {
        val viewer = viewer ?: return
        val service = service ?: return
        val authors = page.map { it.userId }.toSet() - viewer
        val set = runCatching { service.followedAuthors(authors, viewer) }.getOrDefault(emptySet())
        if (request == generation) following.value = following.value + set
    }

    private suspend fun loadBookmarks(page: List<Video>, request: Int) {
        if (viewer == null) return
        val service = service ?: return
        val revision = bookmarkRevision
        val ids = page.map { it.id }
        val saved = runCatching { service.savedVideoIds(ids) }.getOrNull() ?: return
        if (request != generation || revision != bookmarkRevision) return
        savedIds.value = (savedIds.value - ids.toSet()) + saved
    }

    private suspend fun loadAudioPermissions(page: List<Video>, request: Int) {
        val ids = runCatching { loadAudioDownloadIds(page.map { it.id }) }.getOrNull() ?: return
        if (request == generation) audioDownloadIds.value = audioDownloadIds.value + ids
    }

    suspend fun toggleAudioPermission(id: UUID): Boolean {
        val allowed = id !in audioDownloadIds.value
        service?.setAudioDownloadsAllowed(allowed, id)
        audioDownloadIds.value = if (allowed) audioDownloadIds.value + id else audioDownloadIds.value - id
        return allowed
    }

    /** Returns the new saved state, or null when another write is in flight. */
    suspend fun toggleBookmark(id: UUID, user: UUID, explicitlySave: Boolean = false): Boolean? {
        val service = service ?: return null
        if (!(user == viewer || explicitlySave) || !pendingBookmarks.add(id)) return null
        try {
            bookmarkRevision += 1
            val save = explicitlySave || id !in savedIds.value
            service.setBookmark(save, id, user)
            if (viewer != user) return if (explicitlySave) save else null
            bookmarkRevision += 1
            savedIds.value = if (save) savedIds.value + id else savedIds.value - id
            return save
        } finally {
            pendingBookmarks.remove(id)
        }
    }

    fun removedBookmark(id: UUID) {
        bookmarkRevision += 1
        savedIds.value = savedIds.value - id
    }

    suspend fun toggleLike(video: Video, user: UUID) {
        val original = videos.value.firstOrNull { it.id == video.id } ?: return
        if (!pendingLikes.add(video.id)) return
        try {
            val request = generation
            val liked = original.likedByMe != true
            update(video.id) { it.copy(likedByMe = liked, likeCount = maxOf(0, original.likeCount + if (liked) 1 else -1)) } // optimistic
            try {
                writeLike(liked, video.id, user)
            } catch (e: Exception) {
                if (request == generation) update(video.id) { it.copy(likedByMe = original.likedByMe, likeCount = original.likeCount) }
                throw e
            }
        } finally {
            pendingLikes.remove(video.id)
        }
    }

    suspend fun toggleFollow(author: UUID, user: UUID) {
        val service = service ?: return
        if (viewer != user || !pendingFollows.add(author)) return
        try {
            val request = generation
            val follow = author !in following.value
            following.value = if (follow) following.value + author else following.value - author
            try {
                service.setFollowing(follow, author, user)
            } catch (e: Exception) {
                if (request == generation) following.value = if (follow) following.value - author else following.value + author
                throw e
            }
            if (viewer == user) {
                following.value = if (follow) following.value + author else following.value - author
                if (followingOnly && !follow) {
                    remove { (it.userId == author && it.repostedById == null) || (it.repostedById == author && it.userId !in following.value) }
                    videos.value = videos.value.map { if (it.repostedById == author) it.copy(repostedBy = null, repostedById = null) else it }
                }
            }
        } finally {
            pendingFollows.remove(author)
        }
    }

    suspend fun report(video: Video, reason: ReportReason, user: UUID) {
        service?.report(video.id, reason, user)
        remove { it.id == video.id } // hide it for the reporter right away
    }

    suspend fun block(author: UUID, user: UUID) {
        service?.block(author, user)
        removeBlockedAuthor(author)
    }

    fun removeBlockedAuthor(author: UUID) {
        following.value = following.value - author
        remove { it.userId == author || it.repostedById == author }
    }

    suspend fun delete(video: Video) {
        service?.deleteVideo(video.id)
        remove { it.id == video.id }
    }

    private fun remove(match: (Video) -> Boolean) {
        val currentId = videos.value.getOrNull(current.value)?.id
        val kept = videos.value.filterNot(match)
        videos.value = kept
        current.value = kept.indexOfFirst { it.id == currentId }.takeIf { it >= 0 } ?: minOf(current.value, maxOf(kept.size - 1, 0))
    }
}
