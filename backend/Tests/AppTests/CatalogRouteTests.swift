import XCTVapor
import BanhContracts
@testable import App

final class CatalogRouteTests: XCTestCase {
    private var app: Application!

    override func setUp() async throws {
        app = try await Application.make(.testing)
        try await configure(app, config: .localWithShop())
        app.services.clock = CatalogTestData.fixtureClock
        app.services.stubCatalogRepository { _ in CatalogTestData.snapshot }
    }

    override func tearDown() async throws {
        try await app.asyncShutdown()
    }

    private func fetchETag() async throws -> String {
        var tag = ""
        try await app.test(.GET, "v1/catalog") { res async throws in
            tag = try XCTUnwrap(res.headers.first(name: .eTag))
        }
        return tag
    }

    func testReturnsTheSharedFixtureWithValidators() async throws {
        try await app.test(.GET, "v1/catalog") { res async throws in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.headers.first(name: .cacheControl), "no-cache")
            XCTAssertNotNil(res.headers.first(name: .eTag))
            XCTAssertEqual(res.headers.contentType, .json)
            XCTAssertEqual(try res.content.decode(CatalogResponse.self), try CatalogTestData.fixture("catalog-ok.json"))
        }
    }

    func testBodyKeepsSlashesAndHidesTheDailyLimit() async throws {
        try await app.test(.GET, "v1/catalog") { res async throws in
            let text = res.body.string
            XCTAssertTrue(text.contains("\"image_url\":\"/assets/images/banana.png?v=a547ade3\""))
            XCTAssertFalse(text.contains("daily_limit"))
            XCTAssertFalse(text.contains("is_sample"))
        }
    }

    func testEmptyCatalogBytesArePinned() async throws {
        // The exact encoding is part of the contract: sorted keys, compact,
        // slashes unescaped. A change here changes every ETag.
        let empty = CatalogSnapshot(
            shop: CatalogTestData.snapshot.shop, ordering: CatalogTestData.snapshot.ordering,
            products: [], districts: [], slots: []
        )
        app.services.stubCatalogRepository { _ in empty }
        let expected = #"{"districts":[],"products":[],"server_date":"2026-11-02","settings":{"lead_days":2,"max_days_ahead":30,"max_qty_per_cake":99,"min_qty":2,"note_max_length":200},"shop":{"greeting":"Bánh làm thủ công, giao tận nơi.","name":"Tiệm Bánh An Nhiên","phone_contact":"+84900000000","zalo_contact":"84900000000"},"slots":[]}"#
        try await app.test(.GET, "v1/catalog") { res async throws in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.body.string, expected)
            XCTAssertEqual(res.headers.first(name: .eTag), EntityTag(hashing: Data(expected.utf8)).headerValue)
        }
    }

    func testETagIsQuotedLowerCaseHexOf32Characters() async throws {
        let tag = try await fetchETag()
        XCTAssertTrue(tag.wholeMatch(of: /"[0-9a-f]{32}"/) != nil, tag)
    }

    func testUnknownQueryParametersAreIgnored() async throws {
        let plain = try await fetchETag()
        try await app.test(.GET, "v1/catalog?foo=1&bar=x") { res async throws in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.headers.first(name: .eTag), plain)
        }
    }

    func testNotModifiedRepeatsTheRequestID() async throws {
        let tag = try await fetchETag()
        try await app.test(.GET, "v1/catalog", headers: ["If-None-Match": tag]) { res async throws in
            XCTAssertEqual(res.status, .notModified)
            XCTAssertNotNil(res.headers.first(name: "X-Request-Id"))
        }
    }

    func testIdsAreLowerCaseOnTheWire() async throws {
        try await app.test(.GET, "v1/catalog") { res async throws in
            XCTAssertTrue(res.body.string.contains("\"product_id\":\"00000000-0000-4000-8000-000000000011\""))
        }
    }

    func testMatchingETagAnswers304WithoutBody() async throws {
        let tag = try await fetchETag()
        try await app.test(.GET, "v1/catalog", headers: [HTTPHeaders.Name.ifNoneMatch.description: tag]) { res async throws in
            XCTAssertEqual(res.status, .notModified)
            XCTAssertEqual(res.body.readableBytes, 0)
            XCTAssertEqual(res.headers.first(name: .eTag), tag)
            XCTAssertEqual(res.headers.first(name: .cacheControl), "no-cache")
            XCTAssertNil(res.headers.first(name: .contentType))
        }
    }

    func testStaleETagAnswers200() async throws {
        try await app.test(.GET, "v1/catalog", headers: ["If-None-Match": "\"stale\""]) { res async throws in
            XCTAssertEqual(res.status, .ok)
            XCTAssertGreaterThan(res.body.readableBytes, 0)
        }
    }

    func testETagChangesWhenAPriceChanges() async throws {
        let before = try await fetchETag()
        let original = CatalogTestData.snapshot
        let changed = CatalogSnapshot(
            shop: original.shop,
            ordering: original.ordering,
            products: original.products.map {
                ProductRecord(id: $0.id, slug: $0.slug, name: $0.name, description: $0.description, priceVND: $0.priceVND + 1, imagePath: $0.imagePath)
            },
            districts: original.districts,
            slots: original.slots
        )
        app.services.stubCatalogRepository { _ in changed }
        let after = try await fetchETag()
        XCTAssertNotEqual(before, after)
    }

    func testETagChangesWhenTheShopDateChanges() async throws {
        let before = try await fetchETag()
        app.services.clock = FixedWallClock(instant: CatalogTestData.fixtureClock.instant.addingTimeInterval(86_400))
        let after = try await fetchETag()
        XCTAssertNotEqual(before, after, "server_date is part of the body")
    }

    func testETagIsStableAcrossRequests() async throws {
        let first = try await fetchETag()
        let second = try await fetchETag()
        XCTAssertEqual(first, second)
    }

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
