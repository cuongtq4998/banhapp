import Foundation
import XCTest
@testable import BanhContracts

final class HealthResponseTests: XCTestCase {
    /// Fixtures are the contract shared with the Android suite, so the Swift
    /// types are checked against the files, not against inline strings.
    private func fixtureData(_ name: String) throws -> Data {
        let fixtures = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // BanhContractsTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // swift
            .deletingLastPathComponent() // contracts
            .appendingPathComponent("fixtures")
        return try Data(contentsOf: fixtures.appendingPathComponent(name))
    }

    func testDecodesOkFixture() throws {
        let decoded = try JSONDecoder().decode(HealthResponse.self, from: fixtureData("healthz-ok.json"))
        XCTAssertEqual(decoded, HealthResponse(status: .ok))
    }

    func testDecodesDegradedFixture() throws {
        let decoded = try JSONDecoder().decode(HealthResponse.self, from: fixtureData("healthz-degraded.json"))
        XCTAssertEqual(decoded, HealthResponse(status: .degraded))
    }

    func testEncodesToTheFixtureShape() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(HealthResponse(status: .ok))
        XCTAssertEqual(String(decoding: data, as: UTF8.self), #"{"status":"ok"}"#)
    }
}
