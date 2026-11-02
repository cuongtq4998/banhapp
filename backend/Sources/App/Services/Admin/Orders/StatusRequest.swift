import BanhContracts

/// The body of `POST /v1/admin/orders/{code}/status` (api/09 10.13.1), checked
/// field by field so each defect has its own error. The date range is not
/// checked here: a replay skips it (the service decides).
struct StatusRequest: Sendable, Equatable {
    static let reasonKey = "cancel_reason"
    static let dateKey = "expected_delivery_date"
    static let feeKey = "delivery_fee_vnd"
    static let maxFeeVND = 10_000_000

    let expected: OrderStatus
    let target: OrderStatus
    let reason: CancelReason?
    var expectedDate: BusinessDate? = nil
    var feeVND: Int? = nil

    private static let allowedKeys: Set<String> = ["expected_status", "to_status", reasonKey, dateKey, feeKey]

    /// The extra field each target takes; none for Processing and Finished.
    private static let extraKey: [OrderStatus: String] = [
        .cancelled: reasonKey, .deliveryDateScheduled: dateKey, .deliveryStarted: feeKey
    ]

    private static func invalid(_ field: String, _ code: String) -> APIError {
        APIError(.validationFailed, fields: [.init(field: field, code: code, messageKey: APIErrorCode.genericMessageKey)])
    }

    private static func status(_ body: [String: JSONValue], _ key: String) throws -> OrderStatus {
        guard case .string(let text)? = body[key], let value = OrderStatus(rawValue: text) else { throw invalid(key, "STATUS_INVALID") }
        return value
    }

    private static func isPresent(_ value: JSONValue?) -> Bool {
        if case nil = value { return false }
        if case .null? = value { return false }
        return true
    }

    /// - Throws: `VALIDATION_FAILED` for unknown fields, bad enums, a missing
    ///   or malformed extra and an extra the target does not take;
    ///   `CANCEL_REASON_REQUIRED` for a missing or unknown reason on a cancel;
    ///   `STATUS_TRANSITION_INVALID` for a pair the process forbids.
    static func parse(_ body: [String: JSONValue]) throws -> StatusRequest {
        if let unknown = body.keys.filter({ !allowedKeys.contains($0) }).sorted().first { throw invalid(unknown, "UNKNOWN_FIELD") }
        let expected = try status(body, "expected_status"), target = try status(body, "to_status")
        let own = extraKey[target]
        if let foreign = [reasonKey, dateKey, feeKey].filter({ $0 != own && isPresent(body[$0]) }).first {
            throw invalid(foreign, "FIELD_NOT_ALLOWED")
        }
        let reason = try reason(body, target: target)
        let date = try date(body, target: target), fee = try fee(body, target: target)
        guard expected.canMove(to: target) else {
            throw APIError(.statusTransitionInvalid, details: ["status": .string(expected.rawValue)])
        }
        return StatusRequest(expected: expected, target: target, reason: reason, expectedDate: date, feeVND: fee)
    }

    private static func reason(_ body: [String: JSONValue], target: OrderStatus) throws -> CancelReason? {
        guard target == .cancelled else { return nil }
        guard case .string(let text)? = body[reasonKey], let value = CancelReason(rawValue: text) else { throw APIError(.cancelReasonRequired) }
        return value
    }

    private static func date(_ body: [String: JSONValue], target: OrderStatus) throws -> BusinessDate? {
        guard target == .deliveryDateScheduled else { return nil }
        guard isPresent(body[dateKey]) else { throw invalid(dateKey, "EXPECTED_DATE_REQUIRED") }
        guard case .string(let text)? = body[dateKey], let date = BusinessDate(isoString: text) else { throw invalid(dateKey, "EXPECTED_DATE_INVALID") }
        return date
    }

    private static func fee(_ body: [String: JSONValue], target: OrderStatus) throws -> Int? {
        guard target == .deliveryStarted else { return nil }
        guard isPresent(body[feeKey]) else { throw invalid(feeKey, "FEE_REQUIRED") }
        guard case .int(let fee)? = body[feeKey], (0...maxFeeVND).contains(fee) else { throw invalid(feeKey, "FEE_INVALID") }
        return fee
    }
}
