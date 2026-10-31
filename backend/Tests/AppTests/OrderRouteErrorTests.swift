import XCTVapor
import BanhContracts
@testable import App

/// Every rule error of api.md 4.3, produced by the real route over a fake
/// repository, must equal its shared fixture.
final class OrderRouteErrorTests: OrderRouteTestCase {
    typealias Data = OrderTestData

    private func expect(_ status: HTTPResponseStatus, _ fixture: String, body: Foundation.Data? = nil) async throws {
        try await post(body) { try self.assertError($0, status, fixture: "order-error-\(fixture).json") }
    }

    private func setData(products: [UUID: OrderProductRecord]? = nil, slot: OrderSlotRecord?? = nil, district: OrderDistrictRecord?? = nil) {
        let data = Data.referenceData
        repository.update {
            $0.data = OrderReferenceData(
                rules: data.rules, minQty: data.minQty, products: products ?? data.products,
                slot: slot ?? data.slot, district: district ?? data.district
            )
        }
    }

    func testProductSlotAndDistrictErrors() async throws {
        try await start()
        let hidden = JSONValue.object(["product_id": .string(Data.inactiveProductID.uuidString.lowercased()), "quantity": .int(2)])
        try await expect(.conflict, "product-unavailable", body: mutatedBody { $0["items"] = .array([hidden]) })
        setData(slot: .some(nil))
        try await expect(.conflict, "slot-unavailable")
        setData(district: .some(nil))
        try await expect(.unprocessableEntity, "district-unserved")
        XCTAssertEqual(repository.inserted.count, 0)
    }

    func testQuantityAndDateErrors() async throws {
        try await start()
        let one = JSONValue.object(["product_id": .string(Data.productID.uuidString), "quantity": .int(1)])
        try await expect(.unprocessableEntity, "min-qty", body: mutatedBody { $0["items"] = .array([one]); $0["expected_total_vnd"] = .int(70_000) })
        try await expect(.unprocessableEntity, "date-lead", body: mutatedBody { $0["delivery_date"] = .string("2026-11-03") })
        try await expect(.unprocessableEntity, "date-horizon", body: mutatedBody { $0["delivery_date"] = .string("2026-12-03") })
    }

    func testPriceChangedAndCapacityAndReuse() async throws {
        try await start()
        var products = Data.referenceData.products
        products[Data.productID] = OrderProductRecord(id: Data.productID, name: "Bánh chuối", priceVND: 55_000, isActive: true)
        setData(products: products)
        try await expect(.conflict, "price-changed")
        setData(products: Data.referenceData.products)
        repository.update { $0.outcomes = [.capacityExceeded] }
        try await expect(.conflict, "date-capacity")
        repository.update { $0.stored[Data.idempotencyKey] = StoredOrder(placed: Data.placed, requestHash: "other") }
        try await expect(.unprocessableEntity, "idempotency-key-reused")
    }

    func testPerPhoneLimitAnswers429WithTheRetryHint() async throws {
        try await start()
        repository.update { $0.phoneCount = 5 }
        try await post { res in
            XCTAssertEqual(res.status, .tooManyRequests)
            XCTAssertEqual(res.headers.first(name: .retryAfter), "3600")
            try self.assertError(res, .tooManyRequests, fixture: "order-error-rate-limited.json")
        }
    }

    func testOutagesAndUnexpectedErrors() async throws {
        try await start()
        repository.update { $0.failure = APIError(.serviceUnavailable) }
        try await expect(.serviceUnavailable, "service-unavailable")
        repository.update { $0.failure = DatabaseProbeError() }
        try await expect(.internalServerError, "internal-error")
        let everything = capture.lines.map { "\($0.message) \($0.metadata)" }.joined()
        XCTAssertFalse(everything.contains("0900"))
    }
}
