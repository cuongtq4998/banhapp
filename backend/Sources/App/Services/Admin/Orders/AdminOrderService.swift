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

    private func window(_ principal: AdminPrincipal) -> OrderWindow {
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

    func detail(code: String, principal: AdminPrincipal) async throws -> OrderDetail {
        let window = window(principal)
        let found = try await store.read { queries -> OrderDetail? in
            guard let row = try await queries.find(code: code, window: window) else { return nil }
            return try await queries.detail(id: row.id)
        }
        guard let found else { throw APIError(.orderNotFound) }
        return found
    }

    /// ADR-0028: window lookup, field checks, then one conditional UPDATE. Zero
    /// rows is a replay (same account, same move already made) or a 409 with the
    /// current detail. Nothing is written for any outcome but a real change.
    func changeStatus(code: String, body: [String: JSONValue], principal: AdminPrincipal) async throws -> StatusChangeResult {
        let window = window(principal)
        let actor = OrderActor(type: principal.role.rawValue, id: principal.accountID, name: principal.displayName)
        return try await store.write { writer in
            guard let found = try await writer.queries.find(code: code, window: window) else { throw APIError(.orderNotFound) }
            let request = try StatusRequest.parse(body)
            let moved = try await writer.move(id: found.id, from: request.expected, to: request.target, reason: request.reason, actor: actor)
            guard let current = try await writer.queries.detail(id: found.id) else { throw APIError(.orderNotFound) }
            if moved { return StatusChangeResult(order: current, replayed: false) }
            if current.summary.status == request.target.rawValue,
               let last = try await writer.queries.lastEvent(id: found.id),
               last.actorID == actor.id, last.fromStatus == request.expected.rawValue {
                return StatusChangeResult(order: current, replayed: true)
            }
            throw APIError(.orderStateChanged, details: ["order": try Self.json(current)])
        }
    }

    private static func json(_ detail: OrderDetail) throws -> JSONValue {
        try JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(detail))
    }
}
