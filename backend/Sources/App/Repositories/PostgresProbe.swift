import Vapor
import Fluent
import FluentSQL

/// Runs a trivial query on the configured Fluent database.
struct PostgresProbe: DatabaseProbe {
    let app: Application

    func ping() async throws {
        guard let sql = app.db as? SQLDatabase else { throw DatabaseProbeError() }
        try await sql.raw("SELECT 1").run()
    }
}
