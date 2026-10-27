import XCTVapor
import BanhContracts
@testable import App

final class CatalogRouteFailureTests: CatalogRouteTestCase {
    func testDatabaseOutageIsTheContract503() async throws {
        // The real repository against a closed port, no stub.
        let real = try await Application.make(.testing)
        defer { Task { try? await real.asyncShutdown() } }
        try await configure(real, config: .localWithShop())
        try await real.test(.GET, "v1/catalog") { res async throws in
            XCTAssertEqual(res.status, .serviceUnavailable)
            let envelope = try res.content.decode(APIErrorResponse.self)
            XCTAssertEqual(envelope.error.code, "SERVICE_UNAVAILABLE")
            XCTAssertEqual(envelope.error.messageKey, "ERR_SERVER")
            XCTAssertNil(res.headers.first(name: .retryAfter))
        }
    }

    func testRepositoryOutageIsTheContract503() async throws {
        app.services.stubCatalogRepository { _ in throw APIError(.serviceUnavailable) }
        try await app.test(.GET, "v1/catalog") { res async throws in
            XCTAssertEqual(res.status, .serviceUnavailable)
            XCTAssertEqual(try res.content.decode(APIErrorResponse.self).error.code, "SERVICE_UNAVAILABLE")
        }
    }

    func testUnknownShopIsAnInternalError() async throws {
        app.services.stubCatalogRepository { _ in throw CatalogRepositoryError.shopNotFound }
        try await app.test(.GET, "v1/catalog") { res async throws in
            XCTAssertEqual(res.status, .internalServerError)
            XCTAssertEqual(try res.content.decode(APIErrorResponse.self).error.code, "INTERNAL_ERROR")
        }
    }

    func testMissingShopIDAnswers503() async throws {
        let bare = try await Application.make(.testing)
        defer { Task { try? await bare.asyncShutdown() } }
        try await configure(bare, config: .unreachableDatabase)
        bare.services.stubCatalogRepository { _ in CatalogTestData.snapshot }
        try await bare.test(.GET, "v1/catalog") { res async throws in
            XCTAssertEqual(res.status, .serviceUnavailable)
        }
    }

    func testNoDatabaseConfiguredAnswers503() async throws {
        let bare = try await Application.make(.testing)
        defer { Task { try? await bare.asyncShutdown() } }
        try await configure(bare, config: AppConfig(stage: .local, port: 8080, databaseURL: nil, shopID: AppConfig.testShopID))
        try await bare.test(.GET, "v1/catalog") { res async throws in
            XCTAssertEqual(res.status, .serviceUnavailable)
        }
    }

    func testOtherMethodsAreNotRouted() async throws {
        try await app.test(.POST, "v1/catalog") { res async throws in
            XCTAssertEqual(res.status, .notFound)
        }
    }

    func testPublicAssetBaseURLReachesTheBody() async throws {
        let cdn = try await Application.make(.testing)
        defer { Task { try? await cdn.asyncShutdown() } }
        try await configure(cdn, config: .localWithShop(publicAssetBaseURL: "https://cdn.example"))
        cdn.services.stubCatalogRepository { _ in CatalogTestData.snapshot }
        try await cdn.test(.GET, "v1/catalog") { res async throws in
            XCTAssertTrue(res.body.string.contains("\"image_url\":\"https://cdn.example/assets/images/banana.png?v=a547ade3\""))
        }
    }
}
