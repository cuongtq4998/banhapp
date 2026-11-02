import Foundation

/// Columns of one list row, with the keys of its cursor.
struct OrderSummaryRow: Decodable, Sendable {
    let id: UUID
    let orderCode: String
    let status: String
    let customerName: String
    let deliveryDate: String
    let slotStart: String
    let slotEnd: String
    let totalCakes: Int
    let totalVND: Int
    let districtName: String
    let createdAt: String
    let cursorTime: String
    let cursorCreated: String

    private enum CodingKeys: String, CodingKey {
        case id, status, orderCode = "order_code", customerName = "customer_name", deliveryDate = "delivery_date"
        case slotStart = "slot_start", slotEnd = "slot_end", totalCakes = "total_cakes", totalVND = "total_vnd"
        case districtName = "district_name", createdAt = "created_at"
        case cursorTime = "cursor_time", cursorCreated = "cursor_created"
    }

    var summary: OrderSummary {
        OrderSummary(
            orderCode: orderCode, status: status, customerName: customerName, deliveryDate: deliveryDate,
            slot: OrderSlot(start: slotStart, end: slotEnd), totalCakes: totalCakes, totalVND: totalVND,
            districtName: districtName, createdAt: createdAt
        )
    }

    var cursor: OrderCursor {
        OrderCursor(deliveryDate: deliveryDate, slotStart: cursorTime, createdAt: cursorCreated, id: id.uuidString.lowercased())
    }
}

/// Detail-only columns, read with the summary columns.
struct OrderDetailRow: Decodable, Sendable {
    let customerPhone: String
    let customerAddress: String
    let note: String?
    let itemsSubtotalVND: Int
    let deliveryFeeVND: Int
    let cancelReason: String?
    let expectedDeliveryDate: String?
    let deliveryFeeFinalVND: Int?

    private enum CodingKeys: String, CodingKey {
        case note, expectedDeliveryDate = "expected_delivery_date", deliveryFeeFinalVND = "delivery_fee_final_vnd", customerPhone = "customer_phone", customerAddress = "customer_address"
        case itemsSubtotalVND = "items_subtotal_vnd", deliveryFeeVND = "delivery_fee_vnd", cancelReason = "cancel_reason"
    }
}

struct OrderLineRow: Decodable, Sendable {
    let productName: String
    let quantity: Int
    let unitPriceVND: Int
    let lineTotalVND: Int

    private enum CodingKeys: String, CodingKey {
        case quantity, productName = "product_name", unitPriceVND = "unit_price_vnd", lineTotalVND = "line_total_vnd"
    }
}

/// The newest `order_event` of an order.
struct OrderEventRow: Decodable, Sendable {
    let actorID: UUID?
    let actorName: String?
    let fromStatus: String?
    let at: String

    /// The from step with legacy words mapped (events are never rewritten).
    var from: OrderStatus? { fromStatus.flatMap(OrderStatus.fromStored) }

    private enum CodingKeys: String, CodingKey {
        case at, actorID = "actor_id", actorName = "actor_name", fromStatus = "from_status"
    }
}

struct OrderFoundRow: Decodable, Sendable {
    let id: UUID
    let status: String
}

struct CountResult: Decodable, Sendable { let total: Int }
