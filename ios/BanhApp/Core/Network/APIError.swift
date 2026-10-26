/// Every way a call to the backend can fail, so callers branch on cases and never on message text.
nonisolated enum APIError: Error, Equatable, Sendable {
    /// No connection, or the host could not be reached.
    case networkUnavailable
    case timeout
    /// The server answered with the contract error body (api.md section 1).
    /// `messageKey` is a UI document key; the app shows its own text for it, never server text.
    case service(code: APIErrorCode, messageKey: String, httpStatus: Int, requestID: String?)
    /// 429: the caller may try again after `retryAfterSeconds`.
    case rateLimited(retryAfterSeconds: Int, requestID: String?)
    /// A success status with a body that does not match the contract.
    case invalidResponse

    /// True when repeating the same request can succeed: the free host may be waking up (ADR-0003).
    var isTransient: Bool {
        switch self {
        case .networkUnavailable, .timeout: true
        case .service, .rateLimited, .invalidResponse: false
        }
    }
}
