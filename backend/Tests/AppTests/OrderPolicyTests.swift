import XCTest
@testable import App

final class OrderPolicyTests: XCTestCase {
    private let valid = ["APP_ENV": "local", "PORT": "8080"]

    func testDefaults() throws {
        let policy = try AppConfig(variables: valid).orders
        XCTAssertEqual(policy, OrderPolicy())
        XCTAssertTrue(policy.isEnabled)
        XCTAssertEqual(policy.perAddressPerHour, 10)
        XCTAssertEqual(policy.perPhonePerDay, 5)
        XCTAssertEqual(policy.addressWindowSeconds, 3_600)
    }

    func testReadsTheThreeVariables() throws {
        let policy = try AppConfig(variables: valid.merging([
            AppConfig.Key.orderingEnabled: "FALSE", AppConfig.Key.rateLimitOrderPerHour: "3", AppConfig.Key.orderMaxPerPhonePerDay: "2"
        ]) { $1 }).orders
        XCTAssertFalse(policy.isEnabled)
        XCTAssertEqual(policy.perAddressPerHour, 3)
        XCTAssertEqual(policy.perPhonePerDay, 2)
    }

    func testMalformedValuesNameOnlyTheVariable() {
        for (key, value) in [(AppConfig.Key.orderingEnabled, "maybe"), (AppConfig.Key.rateLimitOrderPerHour, "0"),
                             (AppConfig.Key.orderMaxPerPhonePerDay, "x")] {
            XCTAssertThrowsError(try AppConfig(variables: valid.merging([key: value]) { $1 })) {
                XCTAssertEqual($0 as? AppConfig.Failure, .invalid(key))
            }
        }
    }
}
