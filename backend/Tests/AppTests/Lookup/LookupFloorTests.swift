import XCTVapor
@testable import App

/// The response-time floor and its warning line (api/10).
final class LookupFloorTests: LookupRouteTestCase {
    private let slowFloorMilliseconds = 0
    private let paddedFloorMilliseconds = 150

    func testSlowAnswerLogsOneWarningWithoutPhone() async throws {
        var policy = LookupPolicy()
        policy.floorMilliseconds = slowFloorMilliseconds
        try await start(policy: policy)
        store.plant(normalised, [.sample(1)])
        try await lookup(#"{"phone":"\#(phone)"}"#) { XCTAssertEqual($0.status, .ok) }
        let warnings = capture.lines.filter { $0.message == LookupMetrics.eventMessage }
        XCTAssertEqual(warnings.count, 1)
        XCTAssertEqual(app.services.lookupMetrics.floorExceededCount, 1)
        let metadata = try XCTUnwrap(warnings.first?.metadata)
        XCTAssertEqual(Set(metadata.keys).subtracting(["request-id"]), ["duration_ms", "floor_ms"])
        let everything = capture.lines.map { "\($0.message) \($0.metadata)" }.joined()
        XCTAssertFalse(everything.contains(phone))
        XCTAssertFalse(everything.contains(String(normalised.dropFirst())))
    }

    func testFastAnswerIsPaddedToTheFloor() async throws {
        var policy = LookupPolicy()
        policy.floorMilliseconds = paddedFloorMilliseconds
        try await start(policy: policy)
        let started = ContinuousClock.now
        try await lookup(#"{"phone":"\#(phone)"}"#) { XCTAssertEqual($0.status, .ok) }
        XCTAssertGreaterThanOrEqual(ContinuousClock.now - started, .milliseconds(paddedFloorMilliseconds))
        XCTAssertEqual(app.services.lookupMetrics.floorExceededCount, 0)
    }
}
