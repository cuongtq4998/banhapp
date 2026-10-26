import XCTest
@testable import App

final class AppConfigTests: XCTestCase {
    private let valid = [
        "APP_ENV": "staging",
        "PORT": "8080",
        "DATABASE_URL": "postgres://placeholder"
    ]

    func testParsesRequiredValuesAndDefaults() throws {
        let config = try AppConfig(variables: valid)
        XCTAssertEqual(config.stage, .staging)
        XCTAssertEqual(config.port, 8080)
        XCTAssertEqual(config.databaseURL, "postgres://placeholder")
        XCTAssertNil(config.databaseMigrationURL)
        XCTAssertEqual(config.databasePoolMax, AppConfig.Default.databasePoolMax)
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
                    AppConfig.Key.databaseMigrationURL, AppConfig.Key.databasePoolMax]
        for key in keys {
            XCTAssertTrue(text.contains("\(key)="), "\(key) missing from .env.example")
        }
    }
}
