import BanhCore
import Foundation

/// Order statuses of the contract (api/09 10.13). An unknown word is kept, never a crash.
nonisolated enum OrderStatus: Codable, Equatable, Hashable, Sendable {
    case received, processing, deliveryDateScheduled, deliveryStarted, finished, cancelled
    case unknown(String)

    static let known: [OrderStatus] = [.received, .processing, .deliveryDateScheduled, .deliveryStarted, .finished, .cancelled]
    private static let legacyWords = ["New": "Received", "Confirmed": "Processing", "Completed": "Finished"]

    /// The wire word; for `.unknown` the raw text.
    var wireValue: String {
        switch self {
        case .received: "Received"
        case .processing: "Processing"
        case .deliveryDateScheduled: "DeliveryDateScheduled"
        case .deliveryStarted: "DeliveryStarted"
        case .finished: "Finished"
        case .cancelled: "Cancelled"
        case .unknown(let word): word
        }
    }

    init(word: String) {
        self = Self.known.first { $0.wireValue == word } ?? .unknown(word)
    }

    /// History rows written before the rename carry the old words; only they use this.
    init(historyWord word: String) {
        self.init(word: Self.legacyWords[word] ?? word)
    }

    init(from decoder: Decoder) throws {
        self.init(word: try decoder.singleValueContainer().decode(String.self))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(wireValue)
    }

    /// Only open orders can be due; an unknown status is not marked.
    var isOpen: Bool { [.received, .processing, .deliveryDateScheduled, .deliveryStarted].contains(self) }
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
    let expectedDeliveryDate: String?
    /// The date the server sorts and marks by (api/09 10.13.3).
    let listDate: String
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
