package com.handstrudel.models

/**
 * iOS `ChordProgression` (`Models/ChordProgression.swift`): an ordered list of
 * 0-based scale degrees the chord hand cycles through. The 144 built-ins are in
 * the generated `ChordProgressionCatalog.kt` (regenerate from the Swift file;
 * do not hand-edit).
 */
data class ChordProgression(
    val id: String,
    val name: String,
    val emoji: String,
    val degrees: List<Int>,
    val category: ProgressionCategory = ProgressionCategory.CUSTOM,
) {
    val isFree: Boolean get() = id == "free"

    /** User-typed progressions have ids starting "custom". */
    val isCustom: Boolean get() = id.startsWith("custom")

    /** Everything outside Essentials (and any custom progression) is Pro. */
    val isPremium: Boolean get() = category != ProgressionCategory.ESSENTIALS && !isCustom

    val packId: String? get() = if (isPremium) "pro" else null

    companion object {
        /**
         * iOS `ChordProgression.parse`: Roman numerals or scale-degree numbers in
         * any common notation ("I V vi IV", "1 5 6 4", "I-V-vi-IV", "I → V").
         * Qualities/extensions are ignored; unresolvable tokens are skipped.
         * Null when nothing parses.
         */
        fun parse(text: String, name: String = "Custom", emoji: String = "✍️"): ChordProgression? {
            val tokens = splitAlphanumeric(text)
            val degrees = tokens.mapNotNull(::degreeForToken)
            if (degrees.isEmpty()) return null
            return ChordProgression("custom", name, emoji, degrees, ProgressionCategory.CUSTOM)
        }

        /** Splits on anything that isn't a Unicode letter, mark or digit (Swift `CharacterSet.alphanumerics.inverted`). */
        private fun splitAlphanumeric(text: String): List<String> {
            val out = mutableListOf<String>()
            val cur = StringBuilder()
            var i = 0
            while (i < text.length) {
                val cp = text.codePointAt(i)
                val type = Character.getType(cp)
                val alnum = Character.isLetterOrDigit(cp) ||
                    type == Character.NON_SPACING_MARK.toInt() || type == Character.COMBINING_SPACING_MARK.toInt() ||
                    type == Character.ENCLOSING_MARK.toInt() || type == Character.LETTER_NUMBER.toInt() ||
                    type == Character.OTHER_NUMBER.toInt()
                if (alnum) cur.appendCodePoint(cp) else if (cur.isNotEmpty()) { out += cur.toString(); cur.clear() }
                i += Character.charCount(cp)
            }
            if (cur.isNotEmpty()) out += cur.toString()
            return out
        }

        private fun degreeForToken(raw: String): Int? {
            val token = raw.lowercase()
            val digits = token.takeWhile { it.isDigit() }
            if (digits.isNotEmpty()) {
                val n = digits.toIntOrNull() ?: return null
                return if (n in 1..7) n - 1 else null
            }
            return when (token.takeWhile { it == 'i' || it == 'v' }) {
                "i" -> 0
                "ii" -> 1
                "iii" -> 2
                "iv" -> 3
                "v" -> 4
                "vi" -> 5
                "vii" -> 6
                else -> null
            }
        }
    }
}

val FREE_PROGRESSION: ChordProgression = CHORD_PROGRESSIONS.first { it.id == "free" }

/** iOS default `chordMelodyProgression`: "pop", else the free layout. */
val DEFAULT_PROGRESSION: ChordProgression =
    CHORD_PROGRESSIONS.firstOrNull { it.id == "pop" } ?: FREE_PROGRESSION

fun chordProgression(id: String): ChordProgression? = CHORD_PROGRESSIONS.firstOrNull { it.id == id }
