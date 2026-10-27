import XCTest
import Vapor
import Fluent
import FluentSQL
@testable import AppUnderTest

/// Database-level tests (TC-59, TC-60, TC-61, TC-66, TC-70 plus migration and
/// seed behaviour). They need a PostgreSQL 14+ and skip unless
/// DATABASE_MIGRATION_URL is set (a throwaway database; the role needs DDL
/// rights). Every data test runs inside a transaction that is rolled back, so
/// nothing remains except the migrated schema.
/// Shared application, rollback helper and migration; holds no test methods.
class DatabaseTestBase: XCTestCase {

    var app: Application!
    var db: any Database { app.db }

    struct Rollback: Error {}

    override func setUp() async throws {
        guard let url = ProcessInfo.processInfo.environment["DATABASE_MIGRATION_URL"], !url.isEmpty else {
            throw XCTSkip("DATABASE_MIGRATION_URL not set; database-level tests skipped")
        }
        app = try await Application.make(.testing)
        let config = MigrationConfig(stage: .local, databaseMigrationURL: url)
        try configureMigrator(app, config: config, migrationFiles: MigrationFiles.load(from: QAPaths.migrations))
        try await app.autoMigrate()
    }

    override func tearDown() async throws {
        if let app { try await app.asyncShutdown() }
    }

    func inRollback(_ body: @escaping @Sendable (any SQLDatabase) async throws -> Void) async throws {
        do {
            try await db.transaction { tx in
                try await body(tx as! any SQLDatabase)
                throw Rollback()
            }
        } catch is Rollback {}
    }

}
