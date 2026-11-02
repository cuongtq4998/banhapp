import BanhContracts
import BanhCore
import Foundation

/// Filters of `GET /v1/admin/orders` (api/06 10.9). One status, one date, one search text.
nonisolated struct OrderQuery: Equatable, Sendable {
    enum StatusFilter: String, CaseIterable, Sendable {
        case todo, received = "Received", processing = "Processing", scheduled = "DeliveryDateScheduled"
        case started = "DeliveryStarted", finished = "Finished", cancelled = "Cancelled", all
    }

    enum DateFilter: Equatable, Sendable {
        case any, today, tomorrow
        case day(String)
    }

    var status: StatusFilter = .todo
    var date: DateFilter = .any
    /// Already trimmed; empty or shorter than 3 means no search (BR-10).
    var search = ""
    var cursor: String?

    static let minSearchLength = 3

    var items: [URLQueryItem] {
        var items = [URLQueryItem(name: "status", value: status.rawValue)]
        switch date {
        case .any: break
        case .today: items.append(URLQueryItem(name: "date_preset", value: "today"))
        case .tomorrow: items.append(URLQueryItem(name: "date_preset", value: "tomorrow"))
        case .day(let day): items.append(URLQueryItem(name: "delivery_date", value: day))
        }
        if search.count >= Self.minSearchLength { items.append(URLQueryItem(name: "q", value: search)) }
        if let cursor { items.append(URLQueryItem(name: "cursor", value: cursor)) }
        return items
    }
}

/// One status request; the extras depend on the target (api/09 10.13.1).
nonisolated struct StatusRequest: Equatable, Sendable {
    let expected: OrderStatus
    let target: OrderStatus
    var reason: CancelReason?
    var expectedDeliveryDate: String?
    var deliveryFeeVnd: Int?
}

nonisolated protocol OrdersAPI: Sendable {
    func orders(_ query: OrderQuery) async throws -> OrderPage
    func order(code: String) async throws -> OrderDetail
    func changeStatus(code: String, _ request: StatusRequest) async throws -> StatusChangeOutcome
    func changeExpectedDate(code: String, previous: String, to date: String) async throws -> StatusChangeOutcome
    func correctFee(code: String, previous: Int, to fee: Int) async throws -> StatusChangeOutcome
}
