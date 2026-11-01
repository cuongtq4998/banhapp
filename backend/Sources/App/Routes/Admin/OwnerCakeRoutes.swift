import Vapor

/// `/v1/owner/cakes` (api/07 10.17). Owner only. The create route is the one
/// multipart route: its own body limit, and the declared length is checked
/// after the role and before the body is read.
struct OwnerCakeRoutes: RouteCollection {
    /// Nil only in a local run without `SHOP_ID`; the routes then answer 503.
    let shopID: UUID?
    let assets: AssetURLBuilder
    private let gate = UploadGate()

    init(shopID: UUID?, assets: AssetURLBuilder) {
        self.shopID = shopID
        self.assets = assets
    }

    func boot(routes: any RoutesBuilder) throws {
        let owner = routes.ownerGroup()
        owner.grouped(UploadSizeGuard()).on(.POST, "cakes", body: .collect(maxSize: RequestLimits.maxUploadSize), use: create)
        owner.patch("cakes", ":id", use: update)
        owner.delete("cakes", ":id", use: remove)
    }

    private func service(_ req: Request) throws -> CakeService {
        let (database, shopID) = try req.ownerDatabase(shopID: shopID)
        return CakeService(store: SettingsStore(database: database), clock: req.application.services.clock, assets: assets, shopID: shopID)
    }

    private func create(_ req: Request) async throws -> Response {
        let service = try service(req), principal = try req.owner()
        let body = req.body.data ?? ByteBuffer()
        let form = try MultipartFields(body: body, contentType: req.headers.contentType)
        let cake = try await gate.run { try await service.create(form, principal: principal) }
        let response = Response(status: .created)
        try response.content.encode(cake)
        return response
    }

    private func update(_ req: Request) async throws -> CakeView {
        try await service(req).update(id: try req.idParameter(), try req.jsonObject(), principal: try req.owner())
    }

    private func remove(_ req: Request) async throws -> HTTPStatus {
        try await service(req).remove(id: try req.idParameter(), principal: try req.owner())
        return .noContent
    }
}
