import BanhCore
import Foundation

/// Order statuses of the contract (api/06 10.9). The raw values are the wire values.
nonisolated enum OrderStatus: String, Codable, Equatable, Sendable, CaseIterable {
    case new = "New"
    case confirmed = "Confirmed"
    case completed = "Completed"
    case cancelled = "Cancelled"

    /// New and Confirmed orders still have to be handled; only they can be due.
    var isOpen: Bool { self == .new || self == .confirmed }
}

nonisolated struct DeliverySlot: Codable, Equatable, Sendable {
    let start: String
    let end: String

    var text: String { "\(start)-\(end)" }
}

/// One row of `GET /v1/admin/orders`.
nonisolated struct OrderSummary: Codable, Equatable, Sendable, Identifiable {
    let orderCode: String
    let status: OrderStatus
    let customerName: String
    let deliveryDate: String
    let slot: DeliverySlot
    let totalCakes: Int
    let totalVnd: Int
    let districtName: String
    let createdAt: String

    var id: String { orderCode }
}

nonisolated struct OrderItem: Codable, Equatable, Sendable {
    let productName: String
    let quantity: Int
    let unitPriceVnd: Int
    let lineTotalVnd: Int
}

nonisolated struct LastChange: Codable, Equatable, Sendable {
    /// Nil when the customer placed the order and nobody changed it.
    let actorName: String?
    let at: String
}

/// `GET /v1/admin/orders/{code}` and the answer of a status change.
nonisolated struct OrderDetail: Codable, Equatable, Sendable {
    let orderCode: String
    let status: OrderStatus
    let customerName: String
    let deliveryDate: String
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
    let cancelReason: String?
    let allowedActions: [String]
    let lastChange: LastChange
}

nonisolated struct OrderPage: Codable, Equatable, Sendable {
    let items: [OrderSummary]
    let nextCursor: String?
    let unfinishedCount: Int
    let serverDate: String
}

/// The four reasons of S-A5, in the order shown. The raw values are the wire values.
nonisolated enum CancelReason: String, CaseIterable, Sendable {
    case customerAsked = "customer_asked"
    case cannotDeliver = "cannot_deliver"
    case cannotReachCustomer = "cannot_reach_customer"
    case fakeSpam = "fake_spam"
}

/// What a status request led to: the order after the change, or the current order when somebody else
/// changed it first (409 `ORDER_STATE_CHANGED`, FR-19).
nonisolated enum StatusChangeOutcome: Equatable, Sendable {
    case changed(OrderDetail)
    case conflict(OrderDetail)
}

/// Delivery-date marks of a row: computed from the server date of the same response (FR-9).
nonisolated enum DueState: Equatable, Sendable {
    case today
    case overdue(days: Int)

    static func of(status: OrderStatus, deliveryDate: String, serverDate: String) -> DueState? {
        guard status.isOpen, let delivery = ShopDay(deliveryDate), let server = ShopDay(serverDate) else { return nil }
        let late = server.days(since: delivery)
        if late == 0 { return .today }
        return late > 0 ? .overdue(days: late) : nil
    }
}
