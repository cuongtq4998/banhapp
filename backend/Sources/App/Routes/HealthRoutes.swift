import Vapor
import BanhContracts

extension HealthResponse: @retroactive Content {}

/// `GET /healthz` (api.md 4.4). Parses the query, asks `HealthService`,
/// encodes the verdict.
struct HealthRoutes: RouteCollection {
    static let path: PathComponent = "healthz"
    static let deepQueryName = "deep"
    static let deepQueryEnabledValue = "1"

    func boot(routes: any RoutesBuilder) throws {
        routes.get(Self.path, use: health)
    }

    private func health(_ req: Request) async throws -> Response {
        let probe = req.databaseHandle.map(req.application.services.repositories.makeDatabaseProbe)
            ?? UnconfiguredProbe()
        let service = HealthService(
            probe: probe,
            deepTimeout: .seconds(AppConfig.Default.healthDeepTimeoutSeconds)
        )
        let deep = req.query[String.self, at: Self.deepQueryName] == Self.deepQueryEnabledValue
        let body = deep ? await service.deepStatus() : service.shallowStatus()
        return try makeResponse(body)
    }

    private func makeResponse(_ body: HealthResponse) throws -> Response {
        let status: HTTPResponseStatus = body.status == .ok ? .ok : .serviceUnavailable
        let response = Response(status: status)
        try response.content.encode(body, as: .json)
        // Monitors and proxies must never serve a cached verdict.
        response.headers.replaceOrAdd(name: .cacheControl, value: "no-store")
        return response
    }
}
