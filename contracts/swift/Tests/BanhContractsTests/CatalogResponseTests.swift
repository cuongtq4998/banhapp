import Foundation
import XCTest
@testable import BanhContracts

final class CatalogResponseTests: XCTestCase {
    private func loadOk() throws -> CatalogResponse {
        try FixtureFiles.decode(CatalogResponse.self, from: "catalog-ok.json")
    }

    func testDecodesTheOkFixtureWithFourCakes() throws {
        let catalog = try loadOk()
        XCTAssertEqual(catalog.serverDate, "2026-11-02")
        XCTAssertEqual(catalog.products.map(\.slug), [
            "banana", "mung-bean-pork-fat", "mung-bean-vegetarian", "mung-bean-egg-yolk-pork-fat"
        ])
        XCTAssertEqual(catalog.products.first?.priceVND, 35_000)
        XCTAssertEqual(catalog.products.first?.imageURL, "/assets/images/banana.png?v=a547ade3")
        XCTAssertEqual(catalog.districts.count, 5)
        XCTAssertEqual(catalog.slots.first, CatalogSlot(
            slotID: ResourceID(UUID(uuidString: "00000000-0000-4000-8000-000000000031")!),
            start: "08:00",
            end: "10:00"
        ))
        XCTAssertEqual(catalog.settings, CatalogSettings(
            minQty: 2, leadDays: 2, maxDaysAhead: 30, maxQtyPerCake: 99, noteMaxLength: 200
        ))
        XCTAssertEqual(catalog.shop.phoneContact, "+84900000000")
    }

    func testDecodesTheEmptyFixtureWithEmptyLists() throws {
        let catalog = try FixtureFiles.decode(CatalogResponse.self, from: "catalog-empty.json")
        XCTAssertTrue(catalog.products.isEmpty)
        XCTAssertTrue(catalog.districts.isEmpty)
        XCTAssertTrue(catalog.slots.isEmpty)
        XCTAssertEqual(catalog.settings.minQty, 2)
    }

    func testReEncodingKeepsTheFixtureKeysAndValues() throws {
        let original = try loadOk()
        let encoded = try JSONEncoder().encode(original)
        // Same JSON value as the file: key names are the contract.
        let expected = try JSONSerialization.jsonObject(with: FixtureFiles.data("catalog-ok.json")) as? NSDictionary
        let actual = try JSONSerialization.jsonObject(with: encoded) as? NSDictionary
        XCTAssertEqual(actual, expected)
    }

    func testResourceIDsEncodeInLowerCase() throws {
        let id = ResourceID(UUID(uuidString: "0B8F1F0E-1111-4A00-8000-00000000000A")!)
        let data = try JSONEncoder().encode([id])
        XCTAssertEqual(String(decoding: data, as: UTF8.self), #"["0b8f1f0e-1111-4a00-8000-00000000000a"]"#)
    }

    func testResourceIDDecodesEitherCaseAndRejectsText() throws {
        let upper = try JSONDecoder().decode([ResourceID].self, from: Data(#"["0B8F1F0E-1111-4A00-8000-000000000001"]"#.utf8))
        XCTAssertEqual(upper.first?.description, "0b8f1f0e-1111-4a00-8000-000000000001")
        XCTAssertThrowsError(try JSONDecoder().decode([ResourceID].self, from: Data(#"["banana"]"#.utf8)))
    }

    func testIgnoresUnknownResponseFields() throws {
        // api.md section 6: clients ignore fields a later release adds.
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: FixtureFiles.data("catalog-empty.json")) as? [String: Any]
        )
        object["added_later"] = ["anything": 1]
        let data = try JSONSerialization.data(withJSONObject: object)
        XCTAssertNoThrow(try JSONDecoder().decode(CatalogResponse.self, from: data))
    }

    func testNotModifiedFixtureIsHeaderOnly() throws {
        struct Exchange: Decodable {
            let status: Int
            let requestHeaders: [String: String]
            let responseHeaders: [String: String]
            let body: String?
            private enum CodingKeys: String, CodingKey {
                case status
                case requestHeaders = "request_headers"
                case responseHeaders = "response_headers"
                case body
            }
        }
        let exchange = try FixtureFiles.decode(Exchange.self, from: "catalog-not-modified.json")
        XCTAssertEqual(exchange.status, 304)
        XCTAssertNil(exchange.body)
        XCTAssertEqual(exchange.requestHeaders["If-None-Match"], exchange.responseHeaders["ETag"])
        XCTAssertEqual(exchange.responseHeaders["Cache-Control"], "no-cache")
    }

    func testServiceUnavailableFixtureIsAnErrorEnvelope() throws {
        let envelope = try FixtureFiles.decode(APIErrorResponse.self, from: "error-service-unavailable.json")
        XCTAssertEqual(envelope.error.code, "SERVICE_UNAVAILABLE")
        XCTAssertEqual(envelope.error.messageKey, "ERR_SERVER")
        XCTAssertNil(envelope.error.fields)
    }
}
