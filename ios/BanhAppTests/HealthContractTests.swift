import BanhContracts
import XCTest

final class HealthContractTests: XCTestCase {
    /// The shared fixture is the same file the backend and Android tests use, so a
    /// drift in the Swift contract type fails here. It is read relative to this
    /// source file because the tests run on the host Mac, not inside the simulator
    /// sandbox, and the fixture lives outside the Xcode project.
    func testHealthzOkFixtureDecodesThroughBanhContracts() throws {
        let fixture = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // BanhAppTests
            .deletingLastPathComponent() // ios
            .deletingLastPathComponent() // repository root
            .appendingPathComponent("contracts/fixtures/healthz-ok.json")
        let data = try Data(contentsOf: fixture)

        let response = try JSONDecoder().decode(HealthResponse.self, from: data)

        XCTAssertEqual(response, HealthResponse(status: .ok))
    }
}
