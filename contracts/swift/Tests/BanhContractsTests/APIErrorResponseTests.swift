import Foundation
import XCTest
@testable import BanhContracts

final class APIErrorResponseTests: XCTestCase {
    private func fixtureData(_ name: String) throws -> Data {
        let fixtures = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // BanhContractsTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // swift
            .deletingLastPathComponent() // contracts
            .appendingPathComponent("fixtures")
        return try Data(contentsOf: fixtures.appendingPathComponent(name))
    }

    func testDecodesErrorWithoutFields() throws {
        let decoded = try JSONDecoder().decode(APIErrorResponse.self, from: fixtureData("error-date-capacity.json"))
        XCTAssertEqual(decoded.error.code, "DATE_CAPACITY")
        XCTAssertEqual(decoded.error.messageKey, "ERR_DATE_CAPACITY")
        XCTAssertNil(decoded.error.fields)
        XCTAssertEqual(decoded.error.details, [:])
        XCTAssertEqual(decoded.requestID, "7f1c1a52-0c1e-4d6c-9a54-2d7f3d6a0001")
    }

    func testDecodesErrorWithFields() throws {
        let decoded = try JSONDecoder().decode(APIErrorResponse.self, from: fixtureData("error-validation-failed.json"))
        XCTAssertEqual(
            decoded.error.fields,
            [.init(field: "customer.phone", code: "PHONE_INVALID", messageKey: "ERR_PHONE_INVALID")]
        )
    }

    func testRoundTripKeepsDetails() throws {
        let original = APIErrorResponse(
            error: .init(
                code: "PRICE_CHANGED",
                messageKey: "MSG_PRICE_CHANGED",
                details: ["total_vnd": .int(250_000), "items": .array([.object(["name": .string("x")])]), "flag": .bool(true), "none": .null]
            ),
            requestID: "id"
        )
        let data = try JSONEncoder().encode(original)
        XCTAssertEqual(try JSONDecoder().decode(APIErrorResponse.self, from: data), original)
    }

    func testOmitsFieldsKeyWhenNil() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(APIErrorResponse(error: .init(code: "X", messageKey: "ERR_SERVER"), requestID: "r"))
        XCTAssertEqual(
            String(decoding: data, as: UTF8.self),
            #"{"error":{"code":"X","details":{},"message_key":"ERR_SERVER"},"request_id":"r"}"#
        )
    }
}
