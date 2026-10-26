import Vapor

extension Request {
    private struct ErrorCodeKey: StorageKey {
        typealias Value = APIErrorCode
    }

    /// Set by `APIErrorMiddleware`, read by `AccessLogMiddleware`, which sits
    /// outside it and otherwise only sees a status.
    var answeredErrorCode: APIErrorCode? {
        get { storage[ErrorCodeKey.self] }
        set { storage[ErrorCodeKey.self] = newValue }
    }
}

/// The single place an error becomes a response. It replaces Vapor's default
/// `ErrorMiddleware`, whose body does not follow the contract.
struct APIErrorMiddleware: AsyncMiddleware {
    func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        do {
            return try await next.respond(to: request)
        } catch {
            let apiError = APIError.from(error)
            request.answeredErrorCode = apiError.code
            if apiError.code == .internalError {
                // Only the type name: descriptions of database or decoding
                // errors can carry SQL text or customer input (auth.md log policy).
                request.logger.error("Unhandled error", metadata: ["error_type": .string(String(reflecting: type(of: error)))])
            }
            let response = Response(status: apiError.status)
            try response.content.encode(apiError.makeBody(requestID: request.requestID), as: .json)
            for (name, value) in apiError.headers { response.headers.replaceOrAdd(name: name, value: value) }
            if let seconds = apiError.retryAfterSeconds {
                response.headers.replaceOrAdd(name: .retryAfter, value: String(seconds))
            }
            return response
        }
    }
}
