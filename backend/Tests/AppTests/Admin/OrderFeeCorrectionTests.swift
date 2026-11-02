import XCTVapor
@testable import App

/// `PUT /v1/admin/orders/{code}/delivery-fee`.
final class OrderFeeCorrectionTests: OrderCorrectionTestCase {
    private let path = "delivery-fee", table = "order_fee_correction"

    private func started(_ status: String = "DeliveryStarted") async throws -> String {
        try await place(.init(status: status, expectedDate: day(2), finalFee: 25_000))
    }

    private func correct(_ phone: Phone?, _ orderCode: String, _ body: String) async throws -> Reply {
        try await Self.put(app, phone, orderCode, path, body)
    }

    private func currentOrder(_ reply: Reply) -> [String: Any]? {
        (reply.json["error"] as? [String: Any]).flatMap { ($0["details"] as? [String: Any])?["order"] as? [String: Any] }
    }

    func testBothRolesCorrectTheFeeAndTheDetailFollows() async throws {
        for role in [AccountRole.owner, .staff] {
            let who = try await phone(role, "Nhan Vien \(role.rawValue)"), orderCode = try await started()
            let reply = try await correct(who, orderCode, feeBody(previous: "25000", new: "30000"))
            XCTAssertEqual(reply.status, .ok)
            XCTAssertEqual(reply.json["delivery_fee_final_vnd"] as? Int, 30_000)
            XCTAssertEqual(reply.json["amount_to_collect_vnd"] as? Int, 100_000 + 30_000)
            let fixes = reply.json["fee_corrections"] as? [[String: Any]]
            XCTAssertEqual(fixes?.last?["old_fee_vnd"] as? Int, 25_000)
            XCTAssertEqual(fixes?.last?["changed_by_name"] as? String, "Nhan Vien \(role.rawValue)")
            let rows = try await records(table, orderCode)
            XCTAssertEqual(rows, 1)
        }
    }

    func testNoSessionIsRefused() async throws {
        let orderCode = try await started()
        let reply = try await correct(nil, orderCode, feeBody(previous: "25000", new: "30000"))
        XCTAssertEqual(reply.status, .unauthorized)
    }

    func testFeeBoundaries() async throws {
        let staff = try await phone(.staff)
        for (fee, ok) in [("0", true), ("10000000", true), ("10000001", false), ("-1", false), ("1.5", false), ("\"30000\"", false), ("null", false)] {
            let orderCode = try await started()
            let reply = try await correct(staff, orderCode, feeBody(previous: "25000", new: fee))
            let rows = try await records(table, orderCode)
            if ok { XCTAssertEqual(reply.status, .ok, fee) } else {
                XCTAssertEqual(reply.status, .unprocessableEntity, fee)
                XCTAssertEqual(fieldCode(reply), fee == "null" ? "FEE_REQUIRED" : "FEE_INVALID", fee)
                XCTAssertEqual(rows, 0)
            }
        }
    }

    func testMissingFieldsAndWrongStatusAndUnchangedWriteNothing() async throws {
        let staff = try await phone(.staff), orderCode = try await started()
        let noFee = try await correct(staff, orderCode, "{\"expected_status\":\"DeliveryStarted\",\"previous_delivery_fee_vnd\":25000}")
        XCTAssertEqual(fieldCode(noFee), "FEE_REQUIRED")
        let noPrevious = try await correct(staff, orderCode, "{\"expected_status\":\"DeliveryStarted\",\"delivery_fee_vnd\":30000}")
        XCTAssertEqual(fieldCode(noPrevious), "PREVIOUS_FEE_REQUIRED")
        let wrong = try await correct(staff, orderCode, feeBody(previous: "25000", new: "30000", status: "Finished"))
        XCTAssertEqual(wrong.errorCode, "FEE_CORRECTION_NOT_ALLOWED")
        let same = try await correct(staff, orderCode, feeBody(previous: "25000", new: "25000"))
        XCTAssertEqual(fieldCode(same), "FEE_UNCHANGED")
        let rows = try await records(table, orderCode)
        XCTAssertEqual(rows, 0)
    }

    func testFinishedAndCancelledAndEarlierStatusesAreConflictsWithTheCurrentOrder() async throws {
        let staff = try await phone(.staff)
        for status in ["Finished", "Cancelled", "DeliveryDateScheduled"] {
            let orderCode = status == "Finished" ? try await started("Finished")
                : try await place(.init(status: status, reason: status == "Cancelled" ? "fake_spam" : nil, expectedDate: status == "Cancelled" ? nil : day(2)))
            let reply = try await correct(staff, orderCode, feeBody(previous: "25000", new: "30000"))
            XCTAssertEqual(reply.errorCode, "ORDER_STATE_CHANGED", status)
            XCTAssertEqual(currentOrder(reply)?["status"] as? String, status)
            let rows = try await records(table, orderCode)
            XCTAssertEqual(rows, 0)
        }
    }

    func testStalePreviousFeeIsAConflictWithTheCurrentFee() async throws {
        let staff = try await phone(.staff), orderCode = try await started()
        let reply = try await correct(staff, orderCode, feeBody(previous: "20000", new: "30000"))
        XCTAssertEqual(reply.errorCode, "ORDER_STATE_CHANGED")
        XCTAssertEqual(currentOrder(reply)?["delivery_fee_final_vnd"] as? Int, 25_000)
    }

    func testReplayBySameAccountOnlyAndWithoutASecondRow() async throws {
        let a = try await phone(.staff, "A"), b = try await phone(.staff, "B"), orderCode = try await started()
        _ = try await correct(a, orderCode, feeBody(previous: "25000", new: "30000"))
        let again = try await correct(a, orderCode, feeBody(previous: "25000", new: "30000"))
        XCTAssertEqual(again.status, .ok)
        XCTAssertEqual(again.headers.first(name: "Idempotent-Replay"), "true")
        let other = try await correct(b, orderCode, feeBody(previous: "25000", new: "30000"))
        XCTAssertEqual(other.errorCode, "ORDER_STATE_CHANGED")
        let rows = try await records(table, orderCode)
        XCTAssertEqual(rows, 1)
    }

    func testTwoDevicesAtOnceHaveOneWinner() async throws {
        let a = try await phone(.staff, "A"), b = try await phone(.staff, "B"), orderCode = try await started()
        let app = try XCTUnwrap(self.app), first = feeBody(previous: "25000", new: "30000"), second = feeBody(previous: "25000", new: "35000")
        let replies = try await withThrowingTaskGroup(of: Reply.self) { group in
            group.addTask { try await Self.put(app, a, orderCode, "delivery-fee", first) }
            group.addTask { try await Self.put(app, b, orderCode, "delivery-fee", second) }
            var all: [Reply] = []
            for try await reply in group { all.append(reply) }
            return all
        }
        XCTAssertEqual(replies.filter { $0.status == .ok }.count, 1)
        XCTAssertEqual(replies.filter { $0.errorCode == "ORDER_STATE_CHANGED" }.count, 1)
        let rows = try await records(table, orderCode)
        XCTAssertEqual(rows, 1)
    }

    func testDirectSQLFeeChangeIsRefusedAfterFinishedOrCancelled() async throws {
        let finished = try await started("Finished"), cancelled = try await place(.init(status: "Cancelled", reason: "fake_spam"))
        for orderCode in [finished, cancelled] {
            do {
                try await run("UPDATE customer_order SET delivery_fee_final_vnd = 1 WHERE order_code = \(bind: orderCode)")
                XCTFail("fee changed on \(orderCode)")
            } catch {}
        }
    }
}
