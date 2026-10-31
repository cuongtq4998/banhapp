import XCTest
import BanhContracts
@testable import App

/// Runs `contracts/fixtures/validation.json` (ADR-0009 v1.2, canonical shape
/// version 2) against the server rules. Only the canonical keys are read:
/// `phone_pattern`, `phone`, `text_limits`, `text`, `decomposed`, `quantity`,
/// `quantity_max_per_cake`. `VALIDATION_FIXTURE` may name another copy of the file.
final class ValidationFixtureTests: XCTestCase {
    private struct Fixture: Decodable {
        struct Phone: Decodable { let input: String; let valid: Bool; let e164: String? }
        struct Text: Decodable {
            let field: String; let value: String?; let repeatText: String?; let count: Int?; let valid: Bool
            enum CodingKeys: String, CodingKey { case field, value, count, valid; case repeatText = "repeat" }
            var text: String { value ?? String(repeating: repeatText ?? "", count: count ?? 0) }
        }
        struct Decomposed: Decodable {
            let composed: String; let decomposed: String
            let lengthAfterNFC: Int
            enum CodingKeys: String, CodingKey { case composed, decomposed; case lengthAfterNFC = "length_after_nfc" }
        }
        struct Quantity: Decodable {
            let perCake: Int; let valid: Bool
            enum CodingKeys: String, CodingKey { case valid; case perCake = "per_cake" }
        }
        let phonePattern: String
        let phone: [Phone]
        let textLimits: [String: Int]
        let text: [Text]
        let decomposed: Decomposed
        let quantity: [Quantity]
        let quantityMaxPerCake: Int
        enum CodingKeys: String, CodingKey {
            case phone, text, decomposed, quantity
            case phonePattern = "phone_pattern", textLimits = "text_limits", quantityMaxPerCake = "quantity_max_per_cake"
        }
    }

    private func load() throws -> Fixture {
        let override = ProcessInfo.processInfo.environment["VALIDATION_FIXTURE"]
        let url = override.map { URL(fileURLWithPath: $0) } ?? TestPaths.contractFixtures.appendingPathComponent("validation.json")
        guard FileManager.default.fileExists(atPath: url.path) else { throw XCTSkip("validation.json is not in this checkout") }
        return try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: url))
    }

    func testPhoneCases() throws {
        let fixture = try load()
        XCTAssertEqual(fixture.phone.isEmpty, false)
        for item in fixture.phone {
            let result = PhoneNumber.normalise(item.input.trimmingCharacters(in: .whitespacesAndNewlines))
            XCTAssertEqual(result != nil, item.valid, item.input)
            if item.valid { XCTAssertEqual(result, item.e164, item.input) } else { XCTAssertNil(result, item.input) }
        }
        let national = try Regex(fixture.phonePattern)
        XCTAssertNotNil("0912345678".wholeMatch(of: national))
    }

    func testTextCasesAndLimits() throws {
        let fixture = try load()
        XCTAssertEqual(fixture.textLimits["name"], OrderText.nameMaxLength)
        XCTAssertEqual(fixture.textLimits["address"], OrderText.addressMaxLength)
        XCTAssertEqual(fixture.textLimits["note"], InputLimits.noteMaxLength)
        for item in fixture.text {
            let max = try XCTUnwrap(fixture.textLimits[item.field])
            let result = OrderText.normalise(
                item.text, minLength: item.field == "note" ? 0 : 1, maxLength: max, allowsNewline: item.field != "name"
            )
            XCTAssertEqual((try? result.get()) != nil, item.valid, "\(item.field): \(item.text.prefix(20))")
        }
    }

    func testDecomposedTextCountsLikeComposed() throws {
        let sample = try load().decomposed
        let composed = try OrderText.normalise(sample.composed, minLength: 1, maxLength: 100, allowsNewline: false).get()
        let decomposed = try OrderText.normalise(sample.decomposed, minLength: 1, maxLength: 100, allowsNewline: false).get()
        XCTAssertEqual(composed, decomposed)
        XCTAssertEqual(decomposed.unicodeScalars.count, sample.lengthAfterNFC)
    }

    func testQuantityBounds() throws {
        let fixture = try load()
        XCTAssertEqual(fixture.quantityMaxPerCake, OrderRequestParser.hardMaxQuantity)
        for item in fixture.quantity {
            let json = JSONValue.object([
                "items": .array([.object(["product_id": .string(OrderTestData.productID.uuidString), "quantity": .int(item.perCake)])]),
                "delivery_date": .string("2026-11-05"), "slot_id": .string(OrderTestData.slotID.uuidString),
                "customer": .object(["name": .string("A"), "phone": .string("0900000000"), "address": .string("B"),
                                     "district_id": .string(OrderTestData.districtID.uuidString)]),
                "note": .null, "expected_total_vnd": .int(1)
            ])
            XCTAssertEqual((try? OrderRequestParser.parse(json)) != nil, item.valid, "\(item.perCake)")
        }
    }
}
