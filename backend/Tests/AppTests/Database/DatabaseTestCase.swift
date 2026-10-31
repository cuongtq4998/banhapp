import XCTVapor
import Fluent
import FluentSQL
@testable import App

/// Base class for tests against a real PostgreSQL. They run only when
/// `DATABASE_MIGRATION_URL` is set (the migration role is needed to apply the
/// schema); otherwise every test is skipped, so `swift test` works without a
/// database.
///
/// Each test body runs in one transaction that is always rolled back, so
/// nothing is left behind and tests do not see each other's rows. Point the
/// variable at a throwaway database only.
class DatabaseTestCase: XCTestCase {
    private struct Rollback: Error {}

    /// Skips the calling test unless a database is configured; returns the URL.
    private func requireDatabaseURL() throws -> String {
        let value = ProcessInfo.processInfo.environment[AppConfig.Key.databaseMigrationURL] ?? ""
        try XCTSkipIf(value.isEmpty, "\(AppConfig.Key.databaseMigrationURL) is not set; database tests skipped")
        return value
    }

    /// Applies the real migrations (a no-op when CI already did), then runs
    /// `body` inside a transaction that is rolled back afterwards.
    func withRolledBackTransaction(_ body: @escaping @Sendable (any SQLDatabase) async throws -> Void) async throws {
        let url = try requireDatabaseURL()
        let app = try await Application.make(.testing)
        do {
            try configureMigrator(app, config: MigrationConfig(stage: .local, databaseMigrationURL: url))
            try await app.autoMigrate()
            do {
                try await app.db.transaction { transaction in
                    guard let sql = transaction as? SQLDatabase else { throw Abort(.internalServerError) }
                    try await body(sql)
                    throw Rollback()
                }
            } catch is Rollback {
                // Expected: the rollback is how the test cleans up.
            }
        } catch {
            try? await app.asyncShutdown()
            throw error
        }
        try await app.asyncShutdown()
    }
}
