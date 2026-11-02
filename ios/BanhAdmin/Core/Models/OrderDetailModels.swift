import Foundation

/// The seven action names of `allowed_actions` (api/09 10.13.7). Other names decode as `.unknown`.
nonisolated enum OrderAction: String, Codable, Equatable, Sendable {
    case cancel, process
    case scheduleDelivery = "schedule_delivery"
    case startDelivery = "start_delivery"
    case finish
    case changeDate = "change_date"
    case correctFee = "correct_fee"
    case unknown

    init(from decoder: Decoder) throws {
        self = Self(rawValue: try decoder.singleValueContainer().decode(String.self)) ?? .unknown
    }
}

nonisolated struct LastChange: Codable, Equatable, Sendable {
    /// Nil when the customer placed the order and nobody changed it.
    let actorName: String?
    let at: String
    let kind: String?
}

nonisolated struct DateRange: Codable, Equatable, Sendable {
    let min: String
    let max: String
}

nonisolated struct FeeEntry: Codable, Equatable, Sendable {
    let enteredByName: String?
    let enteredAt: String
}

nonisolated struct DateChange: Codable, Equatable, Sendable {
    let oldDate: String
    let newDate: String
    let changedByName: String?
    let changedAt: String
}

nonisolated struct FeeCorrection: Codable, Equatable, Sendable {
    let oldFeeVnd: Int
    let newFeeVnd: Int
    let changedByName: String?
    let changedAt: String
}

/// `GET /v1/admin/orders/{code}` and the answer of every change (api/09 10.13.3).
nonisolated struct OrderDetail: Codable, Equatable, Sendable {
    let orderCode: String
    let status: OrderStatus
    let customerName: String
    let deliveryDate: String
    let requestedDeliveryDate: String?
    let expectedDeliveryDate: String?
    let listDate: String?
    let slot: DeliverySlot
    let totalCakes: Int
    let totalVnd: Int
    let districtName: String
    let createdAt: String
    let customerPhone: String
    let customerAddress: String
    let note: String?
    let items: [OrderItem]
    let itemsSubtotalVnd: Int
    let deliveryFeeVnd: Int
    let deliveryFeeEstimateVnd: Int?
    /// Null until delivery starts; the app shows a fee only from the server.
    let deliveryFeeFinalVnd: Int?
    /// Shown only when not null; the app never sums.
    let amountToCollectVnd: Int?
    let deliveryFeeEntry: FeeEntry?
    let cancelReason: String?
    let expectedDateRange: DateRange?
    let allowedActions: [OrderAction]
    let dateChanges: [DateChange]
    let feeCorrections: [FeeCorrection]
    let lastChange: LastChange

    /// Actions the server allows; unknown names never match a button.
    var actions: [OrderAction] { allowedActions.filter { $0 != .unknown } }
    func allows(_ action: OrderAction) -> Bool { allowedActions.contains(action) && action != .unknown }
}
