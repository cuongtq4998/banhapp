import Vapor
import BanhContracts

/// `POST /v1/orders` (api.md 4.3). Parses headers and body, asks
/// `OrderPlacementService`, encodes the answer. Nothing here logs the body:
/// name, phone, address and note never reach a log (auth.md).
struct OrderRoutes: RouteCollection {
    /// Nil only in a local run without `SHOP_ID` (see `CatalogRoutes`).
    let shopID: UUID?
    let policy: OrderPolicy

    func boot(routes: any RoutesBuilder) throws {
        routes.post(OrderRateLimitMiddleware.pathComponents.map { PathComponent(stringLiteral: $0) }, use: place)
    }

    private func place(_ req: Request) async throws -> Response {
        let headers = try OrderHeaders.parse(req.headers)
        guard policy.isEnabled else { throw APIError(.orderingPaused) }
        guard let shopID, let database = req.databaseHandle else { throw APIError(.serviceUnavailable) }

        let request = try OrderRequestParser.parse(try Self.decodeBody(req))
        let services = req.application.services
        let service = OrderPlacementService(
            repository: services.repositories.makeOrderRepository(database),
            calendar: services.calendar,
            orderCodes: services.orderCodes,
            maxOrdersPerPhonePerDay: policy.perPhonePerDay
        )
        let result = try await service.place(OrderCommand(
            shopID: shopID, request: request, idempotencyKey: headers.idempotencyKey,
            platform: headers.platform, appVersion: headers.appVersion
        ))
        return try Self.makeResponse(result)
    }

    /// A body that is not JSON is a validation failure without fields.
    private static func decodeBody(_ req: Request) throws -> JSONValue {
        guard let buffer = req.body.data,
              let json = try? JSONDecoder().decode(JSONValue.self, from: Data(buffer.readableBytesView)) else {
            throw APIError(.validationFailed)
        }
        return json
    }

    private static func makeResponse(_ result: OrderPlacementResult) throws -> Response {
        let placed: PlacedOrder
        let status: HTTPResponseStatus
        switch result {
        case .created(let order): (placed, status) = (order, .created)
        case .replayed(let order): (placed, status) = (order, .ok)
        }
        let response = Response(status: status)
        // Sorted keys: a replay must be byte-for-byte the original answer.
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        try response.content.encode(OrderCreatedResponse(orderCode: placed.orderCode, createdAt: placed.createdAt), using: encoder)
        response.headers.replaceOrAdd(name: .cacheControl, value: APIError.noStoreCacheControl)
        if case .replayed = result { response.headers.replaceOrAdd(name: OrderHeaders.replayHeaderName, value: "true") }
        return response
    }
}
