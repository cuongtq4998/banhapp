import Vapor

extension Request {
    private struct RequestIDKey: StorageKey {
        typealias Value = UUID
    }

    /// Created on first use, so a log line or error body written before (or
    /// without) `RequestIDMiddleware` still gets one id per request.
    var requestID: UUID {
        if let existing = storage[RequestIDKey.self] { return existing }
        let created = UUID()
        storage[RequestIDKey.self] = created
        return created
    }
}

enum RequestIDLog {
    /// Vapor already tags every request logger with its own `request-id`;
    /// reusing the key replaces that value, so a log line has exactly one id,
    /// the one the client sees in `X-Request-Id`.
    static let metadataKey = "request-id"
    static let headerName = "X-Request-Id"
}

/// Gives each request an id (api.md section 1: `X-Request-Id`, echoed in
/// logs). The id is always generated here, never taken from the client, so a
/// caller cannot inject text into the logs.
struct RequestIDMiddleware: AsyncMiddleware {
    func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        let id = request.requestID
        request.logger[metadataKey: RequestIDLog.metadataKey] = .string(id.uuidString)
        let response = try await next.respond(to: request)
        response.headers.replaceOrAdd(name: RequestIDLog.headerName, value: id.uuidString)
        return response
    }
}
