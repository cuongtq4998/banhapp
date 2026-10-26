/// Stable error codes of docs/system/api.md section 5; the raw values are the wire values.
nonisolated enum APIErrorCode: String, Sendable, CaseIterable {
    case validationFailed = "VALIDATION_FAILED"
    case minQty = "MIN_QTY"
    case dateLead = "DATE_LEAD"
    case dateHorizon = "DATE_HORIZON"
    case dateCapacity = "DATE_CAPACITY"
    case districtUnserved = "DISTRICT_UNSERVED"
    case priceChanged = "PRICE_CHANGED"
    case productUnavailable = "PRODUCT_UNAVAILABLE"
    case slotUnavailable = "SLOT_UNAVAILABLE"
    case idempotencyKeyRequired = "IDEMPOTENCY_KEY_REQUIRED"
    case headerInvalid = "HEADER_INVALID"
    case idempotencyKeyReused = "IDEMPOTENCY_KEY_REUSED"
    case rateLimited = "RATE_LIMITED"
    case payloadTooLarge = "PAYLOAD_TOO_LARGE"
    case orderingPaused = "ORDERING_PAUSED"
    case serviceUnavailable = "SERVICE_UNAVAILABLE"
    case internalError = "INTERNAL_ERROR"
    case notFound = "NOT_FOUND"
    case methodNotAllowed = "METHOD_NOT_ALLOWED"

    /// A code a later server release adds behaves like `internalError` (api.md section 6).
    init(wire: String) {
        self = APIErrorCode(rawValue: wire) ?? .internalError
    }
}
