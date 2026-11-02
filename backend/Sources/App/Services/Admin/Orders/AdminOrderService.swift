import Foundation
import BanhContracts

/// What a status change answered.
struct StatusChangeResult: Sendable {
    let order: OrderDetail
    /// True when the repeat rule of ADR-0028 applied (no second write).
    let replayed: Bool
}

/// Reading and changing orders for owner and staff (FR-9 to FR-19). Every
/// lookup goes through `OrderWindow`.
struct AdminOrderService: Sendable {
    let store: AdminOrderStore
    let calendar: ShopCalendar
    let shopID: UUID

    func window(_ principal: AdminPrincipal) -> OrderWindow {
        OrderWindow(shopID: shopID, now: calendar.clock.now(), demoOnly: principal.isReview)
    }

    func list(_ query: OrderListQuery, principal: AdminPrincipal) async throws -> OrderListResponse {
        let window = window(principal), today = calendar.businessDate(of: window.now)
        let (rows, count) = try await store.read { queries in
            (try await queries.list(window: window, query: query), try await queries.unfinishedCount(window: window, today: today))
        }
        let page = rows.prefix(OrderListQuery.pageSize)
        let hasMore = rows.count > OrderListQuery.pageSize
        return OrderListResponse(
            items: page.map(\.summary), nextCursor: hasMore ? page.last?.cursor.token : nil,
            unfinishedCount: count, serverDate: today.description
        )
    }

    func range(_ window: OrderWindow) -> ExpectedDateRange {
        ExpectedDateRange(today: calendar.businessDate(of: window.now), calendar: calendar)
    }

    func detail(code: String, principal: AdminPrincipal) async throws -> OrderDetail {
        let window = window(principal), range = range(window)
        let found = try await store.read { queries -> OrderDetail? in
            guard let row = try await queries.find(code: code, window: window) else { return nil }
            return try await queries.detail(id: row.id, range: range)
        }
        guard let found else { throw APIError(.orderNotFound) }
        return found
    }

    /// ADR-0028: window lookup, field checks, then one conditional UPDATE. Zero
    /// rows is a replay (same account, same move already made, same date or fee)
    /// or a 409 with the current detail. Nothing is written for any outcome but
    /// a real change. An order outside the window is 404, except for the exact
    /// repeat of the change that closed it (FR-19): that answers the replay.
    /// The date range is checked after the field checks and skipped by a replay.
    func changeStatus(code: String, body: [String: JSONValue], principal: AdminPrincipal) async throws -> StatusChangeResult {
        let window = window(principal), range = range(window)
        let actor = OrderActor(type: principal.role.rawValue, id: principal.accountID, name: principal.displayName)
        return try await store.write { writer in
            guard let found = try await writer.queries.find(code: code, window: window) else {
                guard let request = try? StatusRequest.parse(body), let hidden = try await writer.queries.findIgnoringAge(code: code, window: window),
                      let current = try await writer.queries.detail(id: hidden.id, range: range),
                      try await Self.isRepeat(request, of: current, actor: actor, writer: writer, id: hidden.id)
                else { throw APIError(.orderNotFound) }
                return StatusChangeResult(order: current, replayed: true)
            }
            let request = try StatusRequest.parse(body)
            let rangeError = request.expectedDate.flatMap { range.violation(of: $0) }
            let moved = try await rangeError == nil ? writer.move(id: found.id, request: request, actor: actor) : false
            guard let current = try await writer.queries.detail(id: found.id, range: range) else { throw APIError(.orderNotFound) }
            if moved { return StatusChangeResult(order: current, replayed: false) }
            if try await Self.isRepeat(request, of: current, actor: actor, writer: writer, id: found.id) {
                return StatusChangeResult(order: current, replayed: true)
            }
            if let rangeError { throw rangeError }
            throw APIError(.orderStateChanged, details: ["order": try Self.json(current)])
        }
    }

    /// The order already holds the target, its last change is this account's
    /// move from the same expected status, and the stored date or fee is the
    /// one in the body.
    private static func isRepeat(_ request: StatusRequest, of current: OrderDetail, actor: OrderActor,
                                 writer: AdminOrderWriter, id: UUID) async throws -> Bool {
        guard current.summary.status == request.target.rawValue, try holdsSameValues(request, current),
              let last = try await writer.queries.lastEvent(id: id) else { return false }
        return last.actorID == actor.id && last.from == request.expected
    }

    private static func holdsSameValues(_ request: StatusRequest, _ current: OrderDetail) throws -> Bool {
        if let date = request.expectedDate { return current.process.expectedDeliveryDate == date.description }
        if let fee = request.feeVND { return current.process.deliveryFeeFinalVND == fee }
        return true
    }

    static func json(_ detail: OrderDetail) throws -> JSONValue {
        try JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(detail))
    }
}
