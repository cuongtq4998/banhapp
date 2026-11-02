import Foundation

/// The only mapping of one order to the lookup answer; a field not listed
/// here cannot leave the server (api/10 section 10.14.2).
struct LookupOrderView: Codable, Equatable, Sendable {
    struct Item: Codable, Equatable, Sendable {
        let cakeName: String
        let quantity: Int
        let unitPriceVnd: Int

        enum CodingKeys: String, CodingKey { case cakeName = "cake_name", quantity, unitPriceVnd = "unit_price_vnd" }
    }

    let orderCode: String
    let status: String
    let placedAt: Date
    let phoneMasked: String
    let districtName: String
    let requestedDeliveryDate: String
    let slotStartTime: String
    let slotEndTime: String
    let expectedDeliveryDate: String?
    let items: [Item]
    let itemsSubtotalVnd: Int
    let deliveryFeeEstimateVnd: Int
    let deliveryFeeFinalVnd: Int?
    let amountToCollectVnd: Int?

    enum CodingKeys: String, CodingKey {
        case orderCode = "order_code", status, placedAt = "placed_at", phoneMasked = "phone_masked"
        case districtName = "district_name", requestedDeliveryDate = "requested_delivery_date"
        case slotStartTime = "slot_start_time", slotEndTime = "slot_end_time"
        case expectedDeliveryDate = "expected_delivery_date", items
        case itemsSubtotalVnd = "items_subtotal_vnd", deliveryFeeEstimateVnd = "delivery_fee_estimate_vnd"
        case deliveryFeeFinalVnd = "delivery_fee_final_vnd", amountToCollectVnd = "amount_to_collect_vnd"
    }

    // Unknown values are sent as null, never omitted (stable key set).
    func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(orderCode, forKey: .orderCode)
        try c.encode(status, forKey: .status)
        try c.encode(placedAt, forKey: .placedAt)
        try c.encode(phoneMasked, forKey: .phoneMasked)
        try c.encode(districtName, forKey: .districtName)
        try c.encode(requestedDeliveryDate, forKey: .requestedDeliveryDate)
        try c.encode(slotStartTime, forKey: .slotStartTime)
        try c.encode(slotEndTime, forKey: .slotEndTime)
        try c.encode(expectedDeliveryDate, forKey: .expectedDeliveryDate)
        try c.encode(items, forKey: .items)
        try c.encode(itemsSubtotalVnd, forKey: .itemsSubtotalVnd)
        try c.encode(deliveryFeeEstimateVnd, forKey: .deliveryFeeEstimateVnd)
        try c.encode(deliveryFeeFinalVnd, forKey: .deliveryFeeFinalVnd)
        try c.encode(amountToCollectVnd, forKey: .amountToCollectVnd)
    }

    /// `+84900000001` becomes `+84 900 000 ***`: last 3 digits hidden, groups of 3.
    static func mask(phone: String) -> String {
        let digits = Array(phone.dropFirst(countryPrefix.count))
        let visible = digits.dropLast(hiddenDigits)
        let groups = stride(from: 0, to: visible.count, by: groupSize).map { String(visible[$0..<min($0 + groupSize, visible.count)]) }
        return ([countryPrefix] + groups + [String(repeating: "*", count: hiddenDigits)]).joined(separator: " ")
    }

    private static let countryPrefix = "+84"
    private static let hiddenDigits = 3
    private static let groupSize = 3
}

/// One page of the answer.
struct LookupAnswer: Codable, Equatable, Sendable {
    let orders: [LookupOrderView]
    let nextCursor: String?
    let asOf: Date

    enum CodingKeys: String, CodingKey { case orders, nextCursor = "next_cursor", asOf = "as_of" }

    // `next_cursor` must be present as null, not omitted.
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(orders, forKey: .orders)
        try container.encode(nextCursor, forKey: .nextCursor)
        try container.encode(asOf, forKey: .asOf)
    }
}
