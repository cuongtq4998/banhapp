import XCTVapor
import BanhContracts
@testable import App

final class FixedWindowRateLimiterTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_000_000)

    func testAllowsTheLimitThenRefuses() {
        let limiter = FixedWindowRateLimiter(limit: 3, windowSeconds: 60)
        for _ in 1...3 {
            XCTAssertTrue(limiter.registerRequest(clientKey: "a", at: start).isAllowed)
        }
        XCTAssertFalse(limiter.registerRequest(clientKey: "a", at: start).isAllowed)
    }

    func testARefusedRequestIsNotCounted() {
        let limiter = FixedWindowRateLimiter(limit: 1, windowSeconds: 60)
        XCTAssertTrue(limiter.registerRequest(clientKey: "a", at: start).isAllowed)
        for second in 1...5 {
            XCTAssertFalse(limiter.registerRequest(clientKey: "a", at: start.addingTimeInterval(Double(second))).isAllowed)
        }
        // Counting refusals would not change this, but the next window must hold exactly the limit again.
        XCTAssertTrue(limiter.registerRequest(clientKey: "a", at: start.addingTimeInterval(60)).isAllowed)
        XCTAssertFalse(limiter.registerRequest(clientKey: "a", at: start.addingTimeInterval(61)).isAllowed)
    }

    func testClientsAreCountedSeparately() {
        let limiter = FixedWindowRateLimiter(limit: 1, windowSeconds: 60)
        XCTAssertTrue(limiter.registerRequest(clientKey: "a", at: start).isAllowed)
        XCTAssertTrue(limiter.registerRequest(clientKey: "b", at: start).isAllowed)
        XCTAssertFalse(limiter.registerRequest(clientKey: "a", at: start).isAllowed)
    }

    func testRetryAfterIsTheRemainingWindowRoundedUp() {
        let limiter = FixedWindowRateLimiter(limit: 1, windowSeconds: 60)
        _ = limiter.registerRequest(clientKey: "a", at: start)
        let refused = limiter.registerRequest(clientKey: "a", at: start.addingTimeInterval(20.2))
        XCTAssertFalse(refused.isAllowed)
        XCTAssertEqual(refused.retryAfterSeconds, 40)
    }

    func testRetryAfterIsAtLeastOneSecond() {
        let limiter = FixedWindowRateLimiter(limit: 1, windowSeconds: 60)
        _ = limiter.registerRequest(clientKey: "a", at: start)
        XCTAssertEqual(limiter.registerRequest(clientKey: "a", at: start.addingTimeInterval(59.999)).retryAfterSeconds, 1)
    }

    func testANewWindowStartsFromZero() {
        let limiter = FixedWindowRateLimiter(limit: 1, windowSeconds: 60)
        _ = limiter.registerRequest(clientKey: "a", at: start)
        XCTAssertFalse(limiter.registerRequest(clientKey: "a", at: start.addingTimeInterval(59)).isAllowed)
        XCTAssertTrue(limiter.registerRequest(clientKey: "a", at: start.addingTimeInterval(60)).isAllowed)
    }

    func testAClockStepBackwardsDoesNotLockClientsOut() {
        let limiter = FixedWindowRateLimiter(limit: 1, windowSeconds: 60)
        _ = limiter.registerRequest(clientKey: "a", at: start)
        XCTAssertTrue(limiter.registerRequest(clientKey: "a", at: start.addingTimeInterval(-1_000)).isAllowed)
    }

    func testEachAddressHasItsOwnWindowStartingAtItsFirstRequest() {
        let limiter = FixedWindowRateLimiter(limit: 1, windowSeconds: 60)
        XCTAssertTrue(limiter.registerRequest(clientKey: "a", at: start).isAllowed)
        XCTAssertTrue(limiter.registerRequest(clientKey: "b", at: start.addingTimeInterval(50)).isAllowed)
        // "a" window is over at +60 while "b" window runs until +110.
        XCTAssertTrue(limiter.registerRequest(clientKey: "a", at: start.addingTimeInterval(60)).isAllowed)
        let refused = limiter.registerRequest(clientKey: "b", at: start.addingTimeInterval(60))
        XCTAssertFalse(refused.isAllowed)
        XCTAssertEqual(refused.retryAfterSeconds, 50)
    }

    func testTheTableEvictsExpiredWindowsBeforeTheOldestOne() {
        let limiter = FixedWindowRateLimiter(limit: 1, windowSeconds: 60, maxAddresses: 2)
        XCTAssertTrue(limiter.registerRequest(clientKey: "old", at: start).isAllowed)
        XCTAssertTrue(limiter.registerRequest(clientKey: "newer", at: start.addingTimeInterval(30)).isAllowed)
        // "old" has expired, "newer" has not: only "old" may be evicted.
        XCTAssertTrue(limiter.registerRequest(clientKey: "third", at: start.addingTimeInterval(61)).isAllowed)
        XCTAssertFalse(limiter.registerRequest(clientKey: "newer", at: start.addingTimeInterval(62)).isAllowed)
    }

    func testTheOldestWindowIsEvictedWhenNoneHasExpired() {
        let limiter = FixedWindowRateLimiter(limit: 1, windowSeconds: 60, maxAddresses: 2)
        XCTAssertTrue(limiter.registerRequest(clientKey: "first", at: start).isAllowed)
        XCTAssertTrue(limiter.registerRequest(clientKey: "second", at: start.addingTimeInterval(10)).isAllowed)
        XCTAssertTrue(limiter.registerRequest(clientKey: "third", at: start.addingTimeInterval(20)).isAllowed)
        XCTAssertFalse(limiter.registerRequest(clientKey: "second", at: start.addingTimeInterval(21)).isAllowed)
        XCTAssertFalse(limiter.registerRequest(clientKey: "third", at: start.addingTimeInterval(21)).isAllowed)
        XCTAssertTrue(limiter.registerRequest(clientKey: "first", at: start.addingTimeInterval(22)).isAllowed, "evicted, so counted from zero")
    }

    func testARefusedRequestNeverEvictsAnotherAddress() {
        let limiter = FixedWindowRateLimiter(limit: 1, windowSeconds: 60, maxAddresses: 2)
        _ = limiter.registerRequest(clientKey: "a", at: start)
        _ = limiter.registerRequest(clientKey: "b", at: start.addingTimeInterval(1))
        for second in 2...5 { _ = limiter.registerRequest(clientKey: "a", at: start.addingTimeInterval(Double(second))) }
        XCTAssertFalse(limiter.registerRequest(clientKey: "b", at: start.addingTimeInterval(6)).isAllowed)
    }

    func testTheDefaultBoundIsTenThousandAddresses() {
        XCTAssertEqual(FixedWindowRateLimiter.maxTrackedAddresses, 10_000)
    }

    func testConcurrentRequestsNeverExceedTheLimit() async {
        let limiter = FixedWindowRateLimiter(limit: 50, windowSeconds: 60)
        let now = start
        let allowed = await withTaskGroup(of: Bool.self) { group in
            for _ in 0..<200 {
                group.addTask { limiter.registerRequest(clientKey: "a", at: now).isAllowed }
            }
            return await group.reduce(0) { $0 + ($1 ? 1 : 0) }
        }
        XCTAssertEqual(allowed, 50)
    }
}
