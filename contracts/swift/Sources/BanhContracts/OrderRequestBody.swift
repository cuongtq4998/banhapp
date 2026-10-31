import Foundation

/// Body of `POST /v1/orders` (api.md 4.3). Clients send quantities and the
/// total they showed; prices, fees and the order date are the server's.
public struct OrderRequestBody: Codable, Equatable, Sendable {
    public let items: [OrderItemRequest]
    /// `YYYY-MM-DD` in shop time.
    public let deliveryDate: String
    public let slotID: ResourceID
    public let customer: OrderCustomerRequest
    /// Written as an explicit `null` when absent, as in the api.md example.
    public let note: String?
    /// The total shown on the review; an acknowledgement only (ADR-0010).
    public let expectedTotalVND: Int

    public init(
        items: [OrderItemRequest], deliveryDate: String, slotID: ResourceID,
        customer: OrderCustomerRequest, note: String?, expectedTotalVND: Int
    ) {
        self.items = items
        self.deliveryDate = deliveryDate
        self.slotID = slotID
        self.customer = customer
        self.note = note
        self.expectedTotalVND = expectedTotalVND
    }

    private enum CodingKeys: String, CodingKey {
        case items
        case deliveryDate = "delivery_date"
        case slotID = "slot_id"
        case customer
        case note
        case expectedTotalVND = "expected_total_vnd"
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(items, forKey: .items)
        try container.encode(deliveryDate, forKey: .deliveryDate)
        try container.encode(slotID, forKey: .slotID)
        try container.encode(customer, forKey: .customer)
        try container.encode(note, forKey: .note)
        try container.encode(expectedTotalVND, forKey: .expectedTotalVND)
    }
}

public struct OrderItemRequest: Codable, Equatable, Sendable {
    public let productID: ResourceID
    public let quantity: Int

    public init(productID: ResourceID, quantity: Int) {
        self.productID = productID
        self.quantity = quantity
    }

    private enum CodingKeys: String, CodingKey {
        case productID = "product_id"
        case quantity
    }
}

public struct OrderCustomerRequest: Codable, Equatable, Sendable {
    public let name: String
    /// Any common writing of a Vietnamese mobile number; the server normalises it (ADR-0009).
    public let phone: String
    public let address: String
    public let districtID: ResourceID

    public init(name: String, phone: String, address: String, districtID: ResourceID) {
        self.name = name
        self.phone = phone
        self.address = address
        self.districtID = districtID
    }

    private enum CodingKeys: String, CodingKey {
        case name
        case phone
        case address
        case districtID = "district_id"
    }
}
