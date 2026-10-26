import XCTest
@testable import AppUnderTest

final class ConfigEdgeTests: XCTestCase {
    private let base = ["APP_ENV": "staging", "PORT": "8080", "DATABASE_URL": "postgres://placeholder"]

    private func config(_ overrides: [String: String?]) throws -> AppConfig {
        var vars = base
        for (k, v) in overrides { vars[k] = v }
        return try AppConfig(variables: vars)
    }

    func testPortBoundaries() throws {
        XCTAssertEqual(try config(["PORT": "1"]).port, 1)
        XCTAssertEqual(try config(["PORT": "65535"]).port, 65535)
        for bad in ["65536", "-1", "8080.5", "0x1F90", "8 080", "99999999999999999999"] {
            XCTAssertThrowsError(try config(["PORT": bad]), "PORT=\(bad)")
        }
    }

    func testSurroundingSpacesAreTrimmed() throws {
        XCTAssertEqual(try config(["PORT": " 8080 "]).port, 8080)
    }

    func testWhitespaceOnlyValuesCountAsMissing() {
        XCTAssertThrowsError(try config(["DATABASE_URL": "   "])) {
            XCTAssertEqual($0 as? AppConfig.Failure, .missing("DATABASE_URL"))
        }
        XCTAssertThrowsError(try config(["APP_ENV": " "])) {
            XCTAssertEqual($0 as? AppConfig.Failure, .missing("APP_ENV"))
        }
    }

    func testStageNamesAreCaseSensitive() {
        for bad in ["Staging", "PRODUCTION", "prod", "dev"] {
            XCTAssertThrowsError(try config(["APP_ENV": bad]), bad) {
                XCTAssertEqual($0 as? AppConfig.Failure, .invalid("APP_ENV"))
            }
        }
    }

    func testProductionRequiresDatabaseUrl() {
        XCTAssertThrowsError(try config(["APP_ENV": "production", "DATABASE_URL": nil]))
    }

    func testPoolMaxRejectsNonsense() {
        for bad in ["abc", "-1", "1.5", "99999999999999999999"] {
            XCTAssertThrowsError(try config(["DATABASE_POOL_MAX": bad]), bad)
        }
    }

    func testNeverEchoesAnyValueInErrors() {
        for (key, bad) in [("DATABASE_POOL_MAX", "zz-secret"), ("APP_ENV", "zz-secret"), ("PORT", "zz-secret")] {
            XCTAssertThrowsError(try config([key: bad])) {
                XCTAssertFalse(String(describing: $0).contains("zz-secret"))
                XCTAssertFalse(String(reflecting: $0).contains("zz-secret"))
            }
        }
    }

    func testMigrationUrlIsOptionalAndTrimmed() throws {
        XCTAssertNil(try config([:]).databaseMigrationURL)
        XCTAssertEqual(try config(["DATABASE_MIGRATION_URL": " postgres://m "]).databaseMigrationURL, "postgres://m")
    }

    // ---- Defects ----

    /// D-2: the staging deploy job runs `migrate` with only APP_ENV and
    /// DATABASE_MIGRATION_URL (backend.yml); the config parser demands PORT
    /// and DATABASE_URL as well, so the process exits before migrating.
    func testDefectMigrateNeedsOnlyTheMigrationRole() {
        let vars = ["APP_ENV": "staging", "DATABASE_MIGRATION_URL": "postgres://migrator-placeholder"]
        XCTAssertNoThrow(try AppConfig(variables: vars))
    }

    /// D-5 (low): a value pasted with a trailing newline (common in secret
    /// stores) is rejected for PORT because only spaces and tabs are trimmed.
    func testDefectTrailingNewlineIsTrimmed() {
        XCTAssertNoThrow(try config(["PORT": "8080\n"]))
    }
}
