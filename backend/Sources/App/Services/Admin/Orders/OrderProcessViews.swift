import Vapor

/// The order window of api/09 10.13.3.
struct DateRangeView: Content, Equatable {
    let min: String
    let max: String
}

/// One `order_expected_date_change` row; the first entry has no old date.
struct DateChangeView: Content, Equatable {
    let oldDate: String?
    let newDate: String
    let changedByName: String
    let changedAt: String

    enum CodingKeys: String, CodingKey {
        case oldDate = "old_date", newDate = "new_date", changedByName = "changed_by_name", changedAt = "changed_at"
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(oldDate, forKey: .oldDate)
        try container.encode(newDate, forKey: .newDate)
        try container.encode(changedByName, forKey: .changedByName)
        try container.encode(changedAt, forKey: .changedAt)
    }
}

/// One `order_fee_correction` row.
struct FeeCorrectionView: Content, Equatable {
    let oldFeeVND: Int
    let newFeeVND: Int
    let changedByName: String
    let changedAt: String

    enum CodingKeys: String, CodingKey {
        case oldFeeVND = "old_fee_vnd", newFeeVND = "new_fee_vnd", changedByName = "changed_by_name", changedAt = "changed_at"
    }
}

/// The detail fields added by the order process (api/09 10.13.3), written
/// flat next to the other detail fields.
struct OrderProcessFields: Content, Equatable {
    let requestedDeliveryDate: String
    let expectedDeliveryDate: String?
    let deliveryFeeEstimateVND: Int
    let deliveryFeeFinalVND: Int?
    let amountToCollectVND: Int?
    let expectedDateRange: DateRangeView
    let dateChanges: [DateChangeView]
    let feeCorrections: [FeeCorrectionView]

    enum CodingKeys: String, CodingKey {
        case requestedDeliveryDate = "requested_delivery_date", expectedDeliveryDate = "expected_delivery_date"
        case deliveryFeeEstimateVND = "delivery_fee_estimate_vnd", deliveryFeeFinalVND = "delivery_fee_final_vnd"
        case amountToCollectVND = "amount_to_collect_vnd", expectedDateRange = "expected_date_range"
        case dateChanges = "date_changes", feeCorrections = "fee_corrections"
    }

    // Null keys stay present: clients read them as "not entered yet".
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(requestedDeliveryDate, forKey: .requestedDeliveryDate)
        try container.encode(expectedDeliveryDate, forKey: .expectedDeliveryDate)
        try container.encode(deliveryFeeEstimateVND, forKey: .deliveryFeeEstimateVND)
        try container.encode(deliveryFeeFinalVND, forKey: .deliveryFeeFinalVND)
        try container.encode(amountToCollectVND, forKey: .amountToCollectVND)
        try container.encode(expectedDateRange, forKey: .expectedDateRange)
        try container.encode(dateChanges, forKey: .dateChanges)
        try container.encode(feeCorrections, forKey: .feeCorrections)
    }
}
