package com.handstrudel.social.data

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import okhttp3.Call
import okhttp3.Callback
import okhttp3.HttpUrl
import okhttp3.HttpUrl.Companion.toHttpUrl
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import okhttp3.Response
import java.io.IOException
import java.util.UUID
import java.util.concurrent.TimeUnit
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

/**
 * A thin PostgREST / Edge Functions client that builds the same requests as
 * supabase-swift does for iOS `FeedService` (keyset `or=` cursors, `imatch`
 * search, `Prefer: count=exact` heads). supabase-kt's Postgrest DSL in 3.0.2
 * can't express raw `or` filter strings, so queries go through here; auth
 * (sessions, refresh, OTP, ID tokens) stays on supabase-kt. Pure JVM so it can
 * be driven by a fake [HttpTransport] in unit tests.
 */
class SupabaseRest(
    baseUrl: String,
    private val anonKey: String,
    private val transport: HttpTransport,
    /** Current session JWT, or null to call as `anon`. */
    private val accessToken: suspend () -> String?,
) {
    private val base: HttpUrl = baseUrl.trimEnd('/').toHttpUrl()

    fun from(table: String): Query = Query(this, table)

    /** `POST /rest/v1/rpc/<name>` with named params; returns the raw JSON body. */
    suspend fun rpc(name: String, params: JsonObject): String {
        val url = base.newBuilder().addPathSegments("rest/v1/rpc").addPathSegment(name).build()
        val response = send(RestRequest("POST", url.toString(), headers(json = true), params.toString().toByteArray()))
        return response.body
    }

    /**
     * `POST|DELETE /functions/v1/<name>`. Returns every status; throws only on transport failure.
     * [token] pins the call to a specific session token (capture's account-pinned invoker).
     */
    suspend fun function(
        name: String,
        body: ByteArray? = null,
        contentType: String = "application/json",
        method: String = "POST",
        token: String? = null,
    ): RestResponse {
        val url = base.newBuilder().addPathSegments("functions/v1").addPathSegment(name).build()
        val headers = mutableMapOf(
            "apikey" to anonKey,
            "Authorization" to "Bearer ${token ?: accessToken() ?: anonKey}",
        )
        if (body != null) headers["Content-Type"] = contentType
        return transport.send(RestRequest(method, url.toString(), headers, body ?: if (method == "POST") ByteArray(0) else null))
    }

    internal suspend fun headers(json: Boolean = false): MutableMap<String, String> {
        val token = accessToken() ?: anonKey
        return mutableMapOf("apikey" to anonKey, "Authorization" to "Bearer $token", "Accept" to "application/json").apply {
            if (json) put("Content-Type", "application/json")
        }
    }

    internal fun tableUrl(table: String): HttpUrl.Builder = base.newBuilder().addPathSegments("rest/v1").addPathSegment(table)

    internal suspend fun send(request: RestRequest): RestResponse {
        val response = transport.send(request)
        if (response.status !in 200..299) throw PostgrestException.from(response)
        return response
    }

    /** A PostgREST table/view request. Filters keep insertion order like supabase-swift. */
    class Query internal constructor(private val rest: SupabaseRest, private val table: String) {
        private val params = mutableListOf<Pair<String, String>>()
        private var orders = mutableListOf<String>()
        private var method = "GET"
        private var body: ByteArray? = null
        private var prefer = mutableListOf<String>()
        private var single = false

        fun select(columns: String = "*"): Query = apply { params += "select" to columns.filterNot { it.isWhitespace() } }
        fun eq(column: String, value: Any): Query = filter(column, "eq", value)
        fun neq(column: String, value: Any): Query = filter(column, "neq", value)
        fun gt(column: String, value: Any): Query = filter(column, "gt", value)
        fun lt(column: String, value: Any): Query = filter(column, "lt", value)
        fun isNull(column: String): Query = apply { params += column to "is.null" }
        fun inList(column: String, values: Collection<String>): Query =
            apply { params += column to "in.(${values.joinToString(",") { quoteIn(it) }})" }
        /** Raw PostgREST logic tree, e.g. `created_at.lt.X,and(created_at.eq.X,id.lt.Y)`. */
        fun or(filters: String): Query = apply { params += "or" to "($filters)" }
        fun order(column: String, ascending: Boolean): Query = apply { orders += "$column.${if (ascending) "asc" else "desc"}.nullslast" }
        fun limit(count: Int): Query = apply { params += "limit" to count.toString() }
        /** Inclusive row range, sent as offset/limit like supabase-swift. */
        fun range(from: Int, to: Int): Query = apply {
            params += "offset" to from.toString()
            params += "limit" to (to - from + 1).toString()
        }
        fun single(): Query = apply { single = true }

        fun insert(json: JsonElement, returnMinimal: Boolean = true): Query = apply {
            method = "POST"; body = json.toString().toByteArray()
            prefer += if (returnMinimal) "return=minimal" else "return=representation"
        }
        fun update(json: JsonObject): Query = apply {
            method = "PATCH"; body = json.toString().toByteArray(); prefer += "return=minimal"
        }
        fun delete(): Query = apply { method = "DELETE"; prefer += "return=minimal" }

        private fun filter(column: String, op: String, value: Any): Query = apply { params += column to "$op.${render(value)}" }

        /** The request URL, exposed for tests. */
        fun url(): String {
            val builder = rest.tableUrl(table)
            for ((k, v) in params) builder.addQueryParameter(k, v)
            if (orders.isNotEmpty()) builder.addQueryParameter("order", orders.joinToString(","))
            return builder.build().toString()
        }

        suspend fun execute(): RestResponse {
            val headers = rest.headers(json = body != null)
            if (single) headers["Accept"] = "application/vnd.pgrst.object+json"
            if (prefer.isNotEmpty()) headers["Prefer"] = prefer.joinToString(",")
            return rest.send(RestRequest(method, url(), headers, body))
        }

        /** `select(head: true, count: .exact)`: the row count from `Content-Range`. */
        suspend fun count(): Int? {
            val headers = rest.headers()
            headers["Prefer"] = "count=exact"
            val response = rest.send(RestRequest("HEAD", url(), headers, null))
            return response.headers["content-range"]?.substringAfterLast('/')?.toIntOrNull()
        }

        suspend inline fun <reified T> decodeList(): List<T> = RestJson.decodeFromString(execute().body)
        suspend inline fun <reified T> decodeSingle(): T = RestJson.decodeFromString(execute().body)

        private companion object {
            fun render(value: Any): String = when (value) {
                is UUID -> value.toString().lowercase()
                else -> value.toString()
            }

            fun quoteIn(value: String): String =
                if (value.any { it in ",()\"\\ " }) "\"" + value.replace("\\", "\\\\").replace("\"", "\\\"") + "\"" else value
        }
    }
}

/** JSON settings shared by all social decoding (unknown columns ignored, like Swift Codable). */
val RestJson: Json = Json {
    ignoreUnknownKeys = true
    explicitNulls = false
    coerceInputValues = true
}

data class RestRequest(val method: String, val url: String, val headers: Map<String, String>, val body: ByteArray?)

data class RestResponse(val status: Int, val body: String, val headers: Map<String, String> = emptyMap())

/** A PostgREST error body (`{code, message, details, hint}`), iOS `PostgrestError`. */
class PostgrestException(
    val code: String?,
    override val message: String,
    val status: Int,
    val details: String? = null,
) : Exception(message) {
    companion object {
        fun from(response: RestResponse): PostgrestException {
            val obj = runCatching { RestJson.parseToJsonElement(response.body).jsonObject }.getOrNull()
            fun field(name: String) = obj?.get(name)?.let { runCatching { it.jsonPrimitive.contentOrNull }.getOrNull() }
            return PostgrestException(
                code = field("code"),
                message = field("message") ?: field("msg") ?: field("error") ?: "Request failed (${response.status}).",
                status = response.status,
                details = field("details"),
            )
        }
    }
}

/** Swappable HTTP layer (OkHttp in the app, a fake in tests). */
fun interface HttpTransport {
    suspend fun send(request: RestRequest): RestResponse
}

class OkHttpTransport(
    private val client: OkHttpClient = OkHttpClient.Builder()
        .connectTimeout(15, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .build(),
) : HttpTransport {
    override suspend fun send(request: RestRequest): RestResponse = withContext(Dispatchers.IO) {
        val builder = Request.Builder().url(request.url)
        request.headers.forEach { (k, v) -> builder.header(k, v) }
        val type = (request.headers["Content-Type"] ?: "application/json").toMediaType()
        when (request.method) {
            "GET" -> builder.get()
            "HEAD" -> builder.head()
            "DELETE" -> if (request.body != null) builder.delete(request.body.toRequestBody(type)) else builder.delete()
            else -> builder.method(request.method, (request.body ?: ByteArray(0)).toRequestBody(type))
        }
        val call = client.newCall(builder.build())
        val response = call.await()
        response.use {
            RestResponse(it.code, it.body?.string().orEmpty(), it.headers.associate { (k, v) -> k.lowercase() to v })
        }
    }

    private suspend fun Call.await(): Response = suspendCancellableCoroutine { cont ->
        enqueue(object : Callback {
            override fun onFailure(call: Call, e: IOException) { if (!cont.isCancelled) cont.resumeWithException(e) }
            override fun onResponse(call: Call, response: Response) { cont.resume(response) }
        })
        cont.invokeOnCancellation { runCatching { cancel() } }
    }
}
