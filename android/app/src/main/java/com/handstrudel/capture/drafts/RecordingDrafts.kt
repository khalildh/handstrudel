package com.handstrudel.capture.drafts

import com.handstrudel.capture.upload.DraftPostSubmission
import com.handstrudel.capture.upload.UploadJson
import com.handstrudel.models.SoundSetup
import com.handstrudel.social.model.BackingCredit
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import java.io.File
import java.io.IOException
import java.util.UUID

/**
 * iOS `RecordingDrafts`: the private drafts library under `filesDir/drafts/`.
 * Each draft is a folder `<uuid>/` with `take.mp4` and `draft.json`. Metadata is
 * written before capture starts, so a finished file is found after a restart.
 * Pure JVM (java.io) so it is unit-testable.
 */
class RecordingDrafts(private val directory: File, private val now: () -> Long = System::currentTimeMillis) {
    private val _drafts = MutableStateFlow<List<RecordingDraft>>(emptyList())
    val drafts: StateFlow<List<RecordingDraft>> = _drafts
    private val _loadError = MutableStateFlow<String?>(null)
    val loadError: StateFlow<String?> = _loadError

    init {
        reload()
    }

    @Synchronized
    fun reload() {
        try {
            prepareDirectory()
            _drafts.value = (directory.listFiles() ?: emptyArray())
                .filter { it.isDirectory && !it.name.startsWith(".") }
                .mapNotNull { folder ->
                    val id = runCatching { UUID.fromString(folder.name) }.getOrNull() ?: return@mapNotNull null
                    val video = videoFile(id)
                    if (!video.isFile) return@mapNotNull null
                    readMetadata(id) ?: RecordingDraft(id = id, createdAt = video.lastModified())
                }
                .sortedByDescending { it.createdAt }
            _loadError.value = null
        } catch (e: Exception) {
            _loadError.value = e.message ?: "Drafts couldn't load."
        }
    }

    private fun prepareDirectory() {
        if (!directory.isDirectory && !directory.mkdirs()) throw IOException("Couldn't create the drafts folder.")
    }

    /** Creates the folder and metadata before capture (iOS `begin`). */
    @Synchronized
    fun begin(
        instrument: String?,
        mode: String?,
        soundSetup: SoundSetup? = null,
        backingCredit: BackingCredit? = null,
        halfSpeed: Boolean = false,
    ): RecordingDraft {
        prepareDirectory()
        val draft = RecordingDraft(
            id = UUID.randomUUID(), createdAt = now(), instrument = instrument, mode = mode,
            soundSetup = soundSetup, backingCredit = backingCredit, recordedAtHalfSpeed = if (halfSpeed) true else null,
        )
        if (!folder(draft.id).mkdir()) throw IOException("Couldn't create the draft folder.")
        try {
            writeMetadata(draft)
        } catch (e: Exception) {
            discardUnfinished(draft)
            throw e
        }
        return draft
    }

    /** The take finished writing: list it (iOS `complete`). Throws when the file is empty. */
    @Synchronized
    fun complete(draft: RecordingDraft) {
        val file = videoFile(draft.id)
        if (!file.isFile || file.length() <= 0) throw DraftException(DraftError.UNREADABLE)
        if (_drafts.value.none { it.id == draft.id }) _drafts.value = listOf(draft) + _drafts.value
    }

    fun saveTrim(draft: RecordingDraft): RecordingDraft =
        updateDraft(draft.id) { it.copy(trimStart = draft.trimStart, trimEnd = draft.trimEnd) }

    fun rename(id: UUID, title: String): RecordingDraft =
        updateDraft(id) { it.copy(title = RecordingDraft.normalizedTitle(title)) }

    fun draft(id: UUID): RecordingDraft? = _drafts.value.firstOrNull { it.id == id }

    fun postSubmission(draftId: UUID, accountId: UUID): DraftPostSubmission? =
        draft(draftId)?.postSubmission(accountId)

    /**
     * iOS `replacePostSubmission`: compare-and-swap of one account's submission.
     * Returns false (and changes nothing) if the stored value isn't [previous].
     */
    @Synchronized
    fun replacePostSubmission(previous: DraftPostSubmission?, next: DraftPostSubmission?, draftId: UUID, accountId: UUID): Boolean {
        if (postSubmission(draftId, accountId) != previous) return false
        updateDraft(draftId) { draft ->
            val submissions = (draft.postSubmissions ?: emptyMap()).toMutableMap()
            if (next == null) submissions.remove(accountId.toString()) else submissions[accountId.toString()] = next
            draft.copy(postSubmissions = submissions.ifEmpty { null })
        }
        return true
    }

    @Synchronized
    private fun updateDraft(id: UUID, update: (RecordingDraft) -> RecordingDraft): RecordingDraft {
        val list = _drafts.value
        val index = list.indexOfFirst { it.id == id }
        if (index < 0) throw DraftException(DraftError.MISSING_DRAFT)
        val updated = update(list[index])
        writeMetadata(updated)
        _drafts.value = list.toMutableList().also { it[index] = updated }
        return updated
    }

    @Synchronized
    fun delete(draft: RecordingDraft) {
        val folder = folder(draft.id)
        if (folder.exists() && !folder.deleteRecursively()) throw IOException("Couldn't delete this draft.")
        _drafts.value = _drafts.value.filterNot { it.id == draft.id }
    }

    fun discardUnfinished(draft: RecordingDraft) {
        folder(draft.id).deleteRecursively()
    }

    fun videoFile(id: UUID): File = File(folder(id), "take.mp4")
    private fun folder(id: UUID): File = File(directory, id.toString().uppercase())
    private fun metadataFile(id: UUID): File = File(folder(id), "draft.json")

    private fun readMetadata(id: UUID): RecordingDraft? = runCatching {
        UploadJson.decodeFromString(RecordingDraft.serializer(), metadataFile(id).readText())
    }.getOrNull()?.takeIf { it.id == id }

    /** Atomic write (temp file + rename), like iOS `.atomic`. */
    private fun writeMetadata(draft: RecordingDraft) {
        val target = metadataFile(draft.id)
        val temp = File(target.parentFile, "draft.json.tmp")
        temp.writeText(UploadJson.encodeToString(RecordingDraft.serializer(), draft))
        if (!temp.renameTo(target)) {
            temp.delete()
            throw IOException("Couldn't save the draft details.")
        }
    }

    companion object {
        /** Seconds of output per take (iOS `recordingLimit`). */
        const val RECORDING_LIMIT = 60
    }
}
