import XCTest
@testable import App

/// At most two uploads at once; the third waits a little and then gets 503 (ADR-0025).
final class UploadGateTests: XCTestCase {
    func testAThirdUploadWaitsAndThenIsRefusedWhileTwoRun() async throws {
        let gate = UploadGate(limit: 2, wait: .milliseconds(200))
        let busy = Task { try await gate.run { try await Task.sleep(for: .milliseconds(600)) } }
        let busyToo = Task { try await gate.run { try await Task.sleep(for: .milliseconds(600)) } }
        try await Task.sleep(for: .milliseconds(100))
        do {
            try await gate.run { }
            XCTFail("a third upload ran")
        } catch let error as APIError {
            XCTAssertEqual(error.code, .serviceUnavailable)
        }
        try await busy.value
        try await busyToo.value
        try await gate.run { }
    }

    func testAnUploadThatWaitsForRoomRunsWhenOneEnds() async throws {
        let gate = UploadGate(limit: 1, wait: .seconds(2))
        let first = Task { try await gate.run { try await Task.sleep(for: .milliseconds(150)) } }
        try await Task.sleep(for: .milliseconds(30))
        try await gate.run { }
        try await first.value
    }
}
