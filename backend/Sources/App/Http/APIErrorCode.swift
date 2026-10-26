import Vapor

/// Error codes of api.md section 5, each with its fixed HTTP status and UI
/// message key. One table, so a status can never drift from its code.
enum APIErrorCode: String, CaseIterable, Sendable {
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
    // Routing errors (api.md section 5, v1.3).
    case notFound = "NOT_FOUND"
    case methodNotAllowed = "METHOD_NOT_ALLOWED"

    var status: HTTPResponseStatus {
        switch self {
        case .validationFailed, .minQty, .dateLead, .dateHorizon, .districtUnserved, .idempotencyKeyReused:
            return .unprocessableEntity
        case .dateCapacity, .priceChanged, .productUnavailable, .slotUnavailable:
            return .conflict
        case .idempotencyKeyRequired, .headerInvalid:
            return .badRequest
        case .rateLimited: return .tooManyRequests
        case .payloadTooLarge: return .payloadTooLarge
        case .orderingPaused, .serviceUnavailable: return .serviceUnavailable
        case .internalError: return .internalServerError
        case .notFound: return .notFound
        case .methodNotAllowed: return .methodNotAllowed
        }
    }

    /// The UI key of the "Client behaviour" column; every code without its
    /// own entry shows the generic server error.
    var messageKey: String {
        switch self {
        case .minQty, .dateLead, .dateHorizon, .dateCapacity, .districtUnserved,
             .productUnavailable, .slotUnavailable, .rateLimited:
            return "ERR_" + rawValue
        case .priceChanged:
            return "MSG_PRICE_CHANGED"
        default:
            return Self.genericMessageKey
        }
    }

    static let genericMessageKey = "ERR_SERVER"
}
