import Vapor
import BanhContracts

/// `/v1/admin/orders` (api/06 10.9 to 10.11). Both roles may use all three;
/// the group adds authentication and `RequireRole`. Order data is personal
/// data: nothing here is logged.
struct AdminOrderRoutes: RouteCollection {
    /// Nil only in a local run without `SHOP_ID`; the routes then answer 503.
    let shopID: UUID?

    func boot(routes: any RoutesBuilder) throws {
        let orders = routes.adminGroup().grouped("orders")
        orders.get(use: list)
        orders.get(":code", use: detail)
        orders.post(":code", "status", use: changeStatus)
        orders.put(":code", "expected-delivery-date", use: moveDate)
        orders.put(":code", "delivery-fee", use: correctFee)
    }

    private func service(_ req: Request) throws -> AdminOrderService {
        guard let shopID, let database = req.databaseHandle else { throw APIError(.serviceUnavailable) }
        return AdminOrderService(store: AdminOrderStore(database: database), calendar: req.application.services.calendar, shopID: shopID)
    }

    private func principal(_ req: Request) throws -> AdminPrincipal {
        guard let principal = req.adminPrincipal else { throw APIError(.unauthenticated) }
        return principal
    }

    /// A code outside the format cannot exist: same answer as an unknown code.
    private func code(_ req: Request) throws -> String {
        guard let code = req.parameters.get("code"),
              code.range(of: #"^BT-[2-9A-HJKMNP-Z]{6}$"#, options: .regularExpression) != nil else { throw APIError(.orderNotFound) }
        return code
    }

    private func list(_ req: Request) async throws -> OrderListResponse {
        let service = try service(req), principal = try principal(req)
        let query = try OrderListQuery.parse(OrderListQuery.pairs(of: req.url.query), calendar: service.calendar)
        return try await service.list(query, principal: principal)
    }

    private func detail(_ req: Request) async throws -> OrderDetail {
        try await service(req).detail(code: try code(req), principal: try principal(req))
    }

    private func changeStatus(_ req: Request) async throws -> Response {
        let service = try service(req), principal = try principal(req), code = try code(req)
        let body = try body(req)
        return try reply(try await service.changeStatus(code: code, body: body, principal: principal))
    }

    private func moveDate(_ req: Request) async throws -> Response {
        let service = try service(req), principal = try principal(req), code = try code(req)
        return try reply(try await service.moveDate(code: code, body: try body(req), principal: principal))
    }

    private func correctFee(_ req: Request) async throws -> Response {
        let service = try service(req), principal = try principal(req), code = try code(req)
        return try reply(try await service.correctFee(code: code, body: try body(req), principal: principal))
    }

    private func body(_ req: Request) throws -> [String: JSONValue] {
        guard let body = try? req.content.decode([String: JSONValue].self) else { throw APIError(.validationFailed) }
        return body
    }

    private func reply(_ result: StatusChangeResult) throws -> Response {
        let response = Response(status: .ok)
        try response.content.encode(result.order)
        if result.replayed { response.headers.replaceOrAdd(name: "Idempotent-Replay", value: "true") }
        return response
    }
}
