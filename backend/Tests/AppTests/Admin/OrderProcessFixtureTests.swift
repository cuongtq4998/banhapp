import XCTVapor
import BanhContracts
@testable import App

/// Fixtures of the date and fee routes against the real error answers.
final class OrderProcessFixtureTests: OrderCorrectionTestCase {
    private func envelope(_ reply: Reply) throws -> APIErrorResponse.Body {
        try JSONDecoder().decode(APIErrorResponse.self, from: reply.data).error
    }

    private func expect(_ reply: Reply, _ name: String, file: StaticString = #filePath, line: UInt = #line) throws {
        let actual = try envelope(reply), fixture = try AdminFixtures.error(name)
        XCTAssertEqual(actual.code, fixture.code, name, file: file, line: line)
        XCTAssertEqual(actual.messageKey, fixture.messageKey, name, file: file, line: line)
        XCTAssertEqual(actual.fields?.map(\.code), fixture.fields?.map(\.code), name, file: file, line: line)
        XCTAssertEqual(actual.fields?.map(\.field), fixture.fields?.map(\.field), name, file: file, line: line)
    }

    func testDateAndStatusErrorsMatchTheFixtures() async throws {
        let staff = try await phone(.staff, "Nhan Vien A")
        let order = try await place(.init(status: "DeliveryDateScheduled", expectedDate: day(2)))
        try expect(try await change(staff, order, move("DeliveryDateScheduled", "Cancelled", reason: "fake_spam")), "status-transition-invalid-cancel")
        try expect(try await change(staff, order, move("DeliveryDateScheduled", "DeliveryStarted")), "validation-fee-required")
        try expect(try await Self.put(app, staff, order, "expected-delivery-date", dateBody(previous: day(2), new: day(-1))), "validation-expected-date-past")
        try expect(try await Self.put(app, staff, order, "expected-delivery-date", dateBody(previous: day(2), new: day(30))), "validation-expected-date-too-far")
        let stale = try await Self.put(app, staff, order, "expected-delivery-date", dateBody(previous: day(1), new: day(3)))
        try expect(stale, "order-state-changed-date")
    }

    func testFeeErrorsMatchTheFixtures() async throws {
        let staff = try await phone(.staff, "Nhan Vien A")
        let order = try await place(.init(status: "DeliveryStarted", expectedDate: day(2), finalFee: 25_000))
        try expect(try await Self.put(app, staff, order, "delivery-fee", feeBody(previous: "25000", new: "-1")), "validation-fee-invalid")
        try expect(try await Self.put(app, staff, order, "delivery-fee", feeBody(previous: "25000", new: "1", status: "Finished")), "fee-correction-not-allowed")
        try expect(try await Self.put(app, staff, order, "delivery-fee", feeBody(previous: "1", new: "2")), "order-state-changed-fee")
    }
}
