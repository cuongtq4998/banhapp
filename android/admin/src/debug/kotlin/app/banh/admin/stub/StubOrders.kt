package app.banh.admin.stub

import app.banh.core.model.CancelReason
import app.banh.core.model.LastChange
import app.banh.core.model.OrderAction
import app.banh.core.model.OrderDetail
import app.banh.core.model.OrderStatus
import app.banh.core.model.OrderSummary
import app.banh.core.model.OrdersPage
import java.time.LocalDate

internal const val CONFLICT_CODE = "BT-9C5D3F"
private const val PAGE_SIZE = 50

/** In-memory orders for the stub: the fixture order plus a few that show every list state. Changes survive until the process ends. */
internal class StubOrders(template: OrderDetail, private val serverDate: String) {
    private val orders = LinkedHashMap<String, OrderDetail>()
    private var conflictPlanned = true

    init {
        val actor = LastChange("Nhan Vien A", "2026-11-01T04:00:00Z", "status")
        listOf(
            template,
            template.copy(orderCode = "BT-2H4N8R", status = OrderStatus.Processing, customerName = "Le Van C", deliveryDate = "2026-11-01", districtName = "Quan Binh Thanh", allowedActions = actions(OrderStatus.Processing), lastChange = actor),
            template.copy(orderCode = CONFLICT_CODE, customerName = "Pham Thi D", deliveryDate = "2026-11-04", note = null),
            template.copy(orderCode = "BT-6P2W7X", status = OrderStatus.Finished, customerName = "Nguyen Van E", deliveryDate = "2026-10-30", allowedActions = emptyList(), lastChange = actor),
            template.copy(orderCode = "BT-4M8K2J", status = OrderStatus.Cancelled, customerName = "Do Thi F", deliveryDate = "2026-10-29", cancelReason = CancelReason.CUSTOMER_ASKED, allowedActions = emptyList(), lastChange = actor),
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
    fun change(code: String, expected: OrderStatus, to: OrderStatus, reason: CancelReason?, actorName: String): Change {
        var current = orders[code] ?: return Change.NotFound
        if (code == CONFLICT_CODE && conflictPlanned) {
            conflictPlanned = false
            current = settle(current, OrderStatus.Processing, null, "Nhan Vien A").also { orders[code] = it }
        }
        if (current.status != expected) return Change.Conflict(current)
        if (to !in allowedTargets(current.status)) return Change.Invalid(current.status)
        if (to == OrderStatus.Cancelled && reason == null) return Change.ReasonRequired
        return Change.Done(settle(current, to, reason, actorName).also { orders[code] = it })
    }

    private fun settle(order: OrderDetail, to: OrderStatus, reason: CancelReason?, actor: String) = order.copy(
        status = to,
        cancelReason = reason,
        allowedActions = actions(to),
        lastChange = LastChange(actor, "2026-11-02T04:00:00Z", "status"),
    )

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

        data class Invalid(val status: OrderStatus) : Change

        data object ReasonRequired : Change
    }
}

private fun allowedTargets(status: OrderStatus): List<OrderStatus> = when (status) {
    OrderStatus.Received -> listOf(OrderStatus.Processing, OrderStatus.Cancelled)
    OrderStatus.Processing -> listOf(OrderStatus.Finished, OrderStatus.Cancelled)
    else -> emptyList()
}

private fun actions(status: OrderStatus): List<OrderAction> = when (status) {
    OrderStatus.Received -> listOf(OrderAction.CANCEL, OrderAction.PROCESS)
    OrderStatus.Processing -> listOf(OrderAction.CANCEL, OrderAction.FINISH)
    else -> emptyList()
}
