package com.handstrudel.social

import com.handstrudel.social.data.FeedService
import com.handstrudel.social.data.PostgrestException
import com.handstrudel.social.data.ProfileImageStore
import com.handstrudel.social.data.SocialException
import com.handstrudel.social.data.UnavailableException
import com.handstrudel.social.model.PostSearch
import com.handstrudel.ui.social.feed.FeedMode
import com.handstrudel.ui.social.feed.FeedModel
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.async
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test
import java.util.UUID

/** Ports of the PostgREST-backed cases in iOS `SocialTests.swift` (fake transport). */
class FeedServiceTest {
    private val viewer = UUID.fromString(DISCOVERY_VIEWER)
    private val user = UUID.fromString(DISCOVERY_USER)

    @Test fun requestsCarryTheAnonKeyAndTheSessionToken() = runBlocking {
        val (rest, seen) = fakeRest(token = "jwt") { 200 to "[]" }
        FeedService(rest).page()
        assertEquals("anon-key", seen.single().raw.headers["apikey"])
        assertEquals("Bearer jwt", seen.single().raw.headers["Authorization"])
        val (anon, anonSeen) = fakeRest { 200 to "[]" }
        FeedService(anon).page()
        assertEquals("Bearer anon-key", anonSeen.single().raw.headers["Authorization"])
    }

    @Test fun pagesUseKeysetCursorsAndSearchFilters() = runBlocking {
        val last = video(createdAt = "2026-11-13T05:00:00.123456+00:00")
        val feed = fakeFeed { r ->
            assertEquals("/feed_videos", r.path)
            assertEquals("created_at.desc.nullslast,id.desc.nullslast", r.query("order"))
            assertEquals("10", r.query("limit"))
            200 to "[]"
        }
        feed.page(after = last)
        val (rest, seen) = fakeRest { 200 to "[]" }
        val service = FeedService(rest)
        service.page(after = last)
        val cursor = "created_at.lt.2026-11-13T05:00:00.123456+00:00,and(created_at.eq.2026-11-13T05:00:00.123456+00:00,id.lt.${last.id})"
        assertEquals("($cursor)", seen.last().query("or"))
        val search = PostSearch.parse("@maker")!!
        service.page(after = last, search = search)
        assertEquals("(and(or(${search.filter}),or($cursor)))", seen.last().query("or"))
        service.page(challenge = user)
        assertEquals("/weekly_challenge_entries", seen.last().path)
        assertEquals("eq.$DISCOVERY_USER", seen.last().query("challenge_id"))
        service.page(creator = user, limit = 24)
        assertEquals("eq.$DISCOVERY_USER", seen.last().query("user_id"))
        assertEquals("24", seen.last().query("limit"))
    }

    @Test fun creatorLoadsFromVisibleFeedWhenCreatorViewIsMissing() = runBlocking {
        val feed = fakeFeed { r ->
            if (r.path == "/public_creators") return@fakeFeed MISSING_VIEW
            assertEquals("/feed_videos", r.path)
            assertEquals("eq.$DISCOVERY_USER", r.query("user_id"))
            200 to DISCOVERY_VIDEO
        }
        val creator = feed.creator(user)
        assertEquals(user, creator?.id)
        assertEquals("musician", creator?.username)
        assertEquals("The Musician", creator?.displayName)
    }

    @Test fun followingWithNoFollowsReturnsEmptyWhenViewIsMissing() = runBlocking {
        val feed = fakeFeed { r ->
            if (r.path in setOf("/following_activity_videos", "/following_videos")) return@fakeFeed MISSING_VIEW
            assertEquals("/follows", r.path)
            assertEquals("eq.$DISCOVERY_VIEWER", r.query("follower_id"))
            200 to "[]"
        }
        val page = feed.followingPage(viewer)
        assertTrue(page.videos.isEmpty())
        assertTrue(page.confirmedNoFollows)
    }

    @Test fun followingEmptyViewOnlyClaimsNoFollowsWhenConfirmed() = runBlocking {
        for ((response, expected) in listOf(
            (200 to "[]") to true,
            (200 to """[{"followee_id":"$DISCOVERY_USER"}]""") to false,
            (403 to """{"code":"42501","message":"permission denied"}""") to false,
        )) {
            val feed = fakeFeed { r ->
                if (r.path == "/following_activity_videos") return@fakeFeed 200 to "[]"
                assertEquals("/follows", r.path)
                assertEquals("1", r.query("limit"))
                response
            }
            val page = feed.followingPage(viewer)
            assertTrue(page.videos.isEmpty())
            assertEquals(expected, page.confirmedNoFollows)
        }
    }

    @Test fun followingFallsBackToVisiblePostsWithTheFullPaginationTimestamp() = runBlocking {
        val feed = fakeFeed { r ->
            if (r.path in setOf("/following_activity_videos", "/following_videos")) return@fakeFeed MISSING_VIEW
            if (r.path == "/follows") return@fakeFeed 200 to """[{"followee_id":"$DISCOVERY_USER"}]"""
            assertEquals("/feed_videos", r.path)
            assertTrue(r.query("user_id")!!.contains(DISCOVERY_USER))
            val cursor = r.query("or")
            if (cursor != null) {
                assertTrue(cursor.contains("2026-11-13T05:00:00.123456+00:00"))
                return@fakeFeed 200 to "[]"
            }
            200 to DISCOVERY_VIDEO
        }
        val first = feed.followingPage(viewer)
        val post = first.videos.first()
        assertFalse(first.confirmedNoFollows)
        val next = feed.followingPage(viewer, post)
        assertTrue(next.videos.isEmpty())
        assertFalse(next.confirmedNoFollows)
    }

    @Test fun followingDoesNotHideAnAuthorizationFailure() = runBlocking {
        val feed = fakeFeed { r ->
            assertEquals("/following_activity_videos", r.path)
            403 to """{"code":"42501","message":"permission denied"}"""
        }
        try {
            feed.followingPage(viewer)
            fail("An authorization error is not an empty feed")
        } catch (e: PostgrestException) {
            assertEquals("42501", e.code)
        }
    }

    @Test fun followingPaginatesByRepostTimeAndKeepsOriginalAuthor() = runBlocking {
        val activity = "2026-11-16T12:00:01.123456+00:00"
        val response = DISCOVERY_VIDEO.replace("\"caption\":", "\"activity_at\":\"$activity\",\"reposted_by\":\"friend\",\"caption\":")
        val feed = fakeFeed { r ->
            assertEquals("/following_activity_videos", r.path)
            assertEquals("activity_at.desc.nullslast,id.desc.nullslast", r.query("order"))
            if (r.query("or") != null) {
                assertTrue(r.query("or")!!.contains("activity_at.lt.$activity"))
                return@fakeFeed 200 to "[]"
            }
            200 to response
        }
        val post = feed.followingPage(viewer).videos.first()
        assertEquals("musician", post.username)
        assertEquals("friend", post.repostedBy)
        assertTrue(feed.followingPage(viewer, post).videos.isEmpty())
    }

    @Test fun missingBookmarkTableAndLibraryReportThatSavingIsUnavailable() = runBlocking {
        val feed = fakeFeed { r ->
            if (r.path == "/rpc/set_video_bookmark") return@fakeFeed 404 to """{"code":"PGRST202","message":"Missing function"}"""
            assertTrue(r.path in setOf("/video_bookmarks", "/saved_videos"))
            MISSING_VIEW
        }
        try { feed.setBookmark(true, user, viewer); fail("A bookmark that wasn't saved must not look successful") }
        catch (e: UnavailableException) { assertEquals(UnavailableException.Kind.BOOKMARKS, e.kind) }
        try { feed.bookmarks(); fail("An unavailable library isn't empty") }
        catch (e: UnavailableException) { assertEquals(UnavailableException.Kind.BOOKMARKS, e.kind) }
    }

    @Test fun bookmarkRpcIsPreferredAndDuplicatesCountAsSaved() = runBlocking {
        val (rest, seen) = fakeRest { r ->
            if (r.path == "/rpc/set_video_bookmark") 404 to """{"code":"PGRST202","message":"Missing function"}"""
            else 409 to """{"code":"23505","message":"duplicate"}"""
        }
        FeedService(rest).setBookmark(true, user, viewer)
        assertEquals("""{"target_video":"$DISCOVERY_USER","save":true}""", seen[0].body)
        assertEquals("POST", seen[1].method)
        assertEquals("return=minimal", seen[1].raw.headers["Prefer"])
    }

    @Test fun missingNotificationViewIsDistinctFromAnEmptyInbox() = runBlocking {
        try { fakeFeed { MISSING_VIEW }.activity(); fail("An unavailable inbox isn't empty") }
        catch (e: UnavailableException) { assertEquals(UnavailableException.Kind.ACTIVITY, e.kind) }
        val inbox = fakeFeed { r ->
            if (r.path == "/activity_inbox_v2") return@fakeFeed MISSING_VIEW
            assertEquals("/activity_inbox", r.path)
            200 to "[]"
        }.activity()
        assertTrue(inbox.isEmpty())
    }

    @Test fun groupedLikesLoadFromVersionedInboxAndKeepExactCursor() = runBlocking {
        val feed = fakeFeed { r ->
            assertEquals("/activity_inbox_v2", r.path)
            if (r.query("or") != null) {
                assertTrue(r.query("or")!!.contains("2026-11-14T05:00:00.123456+00:00"))
                return@fakeFeed 200 to "[]"
            }
            200 to """
                [{"id":"33333333-cccc-3333-3333-333333333333","video_id":"$DISCOVERY_USER",
                "comment_id":null,"kind":"video_like","created_at":"2026-11-14T05:00:00.123456+00:00",
                "read_at":null,"username":"listener","body":"A loop","like_count":3}]
            """.trimIndent()
        }
        val item = feed.activity().first()
        assertEquals("@listener and 2 others liked your video", item.title)
        assertNull(item.commentId)
        assertTrue(feed.activity(after = item).isEmpty())
    }

    @Test fun markingLikeActivityReadSendsTheExactTimestamp() = runBlocking {
        val (rest, seen) = fakeRest { 200 to "" }
        val feed = FeedService(rest)
        val item = com.handstrudel.social.data.RestJson.decodeFromString(com.handstrudel.social.model.CreatorActivity.serializer(), """
            {"id":"33333333-cccc-3333-3333-333333333333","video_id":"$DISCOVERY_USER","kind":"video_like",
             "created_at":"2026-11-14T05:00:00.123456+00:00","username":"l","body":""}""")
        feed.markActivityRead(item)
        assertEquals("/rpc/mark_like_activity_read", seen.last().path)
        assertTrue(seen.last().body!!.contains("\"seen_at\":\"2026-11-14T05:00:00.123456+00:00\""))
        feed.markActivityRead(item.copy(kind = com.handstrudel.social.model.CreatorActivity.Kind.COMMENT))
        assertEquals("/rpc/mark_creator_activity_read", seen.last().path)
        // mark_creator_activity_read(target_item) has no seen_at parameter (Swift omits nil).
        assertEquals("""{"target_item":"33333333-cccc-3333-3333-333333333333"}""", seen.last().body)
    }

    @Test fun commentErrorsMapToFriendlyMessages() = runBlocking {
        for ((body, message) in listOf(
            """{"code":"P0001","message":"COMMENT_FILTERED"}""" to "This comment was filtered. Remove links or harmful language and try again.",
            """{"code":"P0001","message":"COMMENT_RATE_LIMITED"}""" to "You're commenting quickly. Wait a minute and try again.",
            """{"code":"42501","message":"new row violates row-level security policy"}""" to "You can't comment on this video right now.",
        )) {
            try { fakeFeed { 400 to body }.addComment(user, null, "hi"); fail() } catch (e: SocialException) { assertEquals(message, e.message) }
        }
        val (rest, seen) = fakeRest { 201 to "" }
        FeedService(rest).addComment(user, null, "hi")
        assertEquals("""{"video_id":"$DISCOVERY_USER","parent_id":null,"body":"hi"}""", seen.single().body)
    }

    @Test fun commentPagesOrderRootsNewestFirstAndRepliesOldestFirst() = runBlocking {
        val (rest, seen) = fakeRest { 200 to "[]" }
        val feed = FeedService(rest)
        feed.comments(user, offset = 20)
        assertEquals("is.null", seen.last().query("parent_id"))
        assertEquals("created_at.desc.nullslast,id.desc.nullslast", seen.last().query("order"))
        assertEquals("20", seen.last().query("offset"))
        assertEquals("20", seen.last().query("limit"))
        feed.comments(user, parent = viewer)
        assertEquals("eq.$DISCOVERY_VIEWER", seen.last().query("parent_id"))
        assertEquals("created_at.asc.nullslast,id.asc.nullslast", seen.last().query("order"))
    }

    @Test fun profileCountsReadContentRangeTotals() = runBlocking {
        val transport = com.handstrudel.social.data.HttpTransport { request ->
            assertEquals("HEAD", request.method)
            assertEquals("count=exact", request.headers["Prefer"])
            com.handstrudel.social.data.RestResponse(200, "", mapOf("content-range" to "*/42"))
        }
        val counts = FeedService(com.handstrudel.social.data.SupabaseRest("https://example.test", "k", transport) { null }).profileCounts(user)
        assertEquals(42, counts.posts)
        assertEquals(42, counts.followers)
        assertNull(counts.likesReceived)
    }

    // ---- FeedModel --------------------------------------------------------------

    @Test fun discoveryMixesCreatorsAndPagesFromUnrankedCursor() = runTest {
        val firstCreator = UUID.randomUUID()
        val secondCreator = UUID.randomUUID()
        val base = java.time.Instant.now()
        fun make(author: UUID, likes: Int = 0, secondsAgo: Long = 0) = video(author = author, likes = likes, createdAt = base.minusSeconds(secondsAgo).toString())
        val firstPage = (0 until 23).map { make(firstCreator, secondsAgo = it.toLong()) } + make(secondCreator, likes = 42, secondsAgo = 24)
        val secondPage = listOf(make(firstCreator, likes = 100, secondsAgo = 25), make(secondCreator, secondsAgo = 26), firstPage[0])
        val model = FeedModel(null, loadPublicPage = { cursor, limit ->
            assertEquals(24, limit)
            if (cursor != null) { assertEquals(firstPage.last().id, cursor.id); secondPage } else firstPage
        }, loadAudioDownloadIds = { emptySet() })
        model.refresh(null)
        assertEquals(24, model.videos.value.size)
        assertEquals(firstPage.last().id, model.videos.value.first().id)
        model.current.value = 23
        model.loadMore()
        assertEquals(26, model.videos.value.size)
        assertEquals(secondCreator, model.videos.value[24].userId)
        assertEquals(26, model.videos.value.map { it.id }.toSet().size)
    }

    @Test fun followingModelSeparatesFallbackErrorFromConfirmedEmptyRetry() = runTest {
        val denied = fakeFeed { r ->
            if (r.path in setOf("/following_activity_videos", "/following_videos")) return@fakeFeed MISSING_VIEW
            403 to """{"code":"42501","message":"permission denied"}"""
        }
        var service = denied
        val model = FeedModel(null, loadFollowingPage = { u, last -> service.followingPage(u, last) }, loadAudioDownloadIds = { emptySet() })
        model.mode.value = FeedMode.FOLLOWING
        model.refresh(viewer)
        assertEquals("Couldn't load posts from creators you follow.", model.error.value)
        assertFalse(model.confirmedNoFollows.value)
        assertFalse(model.loading.value)
        service = fakeFeed { r ->
            if (r.path in setOf("/following_activity_videos", "/following_videos")) return@fakeFeed MISSING_VIEW
            200 to "[]"
        }
        model.refresh(viewer)
        assertTrue(model.videos.value.isEmpty())
        assertNull(model.error.value)
        assertTrue(model.confirmedNoFollows.value)
        assertFalse(model.loading.value)
    }

    @Test fun followingRequiresASignedInViewer() = runTest {
        val model = FeedModel(null, loadFollowingPage = { _, _ -> fail("signed out"); throw IllegalStateException() })
        model.mode.value = FeedMode.FOLLOWING
        model.refresh(null)
        assertTrue(model.videos.value.isEmpty())
        assertFalse(model.loading.value)
    }

    @Test fun failedLikeDoesNotChangeAnotherVideoAfterFeedChanges() = runBlocking {
        val started = CompletableDeferred<Unit>()
        val release = CompletableDeferred<Unit>()
        val model = FeedModel(null, writeLike = { _, _, _ -> started.complete(Unit); release.await(); throw SocialException("Test write failure") })
        val original = video(likes = 4)
        val replacement = video(likes = 7)
        model.videos.value = listOf(original)
        val update = async { runCatching { model.toggleLike(original, UUID.randomUUID()) } }
        started.await()
        assertEquals(5, model.videos.value.first().likeCount)
        assertEquals(true, model.videos.value.first().likedByMe)
        model.videos.value = listOf(replacement)
        release.complete(Unit)
        assertTrue(update.await().isFailure)
        assertEquals(listOf(replacement), model.videos.value)
    }

    @Test fun failedLikeRevertsTheOptimisticCount() = runBlocking {
        val model = FeedModel(null, writeLike = { _, _, _ -> throw SocialException("nope") })
        val original = video(likes = 4)
        model.videos.value = listOf(original)
        assertTrue(runCatching { model.toggleLike(original, UUID.randomUUID()) }.isFailure)
        assertEquals(4, model.videos.value.first().likeCount)
        assertNull(model.videos.value.first().likedByMe)
    }

    @Test fun blockingRemovesTheCreatorsPostsAndRepostsAndKeepsSelection() {
        val blocked = UUID.randomUUID()
        val other = UUID.randomUUID()
        val keep1 = video(author = other)
        val gone = video(author = blocked)
        val repost = video(author = other, extra = ""","reposted_by":"x","reposted_by_id":"$blocked"""")
        val keep2 = video(author = other)
        val model = FeedModel(null)
        model.videos.value = listOf(keep1, gone, repost, keep2)
        model.current.value = 3
        model.removeBlockedAuthor(blocked)
        assertEquals(listOf(keep1.id, keep2.id), model.videos.value.map { it.id })
        assertEquals(1, model.current.value)
    }

    // ---- Images -----------------------------------------------------------------

    @Test fun avatarIsAvailableImmediatelyOnReturnAndExpires() = runTest {
        var now = 0L
        var fetches = 0
        val store = ProfileImageStore<String>(backgroundScope, fetch = { fetches++; ProfileImageStore.FetchResult.Loaded("img$fetches") }, now = { now })
        val avatar = ProfileImageStore.Resource("https://x/a.jpg", ProfileImageStore.Kind.AVATAR)
        assertEquals("img1", store.load(avatar))
        assertEquals("img1", store.load(avatar))
        assertEquals(1, fetches)
        now += 301_000
        assertNull(store.displayedImage(avatar))
        assertEquals("img2", store.load(avatar))
    }

    @Test fun thumbnailRechecksVisibilityWithoutBlankingTheWarmImage() = runTest {
        var result: ProfileImageStore.FetchResult<String> = ProfileImageStore.FetchResult.Loaded("thumb")
        val store = ProfileImageStore<String>(backgroundScope, fetch = { result })
        val thumb = ProfileImageStore.Resource("https://x/t.jpg", ProfileImageStore.Kind.THUMBNAIL)
        assertEquals("thumb", store.load(thumb))
        result = ProfileImageStore.FetchResult.Unavailable
        assertEquals("a transient failure keeps the warm image", "thumb", store.load(thumb))
        result = ProfileImageStore.FetchResult.Denied
        assertNull(store.load(thumb))
        assertNull(store.displayedImage(thumb))
    }

    @Test fun clearingProfileImagesRejectsAnInFlightResponse() = runTest {
        val gate = CompletableDeferred<Unit>()
        val store = ProfileImageStore<String>(backgroundScope, fetch = { gate.await(); ProfileImageStore.FetchResult.Loaded("late") })
        val avatar = ProfileImageStore.Resource("https://x/a.jpg", ProfileImageStore.Kind.AVATAR)
        val pending = async { store.load(avatar) }
        testScheduler.advanceUntilIdle()
        store.clear()
        gate.complete(Unit)
        assertNull(pending.await())
        assertNull(store.displayedImage(avatar))
    }

    // ---- Portfolio --------------------------------------------------------------

    @Test fun accountPortfolioKeepsItsSnapshotWhileRefreshingAndRejectsAnotherAccount() = runTest {
        val me = UUID.randomUUID()
        val other = UUID.randomUUID()
        val clip = video(author = me)
        val gate = CompletableDeferred<Unit>()
        var blockNext = false
        val portfolio = AccountPortfolio(backgroundScope, null, null,
            fetchPage = { _, _ -> if (blockNext) gate.await(); listOf(clip) },
            fetchCounts = { FeedService.ProfileCounts(1, 2, 3, null, null) })
        portfolio.selectAccount(me)
        portfolio.load(me)
        assertEquals(listOf(clip), portfolio.videos.value)
        assertTrue(portfolio.hasLoadedPage.value)
        blockNext = true
        val refresh = async { portfolio.load(me) }
        testScheduler.advanceUntilIdle()
        assertEquals("snapshot stays while refreshing", listOf(clip), portfolio.videos.value)
        portfolio.selectAccount(other)
        gate.complete(Unit)
        refresh.await()
        assertTrue("an older account's response is rejected", portfolio.videos.value.isEmpty())
        assertNull(portfolio.counts.value)
        portfolio.load(me) // not the selected account: ignored
        assertTrue(portfolio.videos.value.isEmpty())
    }

}
