import XCTVapor
import BanhContracts
@testable import App

final class AvailabilityRouteTests: XCTestCase {
    private var app: Application!

    private func start(rateLimit: Int = AppConfig.Default.rateLimitReadPerMinute) async throws {
        app = try await Application.make(.testing)
        try await configure(app, config: .localWithShop(rateLimitReadPerMinute: rateLimit))
        app.services.clock = AvailabilityTestData.clock
        app.services.stubAvailabilityRepository(
            FakeAvailabilityRepository(rules: AvailabilityTestData.rules, accepted: AvailabilityTestData.fixtureLoads)
        )
    }

    override func tearDown() async throws {
        try await app?.asyncShutdown()
    }

    func testMatchesTheSharedFixtureAndIsNotCached() async throws {
        try await start()
        try await app.test(.GET, "v1/availability?cakes=3") { res async throws in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.headers.first(name: .cacheControl), "no-store")
            XCTAssertNil(res.headers.first(name: .eTag))
            XCTAssertNotNil(res.headers.first(name: "X-Request-Id"))
            XCTAssertEqual(res.headers.contentType, .json)
            let expected = try JSONDecoder().decode(
                AvailabilityResponse.self,
                from: Data(contentsOf: TestPaths.contractFixtures.appendingPathComponent("availability-ok.json"))
            )
            XCTAssertEqual(try res.content.decode(AvailabilityResponse.self), expected)
        }
    }

    func testAvailableDateCarriesAnExplicitNullReasonAndNoRemainingAmount() async throws {
        try await start()
        try await app.test(.GET, "v1/availability?cakes=3") { res async throws in
            let text = res.body.string
            XCTAssertTrue(text.contains(#""reason":null"#))
            XCTAssertFalse(text.contains("remaining"))
            XCTAssertFalse(text.contains("daily_limit"))
        }
    }

    func testInvalidCakesAnswer422WithTheFieldError() async throws {
        try await start()
        for query in ["", "?cakes=", "?cakes=0", "?cakes=-2", "?cakes=397", "?cakes=abc", "?cakes=1.5"] {
            try await app.test(.GET, "v1/availability\(query)") { res async throws in
                XCTAssertEqual(res.status, .unprocessableEntity, query)
                let body = try res.content.decode(APIErrorResponse.self)
                XCTAssertEqual(body.error.code, "VALIDATION_FAILED", query)
                XCTAssertEqual(body.error.messageKey, "ERR_SERVER", query)
                XCTAssertEqual(body.error.fields, [.init(field: "cakes", code: "CAKES_INVALID", messageKey: "ERR_SERVER")], query)
            }
        }
    }

    func testBoundsAreAccepted() async throws {
        try await start()
        for cakes in [1, 396] {
            try await app.test(.GET, "v1/availability?cakes=\(cakes)") { res async throws in
                XCTAssertEqual(res.status, .ok, "\(cakes)")
            }
        }
    }

    func testOtherQueryParametersAreIgnored() async throws {
        try await start()
        try await app.test(.GET, "v1/availability?cakes=3&slot=abc&foo=1") { res async throws in
            XCTAssertEqual(res.status, .ok)
        }
    }

    func testRepositoryOutageAnswers503() async throws {
        try await start()
        app.services.repositories.makeAvailabilityRepository = { _ in ThrowingAvailabilityRepository() }
        try await app.test(.GET, "v1/availability?cakes=3") { res async throws in
            XCTAssertEqual(res.status, .serviceUnavailable)
            XCTAssertEqual(try res.content.decode(APIErrorResponse.self).error.code, "SERVICE_UNAVAILABLE")
        }
    }

    func testSharesTheReadRateLimitWithTheCatalogue() async throws {
        try await start(rateLimit: 2)
        app.services.stubCatalogRepository { _ in CatalogTestData.snapshot }
        try await app.test(.GET, "v1/catalog") { res async throws in XCTAssertEqual(res.status, .ok) }
        try await app.test(.GET, "v1/availability?cakes=3") { res async throws in XCTAssertEqual(res.status, .ok) }
        try await app.test(.GET, "v1/availability?cakes=3") { res async throws in
            XCTAssertEqual(res.status, .tooManyRequests)
            let body = try res.content.decode(APIErrorResponse.self)
            XCTAssertEqual(body.error.code, "RATE_LIMITED")
            XCTAssertNotNil(res.headers.first(name: .retryAfter))
        }
    }

    func testWithoutAShopTheEndpointIsUnavailable() async throws {
        app = try await Application.make(.testing)
        try await configure(app, config: .unreachableDatabase)
        try await app.test(.GET, "v1/availability?cakes=3") { res async throws in
            XCTAssertEqual(res.status, .serviceUnavailable)
        }
    }
}

private struct ThrowingAvailabilityRepository: AvailabilityRepository {
    func loadRules(shopID: UUID) async throws -> AvailabilityRules { throw APIError(.serviceUnavailable) }
    func loadAcceptedCakes(shopID: UUID, from: BusinessDate, through: BusinessDate) async throws -> [BusinessDate: Int] {
        throw APIError(.serviceUnavailable)
    }
}
