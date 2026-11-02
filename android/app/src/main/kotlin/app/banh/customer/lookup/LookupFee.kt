package app.banh.customer.lookup

import app.banh.customer.data.lookup.LookupOrder
import app.banh.customer.data.lookup.TrackingStatus

/** The fee block of a card (design part 13). The app never adds numbers; every amount is a server value. */
sealed interface LookupFee {
    /** No block: a cancelled card. */
    data object None : LookupFee

    /** Amount to collect is null: the estimate is shown as an estimate and no total exists. */
    data class Unknown(val subtotalVnd: Long, val estimateVnd: Long?) : LookupFee

    data class Known(val subtotalVnd: Long, val feeVnd: Long, val collectVnd: Long) : LookupFee

    /** Real fee 0: free delivery, collect = server amount. */
    data class Free(val subtotalVnd: Long, val collectVnd: Long) : LookupFee
}

/** Chosen only by whether the server amount is null, never by the status step. */
fun LookupOrder.feeState(): LookupFee {
    if (status == TrackingStatus.Known.CANCELLED) return LookupFee.None
    val collect = amountToCollectVnd ?: return LookupFee.Unknown(itemsSubtotalVnd, deliveryFeeEstimateVnd)
    val fee = deliveryFeeFinalVnd ?: return LookupFee.Unknown(itemsSubtotalVnd, deliveryFeeEstimateVnd)
    return if (fee == 0L) LookupFee.Free(itemsSubtotalVnd, collect) else LookupFee.Known(itemsSubtotalVnd, fee, collect)
}
