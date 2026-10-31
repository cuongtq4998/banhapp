import XCTVapor
import BanhContracts
@testable import App

final class RateLimitMiddlewareTests: XCTestCase {
    private func makeApp(limit: Int, trustProxy: Bool = false) async throws -> Application {
        let app = try await Application.make(.testing)
        try await configure(app, config: .localWithShop(rateLimitReadPerMinute: limit, trustProxy: trustProxy))
        app.services.clock = CatalogTestData.fixtureClock
        app.services.stubCatalogRepository { _ in CatalogTestData.snapshot }
        return app
    }

    func testTheRequestOverTheLimitGetsTheContract429() async throws {
        let app = try await makeApp(limit: 2)
        defer { Task { try? await app.asyncShutdown() } }
        try await app.test(.GET, "v1/catalog") { res async throws in XCTAssertEqual(res.status, .ok) }
        try await app.test(.GET, "v1/catalog") { res async throws in XCTAssertEqual(res.status, .ok) }
        try await app.test(.GET, "v1/catalog") { res async throws in
            XCTAssertEqual(res.status, .tooManyRequests)
            let envelope = try res.content.decode(APIErrorResponse.self)
            XCTAssertEqual(envelope.error.code, "RATE_LIMITED")
            XCTAssertEqual(envelope.error.messageKey, "ERR_RATE_LIMITED")
            let header = try XCTUnwrap(res.headers.first(name: .retryAfter).flatMap(Int.init))
            XCTAssertEqual(envelope.error.details["retry_after_seconds"], .int(header))
            XCTAssertTrue((1...60).contains(header))
            XCTAssertNil(envelope.error.fields)
        }
    }

    func testTheReadLimitCoversEveryReadEndpoint() async throws {
        let app = try await makeApp(limit: 1)
        defer { Task { try? await app.asyncShutdown() } }
        try await app.test(.GET, "healthz") { res async throws in XCTAssertEqual(res.status, .ok) }
        for path in ["healthz", "v1/catalog", "privacy", "assets/images/banana.png"] {
            try await app.test(.GET, path) { res async throws in
                XCTAssertEqual(res.status, .tooManyRequests, path)
            }
        }
    }

    func testTheWindowReopensWhenTheClockMovesOn() async throws {
        let app = try await makeApp(limit: 1)
        defer { Task { try? await app.asyncShutdown() } }
        try await app.test(.GET, "v1/catalog") { res async throws in XCTAssertEqual(res.status, .ok) }
        try await app.test(.GET, "v1/catalog") { res async throws in XCTAssertEqual(res.status, .tooManyRequests) }
        app.services.clock = FixedWallClock(instant: CatalogTestData.fixtureClock.instant.addingTimeInterval(61))
        try await app.test(.GET, "v1/catalog") { res async throws in XCTAssertEqual(res.status, .ok) }
    }

    func testForwardedAddressesAreIgnoredUnlessTheProxyIsTrusted() async throws {
        let app = try await makeApp(limit: 1)
        defer { Task { try? await app.asyncShutdown() } }
        try await app.test(.GET, "v1/catalog", headers: ["X-Forwarded-For": "203.0.113.1"]) { res async throws in XCTAssertEqual(res.status, .ok) }
        try await app.test(.GET, "v1/catalog", headers: ["X-Forwarded-For": "203.0.113.2"]) { res async throws in
            XCTAssertEqual(res.status, .tooManyRequests, "a client must not pick its own bucket")
        }
    }

    func testTrustedProxyCountsTheLastForwardedAddress() async throws {
        let app = try await makeApp(limit: 1, trustProxy: true)
        defer { Task { try? await app.asyncShutdown() } }
        // The first entry is whatever the client claims; only the last is the proxy's observation.
        try await app.test(.GET, "v1/catalog", headers: ["X-Forwarded-For": "198.51.100.1, 203.0.113.1"]) { res async throws in XCTAssertEqual(res.status, .ok) }
        try await app.test(.GET, "v1/catalog", headers: ["X-Forwarded-For": "198.51.100.2, 203.0.113.1"]) { res async throws in
            XCTAssertEqual(res.status, .tooManyRequests, "same last entry, same client")
        }
        try await app.test(.GET, "v1/catalog", headers: ["X-Forwarded-For": "198.51.100.1, 203.0.113.9"]) { res async throws in
            XCTAssertEqual(res.status, .ok, "different last entry, different client")
        }
    }

    func testTrustedProxyJoinsSeparateForwardedLinesAndUsesTheLastEntry() async throws {
        let app = try await makeApp(limit: 1, trustProxy: true)
        defer { Task { try? await app.asyncShutdown() } }
        func headers(forged: String) -> HTTPHeaders {
            var headers = HTTPHeaders()
            headers.add(name: "X-Forwarded-For", value: forged)
            headers.add(name: "X-Forwarded-For", value: "203.0.113.1")
            return headers
        }
        try await app.test(.GET, "v1/catalog", headers: headers(forged: "198.51.100.1")) { res async throws in XCTAssertEqual(res.status, .ok) }
        try await app.test(.GET, "v1/catalog", headers: headers(forged: "198.51.100.2")) { res async throws in
            XCTAssertEqual(res.status, .tooManyRequests, "a forged first line must not choose the bucket")
        }
    }

    func testTrustedProxyWithoutTheHeaderFallsBackToTheConnection() async throws {
        let app = try await makeApp(limit: 1, trustProxy: true)
        defer { Task { try? await app.asyncShutdown() } }
        try await app.test(.GET, "v1/catalog") { res async throws in XCTAssertEqual(res.status, .ok) }
        try await app.test(.GET, "v1/catalog") { res async throws in XCTAssertEqual(res.status, .tooManyRequests) }
    }

    func testUnroutedReadsAndNotModifiedAnswersCountAgainstTheLimit() async throws {
        let app = try await makeApp(limit: 2)
        defer { Task { try? await app.asyncShutdown() } }
        try await app.test(.GET, "nope") { res async throws in XCTAssertEqual(res.status, .notFound) }
        try await app.test(.GET, "v1/catalog", headers: ["If-None-Match": "*"]) { res async throws in XCTAssertEqual(res.status, .notModified) }
        try await app.test(.GET, "v1/catalog") { res async throws in XCTAssertEqual(res.status, .tooManyRequests) }
    }

    func testWritesDoNotUseTheReadBudget() async throws {
        let app = try await makeApp(limit: 1)
        defer { Task { try? await app.asyncShutdown() } }
        try await app.test(.POST, "v1/catalog") { res async throws in XCTAssertEqual(res.status, .notFound) }
        try await app.test(.GET, "v1/catalog") { res async throws in XCTAssertEqual(res.status, .ok) }
    }

    func testTheWindowLengthComesFromTheConfiguration() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try? await app.asyncShutdown() } }
        let config = AppConfig(
            stage: .local, port: 8080, databaseURL: "postgres://test:test@127.0.0.1:1/test",
            shopID: AppConfig.testShopID, rateLimitReadPerMinute: 1, rateLimitWindowSeconds: 5
        )
        try await configure(app, config: config)
        app.services.clock = CatalogTestData.fixtureClock
        try await app.test(.GET, "nope") { _ async throws in }
        try await app.test(.GET, "nope") { res async throws in
            XCTAssertEqual(res.status, .tooManyRequests)
            XCTAssertTrue((1...5).contains(try XCTUnwrap(res.headers.first(name: .retryAfter).flatMap(Int.init))))
        }
        app.services.clock = FixedWallClock(instant: CatalogTestData.fixtureClock.instant.addingTimeInterval(6))
        try await app.test(.GET, "nope") { res async throws in XCTAssertEqual(res.status, .notFound) }
    }
}
