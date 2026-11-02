import XCTVapor
@testable import App

/// `PUT /v1/admin/orders/{code}/expected-delivery-date`.
final class OrderDateMoveTests: OrderCorrectionTestCase {
    private let path = "expected-delivery-date", table = "order_expected_date_change"

    private func scheduled() async throws -> String {
        try await place(.init(status: "DeliveryDateScheduled", expectedDate: day(2)))
    }

    private func move(_ phone: Phone?, _ orderCode: String, to date: String, from previous: String? = nil) async throws -> Reply {
        try await Self.put(app, phone, orderCode, path, dateBody(previous: previous ?? day(2), new: date))
    }

    func testBothRolesMoveTheDateAndOneRecordRowIsWritten() async throws {
        for role in [AccountRole.owner, .staff] {
            let who = try await phone(role, "Nhan Vien \(role.rawValue)"), orderCode = try await scheduled()
            let reply = try await move(who, orderCode, to: day(4))
            XCTAssertEqual(reply.status, .ok)
            XCTAssertEqual(reply.string("expected_delivery_date"), day(4))
            let changes = reply.json["date_changes"] as? [[String: Any]]
            XCTAssertEqual(changes?.last?["old_date"] as? String, day(2))
            XCTAssertEqual(changes?.last?["new_date"] as? String, day(4))
            XCTAssertEqual(changes?.last?["changed_by_name"] as? String, "Nhan Vien \(role.rawValue)")
            let rows = try await records(table, orderCode)
            XCTAssertEqual(rows, 1)
        }
    }

    func testNoSessionIsRefused() async throws {
        let orderCode = try await scheduled()
        let none = try await move(nil, orderCode, to: day(3))
        XCTAssertEqual(none.status, .unauthorized)
        let rows = try await records(table, orderCode)
        XCTAssertEqual(rows, 0)
    }

    func testRangeBoundaries() async throws {
        let staff = try await phone(.staff)
        for (offset, code) in [(-1, "EXPECTED_DATE_PAST"), (0, nil), (7, nil), (8, "EXPECTED_DATE_TOO_FAR")] as [(Int, String?)] {
            let orderCode = try await place(.init(status: "DeliveryDateScheduled", expectedDate: day(offset == 3 ? 4 : 3)))
            let reply = try await move(staff, orderCode, to: day(offset), from: day(offset == 3 ? 4 : 3))
            if let code {
                XCTAssertEqual(reply.status, .unprocessableEntity, "\(offset)")
                XCTAssertEqual(fieldCode(reply), code)
                let range = (reply.json["error"] as? [String: Any]).flatMap { ($0["details"] as? [String: Any])?["expected_date_range"] as? [String: String] }
                XCTAssertEqual(range, ["min": day(0), "max": day(7)])
                let rows = try await records(table, orderCode)
                XCTAssertEqual(rows, 0)
            } else {
                XCTAssertEqual(reply.status, .ok, "\(offset)")
            }
        }
    }

    func testBodyDefectsAndUnchangedDateWriteNothing() async throws {
        let staff = try await phone(.staff), orderCode = try await scheduled()
        let same = try await move(staff, orderCode, to: day(2))
        XCTAssertEqual(fieldCode(same), "EXPECTED_DATE_UNCHANGED")
        let invalid = try await Self.put(app, staff, orderCode, path, dateBody(previous: day(2), new: "2026-13-40"))
        XCTAssertEqual(fieldCode(invalid), "EXPECTED_DATE_INVALID")
        let missing = try await Self.put(app, staff, orderCode, path, "{\"expected_status\":\"DeliveryDateScheduled\",\"expected_delivery_date\":\"\(day(3))\"}")
        XCTAssertEqual(fieldCode(missing), "EXPECTED_DATE_REQUIRED")
        let rows = try await records(table, orderCode)
        XCTAssertEqual(rows, 0)
    }

    func testOtherStatusesAnswerTheCurrentOrderAndWriteNothing() async throws {
        let staff = try await phone(.staff)
        for status in ["Processing", "DeliveryStarted", "Finished", "Cancelled"] {
            let started = status == "DeliveryStarted" || status == "Finished"
            let orderCode = try await place(.init(status: status, reason: status == "Cancelled" ? "fake_spam" : nil,
                                                  expectedDate: started ? day(2) : nil, finalFee: started ? 20_000 : nil))
            let reply = try await move(staff, orderCode, to: day(4))
            XCTAssertEqual(reply.errorCode, "ORDER_STATE_CHANGED", status)
            let order = (reply.json["error"] as? [String: Any]).flatMap { ($0["details"] as? [String: Any])?["order"] as? [String: Any] }
            XCTAssertEqual(order?["status"] as? String, status)
            let rows = try await records(table, orderCode)
            XCTAssertEqual(rows, 0)
        }
    }

    func testStalePreviousDateIsAConflictWithTheCurrentDetail() async throws {
        let staff = try await phone(.staff), orderCode = try await scheduled()
        let reply = try await move(staff, orderCode, to: day(4), from: day(5))
        XCTAssertEqual(reply.errorCode, "ORDER_STATE_CHANGED")
        let order = (reply.json["error"] as? [String: Any]).flatMap { ($0["details"] as? [String: Any])?["order"] as? [String: Any] }
        XCTAssertEqual(order?["expected_delivery_date"] as? String, day(2))
    }

    func testReplayBySameAccountOnlyAndWithoutASecondRow() async throws {
        let a = try await phone(.staff, "A"), b = try await phone(.staff, "B"), orderCode = try await scheduled()
        _ = try await move(a, orderCode, to: day(4))
        let again = try await move(a, orderCode, to: day(4))
        XCTAssertEqual(again.status, .ok)
        XCTAssertEqual(again.headers.first(name: "Idempotent-Replay"), "true")
        let other = try await move(b, orderCode, to: day(4))
        XCTAssertEqual(other.errorCode, "ORDER_STATE_CHANGED")
        let rows = try await records(table, orderCode)
        XCTAssertEqual(rows, 1)
    }

    func testTwoDevicesAtOnceHaveOneWinner() async throws {
        let a = try await phone(.staff, "A"), b = try await phone(.staff, "B"), orderCode = try await scheduled()
        let app = try XCTUnwrap(self.app), first = dateBody(previous: day(2), new: day(4)), second = dateBody(previous: day(2), new: day(5))
        let replies = try await withThrowingTaskGroup(of: Reply.self) { group in
            group.addTask { try await Self.put(app, a, orderCode, "expected-delivery-date", first) }
            group.addTask { try await Self.put(app, b, orderCode, "expected-delivery-date", second) }
            var all: [Reply] = []
            for try await reply in group { all.append(reply) }
            return all
        }
        XCTAssertEqual(replies.filter { $0.status == .ok }.count, 1)
        XCTAssertEqual(replies.filter { $0.errorCode == "ORDER_STATE_CHANGED" }.count, 1)
        let rows = try await records(table, orderCode)
        XCTAssertEqual(rows, 1)
    }

    func testAReplayOfAMoveThatIsNowOutOfRangeSkipsTheRangeCheck() async throws {
        let staff = try await phone(.staff), orderCode = try await scheduled()
        let far = day(7), from = day(2)
        _ = try await move(staff, orderCode, to: far)
        clock.set(clock.now().addingTimeInterval(-3 * 86_400))
        let again = try await move(staff, orderCode, to: far, from: from)
        XCTAssertEqual(again.status, .ok)
    }

    func testDirectSQLIsRefusedAfterFinishedOrCancelled() async throws {
        let finished = try await place(.init(status: "Finished", expectedDate: day(2), finalFee: 20_000))
        let cancelled = try await place(.init(status: "Cancelled", reason: "fake_spam"))
        for orderCode in [finished, cancelled] {
            do {
                try await run("UPDATE customer_order SET expected_delivery_date = \(bind: day(5))::date WHERE order_code = \(bind: orderCode)")
                XCTFail("date changed on \(orderCode)")
            } catch {}
        }
    }
}
