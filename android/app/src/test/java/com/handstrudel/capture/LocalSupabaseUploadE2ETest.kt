package com.handstrudel.capture

import com.handstrudel.capture.drafts.RecordingDrafts
import com.handstrudel.capture.upload.DraftPostSubmission
import com.handstrudel.capture.upload.PreparedClip
import com.handstrudel.capture.upload.PresignedPut
import com.handstrudel.capture.upload.UploadPlatform
import com.handstrudel.capture.upload.VideoUploader
import com.handstrudel.social.AccountChangedException
import com.handstrudel.social.FunctionResponse
import com.handstrudel.social.SupabaseFunctionsInvoker
import com.handstrudel.social.model.BackingCredit
import com.handstrudel.social.model.Video
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Assume.assumeTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File
import java.util.UUID

/**
 * End-to-end upload against a **local** Supabase stack with the edge functions
 * served locally (R2 and Sightengine mocked in the served copy). Skipped unless
 * these are set (never point them at production):
 *
 * `HANDSTRUDEL_E2E_SUPABASE_URL`, `HANDSTRUDEL_E2E_ANON_KEY`, `HANDSTRUDEL_E2E_PASSWORD`,
 * `HANDSTRUDEL_E2E_EMAIL`, `HANDSTRUDEL_E2E_EMAIL2`, `HANDSTRUDEL_E2E_CLIP` (720×1280 MP4), `HANDSTRUDEL_E2E_THUMB` (JPEG).
 */
class LocalSupabaseUploadE2ETest {
    @get:Rule val tmp = TemporaryFolder()

    private fun env(name: String): String? = System.getenv(name)?.takeIf { it.isNotBlank() }
    private val url = env("HANDSTRUDEL_E2E_SUPABASE_URL")
    private val anon = env("HANDSTRUDEL_E2E_ANON_KEY")
    private val http = OkHttpClient()
    private val json = Json { ignoreUnknownKeys = true }

    private fun signIn(email: String): Pair<UUID, String> {
        val body = """{"email":"$email","password":"${env("HANDSTRUDEL_E2E_PASSWORD")}"}""".toRequestBody("application/json".toMediaType())
        val request = Request.Builder().url("$url/auth/v1/token?grant_type=password").header("apikey", anon!!).post(body).build()
        http.newCall(request).execute().use { response ->
            val obj = json.parseToJsonElement(response.body!!.string()).jsonObject
            check(response.isSuccessful) { "sign-in failed: ${response.code}" }
            val user = obj["user"]!!.jsonObject
            return UUID.fromString(user["id"]!!.jsonPrimitive.content) to obj["access_token"]!!.jsonPrimitive.content
        }
    }

    private inner class LocalPlatform(val account: UUID, val token: String, val source: Video? = null) : UploadPlatform {
        override suspend fun fetchVideo(id: UUID): Video? = source?.takeIf { it.id == id }
        override suspend fun hasAudio(clip: File) = true
        override suspend fun prepare(clip: File): PreparedClip {
            val copy = tmp.newFile("post.mp4").also { clip.copyTo(it, overwrite = true) }
            return PreparedClip(copy, File(env("HANDSTRUDEL_E2E_THUMB")!!).readBytes(), 720, 1280, 4.0)
        }
        override suspend fun functions(accountId: UUID): SupabaseFunctionsInvoker {
            if (accountId != account) throw AccountChangedException()
            return object : SupabaseFunctionsInvoker {
                override val accountId = account
                override suspend fun invoke(function: String, body: JsonElement): FunctionResponse = withContext(Dispatchers.IO) {
                    val request = Request.Builder().url("$url/functions/v1/$function")
                        .header("apikey", anon!!).header("Authorization", "Bearer $token")
                        .post(body.toString().toRequestBody("application/json".toMediaType())).build()
                    http.newCall(request).execute().use { FunctionResponse(it.code, it.body!!.string()) }
                }
            }
        }
        override suspend fun put(url: String, contentType: String, file: File?, bytes: ByteArray?) =
            withContext(Dispatchers.IO) { PresignedPut.put(http, url, contentType, file, bytes) }
    }

    private fun feedRow(id: UUID): Map<String, JsonElement>? {
        val request = Request.Builder().url("$url/rest/v1/feed_videos?id=eq.$id&select=*").header("apikey", anon!!).build()
        http.newCall(request).execute().use { response ->
            val rows = json.parseToJsonElement(response.body!!.string()) as JsonArray
            return rows.firstOrNull()?.jsonObject
        }
    }

    private fun post(platform: LocalPlatform, caption: String, backingEnabled: Boolean, credit: BackingCredit?): Pair<VideoUploader, UUID> = runBlocking {
        val store = RecordingDrafts(tmp.newFolder())
        val draft = store.begin("Grand Piano", "scale", backingCredit = credit)
        store.videoFile(draft.id).writeBytes(File(env("HANDSTRUDEL_E2E_CLIP")!!).readBytes())
        store.complete(draft)
        val uploader = VideoUploader(platform)
        val posted = uploader.post(store.videoFile(draft.id), draft.id, platform.account, store, caption, "Grand Piano", "scale",
            null, commentsEnabled = false, backingEnabled = backingEnabled, backingCredit = credit)
        assertEquals(VideoUploader.Phase.Done, uploader.phase.value)
        assertTrue("published", posted)
        val published = store.postSubmission(draft.id, platform.account) as DraftPostSubmission.Published
        // Persisted: a fresh store sees it.
        assertEquals(published, RecordingDrafts(store.videoFile(draft.id).parentFile!!.parentFile!!).postSubmission(draft.id, platform.account))
        uploader to published.id
    }

    @Test fun postsAndPlaysAlongThroughLocalStack() {
        assumeTrue("local stack not configured", url != null && anon != null && env("HANDSTRUDEL_E2E_CLIP") != null)
        check(!url!!.contains("supabase.co")) { "E2E must not target a hosted project" }

        val (posterId, posterToken) = signIn(env("HANDSTRUDEL_E2E_EMAIL")!!)
        val (_, sourceId) = post(LocalPlatform(posterId, posterToken), "local e2e source", backingEnabled = true, credit = null)
        val source = feedRow(sourceId)!!
        assertEquals("local e2e source", source["caption"]!!.jsonPrimitive.content)
        assertEquals("true", source["backing_enabled"]!!.jsonPrimitive.content)
        assertEquals("false", source["comments_enabled"]!!.jsonPrimitive.content)
        assertEquals(720, source["width"]!!.jsonPrimitive.content.toInt())
        assertTrue(source["video_key"]!!.jsonPrimitive.content.matches(Regex("videos/$posterId/screened/$sourceId\\.mp4")))

        // A play-along take by another account credits the source.
        val (makerId, makerToken) = signIn(env("HANDSTRUDEL_E2E_EMAIL2")!!)
        val sourceVideo = json.decodeFromString(Video.serializer(), source.let { kotlinx.serialization.json.JsonObject(it) }.toString())
        val credit = BackingCredit(sourceId, sourceVideo.username!!)
        val (_, remixId) = post(LocalPlatform(makerId, makerToken, sourceVideo), "local e2e remix", backingEnabled = false, credit = credit)
        val remix = feedRow(remixId)!!
        assertEquals(sourceId.toString(), remix["source_video_id"]!!.jsonPrimitive.content)
    }
}
