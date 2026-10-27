import Foundation

/// Reads what the availability list needs. A protocol so the service and the
/// route are tested without PostgreSQL. The slot is deliberately absent from
/// every method: a slot never changes availability (BR-11).
protocol AvailabilityRepository: Sendable {
    /// - Throws: `APIError(.serviceUnavailable)` when the database cannot be
    ///   reached; `CatalogRepositoryError.shopNotFound` when `shopID` names no
    ///   shop.
    func loadRules(shopID: UUID) async throws -> AvailabilityRules

    /// Cakes already accepted per date, for the dates in `from...through`
    /// (inclusive). A date without a `day_load` row is simply missing: nothing
    /// is accepted there yet.
    func loadAcceptedCakes(shopID: UUID, from: BusinessDate, through: BusinessDate) async throws -> [BusinessDate: Int]
}
