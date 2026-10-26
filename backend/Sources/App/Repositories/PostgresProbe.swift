import Fluent
import FluentSQL

/// Runs a trivial query on the database handle it is given.
struct PostgresProbe: DatabaseProbe {
    let database: any Database

    func ping() async throws {
        guard let sql = database as? any SQLDatabase else { throw DatabaseProbeError() }
        try await sql.raw("SELECT 1").run()
    }
}
