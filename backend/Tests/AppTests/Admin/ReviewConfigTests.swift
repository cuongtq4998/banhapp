import XCTest
@testable import App

/// ADR-0027: the review account is off unless both variables are set; a half-set pair stops the start.
final class ReviewConfigTests: XCTestCase {
    private let pepper = String(repeating: "k", count: 32)
    private let base = ["AUTH_CODE_PEPPER": String(repeating: "k", count: 32), "EMAIL_PROVIDER": "console"]
    private let review = ["REVIEW_ACCOUNT_EMAIL": " Review.Demo@Example.com ", "REVIEW_ACCOUNT_CODE": "123456"]

    private func admin(_ values: [String: String], stage: AppConfig.Stage = .local) throws -> AdminAuthConfig? {
        try AdminAuthConfig(environment: EnvironmentVariables(values), stage: stage)
    }

    func testOffByDefault() throws {
        XCTAssertNil(try admin(base)?.review)
        XCTAssertNil(try admin(["REVIEW_ACCOUNT_EMAIL": "", "REVIEW_ACCOUNT_CODE": "  "].merging(base) { $1 })?.review)
    }

    func testBothSetTurnItOnWithANormalisedAddress() throws {
        let config = try XCTUnwrap(try admin(base.merging(review) { $1 })?.review)
        XCTAssertEqual(config.email, "review.demo@example.com")
        XCTAssertEqual(config.code, "123456")
        XCTAssertTrue(config.isReviewAddress(try XCTUnwrap(EmailAddress("REVIEW.demo@example.com"))))
        XCTAssertFalse(config.isReviewAddress(try XCTUnwrap(EmailAddress("other@example.com"))))
    }

    func testHalfSetStopsTheStart() {
        for (set, missing) in [("REVIEW_ACCOUNT_EMAIL", "REVIEW_ACCOUNT_CODE"), ("REVIEW_ACCOUNT_CODE", "REVIEW_ACCOUNT_EMAIL")] {
            XCTAssertThrowsError(try admin(base.merging([set: review[set]!]) { $1 })) {
                XCTAssertEqual($0 as? AppConfig.Failure, .missing(missing))
            }
        }
    }

    func testBadValuesAreRefusedWithoutEchoingThem() {
        for (values, name) in [(["REVIEW_ACCOUNT_EMAIL": "not-an-address", "REVIEW_ACCOUNT_CODE": "123456"], "REVIEW_ACCOUNT_EMAIL"),
                               (["REVIEW_ACCOUNT_EMAIL": "a@example.com", "REVIEW_ACCOUNT_CODE": "12345"], "REVIEW_ACCOUNT_CODE"),
                               (["REVIEW_ACCOUNT_EMAIL": "a@example.com", "REVIEW_ACCOUNT_CODE": "12345a"], "REVIEW_ACCOUNT_CODE")] {
            XCTAssertThrowsError(try admin(base.merging(values) { $1 })) {
                XCTAssertEqual($0 as? AppConfig.Failure, .invalid(name))
                XCTAssertFalse("\($0)".contains("12345"))
            }
        }
    }

    func testWithoutSignInConfiguredTheStartStops() {
        XCTAssertThrowsError(try admin(review))
    }

    /// The store review runs against the shipped build, so production is allowed (ADR-0027 gives no stage rule).
    func testAllowedInProduction() throws {
        let production = ["AUTH_CODE_PEPPER": pepper, "EMAIL_PROVIDER": "console"]
        XCTAssertThrowsError(try admin(production.merging(review) { $1 }, stage: .production), "console mail is still refused")
        XCTAssertNotNil(try ReviewAccountConfig(environment: EnvironmentVariables(review)))
    }

    func testTheCodeIsNeverPrinted() throws {
        let config = try XCTUnwrap(try ReviewAccountConfig(environment: EnvironmentVariables(review)))
        for text in ["\(config)", String(reflecting: config), String(describing: config)] {
            XCTAssertFalse(text.contains("123456") || text.contains("example.com"))
        }
    }

    func testTheCommandConfigNeedsTheReviewVariablesOnlyForOn() throws {
        let environment = ["APP_ENV": "local", "DATABASE_URL": "postgres://u@127.0.0.1/x", "SHOP_ID": UUID().uuidString]
        let config = try ReviewCommandConfig(variables: environment)
        XCTAssertNil(try config.review(), "off works after the variables were removed")
        XCTAssertNotNil(try ReviewCommandConfig(variables: environment.merging(review) { $1 }).review())
        XCTAssertThrowsError(try ReviewCommandConfig(variables: environment.merging(["REVIEW_ACCOUNT_CODE": "123456"]) { $1 }).review())
        XCTAssertThrowsError(try ReviewCommandConfig(variables: ["APP_ENV": "local"]))
        XCTAssertEqual(requestedCommand(in: ["/usr/bin/App", "review-account", "on"]), reviewAccountCommandName)
    }
}
