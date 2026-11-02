import Foundation

/// Body of the 200 answer of `POST /v1/orders/lookup` (api/10 section 10.14.1).
public struct OrderLookupResponse: Codable, Equatable, Sendable {
    /// One cake line as stored at order time.
    public struct Item: Codable, Equatable, Sendable {
        public let cakeName: String
        public let quantity: Int
        public let unitPriceVND: Int

        public init(cakeName: String, quantity: Int, unitPriceVND: Int) {
            self.cakeName = cakeName
            self.quantity = quantity
            self.unitPriceVND = unitPriceVND
        }

        private enum CodingKeys: String, CodingKey {
            case cakeName = "cake_name"
            case quantity
            case unitPriceVND = "unit_price_vnd"
        }
    }

    /// One order of the phone; the customer never sees more than this.
    public struct Order: Codable, Equatable, Sendable {
        public let orderCode: String
        /// One of the six status names.
        public let status: String
        public let placedAt: String
        public let phoneMasked: String
        public let districtName: String
        public let requestedDeliveryDate: String
        public let slotStartTime: String
        public let slotEndTime: String
        /// Null until staff set it.
        public let expectedDeliveryDate: String?
        public let items: [Item]
        public let itemsSubtotalVND: Int
        public let deliveryFeeEstimateVND: Int
        /// Null until the real fee is entered; 0 is a real fee.
        public let deliveryFeeFinalVND: Int?
        /// Null while the fee is unknown (never from the estimate).
        public let amountToCollectVND: Int?

        public init(
            orderCode: String, status: String, placedAt: String, phoneMasked: String, districtName: String,
            requestedDeliveryDate: String, slotStartTime: String, slotEndTime: String,
            expectedDeliveryDate: String?, items: [Item], itemsSubtotalVND: Int,
            deliveryFeeEstimateVND: Int, deliveryFeeFinalVND: Int?, amountToCollectVND: Int?
        ) {
            self.orderCode = orderCode
            self.status = status
            self.placedAt = placedAt
            self.phoneMasked = phoneMasked
            self.districtName = districtName
            self.requestedDeliveryDate = requestedDeliveryDate
            self.slotStartTime = slotStartTime
            self.slotEndTime = slotEndTime
            self.expectedDeliveryDate = expectedDeliveryDate
            self.items = items
            self.itemsSubtotalVND = itemsSubtotalVND
            self.deliveryFeeEstimateVND = deliveryFeeEstimateVND
            self.deliveryFeeFinalVND = deliveryFeeFinalVND
            self.amountToCollectVND = amountToCollectVND
        }

        private enum CodingKeys: String, CodingKey {
            case orderCode = "order_code"
            case status
            case placedAt = "placed_at"
            case phoneMasked = "phone_masked"
            case districtName = "district_name"
            case requestedDeliveryDate = "requested_delivery_date"
            case slotStartTime = "slot_start_time"
            case slotEndTime = "slot_end_time"
            case expectedDeliveryDate = "expected_delivery_date"
            case items
            case itemsSubtotalVND = "items_subtotal_vnd"
            case deliveryFeeEstimateVND = "delivery_fee_estimate_vnd"
            case deliveryFeeFinalVND = "delivery_fee_final_vnd"
            case amountToCollectVND = "amount_to_collect_vnd"
        }
    }

    public let orders: [Order]
    /// Null on the last page; opaque otherwise.
    public let nextCursor: String?
    /// Server time of the read; shown with a stored answer.
    public let asOf: String

    public init(orders: [Order], nextCursor: String?, asOf: String) {
        self.orders = orders
        self.nextCursor = nextCursor
        self.asOf = asOf
    }

    private enum CodingKeys: String, CodingKey {
        case orders
        case nextCursor = "next_cursor"
        case asOf = "as_of"
    }
}

/// Request body of `POST /v1/orders/lookup`.
public struct OrderLookupRequest: Codable, Equatable, Sendable {
    public let phone: String
    public let cursor: String?

    public init(phone: String, cursor: String? = nil) {
        self.phone = phone
        self.cursor = cursor
    }
}
