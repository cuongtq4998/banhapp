import Foundation
import FluentSQL

/// The one rule of which orders an account can see (BR-9, ADR-0029 v1.3):
/// open orders (New, Confirmed) of any age, finished orders for 90 days after
/// they were placed (exactly 90 days still shown). Used by the list, search,
/// badge, detail and status change, so the rule cannot drift between them.
/// Review accounts see only demo rows, real accounts never see them.
struct OrderWindow: Sendable {
    static let finishedDays = 90

    let shopID: UUID
    let now: Date
    let demoOnly: Bool

    var predicate: SQLQueryString {
        """
        shop_id = \(bind: shopID) AND is_demo = \(bind: demoOnly) \
        AND (status IN ('New', 'Confirmed') \
        OR created_at >= \(timestamp(now)) - interval '\(unsafeRaw: String(Self.finishedDays)) days')
        """
    }
}
