import Vapor

/// One log line per request: method, route template, status, duration, error
/// code, platform and app version (deployment.md section 7).
///
/// Log policy (auth.md): no name, phone, address or note, so no query string,
/// body or client address. The route template (`/v1/orders`) is logged
/// instead of the raw path, which also keeps unmatched paths, typed by
/// anyone, out of the logs. Platform and app version come from client
/// headers, so they are logged only when they match a strict pattern
/// (`ClientHeaderLog`); anything else is `-`, which blocks log injection.
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
            "duration_ms": .stringConvertible(milliseconds),
            "error_code": .string(request.answeredErrorCode?.rawValue ?? ClientHeaderLog.absent),
            "platform": .string(ClientHeaderLog.platform(of: request)),
            "app_version": .string(ClientHeaderLog.appVersion(of: request))
        ])
    }
}

/// Reads the client-supplied `X-Platform` and `X-App-Version` for the log.
enum ClientHeaderLog {
    static let absent = "-"
    static let platformHeader = "X-Platform"
    static let appVersionHeader = "X-App-Version"

    // api.md section 1: `ios` or `android`; a semantic version (numbers only,
    // bounded length, so a header can never add text to a log line).
    // Computed: `Regex` is not Sendable, so it cannot be a shared static.
    private static var platformPattern: Regex<Substring> { /ios|android/ }
    private static var appVersionPattern: Regex<Substring> { /[0-9]{1,5}\.[0-9]{1,5}\.[0-9]{1,5}/ }

    static func platform(of request: Request) -> String {
        validated(request.headers.first(name: platformHeader), against: platformPattern)
    }

    static func appVersion(of request: Request) -> String {
        validated(request.headers.first(name: appVersionHeader), against: appVersionPattern)
    }

    private static func validated(_ value: String?, against pattern: Regex<Substring>) -> String {
        guard let value, value.wholeMatch(of: pattern) != nil else { return absent }
        return value
    }
}
