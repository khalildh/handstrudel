package com.handstrudel.capture.drafts

import com.handstrudel.capture.upload.DraftPostSubmission
import com.handstrudel.capture.upload.SoundSetupFieldSerializer
import com.handstrudel.common.UuidSerializer
import com.handstrudel.models.SoundSetup
import com.handstrudel.social.model.BackingCredit
import kotlinx.serialization.Serializable
import java.text.BreakIterator
import java.util.UUID

/**
 * iOS `RecordingDraft`: one private take, stored as `drafts/<uuid>/draft.json`
 * next to `take.mp4`. Kept on device only.
 */
@Serializable
data class RecordingDraft(
    @Serializable(with = UuidSerializer::class) val id: UUID,
    /** Epoch milliseconds. */
    val createdAt: Long,
    val instrument: String? = null,
    val mode: String? = null,
    @Serializable(with = SoundSetupFieldSerializer::class) val soundSetup: SoundSetup? = null,
    val backingCredit: BackingCredit? = null,
    val recordedAtHalfSpeed: Boolean? = null,
    val trimStart: Double? = null,
    val trimEnd: Double? = null,
    val title: String? = null,
    /** Keyed by the lowercase account UUID (iOS `[UUID: DraftPostSubmission]`). */
    val postSubmissions: Map<String, DraftPostSubmission>? = null,
) {
    val displayTitle: String get() = title ?: instrument ?: "Performance"
    val outputScale: Double get() = if (recordedAtHalfSpeed == true) 0.5 else 1.0

    fun postSubmission(accountId: UUID): DraftPostSubmission? = postSubmissions?.get(accountId.toString())

    companion object {
        const val TITLE_LIMIT = 60

        /**
         * iOS `normalizedTitle`: whitespace and control runs collapse to one space,
         * the first 60 characters (grapheme clusters) are kept, blank becomes null.
         */
        fun normalizedTitle(input: String): String? {
            val words = mutableListOf<String>()
            val current = StringBuilder()
            forEachGrapheme(input) { g ->
                val separator = g.all { it.isWhitespace() || Character.getType(it) == Character.CONTROL.toInt() }
                if (separator) {
                    if (current.isNotEmpty()) { words += current.toString(); current.clear() }
                } else current.append(g)
            }
            if (current.isNotEmpty()) words += current.toString()
            val singleLine = words.joinToString(" ")
            val prefix = StringBuilder()
            var count = 0
            forEachGrapheme(singleLine) { g -> if (count < TITLE_LIMIT) { prefix.append(g); count++ } }
            val title = prefix.toString().trim(' ')
            return title.ifEmpty { null }
        }

        private inline fun forEachGrapheme(s: String, body: (String) -> Unit) {
            val it = BreakIterator.getCharacterInstance()
            it.setText(s)
            var start = it.first()
            var end = it.next()
            while (end != BreakIterator.DONE) {
                body(s.substring(start, end))
                start = end
                end = it.next()
            }
        }
    }
}

/** iOS `DraftError` messages. */
enum class DraftError(val message: String) {
    UNREADABLE("This video could not be read or exported."),
    INVALID_TRIM("This trim no longer fits the video. Reset it or choose a new range before exporting."),
    NO_AUDIO("This take doesn't have an audio track to export."),
    MISSING_DRAFT("This draft is no longer in Private drafts."),
}

class DraftException(val error: DraftError) : Exception(error.message)
