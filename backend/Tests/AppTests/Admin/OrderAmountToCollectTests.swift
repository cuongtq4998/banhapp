import XCTVapor
@testable import App

/// amount_to_collect_vnd on the admin detail: items plus the real fee only (api/09).
final class OrderAmountToCollectTests: AdminOrderTestCase {
    private func amount(_ seed: SeedOrder) async throws -> Any? {
        let orderCode = try await place(seed)
        let staff = try await phone(.staff)
        let reply = try await detail(staff, orderCode)
        XCTAssertEqual(reply.status, .ok)
        return reply.json["amount_to_collect_vnd"]
    }

    func testFeeZeroGivesTheSubtotal() async throws {
        let value = try await amount(.init(status: "DeliveryStarted", expectedDate: day(1), finalFee: 0))
        XCTAssertEqual(value as? Int, 100_000)
    }

    func testRealFeeIsAddedToTheSubtotal() async throws {
        let value = try await amount(.init(status: "DeliveryStarted", expectedDate: day(1), finalFee: 25_000))
        XCTAssertEqual(value as? Int, 125_000)
    }

    func testNullFinalFeeIsNullNotTheEstimate() async throws {
        let value = try await amount(.init(status: "DeliveryDateScheduled", expectedDate: day(1), finalFee: nil))
        XCTAssertTrue(value is NSNull, "estimate 20000 must not become the amount")
    }
}
