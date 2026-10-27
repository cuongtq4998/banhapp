import Vapor
import BanhContracts

/// `GET /v1/availability?cakes=N` (api.md 4.2). Parses the query, asks
/// `AvailabilityService`, answers uncached: the list moves with every order.
struct AvailabilityRoutes: RouteCollection {
    static let cacheControl = APIError.noStoreCacheControl
    static let cakesQueryName = AvailabilityService.cakesFieldName

    /// Nil only in a local run without `SHOP_ID` (see `CatalogRoutes`).
    let shopID: UUID?

    func boot(routes: any RoutesBuilder) throws {
        routes.get("v1", "availability", use: availability)
    }

    private func availability(_ req: Request) async throws -> Response {
        guard let shopID, let database = req.databaseHandle else { throw APIError(.serviceUnavailable) }
        let services = req.application.services
        let service = AvailabilityService(
            repository: services.repositories.makeAvailabilityRepository(database),
            calendar: services.calendar
        )
        // Anything that is not a whole number is treated like a missing value.
        let cakes = (try? req.query.get(String.self, at: Self.cakesQueryName)).flatMap { Int($0) }
        let body = try await service.makeAvailability(shopID: shopID, requestedCakes: cakes)

        let response = Response(status: .ok)
        try response.content.encode(body, as: .json)
        response.headers.replaceOrAdd(name: .cacheControl, value: Self.cacheControl)
        return response
    }
}
