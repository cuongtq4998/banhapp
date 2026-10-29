import XCTest
@testable import BanhApp

/// Runs the shared rules fixture (`contracts/fixtures/validation.json`, ADR-0009), the same file the
/// backend and Android read, so the three implementations cannot drift apart.
final class OrderValidationTests: XCTestCase {
    private struct PhoneCase: Decodable {
        let input: String
        let valid: Bool
        let normalized: String?
        let e164: String?
    }

    private struct TextCase: Decodable {
        let field: String
        let value: String?
        let repeatText: String?
        let count: Int?
        let valid: Bool

        private enum CodingKeys: String, CodingKey {
            case field, value, count, valid
            case repeatText = "repeat"
        }

        var text: String {
            value ?? String(repeating: repeatText ?? "", count: count ?? 0)
        }
    }

    private struct QuantityCase: Decodable {
        let perCake: Int
        let valid: Bool

        private enum CodingKeys: String, CodingKey {
            case perCake = "per_cake"
            case valid
        }
    }

    private struct Fixture: Decodable {
        let phone: [PhoneCase]
        let text: [TextCase]
        let quantity: [QuantityCase]
        let quantityMaxPerCake: Int

        private enum CodingKeys: String, CodingKey {
            case phone, text, quantity
            case quantityMaxPerCake = "quantity_max_per_cake"
        }
    }

    private func fixture() throws -> Fixture {
        try Fixtures.decode(Fixture.self, from: "validation.json")
    }

    func testPhoneCasesOfTheFixture() throws {
        let cases = try fixture().phone
        XCTAssertGreaterThan(cases.count, 15)
        for phoneCase in cases {
            let normalized = OrderValidation.validPhone(phoneCase.input)
            XCTAssertEqual(normalized != nil, phoneCase.valid, "phone \"\(phoneCase.input)\"")
            XCTAssertEqual(normalized, phoneCase.normalized, "normalized \"\(phoneCase.input)\"")
            if let normalized, let e164 = phoneCase.e164 {
                XCTAssertEqual(OrderValidation.e164(normalized), e164)
            }
        }
    }

    func testTextCasesOfTheFixture() throws {
        for textCase in try fixture().text {
            let valid: Bool
            switch textCase.field {
            case "name": valid = OrderValidation.isValidName(textCase.text)
            case "address": valid = OrderValidation.isValidAddress(textCase.text)
            case "note": valid = OrderValidation.isValidNote(textCase.text)
            default: return XCTFail("Unknown field \(textCase.field)")
            }
            XCTAssertEqual(valid, textCase.valid, "\(textCase.field) \"\(textCase.text.prefix(20))\" (\(textCase.count ?? 0))")
        }
    }

    func testQuantityCasesOfTheFixture() throws {
        let fixture = try fixture()
        for quantityCase in fixture.quantity {
            XCTAssertEqual(
                OrderValidation.isValidQuantity(quantityCase.perCake, maxPerCake: fixture.quantityMaxPerCake),
                quantityCase.valid, "quantity \(quantityCase.perCake)"
            )
        }
    }

    func testComposedAndDecomposedVietnameseCountTheSame() {
        XCTAssertEqual(OrderValidation.length("ệ"), 1)
        XCTAssertEqual(OrderValidation.length("e\u{0323}\u{0302}"), 1)
        XCTAssertTrue(OrderValidation.isValidNote(String(repeating: "e\u{0323}\u{0302}", count: 200)))
        XCTAssertFalse(OrderValidation.isValidNote(String(repeating: "e\u{0323}\u{0302}", count: 201)))
    }

    func testLimitedCutsAtTheLimitAndReportsIt() {
        XCTAssertEqual(OrderValidation.limited("abc", to: 3).wasCut, false)
        let cut = OrderValidation.limited("abcd", to: 3)
        XCTAssertEqual(cut.text, "abc")
        XCTAssertTrue(cut.wasCut)
        XCTAssertEqual(OrderValidation.limited(String(repeating: "ệ", count: 300), to: 200).text.count, 200)
    }
}
