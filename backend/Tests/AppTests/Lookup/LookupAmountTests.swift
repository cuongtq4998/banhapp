import XCTVapor
@testable import App

/// amount_to_collect_vnd follows the final fee only (api/10).
final class LookupAmountTests: LookupRouteTestCase {
    private func amount(for row: LookupRow) async throws -> Any? {
        store.plant(normalised, [row])
        var found: Any?
        try await lookup(#"{"phone":"\#(phone)"}"#) { res in
            let object = try JSONSerialization.jsonObject(with: Data(res.body.readableBytesView)) as? [String: Any]
            let order = (object?["orders"] as? [[String: Any]])?.first
            found = order?["amount_to_collect_vnd"]
        }
        return found
    }

    private func row(final: Int?) -> LookupRow {
        let base = LookupRow.sample(1)
        return LookupRow(
            id: base.id, order_code: base.order_code, status: base.status, created_at: base.created_at,
            district_name: base.district_name, requested: base.requested, slot_start: base.slot_start, slot_end: base.slot_end,
            expected: base.expected, items_subtotal_vnd: base.items_subtotal_vnd, delivery_fee_vnd: base.delivery_fee_vnd,
            delivery_fee_final_vnd: final, items: base.items)
    }

    func testFinalFeeZeroGivesTheSubtotal() async throws {
        try await start()
        let value = try await amount(for: row(final: 0)) as? Int
        XCTAssertEqual(value, 240_000)
    }

    func testRealFinalFeeIsAdded() async throws {
        try await start()
        let value = try await amount(for: row(final: 30_000)) as? Int
        XCTAssertEqual(value, 270_000)
    }

    func testNullFinalFeeNeverUsesTheEstimate() async throws {
        try await start()
        let value = try await amount(for: row(final: nil))
        XCTAssertTrue(value is NSNull, "estimate 20000 must not become the amount")
    }
}
