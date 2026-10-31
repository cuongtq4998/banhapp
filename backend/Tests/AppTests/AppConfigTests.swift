import XCTest
@testable import App

final class AppConfigTests: XCTestCase {
    private let valid = [
        "APP_ENV": "staging",
        "PORT": "8080",
        "DATABASE_URL": "postgres://placeholder",
        "SHOP_ID": "00000000-0000-4000-8000-000000000001"
    ]

    func testParsesRequiredValuesAndDefaults() throws {
        let config = try AppConfig(variables: valid)
        XCTAssertEqual(config.stage, .staging)
        XCTAssertEqual(config.port, 8080)
        XCTAssertEqual(config.databaseURL, "postgres://placeholder")
        XCTAssertEqual(config.databasePoolMax, AppConfig.Default.databasePoolMax)
        XCTAssertEqual(config.shopID, AppConfig.testShopID)
        XCTAssertFalse(config.trustProxy)
        XCTAssertEqual(config.rateLimitReadPerMinute, 120)
        XCTAssertEqual(config.publicAssetBaseURL, "")
    }

    func testShopIDIsRequiredOutsideLocal() throws {
        var vars = valid
        vars.removeValue(forKey: AppConfig.Key.shopID)
        XCTAssertThrowsError(try AppConfig(variables: vars)) {
            XCTAssertEqual($0 as? AppConfig.Failure, .missing(AppConfig.Key.shopID))
        }
        vars[AppConfig.Key.appEnv] = "local"
        XCTAssertNil(try AppConfig(variables: vars).shopID)
    }

    func testShopIDMustBeAUUID() {
        var vars = valid
        vars[AppConfig.Key.shopID] = "not-a-uuid"
        XCTAssertThrowsError(try AppConfig(variables: vars)) {
            XCTAssertEqual($0 as? AppConfig.Failure, .invalid(AppConfig.Key.shopID))
        }
    }

    func testTrustProxyAcceptsOnlyTrueAndFalse() throws {
        var vars = valid
        vars[AppConfig.Key.trustProxy] = "TRUE"
        XCTAssertTrue(try AppConfig(variables: vars).trustProxy)
        vars[AppConfig.Key.trustProxy] = "false"
        XCTAssertFalse(try AppConfig(variables: vars).trustProxy)
        vars[AppConfig.Key.trustProxy] = "yes"
        XCTAssertThrowsError(try AppConfig(variables: vars)) {
            XCTAssertEqual($0 as? AppConfig.Failure, .invalid(AppConfig.Key.trustProxy))
        }
    }

    func testReadRateLimitMustBePositive() throws {
        var vars = valid
        vars[AppConfig.Key.rateLimitReadPerMinute] = "30"
        XCTAssertEqual(try AppConfig(variables: vars).rateLimitReadPerMinute, 30)
        for bad in ["0", "-1", "many"] {
            vars[AppConfig.Key.rateLimitReadPerMinute] = bad
            XCTAssertThrowsError(try AppConfig(variables: vars), bad)
        }
    }

    func testAssetBaseURLLosesTrailingSlashes() throws {
        var vars = valid
        vars[AppConfig.Key.publicAssetBaseURL] = "https://cdn.example//"
        XCTAssertEqual(try AppConfig(variables: vars).publicAssetBaseURL, "https://cdn.example")
    }

    func testValuesAreTrimmedOfAllWhitespaceAndNewlines() throws {
        var vars = valid
        vars[AppConfig.Key.port] = " 8080\n"
        vars[AppConfig.Key.appEnv] = "staging\r\n"
        let config = try AppConfig(variables: vars)
        XCTAssertEqual(config.port, 8080)
        XCTAssertEqual(config.stage, .staging)
    }

    func testMissingAppEnvNamesTheVariable() {
        var vars = valid
        vars.removeValue(forKey: AppConfig.Key.appEnv)
        XCTAssertThrowsError(try AppConfig(variables: vars)) {
            XCTAssertEqual($0 as? AppConfig.Failure, .missing(AppConfig.Key.appEnv))
        }
    }

    func testUnknownStageIsRejected() {
        var vars = valid
        vars[AppConfig.Key.appEnv] = "qa"
        XCTAssertThrowsError(try AppConfig(variables: vars)) {
            XCTAssertEqual($0 as? AppConfig.Failure, .invalid(AppConfig.Key.appEnv))
        }
    }

    func testPortMustBeInRange() {
        for bad in ["0", "70000", "abc", ""] {
            var vars = valid
            vars[AppConfig.Key.port] = bad
            XCTAssertThrowsError(try AppConfig(variables: vars), "PORT=\(bad)")
        }
    }

    func testDatabaseURLRequiredOutsideLocal() throws {
        var vars = valid
        vars.removeValue(forKey: AppConfig.Key.databaseURL)
        XCTAssertThrowsError(try AppConfig(variables: vars)) {
            XCTAssertEqual($0 as? AppConfig.Failure, .missing(AppConfig.Key.databaseURL))
        }
        vars[AppConfig.Key.appEnv] = "local"
        XCTAssertNil(try AppConfig(variables: vars).databaseURL)
    }

    func testPoolMaxMustBePositive() throws {
        var vars = valid
        vars[AppConfig.Key.databasePoolMax] = "3"
        XCTAssertEqual(try AppConfig(variables: vars).databasePoolMax, 3)
        vars[AppConfig.Key.databasePoolMax] = "0"
        XCTAssertThrowsError(try AppConfig(variables: vars))
    }

    func testFailureMessageNeverContainsValues() {
        var vars = valid
        vars[AppConfig.Key.port] = "secret-looking-value"
        XCTAssertThrowsError(try AppConfig(variables: vars)) {
            XCTAssertFalse(String(describing: $0).contains("secret-looking-value"))
        }
    }

    /// `.env.example` must list every variable the code reads.
    func testEnvExampleListsEveryKey() throws {
        let text = try String(contentsOf: TestPaths.backend.appendingPathComponent(".env.example"), encoding: .utf8)
        let keys = [AppConfig.Key.appEnv, AppConfig.Key.port, AppConfig.Key.databaseURL,
                    AppConfig.Key.databaseMigrationURL, AppConfig.Key.databasePoolMax,
                    AppConfig.Key.shopID, AppConfig.Key.trustProxy,
                    AppConfig.Key.rateLimitReadPerMinute, AppConfig.Key.publicAssetBaseURL]
        for key in keys {
            XCTAssertTrue(text.contains("\(key)="), "\(key) missing from .env.example")
        }
    }
}

final class MigrationConfigTests: XCTestCase {
    /// Exactly what the staging deploy job passes (backend.yml).
    private let deployJob = [
        "APP_ENV": "staging",
        "DATABASE_MIGRATION_URL": "postgres://placeholder"
    ]

    func testNeedsOnlyStageAndMigrationURL() throws {
        let config = try MigrationConfig(variables: deployJob)
        XCTAssertEqual(config, MigrationConfig(stage: .staging, databaseMigrationURL: "postgres://placeholder"))
        // The same variables are not enough to serve.
        XCTAssertThrowsError(try AppConfig(variables: deployJob))
    }

    func testMissingMigrationURLNamesTheVariable() {
        var vars = deployJob
        vars.removeValue(forKey: AppConfig.Key.databaseMigrationURL)
        XCTAssertThrowsError(try MigrationConfig(variables: vars)) {
            XCTAssertEqual($0 as? AppConfig.Failure, .missing(AppConfig.Key.databaseMigrationURL))
        }
    }

    func testMissingOrUnknownStageIsRejected() {
        var vars = deployJob
        vars[AppConfig.Key.appEnv] = "qa"
        XCTAssertThrowsError(try MigrationConfig(variables: vars)) {
            XCTAssertEqual($0 as? AppConfig.Failure, .invalid(AppConfig.Key.appEnv))
        }
        vars.removeValue(forKey: AppConfig.Key.appEnv)
        XCTAssertThrowsError(try MigrationConfig(variables: vars)) {
            XCTAssertEqual($0 as? AppConfig.Failure, .missing(AppConfig.Key.appEnv))
        }
    }

    func testMigrationURLIsTrimmed() throws {
        var vars = deployJob
        vars[AppConfig.Key.databaseMigrationURL] = "postgres://placeholder\n"
        XCTAssertEqual(try MigrationConfig(variables: vars).databaseMigrationURL, "postgres://placeholder")
    }
}
