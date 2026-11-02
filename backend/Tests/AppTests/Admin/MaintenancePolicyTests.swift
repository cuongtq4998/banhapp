import XCTest
@testable import App

/// Periods of the purge task (data-model/05 section 14).
final class MaintenancePolicyTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testStatedPeriods() {
        let cutoffs = MaintenancePolicy.standard.cutoffs(now: now)
        XCTAssertEqual(now.timeIntervalSince(cutoffs.authCodeExpiredBefore), 24 * 3_600)
        XCTAssertEqual(now.timeIntervalSince(cutoffs.sessionEndedBefore), 30 * 86_400)
        XCTAssertEqual(now.timeIntervalSince(cutoffs.securityEventBefore), 180 * 86_400)
    }

    func testRunsEveryDay() {
        XCTAssertEqual(MaintenancePolicy.standard.interval, .seconds(86_400))
    }
}
