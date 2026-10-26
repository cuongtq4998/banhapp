import Vapor
import BanhContracts

/// The only error type that reaches a client with a meaningful code. Services
/// and repositories throw it; `APIErrorMiddleware` turns it into the envelope
/// of api.md section 1.
struct APIError: Error, Sendable {
    let code: APIErrorCode
    /// Per-field problems; only for `VALIDATION_FAILED`.
    let fields: [APIErrorResponse.FieldError]?
    let details: [String: JSONValue]

    var status: HTTPResponseStatus { code.status }

    init(_ code: APIErrorCode, fields: [APIErrorResponse.FieldError]? = nil, details: [String: JSONValue] = [:]) {
        self.code = code
        self.fields = fields
        self.details = details
    }

    func makeBody(requestID: UUID) -> APIErrorResponse {
        APIErrorResponse(
            error: .init(code: code.rawValue, messageKey: code.messageKey, fields: fields, details: details),
            requestID: requestID.uuidString
        )
    }

    /// Maps anything thrown to a catalogue error, so no framework default
    /// body ever leaves the server. Details of unexpected errors are never
    /// copied into the response: they can hold SQL or customer data.
    static func from(_ error: any Error) -> APIError {
        if let apiError = error as? APIError { return apiError }
        guard let abort = error as? any AbortError else { return APIError(.internalError) }
        switch abort.status {
        case .notFound: return APIError(.notFound)
        case .methodNotAllowed: return APIError(.methodNotAllowed)
        case .payloadTooLarge: return APIError(.payloadTooLarge)
        case .tooManyRequests: return APIError(.rateLimited)
        case .serviceUnavailable: return APIError(.serviceUnavailable)
        case .badRequest, .unprocessableEntity, .unsupportedMediaType:
            return APIError(.validationFailed)
        default:
            // Remaining client errors are malformed requests; server errors
            // are ours.
            return abort.status.code < 500 ? APIError(.validationFailed) : APIError(.internalError)
        }
    }
}
