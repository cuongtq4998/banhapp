import Vapor

// Response bodies of api/06 10.9 and 10.10 (snake_case).

struct OrderSlot: Content, Equatable {
    let start: String
    let end: String
}

struct OrderSummary: Content, Equatable {
    let orderCode: String
    let status: String
    let customerName: String
    let deliveryDate: String
    let slot: OrderSlot
    let totalCakes: Int
    let totalVND: Int
    let districtName: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case orderCode = "order_code", status, customerName = "customer_name", deliveryDate = "delivery_date"
        case slot, totalCakes = "total_cakes", totalVND = "total_vnd", districtName = "district_name"
        case createdAt = "created_at"
    }
}

struct OrderListResponse: Content {
    let items: [OrderSummary]
    let nextCursor: String?
    let unfinishedCount: Int
    let serverDate: String

    enum CodingKeys: String, CodingKey {
        case items, nextCursor = "next_cursor", unfinishedCount = "unfinished_count", serverDate = "server_date"
    }

    // The cursor key is always present, null at the end.
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(items, forKey: .items)
        try container.encode(nextCursor, forKey: .nextCursor)
        try container.encode(unfinishedCount, forKey: .unfinishedCount)
        try container.encode(serverDate, forKey: .serverDate)
    }
}

struct OrderLine: Content, Equatable {
    let productName: String
    let quantity: Int
    let unitPriceVND: Int
    let lineTotalVND: Int

    enum CodingKeys: String, CodingKey {
        case productName = "product_name", quantity, unitPriceVND = "unit_price_vnd", lineTotalVND = "line_total_vnd"
    }
}

/// The single line "last changed by <name>, <time>" (FR-14). The name is null
/// when the customer placed the order and nobody changed it.
struct OrderLastChange: Content, Equatable {
    let actorName: String?
    let at: String

    enum CodingKeys: String, CodingKey { case actorName = "actor_name", at }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(actorName, forKey: .actorName)
        try container.encode(at, forKey: .at)
    }
}

struct OrderDetail: Content, Equatable {
    let summary: OrderSummary
    let customerPhone: String
    let customerAddress: String
    let note: String?
    let items: [OrderLine]
    let itemsSubtotalVND: Int
    let deliveryFeeVND: Int
    let cancelReason: String?
    let allowedActions: [String]
    let lastChange: OrderLastChange

    enum CodingKeys: String, CodingKey {
        case customerPhone = "customer_phone", customerAddress = "customer_address", note, items
        case itemsSubtotalVND = "items_subtotal_vnd", deliveryFeeVND = "delivery_fee_vnd"
        case cancelReason = "cancel_reason", allowedActions = "allowed_actions", lastChange = "last_change"
    }

    // Summary fields sit at the top level next to the detail fields.
    func encode(to encoder: any Encoder) throws {
        try summary.encode(to: encoder)
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(customerPhone, forKey: .customerPhone)
        try container.encode(customerAddress, forKey: .customerAddress)
        try container.encode(note, forKey: .note)
        try container.encode(items, forKey: .items)
        try container.encode(itemsSubtotalVND, forKey: .itemsSubtotalVND)
        try container.encode(deliveryFeeVND, forKey: .deliveryFeeVND)
        try container.encode(cancelReason, forKey: .cancelReason)
        try container.encode(allowedActions, forKey: .allowedActions)
        try container.encode(lastChange, forKey: .lastChange)
    }

    init(from decoder: any Decoder) throws {
        summary = try OrderSummary(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        customerPhone = try container.decode(String.self, forKey: .customerPhone)
        customerAddress = try container.decode(String.self, forKey: .customerAddress)
        note = try container.decodeIfPresent(String.self, forKey: .note)
        items = try container.decode([OrderLine].self, forKey: .items)
        itemsSubtotalVND = try container.decode(Int.self, forKey: .itemsSubtotalVND)
        deliveryFeeVND = try container.decode(Int.self, forKey: .deliveryFeeVND)
        cancelReason = try container.decodeIfPresent(String.self, forKey: .cancelReason)
        allowedActions = try container.decode([String].self, forKey: .allowedActions)
        lastChange = try container.decode(OrderLastChange.self, forKey: .lastChange)
    }

    init(
        summary: OrderSummary, customerPhone: String, customerAddress: String, note: String?, items: [OrderLine],
        itemsSubtotalVND: Int, deliveryFeeVND: Int, cancelReason: String?, allowedActions: [String], lastChange: OrderLastChange
    ) {
        self.summary = summary; self.customerPhone = customerPhone; self.customerAddress = customerAddress
        self.note = note; self.items = items; self.itemsSubtotalVND = itemsSubtotalVND
        self.deliveryFeeVND = deliveryFeeVND; self.cancelReason = cancelReason
        self.allowedActions = allowedActions; self.lastChange = lastChange
    }
}
