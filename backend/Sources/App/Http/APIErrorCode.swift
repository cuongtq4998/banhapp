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
    // Admin sign-in and sessions (api/08 section 11).
    case unauthenticated = "UNAUTHENTICATED"
    case accessTokenExpired = "ACCESS_TOKEN_EXPIRED"
    case sessionRevoked = "SESSION_REVOKED"
    case sessionExpired = "SESSION_EXPIRED"
    case forbidden = "FORBIDDEN"
    case codeInvalid = "CODE_INVALID"
    case codeExpired = "CODE_EXPIRED"
    case codeResendWait = "CODE_RESEND_WAIT"
    case codeRequestLimit = "CODE_REQUEST_LIMIT"

    var status: HTTPResponseStatus {
        switch self {
        case .codeInvalid, .codeExpired:
            return .unprocessableEntity
        case .unauthenticated, .accessTokenExpired, .sessionRevoked, .sessionExpired:
            return .unauthorized
        case .forbidden: return .forbidden
        case .codeResendWait, .codeRequestLimit: return .tooManyRequests
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
        case .unauthenticated, .accessTokenExpired: return "ERR_ADMIN_SIGN_IN_REQUIRED"
        case .sessionRevoked, .sessionExpired: return "ERR_ADMIN_SESSION_ENDED"
        case .forbidden: return "ERR_ADMIN_FORBIDDEN"
        case .codeInvalid: return "ERR_CODE_INVALID"
        case .codeExpired: return "ERR_CODE_EXPIRED"
        case .codeResendWait: return "ERR_CODE_RESEND_WAIT"
        case .codeRequestLimit: return "ERR_CODE_REQUEST_LIMIT"
        default:
            return Self.genericMessageKey
        }
    }

    static let genericMessageKey = "ERR_SERVER"
}
