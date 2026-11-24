package com.handstrudel.social

import com.handstrudel.social.data.FeedService
import com.handstrudel.social.data.HttpTransport
import com.handstrudel.social.data.RestJson
import com.handstrudel.social.data.RestRequest
import com.handstrudel.social.data.RestResponse
import com.handstrudel.social.data.SupabaseRest
import com.handstrudel.social.model.Video
import okhttp3.HttpUrl.Companion.toHttpUrl
import java.util.UUID

/** A PostgREST request as the fake server sees it (iOS tests' `URLComponents`). */
class SeenRequest(val raw: RestRequest) {
    private val url = raw.url.toHttpUrl()
    /** Path below `/rest/v1` (e.g. `/feed_videos`, `/rpc/set_video_bookmark`) or `/functions/v1/...`. */
    val path: String = url.encodedPath.removePrefix("/rest/v1")
    fun query(name: String): String? = url.queryParameter(name)
    val method: String get() = raw.method
    val body: String? get() = raw.body?.toString(Charsets.UTF_8)
}

fun fakeRest(token: String? = null, respond: (SeenRequest) -> Pair<Int, String>): Pair<SupabaseRest, MutableList<SeenRequest>> {
    val seen = mutableListOf<SeenRequest>()
    val transport = HttpTransport { request ->
        val r = SeenRequest(request)
        seen += r
        val (status, body) = respond(r)
        RestResponse(status, body)
    }
    return SupabaseRest("https://example.test", "anon-key", transport) { token } to seen
}

fun fakeFeed(respond: (SeenRequest) -> Pair<Int, String>): FeedService = FeedService(fakeRest(respond = respond).first)

const val DISCOVERY_USER = "11111111-aaaa-1111-1111-111111111111"
const val DISCOVERY_VIEWER = "22222222-bbbb-2222-2222-222222222222"
val MISSING_VIEW = 404 to """{"code":"PGRST205","message":"Missing view"}"""
val DISCOVERY_VIDEO = """
    [{"id":"33333333-cccc-3333-3333-333333333333","user_id":"$DISCOVERY_USER","video_key":"v.mp4",
      "thumb_key":"t.jpg","caption":"First loop","like_count":0,"created_at":"2026-11-13T05:00:00.123456+00:00",
      "username":"musician","display_name":"The Musician"}]
""".trimIndent()

fun video(
    id: UUID = UUID.randomUUID(),
    author: UUID = UUID.fromString("00000000-0000-0000-0000-00000000000a"),
    likes: Int = 0,
    createdAt: String = "2026-11-14T05:00:00Z",
    extra: String = "",
): Video = RestJson.decodeFromString(Video.serializer(), """
    {"id":"$id","user_id":"$author","video_key":"v.mp4","thumb_key":"t.jpg","caption":"Take",
     "like_count":$likes,"created_at":"$createdAt"$extra}
""".trimIndent())
