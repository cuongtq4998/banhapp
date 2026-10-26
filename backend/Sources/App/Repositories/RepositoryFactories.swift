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

    static let postgres = RepositoryFactories(
        makeDatabaseProbe: { PostgresProbe(database: $0) }
    )
}
