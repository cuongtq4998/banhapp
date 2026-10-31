import Vapor

extension Request {
    private struct PrincipalKey: StorageKey { typealias Value = AdminPrincipal }
    private struct RoleCheckedKey: StorageKey { typealias Value = Bool }

    var adminPrincipal: AdminPrincipal? {
        get { storage[PrincipalKey.self] }
        set { storage[PrincipalKey.self] = newValue }
    }

    /// Set by `RequireRole`; the route-coverage test reads it.
    var roleWasChecked: Bool {
        get { storage[RoleCheckedKey.self] ?? false }
        set { storage[RoleCheckedKey.self] = newValue }
    }
}

/// Authenticates `Authorization: Bearer <access token>` against the session row
/// on every request, so revocation is immediate (auth.md section 2). Nothing
/// in the answers says whether an account or a session exists.
struct AdminAuthMiddleware: AsyncMiddleware {
    func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        guard let text = request.headers.bearerAuthorization?.token,
              let token = SessionToken.parse(text), token.kind == .access else { throw APIError(.unauthenticated) }
        guard let database = request.databaseHandle else { throw APIError(.serviceUnavailable) }
        let services = request.application.services
        let lookup = services.repositories.makeAdminSessionLookup(database)
        let record = try await translatingDatabaseErrors { try await lookup.findSession(id: token.sessionID) }
        guard let record, record.accessHash == token.hash else { throw APIError(.unauthenticated) }

        let now = services.clock.now()
        if record.isRevoked || !record.accountActive { throw APIError(.sessionRevoked) }
        if now >= record.refreshExpiresAt { throw APIError(.sessionExpired) }
        // Valid strictly before the expiry instant.
        if now >= record.accessExpiresAt { throw APIError(.accessTokenExpired) }

        let client = try ClientHeaders.parse(request.headers)
        request.adminPrincipal = AdminPrincipal(
            sessionID: record.sessionID, accountID: record.accountID, role: record.role,
            isReview: record.isReview, displayName: record.displayName, platform: client.platform
        )
        return try await next.respond(to: request)
    }
}

/// Role gate of a route group (BR-1). Runs after `AdminAuthMiddleware`.
struct RequireRole: AsyncMiddleware {
    let allowed: Set<AccountRole>

    init(_ roles: AccountRole...) { allowed = Set(roles) }

    func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        request.roleWasChecked = true
        guard let principal = request.adminPrincipal, allowed.contains(principal.role) else { throw APIError(.forbidden) }
        return try await next.respond(to: request)
    }
}
