import Vapor

/// Routes of any signed-in account (api/06 10.6): who am I, sign out this
/// phone, sign out all other phones.
struct AdminRoutes: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let admin = routes.adminGroup()
        admin.get("me", use: me)
        admin.delete("session", use: signOut)
        admin.delete("sessions", "others", use: signOutOthers)
    }

    private func me(_ req: Request) async throws -> MeResponse {
        let principal = try Self.principal(req)
        return MeResponse(
            account: AccountSummary(name: principal.displayName, role: principal.role.rawValue),
            deviceID: principal.sessionID, serverDate: req.application.services.calendar.today().description
        )
    }

    private func signOut(_ req: Request) async throws -> HTTPStatus {
        try await service(req).signOut(try Self.principal(req))
        return .noContent
    }

    private func signOutOthers(_ req: Request) async throws -> HTTPStatus {
        try await service(req).signOutOthers(try Self.principal(req))
        return .noContent
    }

    private func service(_ req: Request) throws -> SessionService {
        guard let database = req.databaseHandle else { throw APIError(.serviceUnavailable) }
        let services = req.application.services
        return SessionService(store: services.repositories.makeAuthStore(database), clock: services.clock)
    }

    private static func principal(_ req: Request) throws -> AdminPrincipal {
        guard let principal = req.adminPrincipal else { throw APIError(.unauthenticated) }
        return principal
    }
}
