package com.handstrudel.social.model

/**
 * iOS `PostSearch`: a validated search for the `feed_videos` `or=` filter.
 * `@handle` searches only usernames; text searches caption, instrument, username and
 * display name. The term is regex-escaped (`imatch`) then quoted for PostgREST.
 */
class PostSearch private constructor(val text: String, val filter: String, val isHandleSearch: Boolean) {

    /** Removing one @ must not leave another handle-scoped query. */
    val broaderInput: String?
        get() = if (isHandleSearch && !text.startsWith("@")) text else null

    fun filter(after: String?): String = if (after == null) filter else "and(or($filter),or($after))"

    override fun equals(other: Any?): Boolean =
        other is PostSearch && other.text == text && other.filter == filter && other.isHandleSearch == isHandleSearch
    override fun hashCode(): Int = (text.hashCode() * 31 + filter.hashCode()) * 31 + isHandleSearch.hashCode()

    companion object {
        private const val METACHARACTERS = "\\.^$|?*+()[]{}"

        /** Null for fewer than two characters (Swift `Character` count ≈ grapheme count). */
        fun parse(input: String): PostSearch? {
            val cleaned = input.replace("\u0000", "").trim()
            val byHandle = cleaned.startsWith("@")
            val text = graphemePrefix(if (byHandle) cleaned.drop(1) else cleaned, 80).trim()
            if (graphemeCount(text) < 2) return null
            val pattern = buildString {
                for (ch in text) { if (ch in METACHARACTERS) append('\\'); append(ch) }
            }
            val quoted = pattern.replace("\\", "\\\\").replace("\"", "\\\"")
            val columns = if (byHandle) listOf("username") else listOf("caption", "instrument", "username", "display_name")
            val filter = columns.joinToString(",") { "$it.imatch.\"$quoted\"" }
            return PostSearch(text, filter, byHandle)
        }

        private fun graphemeCount(s: String): Int {
            val it = java.text.BreakIterator.getCharacterInstance()
            it.setText(s)
            var n = 0
            while (it.next() != java.text.BreakIterator.DONE) n++
            return n
        }

        private fun graphemePrefix(s: String, max: Int): String {
            val it = java.text.BreakIterator.getCharacterInstance()
            it.setText(s)
            var end = 0
            var n = 0
            while (n < max) {
                val next = it.next()
                if (next == java.text.BreakIterator.DONE) break
                end = next; n++
            }
            return s.substring(0, end)
        }
    }
}
