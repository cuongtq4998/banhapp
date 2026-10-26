import Vapor
import Fluent
import FluentSQL

/// One forward-only `NNNN_<slug>.sql` file wrapped as a Fluent migration, so
/// Fluent records the applied versions in `_fluent_migrations` (data-model.md
/// section 8).
struct SQLFileMigration: AsyncMigration {
    let fileName: String
    let statements: [String]

    // Fluent keys applied migrations by name; the file name is stable and
    // sorts in apply order.
    var name: String { fileName }

    struct ForwardOnlyError: Error, CustomStringConvertible {
        let fileName: String
        var description: String {
            "Migration \(fileName) is forward-only; restore from a backup instead of reverting"
        }
    }

    func prepare(on database: Database) async throws {
        // PostgreSQL DDL is transactional: a failing file leaves nothing behind.
        try await database.transaction { transaction in
            guard let sql = transaction as? SQLDatabase else { throw Abort(.internalServerError) }
            for statement in statements {
                try await sql.raw(SQLQueryString(statement)).run()
            }
        }
    }

    func revert(on database: Database) async throws {
        throw ForwardOnlyError(fileName: fileName)
    }
}

enum MigrationFiles {
    struct InvalidFileName: Error, CustomStringConvertible {
        let fileName: String
        var description: String { "Migration file name must look like 0001_name.sql: \(fileName)" }
    }

    static let fileNamePattern = #"^[0-9]{4}_[a-z0-9_]+\.sql$"#

    /// Reads every `.sql` file of `directory`, ordered by name.
    static func load(from directory: String) throws -> [SQLFileMigration] {
        let url = URL(fileURLWithPath: directory, isDirectory: true)
        let names = try FileManager.default.contentsOfDirectory(atPath: url.path)
            .filter { $0.hasSuffix(".sql") }
            .sorted()
        return try names.map { fileName in
            guard fileName.range(of: fileNamePattern, options: .regularExpression) != nil else {
                throw InvalidFileName(fileName: fileName)
            }
            let script = try String(contentsOf: url.appendingPathComponent(fileName), encoding: .utf8)
            return SQLFileMigration(fileName: fileName, statements: SQLScriptSplitter.statements(in: script))
        }
    }
}
