import Vapor

/// `/v1/owner/settings`, `/districts` and `/slots` (api/07 10.13 to 10.16).
/// Owner only: the group adds authentication and `RequireRole(.owner)`.
struct OwnerSettingsRoutes: RouteCollection {
    /// Nil only in a local run without `SHOP_ID`; the routes then answer 503.
    let shopID: UUID?
    let assets: AssetURLBuilder

    func boot(routes: any RoutesBuilder) throws {
        let owner = routes.ownerGroup()
        let settings = owner.grouped("settings")
        settings.get(use: overview)
        settings.put("shop", use: saveShop)
        settings.get("ordering", use: ordering)
        settings.put("ordering", use: saveOrdering)
        settings.get("ordering", "impact", use: impact)
        owner.post("districts", use: createDistrict)
        owner.patch("districts", ":id", use: updateDistrict)
        owner.post("slots", use: createSlot)
        owner.patch("slots", ":id", use: updateSlot)
    }

    private func store(_ req: Request) throws -> SettingsStore {
        SettingsStore(database: try req.ownerDatabase(shopID: shopID).database)
    }

    private func settings(_ req: Request) throws -> OwnerSettingsService {
        let (_, shopID) = try req.ownerDatabase(shopID: shopID)
        let calendar = req.application.services.calendar
        return OwnerSettingsService(store: try store(req), calendar: calendar, assets: assets, shopID: shopID)
    }

    private func overview(_ req: Request) async throws -> SettingsResponse { try await settings(req).overview() }

    private func saveShop(_ req: Request) async throws -> ShopSection {
        try await settings(req).saveShop(try req.jsonObject(), principal: try req.owner())
    }

    private func ordering(_ req: Request) async throws -> OrderingSection { try await settings(req).ordering() }

    private func saveOrdering(_ req: Request) async throws -> OrderingSaved {
        try await settings(req).saveOrdering(try req.jsonObject(), principal: try req.owner())
    }

    private func impact(_ req: Request) async throws -> OrderingImpact {
        let pairs = Dictionary(OrderListQuery.pairs(of: req.url.query).map { ($0.0, $0.1) }, uniquingKeysWith: { first, _ in first })
        return try await settings(req).impact(query: pairs)
    }

    private func createDistrict(_ req: Request) async throws -> Response {
        let (_, shopID) = try req.ownerDatabase(shopID: shopID)
        let service = DistrictService(store: try store(req), clock: req.application.services.clock, shopID: shopID)
        return try await created(service.create(try req.jsonObject(), principal: try req.owner()))
    }

    private func updateDistrict(_ req: Request) async throws -> DistrictView {
        let (_, shopID) = try req.ownerDatabase(shopID: shopID)
        let service = DistrictService(store: try store(req), clock: req.application.services.clock, shopID: shopID)
        return try await service.update(id: try req.idParameter(), try req.jsonObject(), principal: try req.owner())
    }

    private func createSlot(_ req: Request) async throws -> Response {
        let (_, shopID) = try req.ownerDatabase(shopID: shopID)
        let service = SlotService(store: try store(req), clock: req.application.services.clock, shopID: shopID)
        return try await created(service.create(try req.jsonObject(), principal: try req.owner()))
    }

    private func updateSlot(_ req: Request) async throws -> SlotView {
        let (_, shopID) = try req.ownerDatabase(shopID: shopID)
        let service = SlotService(store: try store(req), clock: req.application.services.clock, shopID: shopID)
        return try await service.update(id: try req.idParameter(), try req.jsonObject(), principal: try req.owner())
    }

    private func created<T: Content>(_ value: T) throws -> Response {
        let response = Response(status: .created)
        try response.content.encode(value)
        return response
    }
}
