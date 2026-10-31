import Fluent

/// Builds repositories on a database handle chosen by the caller.
///
/// A factory, not a connected repository, because the handle decides the
/// unit of work: a request handle for plain reads, a transaction handle when
/// two repositories must commit together (ADR-0008: the `day_load` update and
/// the order insert). New repositories add one member each, in the slice that
/// introduces them.
struct RepositoryFactories: Sendable {
    var makeDatabaseProbe: @Sendable (any Database) -> any DatabaseProbe
    var makeCatalogRepository: @Sendable (any Database) -> any CatalogRepository
    var makeAvailabilityRepository: @Sendable (any Database) -> any AvailabilityRepository
    var makeOrderRepository: @Sendable (any Database) -> any OrderRepository
    var makeAdminSessionLookup: @Sendable (any Database) -> any AdminSessionLookup
    var makeAuthStore: @Sendable (any Database) -> AuthStore

    static let postgres = RepositoryFactories(
        makeDatabaseProbe: { PostgresProbe(database: $0) },
        makeCatalogRepository: { PostgresCatalogRepository(database: $0) },
        makeAvailabilityRepository: { PostgresAvailabilityRepository(database: $0) },
        makeOrderRepository: { PostgresOrderRepository(database: $0) },
        makeAdminSessionLookup: { AuthStore(database: $0) },
        makeAuthStore: { AuthStore(database: $0) }
    )
}
