import XCTest
import XCTVapor
@testable import AppUnderTest

/// Application without a database for the static-content tests; holds no test methods.
class StaticContentBase: XCTestCase {
    var app: Application!

    override func setUp() async throws {
        app = try await CatalogApp.makeWithoutDatabase()
    }

    override func tearDown() async throws { try await app.asyncShutdown() }
}
