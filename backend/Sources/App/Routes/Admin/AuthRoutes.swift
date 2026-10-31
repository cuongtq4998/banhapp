import Vapor
import BanhContracts

/// `/v1/auth/*` (api/05 10.1 to 10.3). Parses, asks the services, encodes.
/// No e-mail address, code or token reaches a log from here.
struct AuthRoutes: RouteCollection {
    /// Nil only in a local run without `SHOP_ID`; the routes then answer 503.
    let shopID: UUID?
    let trustProxy: Bool
    // In memory and per instance: an extra on top of the per-address limits (auth.md 4.2).
    let codeLimiter = FixedWindowRateLimiter(limit: AuthPolicy.codeRequestsPerClientPerHour, windowSeconds: AuthPolicy.hourWindow)
    let authLimiter = FixedWindowRateLimiter(limit: AuthPolicy.authRequestsPerClientPerHour, windowSeconds: AuthPolicy.hourWindow)

    func boot(routes: any RoutesBuilder) throws {
        let auth = routes.authGroup()
        auth.post("code-requests", use: requestCode)
        auth.post("sessions", use: signIn)
        auth.post("refresh", use: refresh)
    }

    private struct Context {
        let config: AdminAuthConfig
        let shopID: UUID
        let store: AuthStore
        let services: AppServices
    }

    private func context(_ req: Request) throws -> Context {
        let services = req.application.services
        guard let config = services.adminAuth, let shopID, let database = req.databaseHandle else {
            throw APIError(.serviceUnavailable)
        }
        return Context(config: config, shopID: shopID, store: services.repositories.makeAuthStore(database), services: services)
    }

    private func requestCode(_ req: Request) async throws -> Response {
        let context = try context(req)
        let decision = codeLimiter.registerRequest(
            clientKey: ClientAddress.key(for: req, trustProxy: trustProxy), at: context.services.clock.now()
        )
        guard decision.isAllowed else { throw APIError.waiting(.codeRequestLimit, seconds: decision.retryAfterSeconds) }

        let body = try Self.decode(CodeRequestBody.self, req)
        guard let email = EmailAddress(body.email) else { throw Self.invalid("email", "EMAIL_INVALID") }
        let service = CodeRequestService(
            store: context.store, clock: context.services.clock, codes: SignInCodes(pepper: context.config.pepper),
            shopID: context.shopID, maxPerDay: context.config.emailMaxPerDay
        )
        if let mail = try await service.requestCode(email) {
            let store = AuthStore(database: req.application.db), clock = context.services.clock
            context.services.mail.sendAfterResponse(
                MailTemplates.signInCode(to: mail.to, code: mail.code), logger: req.logger,
                onSent: { try? await store.markMailSent(codeID: mail.codeID, at: clock.now()) }
            )
        }
        let response = Response(status: .accepted)
        try response.content.encode(CodeRequestResponse(
            resendAfterSeconds: Int(AuthPolicy.resendWait), expiresInSeconds: Int(AuthPolicy.codeLifetime)
        ))
        return response
    }

    private func signIn(_ req: Request) async throws -> Response {
        let context = try context(req)
        try countAuthRequest(req, context)
        let client = try ClientHeaders.parse(req.headers)
        let body = try Self.decode(SignInBody.self, req)
        guard let email = EmailAddress(body.email) else { throw Self.invalid("email", "EMAIL_INVALID") }
        guard SignInCodes.isWellFormed(body.code) else { throw Self.invalid("code", "CODE_FORMAT") }
        guard let installationID = UUID(uuidString: body.installationID) else { throw Self.invalid("installation_id", "INSTALLATION_ID_INVALID") }
        let name = body.deviceName.trimmingCharacters(in: .whitespaces)
        guard (1...AuthPolicy.maxDeviceNameLength).contains(name.unicodeScalars.count),
              !name.unicodeScalars.contains(where: { $0.properties.generalCategory == .control }) else {
            throw Self.invalid("device_name", "DEVICE_NAME_INVALID")
        }
        let service = SignInVerifyService(
            store: context.store, clock: context.services.clock, codes: SignInCodes(pepper: context.config.pepper)
        )
        let result = try await service.verify(SignInAttempt(
            email: email, code: body.code, installationID: installationID, platform: client.platform, deviceName: name
        ))
        if let notice = result.notice {
            context.services.mail.sendAfterResponse(
                MailTemplates.newDeviceNotice(to: notice.to, deviceName: notice.deviceName, at: notice.at), logger: req.logger
            )
        }
        let response = Response(status: .created)
        try response.content.encode(SignInResponse(
            accessToken: result.access.text, refreshToken: result.refresh.text,
            accessExpiresIn: Int(AuthPolicy.accessLifetime), deviceID: result.sessionID,
            account: AccountSummary(name: result.accountName, role: result.role.rawValue), serverDate: result.serverDate
        ))
        return response
    }

    private func refresh(_ req: Request) async throws -> Response {
        let context = try context(req)
        try countAuthRequest(req, context)
        let body = try Self.decode(RefreshBody.self, req)
        // An unreadable credential is treated like an unknown one: sign in again.
        guard let token = SessionToken.parse(body.refreshToken) else { throw APIError(.sessionRevoked) }
        let pair = try await SessionService(store: context.store, clock: context.services.clock).refresh(token)
        let response = Response(status: .ok)
        try response.content.encode(RefreshResponse(
            accessToken: pair.access.text, refreshToken: pair.refresh.text, accessExpiresIn: Int(AuthPolicy.accessLifetime)
        ))
        return response
    }

    private func countAuthRequest(_ req: Request, _ context: Context) throws {
        let decision = authLimiter.registerRequest(
            clientKey: ClientAddress.key(for: req, trustProxy: trustProxy), at: context.services.clock.now()
        )
        guard decision.isAllowed else { throw APIError.rateLimited(retryAfterSeconds: decision.retryAfterSeconds) }
    }

    private static func decode<Body: Decodable>(_ type: Body.Type, _ req: Request) throws -> Body {
        guard let body = try? req.content.decode(type) else { throw APIError(.validationFailed) }
        return body
    }

    private static func invalid(_ field: String, _ code: String) -> APIError {
        APIError(.validationFailed, fields: [.init(field: field, code: code, messageKey: APIErrorCode.genericMessageKey)])
    }
}
