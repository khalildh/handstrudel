package com.handstrudel.common

import kotlinx.serialization.KSerializer
import kotlinx.serialization.descriptors.PrimitiveKind
import kotlinx.serialization.descriptors.PrimitiveSerialDescriptor
import kotlinx.serialization.descriptors.SerialDescriptor
import kotlinx.serialization.encoding.Decoder
import kotlinx.serialization.encoding.Encoder
import kotlinx.serialization.json.JsonDecoder
import kotlinx.serialization.json.JsonEncoder
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.double
import java.util.Locale
import java.util.UUID

// Shared kotlinx.serialization helpers. Integrator-owned (Phase 0); every WS
// may use them. Change them only in coordination, since wire formats depend on
// them.

/** UUID as a lowercase string (Postgres / Supabase rows). Decoding accepts any case. */
object UuidSerializer : KSerializer<UUID> {
    override val descriptor: SerialDescriptor = PrimitiveSerialDescriptor("handstrudel.UUID", PrimitiveKind.STRING)
    override fun serialize(encoder: Encoder, value: UUID) = encoder.encodeString(value.toString())
    override fun deserialize(decoder: Decoder): UUID = UUID.fromString(decoder.decodeString())
}

/**
 * UUID as Swift's `JSONEncoder` writes it: uppercase. Use it for payloads that
 * iOS also encodes with Codable (custom scales in `SoundSetup`, preset packs),
 * so Android output is byte-identical modulo key order.
 */
object SwiftUuidSerializer : KSerializer<UUID> {
    override val descriptor: SerialDescriptor = PrimitiveSerialDescriptor("handstrudel.SwiftUUID", PrimitiveKind.STRING)
    override fun serialize(encoder: Encoder, value: UUID) =
        encoder.encodeString(value.toString().uppercase(Locale.ROOT))
    override fun deserialize(decoder: Decoder): UUID = UUID.fromString(decoder.decodeString())
}

/**
 * A `Double` written the way Swift's `JSONEncoder` writes it: whole values have
 * no fraction (`120`, not `120.0`). Decoding accepts both forms.
 */
object SwiftDoubleSerializer : KSerializer<Double> {
    override val descriptor: SerialDescriptor = PrimitiveSerialDescriptor("handstrudel.SwiftDouble", PrimitiveKind.DOUBLE)

    override fun serialize(encoder: Encoder, value: Double) {
        val whole = value.isFinite() && value == Math.rint(value) && kotlin.math.abs(value) < 1e15
        if (encoder is JsonEncoder && whole) {
            encoder.encodeJsonElement(JsonPrimitive(value.toLong()))
        } else {
            encoder.encodeDouble(value)
        }
    }

    override fun deserialize(decoder: Decoder): Double =
        if (decoder is JsonDecoder) (decoder.decodeJsonElement() as JsonPrimitive).double
        else decoder.decodeDouble()
}
