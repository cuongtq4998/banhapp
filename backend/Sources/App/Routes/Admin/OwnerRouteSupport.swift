import Vapor
import Fluent
import BanhContracts

/// Small helpers shared by the `/v1/owner` route files.
extension Request {
    /// The signed-in account; the group's middleware has set it.
    func owner() throws -> AdminPrincipal {
        guard let principal = adminPrincipal else { throw APIError(.unauthenticated) }
        return principal
    }

    /// The JSON object of the body; anything else is a plain `VALIDATION_FAILED`.
    func jsonObject() throws -> [String: JSONValue] {
        guard let body = try? content.decode([String: JSONValue].self) else { throw APIError(.validationFailed) }
        return body
    }

    /// An id in the path; one that cannot be an id names nothing: 404.
    func idParameter(_ name: String = "id") throws -> UUID {
        guard let id = parameters.get(name).flatMap(UUID.init(uuidString:)) else { throw APIError(.notFound) }
        return id
    }

    /// Database handle and shop of an owner route, or 503 in a local run without them.
    func ownerDatabase(shopID: UUID?) throws -> (database: any Database, shopID: UUID) {
        guard let shopID, let database = databaseHandle else { throw APIError(.serviceUnavailable) }
        return (database, shopID)
    }
}
