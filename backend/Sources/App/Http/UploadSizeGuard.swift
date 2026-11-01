import Vapor

/// Refuses a declared `Content-Length` above the upload limit with 413
/// before the route reads any of the body. It sits inside the owner group, so
/// authentication and the role are checked first and an anonymous caller can
/// never make the server collect megabytes. A body without a length is cut off
/// by the route's own limit while it is collected (ADR-0025).
struct UploadSizeGuard: AsyncMiddleware {
    func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        if let length = request.headers.first(name: .contentLength).flatMap({ Int($0) }), length > RequestLimits.maxUploadBytes {
            throw APIError(.payloadTooLarge)
        }
        return try await next.respond(to: request)
    }
}
