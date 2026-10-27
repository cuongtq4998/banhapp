import XCTVapor
import BanhContracts
@testable import App

/// Shared fixture of the catalogue route tests: an app with a stubbed
/// repository and a fixed clock. It holds no tests itself.
class CatalogRouteTestCase: XCTestCase {
    var app: Application!

    override func setUp() async throws {
        app = try await Application.make(.testing)
        try await configure(app, config: .localWithShop())
        app.services.clock = CatalogTestData.fixtureClock
        app.services.stubCatalogRepository { _ in CatalogTestData.snapshot }
    }

    override func tearDown() async throws {
        try await app.asyncShutdown()
    }

    func fetchETag() async throws -> String {
        var tag = ""
        try await app.test(.GET, "v1/catalog") { res async throws in
            tag = try XCTUnwrap(res.headers.first(name: .eTag))
        }
        return tag
    }
}
