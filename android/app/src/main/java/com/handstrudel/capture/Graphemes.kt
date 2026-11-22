package com.handstrudel.capture

import java.text.BreakIterator

/**
 * Swift `String.prefix(n)`: the first [limit] user-perceived characters (grapheme
 * clusters), so an emoji or an accented letter is never cut in half.
 */
fun String.graphemePrefix(limit: Int): String {
    if (limit <= 0) return ""
    if (length <= limit) return this // A cluster is at least one UTF-16 unit.
    val breaks = BreakIterator.getCharacterInstance()
    breaks.setText(this)
    var end = breaks.first()
    repeat(limit) {
        val next = breaks.next()
        if (next == BreakIterator.DONE) return this
        end = next
    }
    return substring(0, end)
}
