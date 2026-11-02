import Vapor
import BanhContracts

/// `POST /v1/orders/lookup` (api/10). Parses, limits, asks `LookupService`.
/// Nothing here logs the body, the phone or the cursor.
struct LookupRoutes: RouteCollection {
    static let path: [PathComponent] = ["v1", "orders", "lookup"]
    static let installationHeader = "X-Installation-Id"
    private static let phoneField = "phone"
    private static let cursorField = "cursor"

    private struct Body: Decodable {
        let phone: String?
        let cursor: String?
    }

    func boot(routes: any RoutesBuilder) throws {
        routes.post(Self.path, use: lookup)
    }

    private func lookup(_ req: Request) async throws -> Response {
        let started = ContinuousClock.now
        let services = req.application.services
        let policy = services.lookup
        let body = try Self.decodeBody(req)
        // Limiter first: an invalid phone never reaches the database.
        let phone = try Self.normalisedPhone(body.phone)
        let hasher = LookupKeyHasher(secret: policy.keySecret)
        try services.lookupGuard.check(
            phoneKey: hasher.hash(phone), addressKey: hasher.hash(ClientAddress.lookupKey(
                for: req, headerName: policy.clientAddressHeader, trustedHops: policy.trustedProxyHops)),
            installationKey: req.headers.first(name: Self.installationHeader).map(hasher.hash),
            hasCursor: body.cursor != nil, cursorIsValid: body.cursor.map { LookupCursor.decode($0, phone: phone, hasher: hasher) != nil } ?? false,
            at: services.clock.now()
        )
        guard let database = req.databaseHandle else { throw APIError(.serviceUnavailable) }
        let service = LookupService(store: services.makeLookupStore(database), policy: policy, hasher: hasher, clock: services.clock)
        let answer: LookupAnswer
        do { answer = try await service.page(phone: phone, cursorText: body.cursor) } catch LookupError.cursorInvalid {
            throw Self.invalid(Self.cursorField, "CURSOR_INVALID")
        }
        try await Self.waitForFloor(since: started, policy: policy, services: services, logger: req.logger)
        let response = Response(status: .ok)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try response.content.encode(answer, using: encoder)
        response.headers.replaceOrAdd(name: .cacheControl, value: APIError.noStoreCacheControl)
        return response
    }

    private static func decodeBody(_ req: Request) throws -> Body {
        guard let buffer = req.body.data, let body = try? JSONDecoder().decode(Body.self, from: Data(buffer.readableBytesView)) else {
            throw APIError(.validationFailed)
        }
        return body
    }

    private static func normalisedPhone(_ text: String?) throws -> String {
        guard let text, !text.trimmingCharacters(in: .whitespaces).isEmpty else { throw invalid(phoneField, "PHONE_REQUIRED") }
        guard let phone = PhoneNumber.normalise(text) else { throw invalid(phoneField, "PHONE_INVALID") }
        return phone
    }

    private static func invalid(_ field: String, _ code: String) -> APIError {
        APIError(.validationFailed, fields: [.init(field: field, code: code, messageKey: "ERR_FIELD_" + (code.split(separator: "_").last ?? "INVALID"))])
    }

    /// Same duration for empty and full answers; a slow one is counted.
    private static func waitForFloor(since started: ContinuousClock.Instant, policy: LookupPolicy, services: AppServices, logger: Logger) async throws {
        let floor = Duration.milliseconds(policy.floorMilliseconds)
        let elapsed = ContinuousClock.now - started
        if elapsed < floor { try await Task.sleep(for: floor - elapsed) } else {
            services.lookupMetrics.recordFloorExceeded(
                durationMilliseconds: Int(elapsed.components.seconds * 1000 + elapsed.components.attoseconds / 1_000_000_000_000_000),
                floorMilliseconds: policy.floorMilliseconds, logger: logger)
        }
    }
}
