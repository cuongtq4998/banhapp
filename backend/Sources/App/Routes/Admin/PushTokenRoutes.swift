import Vapor
import BanhContracts

/// `PUT /v1/admin/push-token` (api/06 10.8). Owner and staff; the token is
/// stored on the calling session only. There is no `DELETE`: sign-out, sign
/// out of other phones and deactivation clear it on the server.
struct PushTokenRoutes: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        routes.adminGroup().put("push-token", use: register)
    }

    private func register(_ req: Request) async throws -> HTTPStatus {
        guard let principal = req.adminPrincipal else { throw APIError(.unauthenticated) }
        guard let body = try? req.content.decode([String: JSONValue].self) else { throw APIError(.validationFailed) }
        let parsed = try PushTokenRequest.parse(body)
        guard let database = req.databaseHandle else { throw APIError(.serviceUnavailable) }
        let services = req.application.services
        let stored = try await services.repositories.makePushStore(database).register(
            sessionID: principal.sessionID, platform: parsed.platform.rawValue,
            token: parsed.token, apnsEnvironment: parsed.apnsEnvironment
        )
        // The session is live (the middleware just checked), so a miss means the
        // body names another platform than the one this phone signed in with.
        guard stored else {
            throw APIError(.validationFailed, fields: [.init(field: "platform", code: "PLATFORM_MISMATCH", messageKey: APIErrorCode.genericMessageKey)])
        }
        return .noContent
    }
}
