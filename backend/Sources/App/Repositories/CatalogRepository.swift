import Foundation

/// Reads the shop configuration of ADR-0013. A protocol so the service and
/// the route are tested without PostgreSQL.
protocol CatalogRepository: Sendable {
    /// Active products, districts and slots in display order, plus the shop
    /// and its ordering parameters.
    /// - Throws: `APIError(.serviceUnavailable)` when the database cannot be
    ///   reached; `CatalogRepositoryError.shopNotFound` when `shopID` names no
    ///   shop (a deployment mistake, answered as an internal error).
    func loadCatalog(shopID: UUID) async throws -> CatalogSnapshot
}

enum CatalogRepositoryError: Error, Equatable {
    case shopNotFound
    /// The database handle cannot run SQL (never the case with PostgreSQL).
    case sqlNotSupported
}

/// Used when no database is configured (local runs only).
struct UnconfiguredCatalogRepository: CatalogRepository {
    func loadCatalog(shopID: UUID) async throws -> CatalogSnapshot {
        throw APIError(.serviceUnavailable)
    }
}
