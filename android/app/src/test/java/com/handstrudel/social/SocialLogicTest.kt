package com.handstrudel.social

import com.handstrudel.social.data.ClipViewReceipt
import com.handstrudel.social.data.DiscoveryFeedRanking
import com.handstrudel.social.data.FeedNavigation
import com.handstrudel.social.data.FeedPlaybackPosition
import com.handstrudel.social.data.QualifiedClipWatch
import com.handstrudel.social.data.RestJson
import com.handstrudel.social.model.CreatorActivity
import com.handstrudel.social.model.PerformanceLink
import com.handstrudel.social.model.PostSearch
import com.handstrudel.social.model.Profile
import com.handstrudel.social.model.PublicCreator
import com.handstrudel.social.model.Video
import com.handstrudel.social.model.VideoComment
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test
import java.time.Instant
import java.util.UUID

/** Ports of the pure-logic cases in iOS `HandStrudelTests/SocialTests.swift`. */
class SocialLogicTest {

    // ---- PerformanceLink ---------------------------------------------------------

    @Test fun universalPerformanceLinksOnlyOpenCanonicalVideoUrls() {
        val id = UUID.fromString("52000000-0000-0000-0000-000000000001")
        assertEquals(PerformanceLink.Watch(id), PerformanceLink.parse("https://handstrudel.com/watch?v=$id"))
        assertEquals(PerformanceLink.Watch(id), PerformanceLink.parse("https://handstrudel.com/watch/?v=$id&source=share"))
        assertEquals(PerformanceLink.Comments(id), PerformanceLink.parse("handstrudel://comments/$id"))
        assertEquals(PerformanceLink.Watch(id), PerformanceLink.parse("handstrudel://watch/$id"))
        assertEquals(PerformanceLink.Sound(id), PerformanceLink.parse("handstrudel://sound/$id"))
        assertEquals(PerformanceLink.PlayAlong(id), PerformanceLink.parse("handstrudel://play/$id"))
        assertNull(PerformanceLink.parse("https://handstrudel.com/watch"))
        assertNull(PerformanceLink.parse("http://handstrudel.com/watch?v=$id"))
        assertNull(PerformanceLink.parse("https://handstrudel.com.example.org/watch?v=$id"))
        assertNull(PerformanceLink.parse("https://handstrudel.com/watch?v=$id&v=$id"))
        assertNull(PerformanceLink.parse("https://handstrudel.com/watch?v=bad"))
        assertNull(PerformanceLink.parse("https://handstrudel.com/watch/other?v=$id"))
        assertNull(PerformanceLink.parse("https://user:pw@handstrudel.com/watch?v=$id"))
        assertNull(PerformanceLink.parse("https://handstrudel.com:8443/watch?v=$id"))
        assertNull(PerformanceLink.parse("handstrudel://other/$id"))
    }

    // ---- Profile ----------------------------------------------------------------

    @Test fun usernameValidation() {
        assertTrue(Profile.isValidUsername("hand_strudel1"))
        assertFalse(Profile.isValidUsername("ab"))
        assertFalse(Profile.isValidUsername("UpperCase"))
        assertFalse(Profile.isValidUsername("has space"))
        assertFalse(Profile.isValidUsername("a".repeat(21)))
    }

    @Test fun usernameNormalization() {
        assertEquals("handstrudel", Profile.normalizeUsername("Hand Strudel!"))
        assertEquals("hllo_wrld", Profile.normalizeUsername("héllo_wörld"))
        assertEquals(20, Profile.normalizeUsername("x".repeat(30)).length)
    }

    // ---- Media URLs -------------------------------------------------------------

    @Test fun screenedKeysUseTheClipDomainAndEverythingElseTheMediaDomain() {
        val media = "https://media.example"
        val clips = "https://clips.example"
        assertEquals("https://clips.example/videos/u/screened/a.mp4", SocialConfig.mediaUrl("videos/u/screened/a.mp4", media, clips))
        assertEquals("https://clips.example/thumbs/u/screened/a.jpg", SocialConfig.mediaUrl("thumbs/u/screened/a.jpg", media, clips))
        assertEquals("https://media.example/videos/u/a.mp4", SocialConfig.mediaUrl("videos/u/a.mp4", media, clips))
        assertEquals("https://media.example/avatars/u/screened/a.jpg", SocialConfig.mediaUrl("avatars/u/screened/a.jpg", media, clips))
        assertEquals("https://media.example/videos/u/screened/x/a.mp4", SocialConfig.mediaUrl("videos/u/screened/x/a.mp4", media, clips))
        assertEquals("https://media.example/videos/u/other/a.mp4", SocialConfig.mediaUrl("videos/u/other/a.mp4", media, clips))
        assertEquals("https://media.example/a%20b.mp4", SocialConfig.mediaUrl("a b.mp4", media, clips))
    }

    @Test fun configurationRejectsPlaceholderKeysAndCreatorUrlsEscape() {
        assertFalse(SocialConfig.isConfigured(""))
        assertFalse(SocialConfig.isConfigured("YOUR-ANON-KEY"))
        assertTrue(SocialConfig.isConfigured("sb_publishable_x"))
        assertEquals("https://handstrudel.com/creator?u=keys_1", SocialConfig.creatorUrl("keys_1"))
    }

    // ---- Decoding ---------------------------------------------------------------

    @Test fun feedVideoDecodesAndToleratesAnUnsupportedSoundSetup() {
        val json = """
        {"id":"11111111-1111-1111-1111-111111111111","user_id":"00000000-0000-0000-0000-00000000000a",
         "video_key":"videos/a/v.mp4","thumb_key":"thumbs/a/v.jpg","caption":"hi","instrument":"Piano",
         "mode":"scale","duration_s":7.0,"width":720,"height":1558,"like_count":3,"hidden":false,
         "created_at":"2026-11-13T05:00:00Z","username":"alice","liked_by_me":true}
        """.trimIndent()
        val v = RestJson.decodeFromString(Video.serializer(), json)
        assertEquals(3, v.likeCount)
        assertEquals("alice", v.username)
        assertEquals(true, v.likedByMe)
        assertTrue(v.videoUrl.endsWith("videos/a/v.mp4"))
        assertNull(v.soundSetup)
        assertNull("Clients should support a backend without the comments migration", v.commentsEnabled)
        val unsupported = RestJson.decodeFromString(Video.serializer(),
            json.dropLast(1) + ""","sound_setup":{"version":99},"comments_enabled":true,"comment_count":12}""")
        assertEquals(v.id, unsupported.id)
        assertNull(unsupported.soundSetup)
        assertEquals(true, unsupported.commentsEnabled)
        assertEquals(12, unsupported.commentCount)
    }

    @Test fun publicCreatorDecodesProfileTotalsAndSupportsOldRows() {
        fun creator(total: String) = RestJson.decodeFromString(PublicCreator.serializer(),
            """{"id":"71000000-0000-4000-8000-000000000001","username":"keys","display_name":null$total}""")
        assertEquals(1243, creator(",\"likes_received\":1243").likesReceived)
        assertEquals(0, creator(",\"likes_received\":0").likesReceived)
        assertNull(creator("").likesReceived)
        assertEquals(1234, creator(",\"views_received\":1234").viewsReceived)
        assertNull(creator("").viewsReceived)
        val fromVideo = PublicCreator.fromVisibleVideo(video(extra = ""","username":"m","display_name":"M""""))
        assertEquals("m", fromVideo?.username)
        assertNull(PublicCreator.fromVisibleVideo(video()))
    }

    // ---- Search -----------------------------------------------------------------

    @Test fun searchUsesLiteralTextAndHandleScope() {
        assertNull(PostSearch.parse(" @x "))
        assertNull(PostSearch.parse("  "))
        val handle = PostSearch.parse(" @cloud_music ")!!
        assertEquals("cloud_music", handle.text)
        assertEquals("username.imatch.\"cloud_music\"", handle.filter)
        val search = PostSearch.parse("hi,.*")!!
        assertTrue(search.filter, search.filter.startsWith("""caption.imatch."hi,\\.\\*",instrument.imatch."""))
        assertTrue(search.filter.contains("display_name.imatch"))
        assertEquals("and(or(${search.filter}),or(cursor))", search.filter("cursor"))
        assertEquals(search.filter, search.filter(null))
        // Quotes are escaped for PostgREST's grammar.
        assertEquals("""username.imatch."a\"b"""", PostSearch.parse("@a\"b")!!.filter)
    }

    @Test fun searchCanBroadenAHandleMissWithoutChangingTheTerm() {
        val handle = PostSearch.parse(" @Cloud_Music ")!!
        assertTrue(handle.isHandleSearch)
        val input = handle.broaderInput!!
        assertEquals("Cloud_Music", input)
        val broader = PostSearch.parse(input)!!
        assertFalse(broader.isHandleSearch)
        assertEquals(handle.text, broader.text)
        assertTrue(broader.filter.contains(handle.filter))
        assertTrue(broader.filter.contains("display_name.imatch"))
        assertNull(broader.broaderInput)
    }

    @Test fun searchCannotBroadenToAnotherHandleSearch() {
        val handle = PostSearch.parse("@ @cloud_music")!!
        assertTrue(handle.isHandleSearch)
        assertNull(handle.broaderInput)
    }

    @Test fun searchCapsTheTermAt80Characters() {
        assertEquals(80, PostSearch.parse("a".repeat(120))!!.text.length)
    }

    // ---- Ranking & navigation ---------------------------------------------------

    @Test fun discoveryPrefersFreshEngagedClipsAndAlternatesCreators() {
        val now = Instant.parse("2026-11-20T12:00:00Z")
        val a = UUID.randomUUID(); val b = UUID.randomUUID()
        val oldPopular = video(author = a, likes = 1000, createdAt = "2026-11-01T12:00:00Z")
        val fresh1 = video(author = a, createdAt = "2026-11-20T11:00:00Z")
        val fresh2 = video(author = a, createdAt = "2026-11-20T10:00:00Z")
        val freshB = video(author = b, createdAt = "2026-11-19T12:00:00Z")
        val ordered = DiscoveryFeedRanking.order(listOf(oldPopular, fresh2, freshB, fresh1), now)
        assertEquals(fresh1.id, ordered[0].id)
        assertEquals("never the same creator twice in a row when another is available", b, ordered[1].userId)
        assertEquals(fresh2.id, ordered[2].id)
        assertEquals(oldPopular.id, ordered[3].id)
        // The previous page's last creator is honoured.
        assertEquals(b, DiscoveryFeedRanking.order(listOf(fresh1, freshB), now, after = a).first().userId)
        // Ties keep server order.
        val t1 = video(author = a, createdAt = "2026-11-20T11:00:00Z"); val t2 = video(author = b, createdAt = "2026-11-20T11:00:00Z")
        assertEquals(listOf(t1.id, t2.id), DiscoveryFeedRanking.order(listOf(t1, t2), now).map { it.id })
    }

    @Test fun feedNavigationKeepsAdjacentVideosInOrder() {
        for ((current, step, expected) in listOf(Triple(0, 1, 1), Triple(1, 1, 2), Triple(2, -1, 1), Triple(1, -1, 0))) {
            assertEquals(expected, FeedNavigation.destination(current, step, 3) { fail("Only the edges should choose a random clip."); 0 })
        }
    }

    @Test fun feedNavigationCanChooseEveryOtherVideoAtEitherEdge() {
        for (count in 2..8) {
            for ((current, step) in listOf(0 to -1, (count - 1) to 1)) {
                val targets = (0 until count - 1).mapNotNull { candidate ->
                    FeedNavigation.destination(current, step, count) { range -> assertEquals(0 until count - 1, range); candidate }
                }
                assertEquals((0 until count).toSet() - current, targets.toSet())
            }
        }
    }

    @Test fun feedNavigationDoesNotInventAnAlternativeForEmptyOrSingleClipFeeds() {
        for (count in listOf(0, 1)) {
            assertNull(FeedNavigation.destination(0, 1, count))
            assertNull(FeedNavigation.destination(0, -1, count))
        }
        assertNull(FeedNavigation.destination(-1, 1, 3))
        assertNull(FeedNavigation.destination(3, -1, 3))
        assertNull(FeedNavigation.destination(0, 0, 3))
        // The default chooser never lands on the current clip.
        repeat(50) { assertNotEquals(2, FeedNavigation.destination(2, 1, 3)) }
    }

    // ---- Playback ---------------------------------------------------------------

    @Test fun feedProgressBoundsSeekInsideClipAndFormatsDuration() {
        assertNull(FeedPlaybackPosition.of(Double.POSITIVE_INFINITY, 1.0))
        assertNull(FeedPlaybackPosition.of(0.0, 1.0))
        assertNull(FeedPlaybackPosition.of(4.0, Double.NaN))
        val end = FeedPlaybackPosition.of(4.0, 9.0)!!
        assertEquals(4.0, end.seconds, 0.0)
        assertTrue(end.seekSeconds > 3.9 && end.seekSeconds < 4)
        assertEquals(0.0, FeedPlaybackPosition.of(4.0, -3.0)!!.seconds, 0.0)
        assertEquals("1:01", FeedPlaybackPosition.timeLabel(61.0))
        assertEquals("0:00", FeedPlaybackPosition.timeLabel(Double.NaN))
    }

    @Test fun qualifiedVideoViewRequiresPlaybackAndIgnoresScrubbing() {
        val watch = QualifiedClipWatch()
        // min(2 s, 3 s / 2) = 1.5 s of real playback.
        fun at(s: Double) = FeedPlaybackPosition.of(3.0, s)!!
        assertFalse(watch.sample(at(0.0), playing = true))
        assertFalse(watch.sample(at(2.5), playing = true)) // a jump (scrub) doesn't count
        var t = 0.0
        var qualified = false
        repeat(8) { t += 0.2; qualified = watch.sample(at(t), playing = true) || qualified } // 7 × 0.2 s counted
        assertFalse("1.4 s isn't enough", qualified)
        assertFalse(watch.sample(at(t + 0.2), playing = false)) // paused samples don't count
        t += 0.4
        assertFalse(watch.sample(at(t), playing = true)) // the first sample after a pause only re-anchors
        assertTrue(watch.sample(at(t + 0.2), playing = true))
        assertFalse("reports once", watch.sample(at(t + 0.4), playing = true))
    }

    @Test fun shortClipCanQualifyAtHalfItsDuration() {
        val watch = QualifiedClipWatch()
        fun at(s: Double) = FeedPlaybackPosition.of(1.0, s)!!
        assertFalse(watch.sample(at(0.0), playing = true))
        assertFalse(watch.sample(at(0.3), playing = true))
        assertTrue(watch.sample(at(0.6), playing = true))
    }

    @Test fun viewReceiptIsStablePerClipForTheRun() {
        val a = UUID.randomUUID(); val b = UUID.randomUUID()
        assertEquals(ClipViewReceipt.forVideo(a), ClipViewReceipt.forVideo(a))
        assertNotEquals(ClipViewReceipt.forVideo(a), ClipViewReceipt.forVideo(b))
    }

    // ---- Comments ---------------------------------------------------------------

    @Test fun commentBodyValidationCountsUnicodeScalars() {
        assertFalse(VideoComment.isValidBody(" \t\n "))
        assertTrue(VideoComment.isValidBody(" " + "a".repeat(300) + "\n"))
        assertFalse(VideoComment.isValidBody("a".repeat(301)))
        // 👨‍👩‍👦 is 5 scalars: 100 of them are 500.
        assertFalse(VideoComment.isValidBody("👨‍👩‍👦".repeat(100)))
        assertTrue(VideoComment.isValidBody("👨‍👩‍👦".repeat(60)))
        assertEquals(2, VideoComment.scalarCount("😀😀"))
    }

    @Test fun commentReplyDecodingAndLikes() {
        val row = """
        {"id":"11111111-1111-1111-1111-111111111111","video_id":"22222222-2222-2222-2222-222222222222",
         "user_id":"33333333-3333-3333-3333-333333333333","parent_id":"44444444-4444-4444-4444-444444444444",
         "username":"listener","body":"Love this sound!","created_at":"2026-11-14T05:00:00Z","reply_count":0}
        """.trimIndent()
        val reply = RestJson.decodeFromString(VideoComment.serializer(), row)
        assertNotNull(reply.parentId)
        assertEquals("listener", reply.username)
        assertNull(reply.likeCount)
        assertEquals(reply, reply.applyingLike(true)) // no counts → unchanged
        var reaction = RestJson.decodeFromString(VideoComment.serializer(), row.dropLast(1) + ""","like_count":2,"liked_by_me":false}""")
        reaction = reaction.applyingLike(true).applyingLike(true)
        assertEquals(3, reaction.likeCount)
        assertEquals(true, reaction.likedByMe)
        reaction = reaction.applyingLike(false)
        assertEquals(2, reaction.likeCount)
    }

    @Test fun commentRefreshKeepsReplyTargetOutsideFirstPageAndUsesLatestRow() {
        fun root(likes: Int? = null, id: UUID = UUID.randomUUID()) = VideoComment(id, UUID.randomUUID(), UUID.randomUUID(), null, "A comment",
            "2026-11-14T05:00:00Z", "listener", 0, likes)
        val target = root()
        val page = (0 until 20).map { root() }
        assertEquals(target, VideoComment.replyTargetAfterRefresh(target, page))
        val fresh = target.copy(likeCount = 1)
        assertEquals(fresh, VideoComment.replyTargetAfterRefresh(target, listOf(root(), fresh)))
        assertNull(VideoComment.replyTargetAfterRefresh(null, page))
    }

    // ---- Activity ---------------------------------------------------------------

    @Test fun creatorActivityTitlesPluraliseGroupedLikes() {
        fun item(kind: String, likes: Int?) = RestJson.decodeFromString(CreatorActivity.serializer(), """
            {"id":"33333333-cccc-3333-3333-333333333333","video_id":"$DISCOVERY_USER","comment_id":null,"kind":"$kind",
             "created_at":"2026-11-14T05:00:00.123456+00:00","read_at":null,"username":"listener","body":"A loop"
             ${likes?.let { ",\"like_count\":$it" } ?: ""}}
        """.trimIndent())
        assertEquals("@listener and 2 others liked your video", item("video_like", 3).title)
        assertEquals("@listener and 1 other liked your comment", item("comment_like", 2).title)
        assertEquals("@listener liked your reply", item("reply_like", 1).title)
        assertEquals("@listener liked your video", item("video_like", null).title)
        assertEquals("@listener commented on your video", item("comment", null).title)
        assertEquals("@listener replied to you", item("reply", null).title)
        assertTrue(item("video_like", 1).kind.isLike)
        assertFalse(item("comment", null).kind.isLike)
        assertEquals("View reply", item("reply_like", 1).kind.commentAction)
        assertEquals("View comment", item("comment", null).kind.commentAction)
        assertEquals("2026-11-14T05:00:00.123456+00:00", item("comment", null).timestamp)
    }

    // ---- Account deletion -------------------------------------------------------

    @Test fun accountDeletionFailureIsUnconfirmedAndDoesNotSignOut() = runBlocking {
        var signedOut = false
        val result = AuthManager.performAccountDeletion(request = { throw java.io.IOException("lost") }, signOut = { signedOut = true })
        assertEquals(AuthManager.AccountDeletionResult.UNCONFIRMED, result)
        assertFalse(signedOut)
    }

    @Test fun accountDeletionSignsOutAfterSuccessfulRequest() = runBlocking {
        var signedOut = false
        val result = AuthManager.performAccountDeletion(request = {}, signOut = { signedOut = true })
        assertEquals(AuthManager.AccountDeletionResult.DELETED, result)
        assertTrue(signedOut)
    }
}
