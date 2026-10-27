import XCTest
@testable import AppUnderTest

// MARK: - Deadline race

final class DeadlineEdgeTests: XCTestCase {
    func testFastOperationsLeaveNothingBehind() async throws {
        let started = ContinuousClock.now
        for i in 0..<2_000 {
            let value = try await withDeadline(.seconds(5)) { i }
            XCTAssertEqual(value, i)
        }
        XCTAssertLessThan(ContinuousClock.now - started, .seconds(10))
    }

    func testOperationErrorPropagatesUnchanged() async {
        struct Boom: Error {}
        do { _ = try await withDeadline(.seconds(5)) { () async throws -> Int in throw Boom() }; XCTFail() }
        catch { XCTAssertTrue(error is Boom) }
    }

    func testSlowOperationTimesOutOnTime() async {
        let started = ContinuousClock.now
        do { try await withDeadline(.milliseconds(200)) { try await Task.sleep(for: .seconds(10)) }; XCTFail() }
        catch { XCTAssertTrue(error is DeadlineExceededError) }
        let elapsed = ContinuousClock.now - started
        XCTAssertGreaterThan(elapsed, .milliseconds(150))
        XCTAssertLessThan(elapsed, .seconds(2))
    }

    func testOperationIgnoringCancellationStillTimesOut() async {
        let started = ContinuousClock.now
        do {
            try await withDeadline(.milliseconds(150)) {
                await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
                    DispatchQueue.global().asyncAfter(deadline: .now() + 1.5) { c.resume() }
                }
            }
            XCTFail()
        } catch { XCTAssertTrue(error is DeadlineExceededError) }
        XCTAssertLessThan(ContinuousClock.now - started, .seconds(1))
    }

    func testCallerCancellationIsPrompt() async {
        let task = Task { try await withDeadline(.seconds(30)) { try await Task.sleep(for: .seconds(30)) } }
        try? await Task.sleep(for: .milliseconds(100))
        let started = ContinuousClock.now
        task.cancel()
        do { _ = try await task.value; XCTFail() } catch { XCTAssertTrue(error is CancellationError, "\(error)") }
        XCTAssertLessThan(ContinuousClock.now - started, .seconds(1))
    }

    func testAlreadyCancelledCallerFailsFastWithoutHanging() async {
        let task = Task { () async throws -> Int in
            try await Task.sleep(for: .milliseconds(1)) // lets the cancel below land first
            return try await withDeadline(.seconds(30)) { try await Task.sleep(for: .seconds(30)); return 1 }
        }
        task.cancel()
        do { _ = try await task.value; XCTFail() } catch { /* CancellationError either way */ }
    }

    func testZeroAndNegativeLimitsNeverHang() async {
        for limit in [Duration.zero, .milliseconds(-5)] {
            do { _ = try await withDeadline(limit) { try await Task.sleep(for: .seconds(5)) } ; XCTFail() }
            catch { XCTAssertTrue(error is DeadlineExceededError, "\(limit): \(error)") }
        }
    }

    func testRacingFinishAndTimerNeverResumesTwice() async throws {
        // 600 concurrent races where the operation ends about when the timer fires.
        let outcomes = try await withThrowingTaskGroup(of: Bool.self) { group in
            for i in 0..<600 {
                group.addTask {
                    do {
                        try await withDeadline(.milliseconds(10)) { try await Task.sleep(for: .milliseconds(8 + (i % 5))) }
                        return true
                    } catch is DeadlineExceededError { return false }
                }
            }
            var all: [Bool] = []
            for try await o in group { all.append(o) }
            return all
        }
        XCTAssertEqual(outcomes.count, 600)
    }
}
