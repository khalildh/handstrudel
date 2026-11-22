package com.handstrudel.social.data

import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

/**
 * iOS `ProfileImageStore`: a small expiring snapshot cache for profile avatars and
 * portfolio thumbnails. Avatars are reused for 5 minutes (their URL changes when the
 * photo is replaced); thumbnails are shown warm for 60 s but re-fetched on each visit,
 * so a post that turned private stops showing (`denied` drops the snapshot) while a
 * transient failure keeps the warm image. Generic over the image type for JVM tests.
 */
class ProfileImageStore<Image : Any>(
    private val scope: CoroutineScope,
    private val fetch: suspend (String) -> FetchResult<Image>,
    private val now: () -> Long = System::currentTimeMillis,
    private val countLimit: Int = 48,
) {
    enum class Kind(val displayLifetimeMillis: Long) { AVATAR(300_000), THUMBNAIL(60_000) }

    data class Resource(val url: String, val kind: Kind) {
        val key: String get() = "${kind.name.lowercase()}:$url"
    }

    sealed interface FetchResult<out I> {
        data class Loaded<I>(val image: I) : FetchResult<I>
        data object Denied : FetchResult<Nothing>
        data object Unavailable : FetchResult<Nothing>
    }

    private class Snapshot<I>(val image: I, val expiry: Long)
    private class Pending<I>(val job: Job, val result: CompletableDeferred<I?>)

    private val lock = Mutex()
    private val snapshots = object : LinkedHashMap<String, Snapshot<Image>>(16, 0.75f, true) {
        override fun removeEldestEntry(eldest: MutableMap.MutableEntry<String, Snapshot<Image>>?) = size > countLimit
    }
    private val requests = mutableMapOf<Resource, Pending<Image>>()
    private var generation = 0

    fun displayedImage(resource: Resource): Image? = synchronized(snapshots) {
        val snapshot = snapshots[resource.key] ?: return null
        if (snapshot.expiry <= now()) { snapshots.remove(resource.key); return null }
        snapshot.image
    }

    suspend fun load(resource: Resource): Image? {
        if (resource.kind == Kind.AVATAR) displayedImage(resource)?.let { return it }
        val pending = lock.withLock {
            requests[resource] ?: run {
                val result = CompletableDeferred<Image?>()
                val started = generation
                val job = scope.launch {
                    val fetched = runCatching { fetch(resource.url) }.getOrElse { FetchResult.Unavailable }
                    val value = lock.withLock {
                        if (started != generation) return@withLock null
                        requests.remove(resource)
                        when (fetched) {
                            is FetchResult.Loaded -> {
                                synchronized(snapshots) {
                                    snapshots[resource.key] = Snapshot(fetched.image, now() + resource.kind.displayLifetimeMillis)
                                }
                                fetched.image
                            }
                            FetchResult.Denied -> { synchronized(snapshots) { snapshots.remove(resource.key) }; null }
                            FetchResult.Unavailable -> displayedImage(resource)
                        }
                    }
                    result.complete(value)
                }
                job.invokeOnCompletion { if (!result.isCompleted) result.complete(null) }
                Pending(job, result).also { requests[resource] = it }
            }
        }
        return pending.result.await()
    }

    suspend fun discard(resource: Resource) {
        lock.withLock { requests.remove(resource)?.job?.cancel() }
        synchronized(snapshots) { snapshots.remove(resource.key) }
    }

    suspend fun clear() {
        lock.withLock {
            generation++
            requests.values.forEach { it.job.cancel() }
            requests.clear()
        }
        synchronized(snapshots) { snapshots.clear() }
    }
}
