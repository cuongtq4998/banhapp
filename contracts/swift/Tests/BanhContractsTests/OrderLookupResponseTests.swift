import Foundation
import XCTest
@testable import BanhContracts

final class OrderLookupResponseTests: XCTestCase {
    private func answer(_ name: String) throws -> OrderLookupResponse {
        try FixtureFiles.decode(OrderLookupResponse.self, from: "customer/order-lookup-answer-\(name).json")
    }

    func testOpenAnswerKeepsNullFeesAsNil() throws {
        let orders = try answer("open").orders
        XCTAssertEqual(orders.map(\.status), ["Received", "Processing", "DeliveryDateScheduled", "DeliveryStarted"])
        XCTAssertNil(orders[0].amountToCollectVND)
        XCTAssertNil(orders[0].deliveryFeeFinalVND)
        XCTAssertNil(orders[0].expectedDeliveryDate)
        XCTAssertEqual(orders[3].amountToCollectVND, 175_000)
        XCTAssertEqual(orders[0].items.count, 2)
    }

    func testFeeZeroIsARealFee() throws {
        let order = try XCTUnwrap(answer("fee-zero").orders.first)
        XCTAssertEqual(order.deliveryFeeFinalVND, 0)
        XCTAssertEqual(order.amountToCollectVND, order.itemsSubtotalVND)
    }

    func testCorrectedFeeAndCancelledAnswersDecode() throws {
        XCTAssertEqual(try answer("fee-corrected").orders.first?.deliveryFeeFinalVND, 35_000)
        XCTAssertEqual(try answer("cancelled").orders.first?.status, "Cancelled")
    }

    func testEmptyAndPagedAnswers() throws {
        let empty = try answer("empty")
        XCTAssertTrue(empty.orders.isEmpty)
        XCTAssertNil(empty.nextCursor)
        let first = try answer("page-one"), last = try answer("last-page")
        XCTAssertEqual(first.orders.count, 10)
        XCTAssertNotNil(first.nextCursor)
        XCTAssertEqual(last.orders.count, 2)
        XCTAssertNil(last.nextCursor)
    }

    func testMissingNullableKeysDecodeAsNil() throws {
        let json = #"{"orders":[{"order_code":"BT-FIX001","status":"Received","placed_at":"x","phone_masked":"x","district_name":"d","requested_delivery_date":"d","slot_start_time":"a","slot_end_time":"b","items":[],"items_subtotal_vnd":1,"delivery_fee_estimate_vnd":2}],"as_of":"t"}"#
        let decoded = try JSONDecoder().decode(OrderLookupResponse.self, from: Data(json.utf8))
        XCTAssertNil(decoded.nextCursor)
        XCTAssertNil(decoded.orders[0].amountToCollectVND)
        XCTAssertNil(decoded.orders[0].deliveryFeeFinalVND)
    }

    func testRequestAndErrorFixturesDecode() throws {
        let request = try FixtureFiles.decode(OrderLookupRequest.self, from: "customer/order-lookup-request.json")
        XCTAssertEqual(request.phone, "+84900000001")
        XCTAssertNil(request.cursor)
        for (name, code) in [("phone-required", "VALIDATION_FAILED"), ("phone-invalid", "VALIDATION_FAILED"),
                             ("cursor-invalid", "VALIDATION_FAILED"), ("rate-limited", "RATE_LIMITED")] {
            let error = try FixtureFiles.decode(APIErrorResponse.self, from: "customer/error-lookup-\(name).json")
            XCTAssertEqual(error.error.code, code, name)
        }
    }
}
