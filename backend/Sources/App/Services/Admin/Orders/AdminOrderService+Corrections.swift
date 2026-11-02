import Foundation
import BanhContracts

/// The two corrections of an order that is already past scheduling
/// (ADR-0033 decisions 2, 9, 10): move the expected date, correct the fee.
extension AdminOrderService {
    private func actor(_ principal: AdminPrincipal) -> OrderActor {
        OrderActor(type: principal.role.rawValue, id: principal.accountID, name: principal.displayName)
    }

    /// Range check first, skipped by a replay; then `EXPECTED_DATE_UNCHANGED`;
    /// then one compare-and-set on (status, previous date).
    func moveDate(code: String, body: [String: JSONValue], principal: AdminPrincipal) async throws -> StatusChangeResult {
        let scope = window(principal), range = range(scope), actor = actor(principal)
        let request = try DateMoveRequest.parse(body)
        let early = range.violation(of: request.new) ?? request.unchangedError
        return try await store.write { writer in
            guard let found = try await writer.queries.find(code: code, window: scope) else { throw APIError(.orderNotFound) }
            if early == nil, try await writer.changeDate(id: found.id, request: request, actor: actor) {
                return try await Self.current(found.id, range: range, writer: writer, replayed: false)
            }
            let current = try await Self.current(found.id, range: range, writer: writer, replayed: true)
            if current.order.process.expectedDeliveryDate == request.new.description,
               try await writer.lastDateChanger(id: found.id) == actor.id { return current }
            if let early { throw early }
            throw APIError(.orderStateChanged, details: ["order": try Self.json(current.order)])
        }
    }

    /// Range check, then `FEE_UNCHANGED` (both inside the parse and the
    /// early error), then one compare-and-set on (status, previous fee).
    func correctFee(code: String, body: [String: JSONValue], principal: AdminPrincipal) async throws -> StatusChangeResult {
        let scope = window(principal), range = range(scope), actor = actor(principal)
        let request = try FeeCorrectionRequest.parse(body)
        if let unchanged = request.unchangedError { throw unchanged }
        return try await store.write { writer in
            guard let found = try await writer.queries.find(code: code, window: scope) else { throw APIError(.orderNotFound) }
            if try await writer.correctFee(id: found.id, request: request, actor: actor) {
                return try await Self.current(found.id, range: range, writer: writer, replayed: false)
            }
            let current = try await Self.current(found.id, range: range, writer: writer, replayed: true)
            if current.order.summary.status == OrderStatus.deliveryStarted.rawValue,
               current.order.process.deliveryFeeFinalVND == request.new,
               try await writer.lastFeeChanger(id: found.id) == actor.id { return current }
            throw APIError(.orderStateChanged, details: ["order": try Self.json(current.order)])
        }
    }

    private static func current(_ id: UUID, range: ExpectedDateRange, writer: AdminOrderWriter, replayed: Bool) async throws -> StatusChangeResult {
        guard let order = try await writer.queries.detail(id: id, range: range) else { throw APIError(.orderNotFound) }
        return StatusChangeResult(order: order, replayed: replayed)
    }
}
