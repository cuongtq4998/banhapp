import Vapor

/// The per-address limit of `POST /v1/orders` (10 per hour by default,
/// api.md section 1). It is a global middleware, not a route one, so it runs
/// before Vapor reads the body and a flood is refused before the 413 check
/// (api.md 4.3 step 1). Reads have their own budget (`RateLimitMiddleware`).
///
/// Every request that reaches it counts, a replay included; a request answered
/// 429 does not. The per-phone limit is separate and is counted in the database.
struct OrderRateLimitMiddleware: AsyncMiddleware {
    static let pathComponents = ["v1", "orders"]

    let limiter: FixedWindowRateLimiter
    let trustProxy: Bool

    func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        guard request.method == .POST, request.url.path.split(separator: "/").map(String.init) == Self.pathComponents else {
            return try await next.respond(to: request)
        }
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
