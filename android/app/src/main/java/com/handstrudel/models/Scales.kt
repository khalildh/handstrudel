package com.handstrudel.models

import com.handstrudel.common.SwiftUuidSerializer
import kotlinx.serialization.KSerializer
import kotlinx.serialization.SerializationException
import kotlinx.serialization.Serializable
import kotlinx.serialization.descriptors.SerialDescriptor
import kotlinx.serialization.descriptors.buildClassSerialDescriptor
import kotlinx.serialization.encoding.Decoder
import kotlinx.serialization.encoding.Encoder
import kotlinx.serialization.json.JsonDecoder
import kotlinx.serialization.json.JsonEncoder
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.decodeFromJsonElement
import kotlinx.serialization.json.encodeToJsonElement
import java.util.UUID

/**
 * Port of iOS `CustomScale` (`Models/MusicTheory.swift`). Owner: engine.
 * Wire shape: `{"id": "<UUID>", "name": "...", "intervals": [0, ...]}`.
 * Construct through [create], which applies the iOS validation.
 */
@Serializable
data class CustomScale(
    @Serializable(with = SwiftUuidSerializer::class) val id: UUID,
    val name: String,
    val intervals: List<Int>,
) {
    val isValid: Boolean get() = create(id, name, intervals)?.let { it.name == name } == true

    companion object {
        /** iOS `CustomScale.init?`: trimmed non-empty name ≤40 scalars, no control chars,
         *  3–12 unique ascending intervals starting at 0 and below 12. */
        fun create(id: UUID = UUID.randomUUID(), name: String, intervals: List<Int>): CustomScale? {
            val trimmed = name.trim()
            val scalars = trimmed.codePointCount(0, trimmed.length)
            if (trimmed.isEmpty() || scalars > 40) return null
            if (TextRules.containsControl(trimmed)) return null // Cc + Cf, like `CharacterSet.controlCharacters`
            if (intervals.size !in 3..12 || intervals.first() != 0) return null
            if (intervals != intervals.sorted() || intervals.last() >= 12) return null
            if (intervals.toSet().size != intervals.size) return null
            return CustomScale(id, trimmed, intervals)
        }
    }
}

/**
 * iOS `Scale` enum: a built-in scale or a user custom scale. Owner: engine.
 * Encodes as the built-in raw name string, or as a [CustomScale] object.
 */
@Serializable(with = ScaleSelectionSerializer::class)
sealed interface ScaleSelection {
    data class BuiltIn(val scale: Scale) : ScaleSelection
    data class Custom(val scale: CustomScale) : ScaleSelection

    val rawValue: String get() = when (this) {
        is BuiltIn -> scale.rawValue
        is Custom -> "Custom"
    }
    /** iOS `Scale.id`: the custom scale's uppercase UUID, else the raw name. */
    val id: String get() = when (this) {
        is BuiltIn -> scale.rawValue
        is Custom -> scale.id.toString().uppercase()
    }
    val customScale: CustomScale? get() = (this as? Custom)?.scale
    val displayName: String get() = when (this) {
        is BuiltIn -> scale.displayName
        is Custom -> scale.name
    }
    val intervals: List<Int> get() = when (this) {
        is BuiltIn -> scale.intervals
        is Custom -> scale.intervals
    }
    val isPremium: Boolean get() = when (this) {
        is BuiltIn -> scale.isPremium
        is Custom -> true
    }
    val packId: String? get() = if (isPremium) "pro" else null

    companion object {
        val PENTATONIC: ScaleSelection = BuiltIn(Scale.PENTATONIC)
        /** iOS `Scale.allCases`: the 23 built-ins. */
        val allBuiltIn: List<ScaleSelection> get() = Scale.entries.map(::BuiltIn)
    }
}

object ScaleSelectionSerializer : KSerializer<ScaleSelection> {
    override val descriptor: SerialDescriptor = buildClassSerialDescriptor("handstrudel.Scale")

    override fun serialize(encoder: Encoder, value: ScaleSelection) {
        val json = encoder as? JsonEncoder ?: throw SerializationException("Scale encodes to JSON only")
        when (value) {
            is ScaleSelection.BuiltIn -> json.encodeJsonElement(JsonPrimitive(value.scale.rawValue))
            is ScaleSelection.Custom -> json.encodeJsonElement(json.json.encodeToJsonElement(value.scale))
        }
    }

    override fun deserialize(decoder: Decoder): ScaleSelection {
        val json = decoder as? JsonDecoder ?: throw SerializationException("Scale decodes from JSON only")
        return when (val element = json.decodeJsonElement()) {
            is JsonPrimitive -> {
                if (!element.isString) throw SerializationException("Scale must be a string or object")
                ScaleSelection.BuiltIn(Scale.fromRaw(element.content)
                    ?: throw SerializationException("Unknown built-in scale"))
            }
            is JsonObject -> {
                val custom = json.json.decodeFromJsonElement<CustomScale>(element)
                if (!custom.isValid) throw SerializationException("Invalid custom scale")
                ScaleSelection.Custom(custom)
            }
            else -> throw SerializationException("Scale must be a string or object")
        }
    }
}
