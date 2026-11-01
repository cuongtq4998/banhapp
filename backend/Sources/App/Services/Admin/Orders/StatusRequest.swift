import BanhContracts

/// The body of `POST /v1/admin/orders/{code}/status` (api/06 10.11), checked
/// field by field so each defect has its own error.
struct StatusRequest: Sendable, Equatable {
    let expected: OrderStatus
    let target: OrderStatus
    let reason: CancelReason?

    private static let allowedKeys: Set<String> = ["expected_status", "to_status", "cancel_reason"]

    /// - Throws: `VALIDATION_FAILED` for unknown fields, bad enums and a reason
    ///   with a non-cancel target; `CANCEL_REASON_REQUIRED` for a missing or
    ///   unknown reason on a cancel; `STATUS_TRANSITION_INVALID` for a pair BR-2 forbids.
    static func parse(_ body: [String: JSONValue]) throws -> StatusRequest {
        func invalid(_ field: String, _ code: String) -> APIError {
            APIError(.validationFailed, fields: [.init(field: field, code: code, messageKey: APIErrorCode.genericMessageKey)])
        }
        if let unknown = body.keys.filter({ !allowedKeys.contains($0) }).sorted().first { throw invalid(unknown, "UNKNOWN_FIELD") }
        func status(_ key: String) throws -> OrderStatus {
            guard case .string(let text)? = body[key], let value = OrderStatus(rawValue: text) else { throw invalid(key, "STATUS_INVALID") }
            return value
        }
        let expected = try status("expected_status"), target = try status("to_status")
        var reason: CancelReason?
        switch body["cancel_reason"] {
        case nil, .null?:
            if target == .cancelled { throw APIError(.cancelReasonRequired) }
        case .string(let text)?:
            if target != .cancelled { throw invalid("cancel_reason", "REASON_NOT_ALLOWED") }
            guard let value = CancelReason(rawValue: text) else { throw APIError(.cancelReasonRequired) }
            reason = value
        default:
            throw target == .cancelled ? APIError(.cancelReasonRequired) : invalid("cancel_reason", "REASON_NOT_ALLOWED")
        }
        guard expected.canMove(to: target) else {
            throw APIError(.statusTransitionInvalid, details: ["status": .string(expected.rawValue)])
        }
        return StatusRequest(expected: expected, target: target, reason: reason)
    }
}
