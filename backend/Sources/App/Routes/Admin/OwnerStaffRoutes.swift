import Vapor

/// `/v1/owner/staff` (api/07 10.18). Names and addresses are personal data:
/// nothing here is logged.
struct OwnerStaffRoutes: RouteCollection {
    /// Nil only in a local run without `SHOP_ID`; the routes then answer 503.
    let shopID: UUID?

    func boot(routes: any RoutesBuilder) throws {
        let staff = routes.ownerGroup().grouped("staff")
        staff.get(use: list)
        staff.post(use: add)
        staff.patch(":id", use: setActive)
    }

    private func service(_ req: Request) throws -> StaffService {
        let (database, shopID) = try req.ownerDatabase(shopID: shopID)
        return StaffService(store: SettingsStore(database: database), clock: req.application.services.clock, shopID: shopID)
    }

    private func list(_ req: Request) async throws -> StaffList { try await service(req).list() }

    private func add(_ req: Request) async throws -> Response {
        let account = try await service(req).add(try req.jsonObject(), principal: try req.owner())
        let response = Response(status: .created)
        try response.content.encode(account)
        return response
    }

    private func setActive(_ req: Request) async throws -> StaffView {
        try await service(req).setActive(id: try req.idParameter(), try req.jsonObject(), principal: try req.owner())
    }
}
