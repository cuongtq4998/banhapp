import Foundation

/// Body of the 201 answer (and of the 200 replay) of `POST /v1/orders`
/// (api.md 4.3). Nothing else is returned: no status, no payment fields (FR-19).
public struct OrderCreatedResponse: Codable, Equatable, Sendable {
    /// `BT-` plus 6 characters (ADR-0009).
    public let orderCode: String
    /// ISO 8601 UTC with `Z`, whole seconds.
    public let createdAt: String

    public init(orderCode: String, createdAt: String) {
        self.orderCode = orderCode
        self.createdAt = createdAt
    }

    private enum CodingKeys: String, CodingKey {
        case orderCode = "order_code"
        case createdAt = "created_at"
    }
}

/// `details` of the 409 `PRICE_CHANGED` error (api.md 4.3): the current
/// prices, so the app can refresh the review.
public struct PriceChangedDetails: Codable, Equatable, Sendable {
    public struct Item: Codable, Equatable, Sendable {
        public let productID: ResourceID
        public let priceVND: Int

        public init(productID: ResourceID, priceVND: Int) {
            self.productID = productID
            self.priceVND = priceVND
        }

        private enum CodingKeys: String, CodingKey {
            case productID = "product_id"
            case priceVND = "price_vnd"
        }
    }

    public let items: [Item]
    public let deliveryFeeVND: Int
    public let totalVND: Int

    public init(items: [Item], deliveryFeeVND: Int, totalVND: Int) {
        self.items = items
        self.deliveryFeeVND = deliveryFeeVND
        self.totalVND = totalVND
    }

    private enum CodingKeys: String, CodingKey {
        case items
        case deliveryFeeVND = "delivery_fee_vnd"
        case totalVND = "total_vnd"
    }
}
