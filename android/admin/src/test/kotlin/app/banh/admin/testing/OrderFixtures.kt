package app.banh.admin.testing

import app.banh.core.model.OrderDetail
import app.banh.core.network.ApiJson

/** Decodes the shared server fixtures (copied nowhere: read from the contracts folder). */
object OrderFixtures {
    fun detail(name: String): OrderDetail = ApiJson.decodeFromString(OrderDetail.serializer(), Fixtures.body(name))
}
