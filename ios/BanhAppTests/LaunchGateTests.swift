import XCTest
@testable import BanhApp

@MainActor
final class LaunchGateTests: XCTestCase {
    private let gate = LaunchGate(minDuration: .milliseconds(150), maxDuration: .milliseconds(500))

    private func elapsed(settled: @MainActor () -> Bool) async -> Duration {
        let clock = ContinuousClock()
        let start = clock.now
        await gate.awaitExit(settled: settled)
        return start.duration(to: clock.now)
    }

    func testWaitsTheMinimumEvenWhenTheDataIsAlreadyThere() async {
        let time = await elapsed { true }
        XCTAssertGreaterThanOrEqual(time, .milliseconds(150))
        XCTAssertLessThan(time, .milliseconds(450))
    }

    func testNeverWaitsPastTheMaximumForSlowStartWork() async {
        let time = await elapsed { false }
        XCTAssertGreaterThanOrEqual(time, .milliseconds(500))
        XCTAssertLessThan(time, .milliseconds(900))
    }

    func testLeavesAsSoonAsTheWorkSettlesBetweenMinimumAndMaximum() async {
        let clock = ContinuousClock()
        let start = clock.now
        let time = await elapsed { start.duration(to: clock.now) > .milliseconds(300) }
        XCTAssertGreaterThanOrEqual(time, .milliseconds(300))
        XCTAssertLessThan(time, .milliseconds(480))
    }

    func testDefaultsAreOneAndTwoSeconds() {
        XCTAssertEqual(LaunchGate.defaultMinDuration, .seconds(1))
        XCTAssertEqual(LaunchGate.defaultMaxDuration, .seconds(2))
    }
}
