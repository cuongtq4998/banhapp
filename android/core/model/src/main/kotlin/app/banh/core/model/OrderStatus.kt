package app.banh.core.model

import kotlinx.serialization.KSerializer
import kotlinx.serialization.Serializable
import kotlinx.serialization.descriptors.PrimitiveKind
import kotlinx.serialization.descriptors.PrimitiveSerialDescriptor
import kotlinx.serialization.encoding.Decoder
import kotlinx.serialization.encoding.Encoder

/** The six order words (api/09 10.13); [Unknown] keeps a word a newer server may add, so the order still shows. */
@Serializable(with = OrderStatusSerializer::class)
sealed interface OrderStatus {
    val wire: String

    data object Received : OrderStatus { override val wire = "Received" }

    data object Processing : OrderStatus { override val wire = "Processing" }

    data object DeliveryDateScheduled : OrderStatus { override val wire = "DeliveryDateScheduled" }

    data object DeliveryStarted : OrderStatus { override val wire = "DeliveryStarted" }

    data object Finished : OrderStatus { override val wire = "Finished" }

    data object Cancelled : OrderStatus { override val wire = "Cancelled" }

    /** A word this app does not know; [raw] is kept as received. */
    data class Unknown(val raw: String) : OrderStatus { override val wire get() = raw }

    /** Open orders are the ones that can become due (FR-9). */
    val isOpen: Boolean get() = this is Received || this is Processing || this is DeliveryDateScheduled || this is DeliveryStarted

    companion object {
        // Lazy: the objects initialise this companion, so an eager list would hold nulls.
        private val known by lazy { listOf(Received, Processing, DeliveryDateScheduled, DeliveryStarted, Finished, Cancelled) }

        // History rows written before ADR-0033 still carry the old words.
        private val legacy by lazy { mapOf("New" to Received, "Confirmed" to Processing, "Completed" to Finished) }

        /** Maps a wire word to its case; an unrecognised word becomes [Unknown]. */
        fun fromWire(word: String): OrderStatus = known.firstOrNull { it.wire == word } ?: legacy[word] ?: Unknown(word)
    }
}

object OrderStatusSerializer : KSerializer<OrderStatus> {
    override val descriptor = PrimitiveSerialDescriptor("OrderStatus", PrimitiveKind.STRING)

    override fun deserialize(decoder: Decoder): OrderStatus = OrderStatus.fromWire(decoder.decodeString())

    override fun serialize(encoder: Encoder, value: OrderStatus) = encoder.encodeString(value.wire)
}
