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
    // Admin orders (api/08 section 11).
    case orderNotFound = "ORDER_NOT_FOUND"
    case orderStateChanged = "ORDER_STATE_CHANGED"
    case statusTransitionInvalid = "STATUS_TRANSITION_INVALID"
    case cancelReasonRequired = "CANCEL_REASON_REQUIRED"
    // Owner settings and staff (api/08 section 11).
    case lastActiveDistrict = "LAST_ACTIVE_DISTRICT"
    case lastActiveSlot = "LAST_ACTIVE_SLOT"
    case slotDuplicate = "SLOT_DUPLICATE"
    case emailTaken = "EMAIL_TAKEN"
    case staffLimitReached = "STAFF_LIMIT_REACHED"
    case ownerProtected = "OWNER_PROTECTED"

    var status: HTTPResponseStatus {
        switch self {
        case .codeInvalid, .codeExpired:
            return .unprocessableEntity
        case .unauthenticated, .accessTokenExpired, .sessionRevoked, .sessionExpired:
            return .unauthorized
        case .forbidden: return .forbidden
        case .codeResendWait, .codeRequestLimit: return .tooManyRequests
        case .statusTransitionInvalid, .cancelReasonRequired, .slotDuplicate:
            return .unprocessableEntity
        case .lastActiveDistrict, .lastActiveSlot, .emailTaken, .staffLimitReached, .ownerProtected:
            return .conflict
        case .orderNotFound: return .notFound
        case .orderStateChanged: return .conflict
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
        case .orderNotFound: return "ERR_ORDER_NOT_FOUND"
        case .orderStateChanged: return "ERR_ORDER_STATE_CHANGED"
        case .statusTransitionInvalid: return "ERR_ORDER_STATUS_INVALID"
        case .cancelReasonRequired: return "ERR_CANCEL_REASON_REQUIRED"
        case .lastActiveDistrict: return "ERR_LAST_ACTIVE_DISTRICT"
        case .lastActiveSlot: return "ERR_LAST_ACTIVE_SLOT"
        case .slotDuplicate: return "ERR_SLOT_DUPLICATE"
        case .emailTaken: return "ERR_EMAIL_TAKEN"
        case .staffLimitReached: return "ERR_STAFF_LIMIT"
        default:
            return Self.genericMessageKey
        }
    }

    static let genericMessageKey = "ERR_SERVER"
}
