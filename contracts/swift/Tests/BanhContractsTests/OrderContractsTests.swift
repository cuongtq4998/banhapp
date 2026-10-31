import Foundation
import XCTest
@testable import BanhContracts

final class OrderContractsTests: XCTestCase {
    private let productID = ResourceID(UUID(uuidString: "0b8f1f0e-1111-4a00-8000-000000000001")!)

    func testRequestFixtureDecodesAndRoundTrips() throws {
        let body = try FixtureFiles.decode(OrderRequestBody.self, from: "order-request.json")
        XCTAssertEqual(body.items, [OrderItemRequest(productID: productID, quantity: 2)])
        XCTAssertEqual(body.deliveryDate, "2026-11-05")
        XCTAssertEqual(body.customer.phone, "0900 000 000")
        XCTAssertNil(body.note)
        XCTAssertEqual(body.expectedTotalVND, 120_000)
        let again = try JSONDecoder().decode(OrderRequestBody.self, from: JSONEncoder().encode(body))
        XCTAssertEqual(again, body)
    }

    func testAbsentNoteIsWrittenAsExplicitNull() throws {
        let body = try FixtureFiles.decode(OrderRequestBody.self, from: "order-request.json")
        XCTAssertTrue(String(decoding: try JSONEncoder().encode(body), as: UTF8.self).contains("\"note\":null"))
    }

    func testCreatedAndReplayFixturesCarryTheSameBody() throws {
        let created = try Exchange.load("order-created.json")
        let replay = try Exchange.load("order-replay.json")
        XCTAssertEqual(created.status, 201)
        XCTAssertEqual(replay.status, 200)
        XCTAssertEqual(created.body, OrderCreatedResponse(orderCode: "BT-7K3M9Q", createdAt: "2026-11-02T03:15:09Z"))
        XCTAssertEqual(replay.body, created.body)
        XCTAssertEqual(replay.responseHeaders["Idempotent-Replay"], "true")
        XCTAssertNil(created.responseHeaders["Idempotent-Replay"])
    }

    func testCreatedBodyHasNoStatusOrPaymentField() throws {
        let data = try JSONEncoder().encode(OrderCreatedResponse(orderCode: "BT-7K3M9Q", createdAt: "2026-11-02T03:15:09Z"))
        let keys = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any]).keys
        XCTAssertEqual(Set(keys), ["order_code", "created_at"])
    }

    func testEveryOrderErrorFixtureDecodesWithItsCatalogueKey() throws {
        let expected: [String: (code: String, key: String)] = [
            "validation-failed": ("VALIDATION_FAILED", "ERR_SERVER"), "price-changed": ("PRICE_CHANGED", "MSG_PRICE_CHANGED"),
            "min-qty": ("MIN_QTY", "ERR_MIN_QTY"), "date-lead": ("DATE_LEAD", "ERR_DATE_LEAD"),
            "date-horizon": ("DATE_HORIZON", "ERR_DATE_HORIZON"), "date-capacity": ("DATE_CAPACITY", "ERR_DATE_CAPACITY"),
            "product-unavailable": ("PRODUCT_UNAVAILABLE", "ERR_PRODUCT_UNAVAILABLE"),
            "slot-unavailable": ("SLOT_UNAVAILABLE", "ERR_SLOT_UNAVAILABLE"),
            "district-unserved": ("DISTRICT_UNSERVED", "ERR_DISTRICT_UNSERVED"),
            "idempotency-key-required": ("IDEMPOTENCY_KEY_REQUIRED", "ERR_SERVER"),
            "header-invalid": ("HEADER_INVALID", "ERR_SERVER"),
            "idempotency-key-reused": ("IDEMPOTENCY_KEY_REUSED", "ERR_SERVER"),
            "rate-limited": ("RATE_LIMITED", "ERR_RATE_LIMITED"), "payload-too-large": ("PAYLOAD_TOO_LARGE", "ERR_SERVER"),
            "ordering-paused": ("ORDERING_PAUSED", "ERR_SERVER"), "service-unavailable": ("SERVICE_UNAVAILABLE", "ERR_SERVER"),
            "internal-error": ("INTERNAL_ERROR", "ERR_SERVER")
        ]
        for (name, want) in expected {
            let decoded = try FixtureFiles.decode(APIErrorResponse.self, from: "order-error-\(name).json")
            XCTAssertEqual(decoded.error.code, want.code, name)
            XCTAssertEqual(decoded.error.messageKey, want.key, name)
        }
    }

    func testPriceChangedDetailsDecodeTyped() throws {
        let decoded = try FixtureFiles.decode(APIErrorResponse.self, from: "order-error-price-changed.json")
        let data = try JSONEncoder().encode(JSONValue.object(decoded.error.details))
        let details = try JSONDecoder().decode(PriceChangedDetails.self, from: data)
        XCTAssertEqual(details, PriceChangedDetails(items: [.init(productID: productID, priceVND: 55_000)], deliveryFeeVND: 20_000, totalVND: 130_000))
    }

    func testValidationFixtureListsFieldKeys() throws {
        let decoded = try FixtureFiles.decode(APIErrorResponse.self, from: "order-error-validation-failed.json")
        XCTAssertEqual(decoded.error.fields?.map(\.messageKey), ["ERR_NAME_REQUIRED", "ERR_PHONE_INVALID"])
    }
}

/// The exchange wrapper used by the fixtures that carry a status and headers.
struct Exchange: Decodable {
    let status: Int
    let responseHeaders: [String: String]
    let body: OrderCreatedResponse

    static func load(_ name: String) throws -> Exchange {
        try FixtureFiles.decode(Exchange.self, from: name)
    }

    private enum CodingKeys: String, CodingKey {
        case status
        case responseHeaders = "response_headers"
        case body
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = try container.decode(Int.self, forKey: .status)
        responseHeaders = try container.decode([String: String].self, forKey: .responseHeaders)
        body = try container.decode(OrderCreatedResponse.self, forKey: .body)
    }
}
