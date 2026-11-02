import Foundation
import FluentSQL

/// The one rule of which orders an account can see (BR-9, ADR-0029, ADR-0033):
/// open orders of any age, final orders for 90 days after they were placed
/// (exactly 90 days still shown). Used by the list, search, badge, detail
/// and status change, so the rule cannot drift between them.
/// Review accounts see only demo rows, real accounts never see them.
struct OrderWindow: Sendable {
    static let finalDays = 90

    let shopID: UUID
    let now: Date
    let demoOnly: Bool

    var predicate: SQLQueryString {
        """
        shop_id = \(bind: shopID) AND is_demo = \(bind: demoOnly) \
        AND (status IN (\(unsafeRaw: OrderStatus.sqlList(OrderStatus.open))) \
        OR created_at >= \(timestamp(now)) - interval '\(unsafeRaw: String(Self.finalDays)) days')
        """
    }

    /// Same rule in Swift, for rows already loaded.
    func shows(status: OrderStatus, placedAt: Date) -> Bool {
        if status.isOpen { return true }
        let oldest = now.addingTimeInterval(-Double(Self.finalDays) * 86_400)
        return placedAt >= oldest
    }
}

/// The date an order is listed and sorted by (order-process.md section 4).
enum OrderListDate {
    /// SQL expression: expected date when set, else the requested date.
    static let sql = "COALESCE(expected_delivery_date, delivery_date)"

    /// The same choice in Swift.
    static func value<D>(expected: D?, requested: D) -> D { expected ?? requested }
}
