import Foundation
import BanhContracts

/// Reads a JSON object field by field and keeps every problem, so one answer
/// lists them all (api/07: `fields[]`). Codes are `<FIELD>_REQUIRED`,
/// `_INVALID`, `_TOO_LONG` and `_OUT_OF_RANGE`; message keys `ERR_FIELD_*`.
struct FormReader {
    typealias Problem = APIErrorResponse.FieldError

    private let body: [String: JSONValue]
    private(set) var problems: [Problem] = []

    /// Unknown keys are problems too (`FIELD_UNKNOWN`), so a typo is never silently ignored.
    init(_ body: [String: JSONValue], allowed: Set<String>) {
        self.body = body
        for key in body.keys.filter({ !allowed.contains($0) }).sorted() { add(key, "FIELD_UNKNOWN", "INVALID") }
    }

    func has(_ key: String) -> Bool { body[key] != nil }

    mutating func add(_ field: String, _ code: String, _ kind: String) {
        problems.append(Problem(field: field, code: code, messageKey: "ERR_FIELD_" + kind))
    }

    mutating func fail(_ field: String, _ kind: String) {
        add(field, field.uppercased() + "_" + kind, kind)
    }

    /// Trimmed, NFC text of `length` characters. Absent or null is `REQUIRED`
    /// unless `required` is false (then nil, no problem).
    mutating func text(_ key: String, _ length: ClosedRange<Int>, required: Bool = true) -> String? {
        switch body[key] {
        case nil, .null?:
            if required || body[key] != nil { fail(key, "REQUIRED") }
            return nil
        case .string(let raw)?:
            let value = raw.trimmingCharacters(in: .whitespacesAndNewlines).precomposedStringWithCanonicalMapping
            if value.isEmpty { fail(key, "REQUIRED"); return nil }
            if value.unicodeScalars.contains(where: { $0.properties.generalCategory == .control }) { fail(key, "INVALID"); return nil }
            if value.count > length.upperBound { fail(key, "TOO_LONG"); return nil }
            if value.count < length.lowerBound { fail(key, "INVALID"); return nil }
            return value
        default:
            fail(key, "INVALID")
            return nil
        }
    }

    /// A whole JSON number inside `range`; anything else is a problem.
    mutating func integer(_ key: String, _ range: ClosedRange<Int>, required: Bool = true) -> Int? {
        switch body[key] {
        case nil, .null?:
            if required || body[key] != nil { fail(key, "REQUIRED") }
            return nil
        case .int(let value)?:
            guard range.contains(value) else { fail(key, "OUT_OF_RANGE"); return nil }
            return value
        default:
            fail(key, "INVALID")
            return nil
        }
    }

    mutating func bool(_ key: String, required: Bool = true) -> Bool? {
        switch body[key] {
        case nil, .null?:
            if required || body[key] != nil { fail(key, "REQUIRED") }
            return nil
        case .bool(let value)?: return value
        default:
            fail(key, "INVALID")
            return nil
        }
    }

    /// 422 `VALIDATION_FAILED` listing every problem, or nothing.
    func finish() throws {
        if !problems.isEmpty { throw APIError(.validationFailed, fields: problems) }
    }

    /// A change request names at least one field.
    mutating func requireAny() {
        if body.isEmpty { add("body", "BODY_EMPTY", "REQUIRED") }
    }

    /// A single named problem, thrown at once (a rule that needs the database).
    static func refusal(_ field: String, _ code: String, _ kind: String) -> APIError {
        APIError(.validationFailed, fields: [Problem(field: field, code: code, messageKey: "ERR_FIELD_" + kind)])
    }
}
