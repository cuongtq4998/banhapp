import XCTest
@testable import AppUnderTest

final class ConfigEdgeTests: XCTestCase {
    private let base = ["APP_ENV": "staging", "PORT": "8080", "DATABASE_URL": "postgres://placeholder",
                          "SHOP_ID": "5b0f3c1e-0000-4000-8000-000000000001"]

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

    // ---- Migration command configuration (D-2, retested in round 2) ----

    private func migration(_ vars: [String: String]) throws -> MigrationConfig {
        try MigrationConfig(variables: vars)
    }

    /// D-2: the staging deploy job passes only APP_ENV and DATABASE_MIGRATION_URL.
    func testMigrateNeedsOnlyTheMigrationRole() throws {
        let config = try migration(["APP_ENV": "staging", "DATABASE_MIGRATION_URL": "postgres://migrator-placeholder"])
        XCTAssertEqual(config.stage, .staging)
        XCTAssertEqual(config.databaseMigrationURL, "postgres://migrator-placeholder")
    }

    func testMigrationUrlIsRequiredAndTrimmed() throws {
        XCTAssertThrowsError(try migration(["APP_ENV": "staging"])) {
            XCTAssertEqual($0 as? AppConfig.Failure, .missing("DATABASE_MIGRATION_URL"))
        }
        XCTAssertThrowsError(try migration(["APP_ENV": "staging", "DATABASE_MIGRATION_URL": " \n "]))
        XCTAssertEqual(
            try migration(["APP_ENV": "local", "DATABASE_MIGRATION_URL": " postgres://m \n"]).databaseMigrationURL,
            "postgres://m"
        )
    }

    func testMigrationStageIsRequiredAndValidated() {
        XCTAssertThrowsError(try migration(["DATABASE_MIGRATION_URL": "postgres://m"])) {
            XCTAssertEqual($0 as? AppConfig.Failure, .missing("APP_ENV"))
        }
        XCTAssertThrowsError(try migration(["APP_ENV": "Staging", "DATABASE_MIGRATION_URL": "postgres://m"])) {
            XCTAssertEqual($0 as? AppConfig.Failure, .invalid("APP_ENV"))
        }
    }

    func testMigrationConfigNeverEchoesTheUrl() {
        XCTAssertThrowsError(try migration(["APP_ENV": "zz-secret", "DATABASE_MIGRATION_URL": "postgres://zz-secret"])) {
            XCTAssertFalse(String(describing: $0).contains("zz-secret"))
            XCTAssertFalse(String(reflecting: $0).contains("zz-secret"))
        }
    }

    /// The serve configuration must not take over the migration URL any more.
    func testServeConfigIgnoresTheMigrationUrl() throws {
        XCTAssertThrowsError(try config(["DATABASE_URL": nil, "DATABASE_MIGRATION_URL": "postgres://m"]),
                             "a staging server must not fall back to the DDL role")
    }

    /// D-5: a value pasted with a trailing newline is trimmed.
    func testTrailingNewlineIsTrimmed() throws {
        XCTAssertEqual(try config(["PORT": "8080\n"]).port, 8080)
        XCTAssertEqual(try config(["PORT": "\r\n8080\r\n"]).port, 8080)
        XCTAssertEqual(try config(["DATABASE_URL": "postgres://x\n"]).databaseURL, "postgres://x")
    }

    func testPoolMaxZeroIsRejected() {
        XCTAssertThrowsError(try config(["DATABASE_POOL_MAX": "0"]))
    }

    func testPoolSizingNeverExceedsTheBudget() {
        for poolMax in 1...40 {
            for cores in [1, 2, 4, 8, 10, 16, 64] {
                let loops = DatabasePoolSizing.eventLoopCount(poolMax: poolMax, coreCount: cores)
                let per = DatabasePoolSizing.connectionsPerLoop(poolMax: poolMax, eventLoopCount: loops)
                XCTAssertGreaterThanOrEqual(loops, 1)
                XCTAssertGreaterThanOrEqual(per, 1)
                XCTAssertLessThanOrEqual(loops * per, poolMax, "poolMax=\(poolMax) cores=\(cores)")
            }
        }
    }

    // ---- Slice 1 configuration (retest on a934ae8) ----

    func testShopIdIsRequiredOutsideLocalAndMustBeAUuid() {
        for stage in ["staging", "production"] {
            XCTAssertThrowsError(try config(["APP_ENV": stage, "SHOP_ID": nil]), stage) {
                XCTAssertEqual($0 as? AppConfig.Failure, .missing("SHOP_ID"))
            }
            XCTAssertThrowsError(try config(["APP_ENV": stage, "SHOP_ID": "   "]), stage)
        }
        for bad in ["not-a-uuid", "123", "5b0f3c1e-0000-4000-8000-00000000000g"] {
            XCTAssertThrowsError(try config(["SHOP_ID": bad]), bad) {
                XCTAssertEqual($0 as? AppConfig.Failure, .invalid("SHOP_ID"))
            }
        }
    }

    func testLocalRunMayOmitShopIdAndDatabase() throws {
        let local = try config(["APP_ENV": "local", "SHOP_ID": nil, "DATABASE_URL": nil])
        XCTAssertNil(local.shopID)
        XCTAssertNil(local.databaseURL)
    }

    func testTrustProxyDefaultsOffAndParsesStrictly() throws {
        XCTAssertFalse(try config([:]).trustProxy)
        XCTAssertTrue(try config(["TRUST_PROXY": "true"]).trustProxy)
        XCTAssertTrue(try config(["TRUST_PROXY": " TRUE\n"]).trustProxy)
        XCTAssertFalse(try config(["TRUST_PROXY": "false"]).trustProxy)
        for bad in ["1", "yes", "on", "truee"] {
            XCTAssertThrowsError(try config(["TRUST_PROXY": bad]), bad) {
                XCTAssertEqual($0 as? AppConfig.Failure, .invalid("TRUST_PROXY"))
            }
        }
    }

    func testReadRateLimitDefaultAndBounds() throws {
        XCTAssertEqual(try config([:]).rateLimitReadPerMinute, 120)
        XCTAssertEqual(try config(["RATE_LIMIT_READ_PER_MINUTE": "1"]).rateLimitReadPerMinute, 1)
        for bad in ["0", "-5", "abc", "1.5", "99999999999999999999"] {
            XCTAssertThrowsError(try config(["RATE_LIMIT_READ_PER_MINUTE": bad]), bad)
        }
        XCTAssertEqual(try config([:]).rateLimitWindowSeconds, 60)
    }

    func testPublicAssetBaseUrlTrailingSlashesAreRemoved() throws {
        XCTAssertEqual(try config([:]).publicAssetBaseURL, "")
        XCTAssertEqual(try config(["PUBLIC_ASSET_BASE_URL": "https://cdn.example.test///"]).publicAssetBaseURL,
                       "https://cdn.example.test")
    }

    func testSlice1ConfigErrorsNeverEchoValues() {
        for key in ["SHOP_ID", "TRUST_PROXY", "RATE_LIMIT_READ_PER_MINUTE"] {
            XCTAssertThrowsError(try config([key: "zz-secret"])) {
                XCTAssertFalse(String(describing: $0).contains("zz-secret"))
                XCTAssertFalse(String(reflecting: $0).contains("zz-secret"))
            }
        }
    }
}
