import Vapor

/// Answers 429 `RATE_LIMITED` with `Retry-After` when a client exceeds its
/// window (api.md section 1, ADR-0014). The `APIError` it throws is turned
/// into the response, and the header, by `APIErrorMiddleware`, so this type
/// does not know the error format.
struct RateLimitMiddleware: AsyncMiddleware {
    let limiter: FixedWindowRateLimiter
    let trustProxy: Bool

    /// Reads share one budget; writes (orders) have their own limits.
    private static let countedMethods: [HTTPMethod] = [.GET, .HEAD]

    func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        guard Self.countedMethods.contains(request.method) else { return try await next.respond(to: request) }
        let decision = limiter.registerRequest(
            clientKey: ClientAddress.key(for: request, trustProxy: trustProxy),
            at: request.application.services.clock.now()
        )
        guard decision.isAllowed else {
            throw APIError.rateLimited(retryAfterSeconds: decision.retryAfterSeconds)
        }
        return try await next.respond(to: request)
    }
}
