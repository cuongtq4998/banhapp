import Vapor

/// One log line per request: method, route template, status, duration.
///
/// Log policy (auth.md): no name, phone, address or note, so no query string,
/// headers, body or client address. The route template (`/v1/orders`) is
/// logged instead of the raw path, which also keeps unmatched paths, typed by
/// anyone, out of the logs.
struct AccessLogMiddleware: AsyncMiddleware {
    static let unmatchedRoute = "-"

    func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        let clock = ContinuousClock()
        let started = clock.now
        do {
            let response = try await next.respond(to: request)
            log(request, status: response.status, since: started, clock: clock)
            return response
        } catch {
            // Only reached when the error middleware itself failed.
            log(request, status: .internalServerError, since: started, clock: clock)
            throw error
        }
    }

    private func log(_ request: Request, status: HTTPResponseStatus, since started: ContinuousClock.Instant, clock: ContinuousClock) {
        let elapsed = clock.now - started
        let milliseconds = Int(elapsed.components.seconds * 1_000 + elapsed.components.attoseconds / 1_000_000_000_000_000)
        let route = request.route.map { "/" + $0.path.map(\.description).joined(separator: "/") } ?? Self.unmatchedRoute
        request.logger.info("request", metadata: [
            "method": .string(request.method.rawValue),
            "route": .string(route),
            "status": .stringConvertible(status.code),
            "duration_ms": .stringConvertible(milliseconds)
        ])
    }
}
