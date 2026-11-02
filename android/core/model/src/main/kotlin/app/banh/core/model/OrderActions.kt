package app.banh.core.model

import kotlinx.serialization.KSerializer
import kotlinx.serialization.Serializable
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.builtins.serializer
import kotlinx.serialization.descriptors.SerialDescriptor
import kotlinx.serialization.encoding.Decoder
import kotlinx.serialization.encoding.Encoder

/** What the server allows next (api/09 10.13.7); the app shows exactly these and never derives them from the status. */
enum class OrderAction(val wire: String) {
    CANCEL("cancel"),
    PROCESS("process"),
    SCHEDULE_DELIVERY("schedule_delivery"),
    START_DELIVERY("start_delivery"),
    FINISH("finish"),
    CHANGE_DATE("change_date"),
    CORRECT_FEE("correct_fee"),
}

/** Reads the action names in server order and drops names this app does not know. */
object AllowedActionsSerializer : KSerializer<List<OrderAction>> {
    private val names = ListSerializer(String.serializer())
    override val descriptor: SerialDescriptor = names.descriptor

    override fun deserialize(decoder: Decoder): List<OrderAction> =
        names.deserialize(decoder).mapNotNull { name -> OrderAction.entries.firstOrNull { it.wire == name } }

    override fun serialize(encoder: Encoder, value: List<OrderAction>) = names.serialize(encoder, value.map { it.wire })
}

typealias AllowedActions = @Serializable(with = AllowedActionsSerializer::class) List<OrderAction>
