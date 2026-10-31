package app.banh.customer.order

import app.banh.customer.data.catalog.Catalog
import app.banh.customer.data.catalog.District
import app.banh.customer.data.catalog.Product

/** One cake of the order with its quantity above 0 (AC-6). */
data class OrderLine(val product: Product, val quantity: Int) {
    /** Price times quantity in whole dong (BR-5). */
    val lineTotalVnd: Long get() = product.priceVnd * quantity
}

/**
 * The order as the review shows it: only active cakes with a quantity, the fee of the chosen district, and the total
 * (BR-5, AC-14). Prices are the ones in the catalog now, which is what the customer saw.
 */
data class OrderSummary(val lines: List<OrderLine>, val district: District?) {
    val totalQuantity: Int get() = lines.sumOf { it.quantity }

    val cakesSubtotalVnd: Long get() = lines.sumOf { it.lineTotalVnd }

    /** Zero until a district is chosen. There is no free-delivery case; the fee is the district's flat fee (BR-3). */
    val deliveryFeeVnd: Long get() = district?.deliveryFeeVnd ?: 0L

    val totalVnd: Long get() = cakesSubtotalVnd + deliveryFeeVnd

    companion object {
        fun of(draft: OrderDraft, catalog: Catalog): OrderSummary {
            val lines = catalog.products
                .map { OrderLine(it, draft.quantityOf(it.id)) }
                .filter { it.quantity > 0 }
            return OrderSummary(lines, catalog.districts.firstOrNull { it.id == draft.districtId })
        }
    }
}
