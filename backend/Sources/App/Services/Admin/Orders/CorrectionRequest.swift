import BanhContracts

/// Body of `PUT .../expected-delivery-date` (api/09 10.13.2).
struct DateMoveRequest: Sendable, Equatable {
    static let previousKey = "previous_expected_delivery_date"
    let previous: BusinessDate
    let new: BusinessDate

    private static let allowedKeys: Set<String> = ["expected_status", previousKey, StatusRequest.dateKey]

    /// - Throws: `VALIDATION_FAILED` with the field code of the first defect.
    static func parse(_ body: [String: JSONValue]) throws -> DateMoveRequest {
        try CorrectionFields.rejectUnknown(body, allowed: allowedKeys)
        try CorrectionFields.expectStatus(body, .deliveryDateScheduled)
        let previous = try date(body, previousKey), new = try date(body, StatusRequest.dateKey)
        return DateMoveRequest(previous: previous, new: new)
    }

    /// Decided from the body alone, after the range check.
    var unchangedError: APIError? {
        previous == new ? CorrectionFields.invalid(StatusRequest.dateKey, "EXPECTED_DATE_UNCHANGED") : nil
    }

    private static func date(_ body: [String: JSONValue], _ key: String) throws -> BusinessDate {
        guard CorrectionFields.isPresent(body[key]) else { throw CorrectionFields.invalid(key, "EXPECTED_DATE_REQUIRED") }
        guard case .string(let text)? = body[key], let date = BusinessDate(isoString: text) else {
            throw CorrectionFields.invalid(key, "EXPECTED_DATE_INVALID")
        }
        return date
    }
}

/// Body of `PUT .../delivery-fee` (api/09 10.13.6).
struct FeeCorrectionRequest: Sendable, Equatable {
    static let previousKey = "previous_delivery_fee_vnd"
    let previous: Int
    let new: Int

    private static let allowedKeys: Set<String> = ["expected_status", previousKey, StatusRequest.feeKey]

    /// Field checks, then `expected_status`, then the range.
    /// - Throws: `VALIDATION_FAILED`, or `FEE_CORRECTION_NOT_ALLOWED`.
    static func parse(_ body: [String: JSONValue]) throws -> FeeCorrectionRequest {
        try CorrectionFields.rejectUnknown(body, allowed: allowedKeys)
        let previous = try fee(body, previousKey, missing: "PREVIOUS_FEE_REQUIRED")
        let new = try fee(body, StatusRequest.feeKey, missing: "FEE_REQUIRED")
        guard case .string(OrderStatus.deliveryStarted.rawValue)? = body["expected_status"] else {
            throw APIError(.feeCorrectionNotAllowed)
        }
        for (key, value) in [(previousKey, previous), (StatusRequest.feeKey, new)] where !(0...StatusRequest.maxFeeVND).contains(value) {
            throw CorrectionFields.invalid(key, "FEE_INVALID")
        }
        return FeeCorrectionRequest(previous: previous, new: new)
    }

    var unchangedError: APIError? {
        previous == new ? CorrectionFields.invalid(StatusRequest.feeKey, "FEE_UNCHANGED") : nil
    }

    private static func fee(_ body: [String: JSONValue], _ key: String, missing: String) throws -> Int {
        guard CorrectionFields.isPresent(body[key]) else { throw CorrectionFields.invalid(key, missing) }
        guard case .int(let value)? = body[key] else { throw CorrectionFields.invalid(key, "FEE_INVALID") }
        return value
    }
}

/// Checks the two correction bodies share.
enum CorrectionFields {
    static func invalid(_ field: String, _ code: String) -> APIError {
        APIError(.validationFailed, fields: [.init(field: field, code: code, messageKey: APIErrorCode.genericMessageKey)])
    }

    static func isPresent(_ value: JSONValue?) -> Bool {
        switch value {
        case nil, .null?: return false
        default: return true
        }
    }

    static func rejectUnknown(_ body: [String: JSONValue], allowed: Set<String>) throws {
        if let unknown = body.keys.filter({ !allowed.contains($0) }).sorted().first { throw invalid(unknown, "UNKNOWN_FIELD") }
    }

    static func expectStatus(_ body: [String: JSONValue], _ status: OrderStatus) throws {
        guard case .string(status.rawValue)? = body["expected_status"] else { throw invalid("expected_status", "STATUS_INVALID") }
    }
}
