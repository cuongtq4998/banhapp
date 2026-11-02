package app.banh.admin.stub

import app.banh.core.model.CancelReason
import app.banh.core.model.DateChangeRequest
import app.banh.core.model.DeliveryFeeEntry
import app.banh.core.model.FeeChangeRequest
import app.banh.core.model.LastChange
import app.banh.core.model.OrderDetail
import app.banh.core.model.OrderStatus
import app.banh.core.model.OrderSummary
import app.banh.core.model.OrdersPage
import app.banh.core.model.StatusChangeRequest
import java.time.LocalDate

internal const val CONFLICT_CODE = "BT-9C5D3F"
internal const val SCHEDULED_CODE = "BT-3S5T9U"
internal const val STARTED_CODE = "BT-5D1L6V"
private const val PAGE_SIZE = 50

/** In-memory orders for the stub: the fixture order plus a few that show every list state. Changes survive until the process ends. */
internal class StubOrders(template: OrderDetail, private val serverDate: String) {
    private val orders = LinkedHashMap<String, OrderDetail>()
    private var conflictPlanned = true

    init {
        val actor = LastChange("Nhan Vien A", "2026-11-01T04:00:00Z", "status")
        listOf(
            template,
            template.copy(orderCode = "BT-2H4N8R", status = OrderStatus.Processing, customerName = "Le Van C", deliveryDate = "2026-11-01", requestedDeliveryDate = "2026-11-01", listDate = "2026-11-01", districtName = "Quan Binh Thanh", allowedActions = actions(OrderStatus.Processing), lastChange = actor),
            template.copy(orderCode = CONFLICT_CODE, customerName = "Pham Thi D", deliveryDate = "2026-11-04", requestedDeliveryDate = "2026-11-04", listDate = "2026-11-04", note = null),
            template.copy(orderCode = "BT-6P2W7X", status = OrderStatus.Finished, customerName = "Nguyen Van E", deliveryDate = "2026-10-30", requestedDeliveryDate = "2026-10-30", listDate = "2026-10-30", allowedActions = emptyList(), lastChange = actor),
            template.copy(orderCode = "BT-4M8K2J", status = OrderStatus.Cancelled, customerName = "Do Thi F", deliveryDate = "2026-10-29", requestedDeliveryDate = "2026-10-29", listDate = "2026-10-29", cancelReason = CancelReason.CUSTOMER_ASKED, allowedActions = emptyList(), lastChange = actor),
            template.copy(orderCode = SCHEDULED_CODE, status = OrderStatus.DeliveryDateScheduled, customerName = "Vo Van G", deliveryDate = "2026-11-05", requestedDeliveryDate = "2026-11-05", expectedDeliveryDate = "2026-11-04", listDate = "2026-11-04", allowedActions = actions(OrderStatus.DeliveryDateScheduled), lastChange = actor),
            template.copy(orderCode = STARTED_CODE, status = OrderStatus.DeliveryStarted, customerName = "Bui Thi H", deliveryDate = "2026-11-05", requestedDeliveryDate = "2026-11-05", expectedDeliveryDate = "2026-11-05", listDate = "2026-11-05", deliveryFeeFinalVnd = 25_000, deliveryFeeVnd = 25_000, amountToCollectVnd = 125_000, deliveryFeeEntry = DeliveryFeeEntry("Nhan Vien A", "2026-11-01T04:00:00Z"), allowedActions = actions(OrderStatus.DeliveryStarted), lastChange = actor),
        ).forEach { orders[it.orderCode] = it }
    }

    fun detail(code: String): OrderDetail? = orders[code]

    fun list(query: Map<String, String>): OrdersPage {
        val status = query["status"] ?: "todo"
        val matching = orders.values.filter { matches(it, status, query) }
            .sortedWith(compareBy({ it.listDate ?: it.deliveryDate }, { it.slot.start }, { it.createdAt }, { it.orderCode }))
        val offset = query["cursor"]?.toIntOrNull() ?: 0
        val page = matching.drop(offset).take(PAGE_SIZE)
        val next = (offset + PAGE_SIZE).takeIf { it < matching.size }?.toString()
        val unfinished = orders.values.count { it.status.isOpen && (it.listDate ?: it.deliveryDate) <= serverDate }
        return OrdersPage(page.map(::summary), next, unfinished, serverDate)
    }

    /** `expected` is what the phone shows. A planned second person changes the conflict order first (FR-19). */
    fun change(code: String, request: StatusChangeRequest, actorName: String): Change {
        var current = orders[code] ?: return Change.NotFound
        if (code == CONFLICT_CODE && conflictPlanned) {
            conflictPlanned = false
            current = settle(current, StatusChangeRequest(OrderStatus.Received, OrderStatus.Processing), "Nhan Vien A").also { orders[code] = it }
        }
        if (current.status != request.expectedStatus) return Change.Conflict(current)
        if (request.toStatus !in allowedTargets(current.status)) return Change.Refused("error-status-transition-invalid", TRANSITION_STATUS)
        refusalOf(request, serverDate)?.let { return Change.Refused(it, VALIDATION_STATUS) }
        return Change.Done(settle(current, request, actorName).also { orders[code] = it })
    }

    fun changeDate(code: String, request: DateChangeRequest, actorName: String): Change {
        val current = orders[code] ?: return Change.NotFound
        if (request.expectedStatus != OrderStatus.DeliveryDateScheduled) return Change.Refused("error-validation-expected-date-past", VALIDATION_STATUS)
        dateRefusal(request.expectedDeliveryDate, serverDate)?.let { return Change.Refused(it, VALIDATION_STATUS) }
        if (current.status != request.expectedStatus || current.expectedDeliveryDate != request.previousExpectedDeliveryDate) return Change.Conflict(current)
        return Change.Done(current.withDate(request.expectedDeliveryDate, actorName).also { orders[code] = it })
    }

    fun changeFee(code: String, request: FeeChangeRequest, actorName: String): Change {
        val current = orders[code] ?: return Change.NotFound
        if (request.expectedStatus != OrderStatus.DeliveryStarted) return Change.Refused("error-fee-correction-not-allowed", VALIDATION_STATUS)
        feeRefusal(request.deliveryFeeVnd)?.let { return Change.Refused(it, VALIDATION_STATUS) }
        if (request.deliveryFeeVnd == request.previousDeliveryFeeVnd) return Change.Refused("error-validation-fee-invalid", VALIDATION_STATUS)
        if (current.status != request.expectedStatus || current.deliveryFeeFinalVnd != request.previousDeliveryFeeVnd) return Change.Conflict(current)
        return Change.Done(current.withFee(request.deliveryFeeVnd, actorName).also { orders[code] = it })
    }

    private fun settle(order: OrderDetail, request: StatusChangeRequest, actor: String): OrderDetail {
        val moved = order.copy(
            status = request.toStatus,
            cancelReason = request.cancelReason,
            allowedActions = actions(request.toStatus),
            lastChange = LastChange(actor, STUB_NOW, "status"),
        )
        return when (request.toStatus) {
            OrderStatus.DeliveryDateScheduled -> moved.copy(expectedDeliveryDate = request.expectedDeliveryDate, listDate = request.expectedDeliveryDate)
            OrderStatus.DeliveryStarted -> moved.withEnteredFee(request.deliveryFeeVnd ?: 0, actor)
            else -> moved
        }
    }

    private fun matches(order: OrderDetail, status: String, query: Map<String, String>): Boolean {
        val statusOk = when (status) {
            "todo" -> order.status.isOpen
            "all" -> true
            else -> order.status.wire == status
        }
        val date = LocalDate.parse(serverDate)
        val dateOk = when {
            query["date_preset"] == "today" -> order.deliveryDate == date.toString()
            query["date_preset"] == "tomorrow" -> order.deliveryDate == date.plusDays(1).toString()
            query["delivery_date"] != null -> order.deliveryDate == query["delivery_date"]
            else -> true
        }
        val text = query["q"]?.lowercase().orEmpty()
        val textOk = text.isEmpty() || order.orderCode.lowercase().contains(text.removePrefix("bt-")) || order.customerName.lowercase().contains(text) || order.customerPhone.contains(text)
        return statusOk && dateOk && textOk
    }

    private fun summary(d: OrderDetail) = OrderSummary(d.orderCode, d.status, d.customerName, d.deliveryDate, d.expectedDeliveryDate, d.listDate ?: d.deliveryDate, d.slot, d.totalCakes, d.totalVnd, d.districtName, d.createdAt)

    sealed interface Change {
        data object NotFound : Change

        data class Done(val detail: OrderDetail) : Change

        data class Conflict(val current: OrderDetail) : Change

        /** [fixture] is the error body the server would send, with [status]. */
        data class Refused(val fixture: String, val status: Int) : Change
    }
}
