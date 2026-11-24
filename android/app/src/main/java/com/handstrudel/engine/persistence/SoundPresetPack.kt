package com.handstrudel.engine.persistence

import com.handstrudel.models.TextRules
import com.handstrudel.engine.PresetPackException
import com.handstrudel.models.NamedSoundSetup
import com.handstrudel.models.SoundSetup
import com.handstrudel.models.SoundSetupJson
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive

/**
 * Port of iOS `SoundPresetPack`: `{format: "handstrudel-presets", version: 1,
 * presets: [{name, sound}]}`, 1–128 presets, ≤256 KB. Validation is
 * all-or-nothing and throws [PresetPackException] with the iOS messages.
 */
@Serializable
data class SoundPresetPack(
    // Required on decode, like Swift's synthesized Codable (a missing key is "wrong format").
    val format: String,
    val version: Int,
    val presets: List<Entry>,
) {
    @Serializable
    data class Entry(val name: String, val sound: SoundSetup) {
        /** iOS `Entry.isValid`. */
        val isValid: Boolean
            get() = name.isNotEmpty() && TextRules.graphemeCount(name) <= 40 && name == name.trim() &&
                !TextRules.containsControl(name) && sound.isValid
    }

    fun validate() {
        if (format != SIGNATURE || version != 1) throw PresetPackException(PresetPackException.Kind.WRONG_FORMAT)
        if (presets.size !in 1..COUNT_LIMIT) throw PresetPackException(PresetPackException.Kind.CAPACITY)
        if (!presets.all { it.isValid }) throw PresetPackException(PresetPackException.Kind.INVALID_PRESET)
    }

    /** iOS `encoded()`: pretty-printed with sorted keys, Foundation style; ≤256 KB. */
    fun encoded(): ByteArray {
        val element = SoundSetupJson.encodeToJsonElement(serializer(), this)
        val bytes = AppleJson.prettyPrinted(element).toByteArray(Charsets.UTF_8)
        if (bytes.size > BYTE_LIMIT) throw PresetPackException(PresetPackException.Kind.CAPACITY)
        return bytes
    }

    companion object {
        const val BYTE_LIMIT = 256 * 1024
        const val COUNT_LIMIT = 128
        const val SIGNATURE = "handstrudel-presets"

        fun from(setups: List<NamedSoundSetup>): SoundPresetPack =
            SoundPresetPack(SIGNATURE, 1, setups.map { Entry(it.name, it.sound) }).also { it.validate() }

        /** iOS `decode(_:)`. */
        fun decode(data: ByteArray): SoundPresetPack {
            if (data.isEmpty() || data.size > BYTE_LIMIT) throw PresetPackException(PresetPackException.Kind.CAPACITY)
            val pack = try {
                SoundSetupJson.decodeFromString(serializer(), data.toString(Charsets.UTF_8))
            } catch (e: Exception) {
                throw PresetPackException(PresetPackException.Kind.WRONG_FORMAT)
            }
            pack.validate()
            return pack
        }
    }
}

/** Swift `JSONEncoder` with `[.prettyPrinted, .sortedKeys]` output shape. */
internal object AppleJson {
    fun prettyPrinted(element: JsonElement): String = StringBuilder().also { write(it, element, 0) }.toString()

    private fun write(sb: StringBuilder, e: JsonElement, depth: Int) {
        when (e) {
            is JsonObject -> {
                if (e.isEmpty()) { sb.append("{\n\n").append("  ".repeat(depth)).append("}"); return }
                sb.append("{\n")
                e.keys.sorted().forEachIndexed { i, key ->
                    sb.append("  ".repeat(depth + 1)).append(quote(key)).append(" : ")
                    write(sb, e.getValue(key), depth + 1)
                    if (i < e.size - 1) sb.append(",")
                    sb.append("\n")
                }
                sb.append("  ".repeat(depth)).append("}")
            }
            is JsonArray -> {
                if (e.isEmpty()) { sb.append("[\n\n").append("  ".repeat(depth)).append("]"); return }
                sb.append("[\n")
                e.forEachIndexed { i, item ->
                    sb.append("  ".repeat(depth + 1))
                    write(sb, item, depth + 1)
                    if (i < e.size - 1) sb.append(",")
                    sb.append("\n")
                }
                sb.append("  ".repeat(depth)).append("]")
            }
            is JsonNull -> sb.append("null")
            is JsonPrimitive -> if (e.isString) sb.append(quote(e.content)) else sb.append(e.content)
        }
    }

    private fun quote(s: String): String {
        val sb = StringBuilder("\"")
        for (c in s) {
            when (c) {
                '"' -> sb.append("\\\"")
                '\\' -> sb.append("\\\\")
                '/' -> sb.append("\\/")
                '\n' -> sb.append("\\n")
                '\r' -> sb.append("\\r")
                '\t' -> sb.append("\\t")
                '\b' -> sb.append("\\b")
                '\u000C' -> sb.append("\\f")
                else -> if (c < ' ') sb.append(String.format("\\u%04x", c.code)) else sb.append(c)
            }
        }
        return sb.append("\"").toString()
    }
}
