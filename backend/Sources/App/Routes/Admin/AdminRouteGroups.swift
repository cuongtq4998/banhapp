import Vapor

/// The only way to open a route group under `/v1/auth`, `/v1/admin` or
/// `/v1/owner`. A route registered through `adminGroup()` or `ownerGroup()`
/// is authenticated and role-checked by construction; the coverage test fails
/// for any such route registered outside them.
extension RoutesBuilder {
    func authGroup() -> any RoutesBuilder {
        grouped("v1", "auth").grouped(AdminResponseHeadersMiddleware())
    }

    /// Any signed-in owner or staff account.
    func adminGroup() -> any RoutesBuilder {
        grouped("v1", "admin")
            .grouped(AdminResponseHeadersMiddleware(), AdminAuthMiddleware(), RequireRole(.owner, .staff))
    }

    /// Owner only.
    func ownerGroup() -> any RoutesBuilder {
        grouped("v1", "owner")
            .grouped(AdminResponseHeadersMiddleware(), AdminAuthMiddleware(), RequireRole(.owner))
    }
}
