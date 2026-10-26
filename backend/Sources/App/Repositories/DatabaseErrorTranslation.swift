import PostgresNIO

/// Turns a failed database call into the error the API promises.
///
/// api.md section 5: a repository answers `SERVICE_UNAVAILABLE` when the
/// database cannot be reached, and the error middleware never reads driver
/// errors itself (they can carry SQL text or customer data). This is the one
/// place that looks at them, and it only classifies; nothing of the driver
/// error is copied into the result.
///
/// Kept as they are, so they surface as `INTERNAL_ERROR` and are logged by type:
/// - a statement the server rejected on a healthy connection (`.server`): a
///   defect in our SQL, not an outage;
/// - a row that does not decode: a mismatch between schema and code;
/// - cancellation of the surrounding task;
/// - a `CatalogRepositoryError`: the repository's own verdict (for example an
///   unknown shop id, a deployment mistake), not a database outage.
/// Everything else (refused or dropped connections, TLS failures, pool
/// timeouts, closed connections) means the database is not usable right now.
func translatingDatabaseErrors<Result>(_ work: () async throws -> Result) async throws -> Result {
    do {
        return try await work()
    } catch let error as APIError {
        throw error
    } catch let error as DecodingError {
        throw error
    } catch let error as CancellationError {
        throw error
    } catch let error as CatalogRepositoryError {
        throw error
    } catch let error as PSQLError where error.code == .server {
        throw error
    } catch {
        throw APIError(.serviceUnavailable)
    }
}
