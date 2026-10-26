/// The one question the deep health check asks the database.
///
/// A protocol so tests can answer without a running PostgreSQL.
protocol DatabaseProbe: Sendable {
    func ping() async throws
}

struct DatabaseProbeError: Error {}

/// Probe used when no database URL is configured (local runs only).
struct UnconfiguredProbe: DatabaseProbe {
    func ping() async throws { throw DatabaseProbeError() }
}
