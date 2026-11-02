import XCTest
@testable import App

final class AdminConfigTests: XCTestCase {
    private let pepper = String(repeating: "k", count: 32)

    private func config(_ values: [String: String], stage: AppConfig.Stage = .local) throws -> AdminAuthConfig? {
        try AdminAuthConfig(environment: EnvironmentVariables(values), stage: stage)
    }

    func testOffWhenNeitherVariableIsSet() throws {
        XCTAssertNil(try config([:]))
        XCTAssertNil(try config([:], stage: .production))
    }

    func testBothAreRequiredTogether() {
        XCTAssertThrowsError(try config(["AUTH_CODE_PEPPER": pepper])) { XCTAssertEqual($0 as? AppConfig.Failure, .missing("EMAIL_PROVIDER")) }
        XCTAssertThrowsError(try config(["EMAIL_PROVIDER": "console"])) { XCTAssertEqual($0 as? AppConfig.Failure, .missing("AUTH_CODE_PEPPER")) }
    }

    func testShortPepperIsRefusedWithoutEchoingIt() {
        XCTAssertThrowsError(try config(["AUTH_CODE_PEPPER": "short", "EMAIL_PROVIDER": "console"])) {
            XCTAssertEqual($0 as? AppConfig.Failure, .invalid("AUTH_CODE_PEPPER"))
            XCTAssertFalse("\($0)".contains("short"))
        }
    }

    func testConsoleAndRecordingAreRefusedInProduction() throws {
        for provider in ["console", "recording"] {
            let values = ["AUTH_CODE_PEPPER": pepper, "EMAIL_PROVIDER": provider]
            XCTAssertNotNil(try config(values, stage: .staging))
            XCTAssertThrowsError(try config(values, stage: .production)) {
                XCTAssertEqual($0 as? AppConfig.Failure, .invalid("EMAIL_PROVIDER"))
            }
        }
        XCTAssertThrowsError(try config(["AUTH_CODE_PEPPER": pepper, "EMAIL_PROVIDER": "unknown"]))
    }

    func testDailyMailCapDefaultsTo80AndMustBePositive() throws {
        let base = ["AUTH_CODE_PEPPER": pepper, "EMAIL_PROVIDER": "console"]
        XCTAssertEqual(try config(base)?.emailMaxPerDay, 80)
        XCTAssertEqual(try config(base.merging(["EMAIL_MAX_PER_DAY": "5"]) { $1 })?.emailMaxPerDay, 5)
        XCTAssertThrowsError(try config(base.merging(["EMAIL_MAX_PER_DAY": "0"]) { $1 }))
    }

    func testCreateOwnerNeedsDatabaseAndShop() throws {
        let shop = UUID().uuidString
        XCTAssertThrowsError(try OwnerCommandConfig(variables: ["APP_ENV": "local", "SHOP_ID": shop]))
        XCTAssertThrowsError(try OwnerCommandConfig(variables: ["APP_ENV": "local", "DATABASE_URL": "postgres://x"]))
        let ok = try OwnerCommandConfig(variables: ["APP_ENV": "local", "DATABASE_URL": "postgres://x", "SHOP_ID": shop])
        XCTAssertEqual(ok.shopID.uuidString, shop)
        XCTAssertEqual(requestedCommand(in: ["App", "create-owner", "--email", "a@example.com"]), createOwnerCommandName)
    }

    func testAdminErrorCodesHaveTheDocumentedStatusAndKey() {
        let table: [(APIErrorCode, UInt, String)] = [
            (.unauthenticated, 401, "ERR_ADMIN_SIGN_IN_REQUIRED"), (.accessTokenExpired, 401, "ERR_ADMIN_SIGN_IN_REQUIRED"),
            (.sessionRevoked, 401, "ERR_ADMIN_SESSION_ENDED"), (.sessionExpired, 401, "ERR_ADMIN_SESSION_ENDED"),
            (.forbidden, 403, "ERR_ADMIN_FORBIDDEN"), (.codeInvalid, 422, "ERR_CODE_INVALID"),
            (.codeExpired, 422, "ERR_CODE_EXPIRED"), (.codeResendWait, 429, "ERR_CODE_RESEND_WAIT"),
            (.codeRequestLimit, 429, "ERR_CODE_REQUEST_LIMIT")
        ]
        for (code, status, key) in table {
            XCTAssertEqual(code.status.code, UInt(status), code.rawValue)
            XCTAssertEqual(code.messageKey, key, code.rawValue)
        }
        XCTAssertEqual(APIError.waiting(.codeResendWait, seconds: 12).retryAfterSeconds, 12)
        XCTAssertEqual(APIError.waiting(.codeRequestLimit, seconds: 0).retryAfterSeconds, 1)
    }
}
