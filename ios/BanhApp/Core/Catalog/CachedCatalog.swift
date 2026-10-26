import BanhContracts
import Foundation

/// The last good catalog with what is needed to revalidate it and to judge its age (ADR-0011).
nonisolated struct CachedCatalog: Codable, Equatable, Sendable {
    /// A cache older than this counts as no cache (ADR-0011). Exactly this old is still valid.
    static let maxAge: TimeInterval = 7 * 24 * 60 * 60

    let catalog: CatalogResponse
    let etag: String?
    let fetchedAt: Date

    func isUsable(at now: Date) -> Bool {
        now.timeIntervalSince(fetchedAt) <= Self.maxAge
    }

    /// The server confirmed this copy is current, so its age starts again.
    func confirmed(at now: Date) -> CachedCatalog {
        CachedCatalog(catalog: catalog, etag: etag, fetchedAt: now)
    }
}
