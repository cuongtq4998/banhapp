import XCTest
import BanhContracts
@testable import App

/// The field rules behind every owner form (api/07: `*_REQUIRED`, `*_INVALID`,
/// `*_TOO_LONG`, `*_OUT_OF_RANGE`), without a database.
final class FormReaderTests: XCTestCase {
    private func codes(_ form: FormReader) -> [String] { form.problems.map(\.code) }

    func testTextIsTrimmedAndCountedInCharacters() {
        var form = FormReader(["a": .string("  Banh Mì  "), "b": .string(String(repeating: "đ", count: 100))], allowed: ["a", "b"])
        XCTAssertEqual(form.text("a", 1...100), "Banh Mì")
        XCTAssertEqual(form.text("b", 1...100)?.count, 100)
        XCTAssertEqual(codes(form), [])
    }

    func testTextProblems() {
        var form = FormReader([
            "empty": .string(" \n"), "long": .string(String(repeating: "x", count: 6)), "short": .string("x"),
            "number": .int(5), "null": .null, "control": .string("a\u{0007}b")
        ], allowed: ["empty", "long", "short", "number", "null", "control", "absent"])
        for key in ["empty", "long", "short", "number", "null", "control", "absent"] { _ = form.text(key, 3...5) }
        XCTAssertEqual(codes(form), ["EMPTY_REQUIRED", "LONG_TOO_LONG", "SHORT_INVALID", "NUMBER_INVALID", "NULL_REQUIRED", "CONTROL_INVALID", "ABSENT_REQUIRED"])
        XCTAssertEqual(form.problems.first?.messageKey, "ERR_FIELD_REQUIRED")
    }

    func testOptionalFieldsMayBeAbsentButNotNull() {
        var form = FormReader(["n": .null], allowed: ["n", "m"])
        XCTAssertNil(form.integer("m", 1...5, required: false))
        XCTAssertNil(form.integer("n", 1...5, required: false))
        XCTAssertEqual(codes(form), ["N_REQUIRED"])
    }

    func testIntegersAreWholeAndInRange() {
        var form = FormReader(["ok": .int(5), "low": .int(0), "high": .int(11), "frac": .double(1.5), "text": .string("5"), "flag": .bool(true)],
                              allowed: ["ok", "low", "high", "frac", "text", "flag"])
        XCTAssertEqual(form.integer("ok", 1...10), 5)
        for key in ["low", "high", "frac", "text", "flag"] { XCTAssertNil(form.integer(key, 1...10)) }
        XCTAssertEqual(codes(form), ["LOW_OUT_OF_RANGE", "HIGH_OUT_OF_RANGE", "FRAC_INVALID", "TEXT_INVALID", "FLAG_INVALID"])
    }

    func testBooleansAndUnknownKeysAndFinish() throws {
        var form = FormReader(["is_active": .bool(false), "zzz": .int(1), "aaa": .int(2)], allowed: ["is_active"])
        XCTAssertEqual(form.bool("is_active"), false)
        XCTAssertEqual(codes(form), ["FIELD_UNKNOWN", "FIELD_UNKNOWN"])
        XCTAssertEqual(form.problems.map(\.field), ["aaa", "zzz"], "sorted, so the answer is stable")
        XCTAssertThrowsError(try form.finish()) { error in
            let api = error as? APIError
            XCTAssertEqual(api?.code, .validationFailed)
            XCTAssertEqual(api?.fields?.count, 2)
        }
        XCTAssertNoThrow(try FormReader([:], allowed: []).finish())
    }

    func testEmptyBodyIsAProblemOnlyWhenAskedFor() {
        var form = FormReader([:], allowed: ["a"])
        form.requireAny()
        XCTAssertEqual(codes(form), ["BODY_EMPTY"])
    }
}
