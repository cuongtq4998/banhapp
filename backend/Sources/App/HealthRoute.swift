import Vapor
import BanhContracts

extension HealthResponse: @retroactive Content {}

/// `GET /healthz` (api.md 4.4).
///
/// Shallow by default: no database query, so an uptime monitor polling every
/// few minutes never wakes the free-tier database (deployment.md section 1).
/// `?deep=1` adds a database round trip with a hard deadline.
enum HealthRoute {
    static let path: PathComponent = "healthz"
    static let deepQueryName = "deep"
    static let deepQueryEnabledValue = "1"

    static func register(on routes: RoutesBuilder) {
        routes.get(path) { req async throws -> Response in
            let deep = req.query[String.self, at: deepQueryName] == deepQueryEnabledValue
            let body = deep
                ? await deepStatus(req.application.databaseProbe)
                : HealthResponse(status: .ok)
            return try makeResponse(body)
        }
    }

    private static func deepStatus(_ probe: any DatabaseProbe) async -> HealthResponse {
        do {
            try await withDeadline(.seconds(AppConfig.Default.healthDeepTimeoutSeconds)) {
                try await probe.ping()
            }
            return HealthResponse(status: .ok)
        } catch {
            return HealthResponse(status: .degraded)
        }
    }

    private static func makeResponse(_ body: HealthResponse) throws -> Response {
        let status: HTTPResponseStatus = body.status == .ok ? .ok : .serviceUnavailable
        let response = Response(status: status)
        try response.content.encode(body, as: .json)
        // Monitors and proxies must never serve a cached verdict.
        response.headers.replaceOrAdd(name: .cacheControl, value: "no-store")
        return response
    }
}
