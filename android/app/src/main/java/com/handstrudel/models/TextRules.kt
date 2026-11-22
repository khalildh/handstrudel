package com.handstrudel.models

import java.text.BreakIterator

/** Swift `String` rules that names must follow so presets and scales round-trip with iOS. */
object TextRules {
    /** Swift `String.count`: extended grapheme clusters, not UTF-16 units. */
    fun graphemeCount(s: String): Int {
        if (s.isEmpty()) return 0
        val breaks = BreakIterator.getCharacterInstance().apply { setText(s) }
        var count = 0
        while (breaks.next() != BreakIterator.DONE) count += 1
        return count
    }

    /** Swift `String(s.prefix(n))`: the first [n] grapheme clusters. */
    fun prefixGraphemes(s: String, n: Int): String {
        if (n <= 0) return ""
        val breaks = BreakIterator.getCharacterInstance().apply { setText(s) }
        var end = 0
        repeat(n) {
            val next = breaks.next()
            if (next == BreakIterator.DONE) return s
            end = next
        }
        return s.substring(0, end)
    }

    /** Swift `CharacterSet.controlCharacters`: general categories Cc and Cf (e.g. U+200D, U+200F). */
    fun isControl(codePoint: Int): Boolean {
        val type = Character.getType(codePoint)
        return type == Character.CONTROL.toInt() || type == Character.FORMAT.toInt()
    }

    fun containsControl(s: String): Boolean = s.codePoints().anyMatch(::isControl)
}
