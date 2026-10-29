import XCTest
import BanhContracts
@testable import App

final class OrderRequestParserTests: XCTestCase {
    private func body(_ mutate: (inout [String: JSONValue]) -> Void) throws -> JSONValue {
        guard case .object(var object) = try OrderTestData.json(OrderTestData.fixtureBody()) else { throw APIError(.internalError) }
        mutate(&object)
        return .object(object)
    }

    private func customer(_ changes: [String: JSONValue?]) throws -> JSONValue {
        try body { root in
            guard case .object(var customer)? = root["customer"] else { return }
            for (key, value) in changes { customer[key] = value }
            root["customer"] = .object(customer)
        }
    }

    private func fields(_ json: JSONValue) -> [String: String] {
        do {
            _ = try OrderRequestParser.parse(json)
            XCTFail("expected VALIDATION_FAILED")
            return [:]
        } catch let error as APIError {
            XCTAssertEqual(error.code, .validationFailed)
            return Dictionary(error.fields?.map { ($0.field, $0.code + "/" + $0.messageKey) } ?? [], uniquingKeysWith: { first, _ in first })
        } catch {
            XCTFail("\(error)")
            return [:]
        }
    }

    func testParsesTheSharedRequestFixture() throws {
        let request = try OrderRequestParser.parse(OrderTestData.json(OrderTestData.fixtureBody()))
        XCTAssertEqual(request, OrderTestData.request.replacing(expected: 120_000))
        XCTAssertEqual(request.customerPhone, "+84900000000")
        XCTAssertNil(request.note)
    }

    func testNormalisesTextPhoneAndNote() throws {
        let json = try customer(["name": .string("  Nguye\u{0302}\u{0303}n Văn A "), "phone": .string("+84 (900) 000-000")])
        guard case .object(var root) = json else { return }
        root["note"] = .string("  Ít đường \n ")
        let request = try OrderRequestParser.parse(.object(root))
        XCTAssertEqual(request.customerName, "Nguyễn Văn A".precomposedStringWithCanonicalMapping)
        XCTAssertEqual(request.customerPhone, "+84900000000")
        XCTAssertEqual(request.note, "Ít đường")
    }

    func testEmptyNoteBecomesNil() throws {
        let json = try body { $0["note"] = .string("   ") }
        XCTAssertNil(try OrderRequestParser.parse(json).note)
    }

    func testCustomerFieldErrorsUseTheCatalogueKeys() throws {
        XCTAssertEqual(fields(try customer(["name": .string("  ")]))["customer.name"], "NAME_REQUIRED/ERR_NAME_REQUIRED")
        XCTAssertEqual(fields(try customer(["name": nil]))["customer.name"], "NAME_REQUIRED/ERR_NAME_REQUIRED")
        XCTAssertEqual(fields(try customer(["phone": .string("")]))["customer.phone"], "PHONE_REQUIRED/ERR_PHONE_REQUIRED")
        XCTAssertEqual(fields(try customer(["phone": .string("0123456789")]))["customer.phone"], "PHONE_INVALID/ERR_PHONE_INVALID")
        XCTAssertEqual(fields(try customer(["phone": .int(900000000)]))["customer.phone"], "PHONE_INVALID/ERR_PHONE_INVALID")
        XCTAssertEqual(fields(try customer(["address": .string("")]))["customer.address"], "ADDRESS_REQUIRED/ERR_ADDRESS_REQUIRED")
        XCTAssertEqual(fields(try customer(["district_id": nil]))["customer.district_id"], "DISTRICT_REQUIRED/ERR_DISTRICT_REQUIRED")
        XCTAssertEqual(fields(try customer(["district_id": .string("x")]))["customer.district_id"], "DISTRICT_INVALID/ERR_SERVER")
    }

    func testLengthsAreCountedInCodePoints() throws {
        let hundred = String(repeating: "ệ", count: 100)
        XCTAssertNoThrow(try OrderRequestParser.parse(customer(["name": .string(hundred)])))
        XCTAssertEqual(fields(try customer(["name": .string(hundred + "a")]))["customer.name"], "NAME_INVALID/ERR_SERVER")
        XCTAssertNoThrow(try OrderRequestParser.parse(customer(["address": .string(String(repeating: "a", count: 250))])))
        XCTAssertEqual(fields(try customer(["address": .string(String(repeating: "a", count: 251))]))["customer.address"], "ADDRESS_INVALID/ERR_SERVER")
    }

    func testNoteLimitIs200() throws {
        XCTAssertNoThrow(try OrderRequestParser.parse(body { $0["note"] = .string(String(repeating: "a", count: 200)) }))
        let long = try body { $0["note"] = .string(String(repeating: "a", count: 201)) }
        XCTAssertEqual(fields(long)["note"], "NOTE_TOO_LONG/ERR_NOTE_MAX")
        XCTAssertEqual(fields(try body { $0["note"] = .int(3) })["note"], "NOTE_INVALID/ERR_SERVER")
    }

    func testControlCharactersAreRejectedExceptNewlineInAddressAndNote() throws {
        XCTAssertEqual(fields(try customer(["name": .string("A\u{7}B")]))["customer.name"], "NAME_INVALID/ERR_SERVER")
        XCTAssertEqual(fields(try customer(["name": .string("A\nB")]))["customer.name"], "NAME_INVALID/ERR_SERVER")
        XCTAssertNoThrow(try OrderRequestParser.parse(customer(["address": .string("1 Street\nFloor 2")])))
        XCTAssertEqual(fields(try customer(["address": .string("a\tb")]))["customer.address"], "ADDRESS_INVALID/ERR_SERVER")
        XCTAssertNoThrow(try OrderRequestParser.parse(body { $0["note"] = .string("a\nb") }))
    }

    func testUnknownFieldsAreRejectedAtEveryLevel() throws {
        XCTAssertEqual(fields(try body { $0["price_vnd"] = .int(1) })["price_vnd"], "FIELD_UNKNOWN/ERR_SERVER")
        XCTAssertEqual(fields(try customer(["email": .string("x")]))["customer.email"], "FIELD_UNKNOWN/ERR_SERVER")
        let item = JSONValue.object(["product_id": .string(OrderTestData.productID.uuidString), "quantity": .int(2), "price_vnd": .int(1)])
        XCTAssertEqual(fields(try body { $0["items"] = .array([item]) })["items[0].price_vnd"], "FIELD_UNKNOWN/ERR_SERVER")
    }

    func testItemRules() throws {
        let id = JSONValue.string(OrderTestData.productID.uuidString)
        func line(_ quantity: JSONValue) -> JSONValue { .object(["product_id": id, "quantity": quantity]) }
        XCTAssertEqual(fields(try body { $0["items"] = .array([]) })["items"], "ITEMS_INVALID/ERR_SERVER")
        XCTAssertEqual(fields(try body { $0["items"] = .null })["items"], "ITEMS_INVALID/ERR_SERVER")
        for bad in [JSONValue.int(0), .int(-1), .int(100), .double(1.5), .string("2")] {
            XCTAssertEqual(fields(try body { $0["items"] = .array([line(bad)]) })["items[0].quantity"], "QUANTITY_INVALID/ERR_SERVER")
        }
        XCTAssertNoThrow(try OrderRequestParser.parse(body { $0["items"] = .array([line(.int(99))]) }))
        XCTAssertEqual(fields(try body { $0["items"] = .array([line(.int(1)), line(.int(2))]) })["items[1].product_id"], "PRODUCT_DUPLICATE/ERR_SERVER")
    }

    func testDateSlotAndTotalRules() throws {
        for bad in ["2026-02-30", "2026-13-01", "05/11/2026", "2026-11-5", ""] {
            XCTAssertEqual(fields(try body { $0["delivery_date"] = .string(bad) })["delivery_date"], "DELIVERY_DATE_INVALID/ERR_SERVER", bad)
        }
        XCTAssertEqual(fields(try body { $0["slot_id"] = .string("nope") })["slot_id"], "SLOT_INVALID/ERR_SERVER")
        XCTAssertEqual(fields(try body { $0["expected_total_vnd"] = .int(-1) })["expected_total_vnd"], "EXPECTED_TOTAL_INVALID/ERR_SERVER")
        XCTAssertEqual(fields(try body { $0["expected_total_vnd"] = nil })["expected_total_vnd"], "EXPECTED_TOTAL_INVALID/ERR_SERVER")
    }

    func testAllProblemsAreReportedTogetherAndNotAnObjectHasNoFields() throws {
        let json = try customer(["name": .string(""), "phone": .string("1")])
        XCTAssertEqual(Set(fields(json).keys), ["customer.name", "customer.phone"])
        XCTAssertThrowsError(try OrderRequestParser.parse(.array([]))) {
            XCTAssertNil(($0 as? APIError)?.fields)
        }
    }
}
