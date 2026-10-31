import XCTest
@testable import App

/// Boundaries of the sign-in and renewal rules (BR-4, BR-5, ADR-0022).
final class AuthRulesTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_800_000_000)
    private func at(_ seconds: TimeInterval) -> Date { start.addingTimeInterval(seconds) }

    func testResendRefusedBefore30SecondsAllowedAtExactly30() {
        XCTAssertEqual(AuthRules.resendWait(lastCreatedAt: start, now: at(10)), 20)
        XCTAssertEqual(AuthRules.resendWait(lastCreatedAt: start, now: at(29)), 1)
        XCTAssertEqual(AuthRules.resendWait(lastCreatedAt: start, now: at(29.5)), 1)
        XCTAssertNil(AuthRules.resendWait(lastCreatedAt: start, now: at(30)))
        XCTAssertNil(AuthRules.resendWait(lastCreatedAt: start, now: at(31)))
        XCTAssertNil(AuthRules.resendWait(lastCreatedAt: nil, now: start))
    }

    func testHourlyLimitIsThreeCodesInARollingHour() {
        let two = [at(0), at(31)]
        XCTAssertNil(AuthRules.hourlyWait(createdInWindow: two, now: at(62)))
        let three = [at(0), at(31), at(62)]
        XCTAssertEqual(AuthRules.hourlyWait(createdInWindow: three, now: at(93)), 3_507)
        XCTAssertEqual(AuthRules.hourlyWait(createdInWindow: three, now: at(3_599)), 1)
        // The oldest of the three leaves the window; with four in the window two must leave.
        let four = [at(0), at(31), at(62), at(93)]
        XCTAssertEqual(AuthRules.hourlyWait(createdInWindow: four, now: at(100)), 3_600 + 31 - 100)
    }

    func testCodeIsValidStrictlyBeforeTenMinutes() {
        let expires = at(AuthPolicy.codeLifetime)
        XCTAssertFalse(AuthRules.isExpired(expiresAt: expires, now: at(599)))
        XCTAssertTrue(AuthRules.isExpired(expiresAt: expires, now: at(600)))
        XCTAssertTrue(AuthRules.isExpired(expiresAt: expires, now: at(601)))
    }

    func testFifthWrongEntryVoidsTheCode() {
        XCTAssertFalse(AuthRules.isVoid(wrongCount: 4))
        XCTAssertTrue(AuthRules.isVoid(wrongCount: 5))
    }

    private let current = Data([1]), previous = Data([2]), other = Data([3])

    private func decide(_ presented: Data, rotatedAgo: TimeInterval = 5, expiresIn: TimeInterval = 100) -> AuthRules.RefreshDecision {
        AuthRules.refreshDecision(
            presented: presented, current: current, previous: previous, rotatedAt: at(-rotatedAgo),
            expiresAt: at(expiresIn), now: start
        )
    }

    func testCurrentCredentialRotates() {
        XCTAssertEqual(decide(current), .rotate)
    }

    func testPreviousCredentialIsToleratedFor20SecondsIncluded() {
        XCTAssertEqual(decide(previous, rotatedAgo: 1), .rotateAgain)
        XCTAssertEqual(decide(previous, rotatedAgo: 19), .rotateAgain)
        XCTAssertEqual(decide(previous, rotatedAgo: 20), .rotateAgain)
        XCTAssertEqual(decide(previous, rotatedAgo: 21), .reuse)
    }

    func testUnknownCredentialIsReuse() {
        XCTAssertEqual(decide(other), .reuse)
        let noHistory = AuthRules.refreshDecision(
            presented: previous, current: current, previous: nil, rotatedAt: nil, expiresAt: at(100), now: start
        )
        XCTAssertEqual(noHistory, .reuse)
    }

    func testSessionIsValidStrictlyLessThanSevenDays() {
        let week = AuthPolicy.refreshLifetime
        func decision(idle: TimeInterval) -> AuthRules.RefreshDecision {
            AuthRules.refreshDecision(
                presented: current, current: current, previous: nil, rotatedAt: nil,
                expiresAt: at(week), now: at(idle)
            )
        }
        XCTAssertEqual(decision(idle: week - 60), .rotate)
        XCTAssertEqual(decision(idle: week - 1), .rotate)
        XCTAssertEqual(decision(idle: week), .expired)
        XCTAssertEqual(decision(idle: week + 60), .expired)
    }
}
