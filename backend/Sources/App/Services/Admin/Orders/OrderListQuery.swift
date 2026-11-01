import Foundation
import BanhContracts

/// The validated query of `GET /v1/admin/orders` (api/06 10.9): one status,
/// one delivery date, a search text and a cursor. Page size is fixed.
struct OrderListQuery: Sendable, Equatable {
    static let pageSize = 50
    private static let allowedKeys: Set<String> = ["status", "date_preset", "delivery_date", "q", "cursor"]

    enum StatusFilter: String, Sendable {
        case todo, all
        case new = "New", confirmed = "Confirmed", completed = "Completed", cancelled = "Cancelled"

        /// Statuses to match; nil means every status.
        var statuses: [OrderStatus]? {
            switch self {
            case .todo: return [.new, .confirmed]
            case .all: return nil
            case .new: return [.new]
            case .confirmed: return [.confirmed]
            case .completed: return [.completed]
            case .cancelled: return [.cancelled]
            }
        }
    }

    var status: StatusFilter = .todo
    var deliveryDate: BusinessDate?
    var search: OrderSearch?
    var cursor: OrderCursor?

    /// `pairs` are the decoded query items in request order; repeated and
    /// unknown names are refused, as is a preset together with a date.
    static func parse(_ pairs: [(String, String)], calendar: ShopCalendar) throws -> OrderListQuery {
        var values: [String: String] = [:]
        var problems: [APIErrorResponse.FieldError] = []
        func fail(_ field: String, _ code: String) {
            problems.append(.init(field: field, code: code, messageKey: APIErrorCode.genericMessageKey))
        }
        for (name, value) in pairs {
            if !allowedKeys.contains(name) { fail(name, "UNKNOWN_PARAMETER") }
            else if values[name] != nil { fail(name, "REPEATED_PARAMETER") }
            else { values[name] = value }
        }
        var query = OrderListQuery()
        if let text = values["status"] {
            if let filter = StatusFilter(rawValue: text) { query.status = filter } else { fail("status", "STATUS_INVALID") }
        }
        if values["date_preset"] != nil, values["delivery_date"] != nil { fail("delivery_date", "DATE_FILTER_CONFLICT") }
        if let preset = values["date_preset"] {
            switch preset {
            case "today": query.deliveryDate = calendar.today()
            case "tomorrow": query.deliveryDate = calendar.adding(days: 1, to: calendar.today())
            default: fail("date_preset", "DATE_PRESET_INVALID")
            }
        }
        if let text = values["delivery_date"] {
            // The round trip rejects 2026-02-31, which PostgreSQL would answer with an error.
            if let date = BusinessDate(isoString: text), calendar.adding(days: 0, to: date) == date {
                query.deliveryDate = date
            } else { fail("delivery_date", "DATE_INVALID") }
        }
        if let text = values["q"] {
            if let search = OrderSearch(text) { query.search = search } else { fail("q", "SEARCH_INVALID") }
        }
        if let token = values["cursor"] {
            if let cursor = OrderCursor(token: token) { query.cursor = cursor } else { fail("cursor", "CURSOR_INVALID") }
        }
        if !problems.isEmpty { throw APIError(.validationFailed, fields: problems) }
        return query
    }

    /// Decodes a raw query string the way form decoding does ("+" is a space).
    static func pairs(of rawQuery: String?) -> [(String, String)] {
        guard let rawQuery, !rawQuery.isEmpty else { return [] }
        return rawQuery.split(separator: "&", omittingEmptySubsequences: true).map { item in
            let parts = item.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            func decode(_ text: Substring) -> String {
                let spaced = text.replacingOccurrences(of: "+", with: " ")
                return spaced.removingPercentEncoding ?? spaced
            }
            return (decode(parts[0]), parts.count > 1 ? decode(parts[1]) : "")
        }
    }
}
