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

    /// A rate-limited error always carries its retry hint (api.md section 5),
    /// so a caller that forgot it still produces a complete response.
    init(_ code: APIErrorCode, fields: [APIErrorResponse.FieldError]? = nil, details: [String: JSONValue] = [:]) {
        var details = details
        if code == .rateLimited, details[Self.retryAfterDetailKey] == nil {
            details[Self.retryAfterDetailKey] = .int(Self.defaultRetryAfterSeconds)
        }
        self.code = code
        self.fields = fields
        self.details = details
    }

    static let retryAfterDetailKey = "retry_after_seconds"

    /// The shortest rate-limit window of api.md section 1 (120 requests per
    /// minute): waiting that long is always enough when the limiter gave no
    /// better answer.
    static let defaultRetryAfterSeconds = 60

    static func rateLimited(retryAfterSeconds: Int) -> APIError {
        APIError(.rateLimited, details: [retryAfterDetailKey: .int(retryAfterSeconds)])
    }

    /// Seconds for the `Retry-After` header; nil unless the code is `RATE_LIMITED`.
    var retryAfterSeconds: Int? {
        guard code == .rateLimited, case .int(let seconds)? = details[Self.retryAfterDetailKey] else { return nil }
        return seconds
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
        case .tooManyRequests:
            let hinted = abort.headers.first(name: .retryAfter).flatMap { Int($0) }
            return hinted.map { APIError.rateLimited(retryAfterSeconds: $0) } ?? APIError(.rateLimited)
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
