package app.banh.admin.orders

import app.banh.admin.auth.SessionManager
import app.banh.admin.auth.bearer
import app.banh.core.model.CancelReason
import app.banh.core.model.OrderDetail
import app.banh.core.model.OrderStatus
import app.banh.core.model.OrdersPage
import app.banh.core.model.StatusChangeRequest
import app.banh.core.network.ApiClient
import app.banh.core.network.ApiException
import app.banh.core.network.ErrorCodes

private const val CONFLICT = 409

/** Order endpoints (api/06 10.9 to 10.11); every call goes through [SessionManager.authorized]. */
class HttpOrdersApi(private val client: ApiClient, private val session: SessionManager) : OrdersApi {
    override suspend fun list(query: OrdersQuery, cursor: String?): OrdersPage =
        session.authorized { client.get("v1/admin/orders", OrdersPage.serializer(), query.toParameters(cursor), bearer(it)) }

    override suspend fun detail(orderCode: String): OrderDetail =
        session.authorized { client.get("v1/admin/orders/$orderCode", OrderDetail.serializer(), headers = bearer(it)) }

    override suspend fun changeStatus(orderCode: String, expected: OrderStatus, to: OrderStatus, reason: CancelReason?): StatusChange {
        val body = StatusChangeRequest(expected, to, reason)
        return try {
            StatusChange.Changed(
                session.authorized {
                    client.post("v1/admin/orders/$orderCode/status", body, StatusChangeRequest.serializer(), OrderDetail.serializer(), bearer(it))
                },
            )
        } catch (e: ApiException.Http) {
            if (e.status == CONFLICT && e.code == ErrorCodes.ORDER_STATE_CHANGED) StatusChange.Conflict(currentOrderOf(e, client)) else throw e
        }
    }
}

// `details.order` is the current detail of the order (api/06 10.11); a 409 without it is treated as a contract mismatch.
private fun currentOrderOf(error: ApiException.Http, client: ApiClient): OrderDetail {
    val order = error.details?.get("order") ?: throw ApiException.InvalidResponse()
    return try {
        client.json.decodeFromJsonElement(OrderDetail.serializer(), order)
    } catch (e: IllegalArgumentException) {
        throw ApiException.InvalidResponse(e)
    }
}

internal fun OrdersQuery.toParameters(cursor: String?): List<Pair<String, String>> = buildList {
    add("status" to status.wire)
    when (date) {
        DateFilter.Any -> Unit
        DateFilter.Today -> add("date_preset" to "today")
        DateFilter.Tomorrow -> add("date_preset" to "tomorrow")
        is DateFilter.One -> add("delivery_date" to date.date.toString())
    }
    if (text.isNotEmpty()) add("q" to text)
    if (cursor != null) add("cursor" to cursor)
}
