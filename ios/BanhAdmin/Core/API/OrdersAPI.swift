import BanhContracts
import BanhCore
import Foundation

/// Filters of `GET /v1/admin/orders` (api/06 10.9). One status, one date, one search text.
nonisolated struct OrderQuery: Equatable, Sendable {
    enum StatusFilter: String, CaseIterable, Sendable {
        case todo, new = "New", confirmed = "Confirmed", completed = "Completed", cancelled = "Cancelled", all
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

nonisolated protocol OrdersAPI: Sendable {
    func orders(_ query: OrderQuery) async throws -> OrderPage
    func order(code: String) async throws -> OrderDetail
    func changeStatus(
        code: String, expected: OrderStatus, to target: OrderStatus, reason: CancelReason?
    ) async throws -> StatusChangeOutcome
}

nonisolated struct HTTPOrdersAPI: OrdersAPI {
    let client: APIClient
    let session: SessionManager

    func orders(_ query: OrderQuery) async throws -> OrderPage {
        try await session.authorized { token in
            try await client.decode(OrderPage.self, "GET", path: "/v1/admin/orders", query: query.items, headers: bearer(token))
        }
    }

    func order(code: String) async throws -> OrderDetail {
        try await session.authorized { token in
            try await client.decode(OrderDetail.self, "GET", path: "/v1/admin/orders/\(code)", headers: bearer(token))
        }
    }

    func changeStatus(
        code: String, expected: OrderStatus, to target: OrderStatus, reason: CancelReason?
    ) async throws -> StatusChangeOutcome {
        var body = ["expected_status": expected.rawValue, "to_status": target.rawValue]
        if let reason { body["cancel_reason"] = reason.rawValue }
        let data = try JSONEncoder().encode(body)
        do {
            return .changed(try await session.authorized { token in
                try await client.decode(OrderDetail.self, "POST", path: "/v1/admin/orders/\(code)/status", body: data, headers: bearer(token))
            })
        } catch let error as APIError {
            guard error.code == "ORDER_STATE_CHANGED", case .service(_, _, _, let details) = error,
                  let current = details["order"],
                  let detail = try? APIClient.decoder.decode(OrderDetail.self, from: JSONEncoder().encode(current))
            else { throw error }
            return .conflict(detail)
        }
    }

    private func bearer(_ token: String) -> [String: String] { ["Authorization": "Bearer \(token)"] }
}
