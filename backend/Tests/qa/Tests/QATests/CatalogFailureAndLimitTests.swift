import XCTest
import XCTVapor
@testable import AppUnderTest

/// Slice 1 tests that need no database: 503 mapping (api.md 5, rule "Database
/// outage"), rate limit (api.md 1, ADR-0014), cache headers of static routes.
/// EXPECTED-FAIL until the slice 1 backend merges, except where noted.
final class CatalogFailureTests: XCTestCase {
    func testTC54_UnreachableDatabaseIsServiceUnavailableNotInternalError() async throws {
        let app = try await CatalogApp.makeUnreachable()
        defer { Task { try? await app.asyncShutdown() } }
        let started = Date()
        let r = try await app.qaSend(.GET, Slice1.catalogPath)
        XCTAssertEqual(r.status, .serviceUnavailable)
        XCTAssertEqual(Slice1.envelopeProblems(r, code: "SERVICE_UNAVAILABLE", messageKey: "ERR_SERVER"), [])
        XCTAssertLessThan(Date().timeIntervalSince(started), 10, "must answer inside the 15 s read timeout of the apps (ADR-0007)")
        for secret in ["127.0.0.1", "postgres://", "qa:qa", "password", "NIOCore", "PSQLError", "Fatal error"] {
            XCTAssertFalse(r.text.contains(secret), "body leaks \(secret)")
        }
        XCTAssertNil(r.header("ETag"), "an error must not carry the catalog ETag")
        let health = try await app.qaSend(.GET, "healthz")
        XCTAssertEqual(health.status, .ok, "shallow health stays up while the database is down")
    }

    func testTC54_NoDatabaseConfiguredAtAllIsServiceUnavailableAndDoesNotCrash() async throws {
        // Fluent traps (fatalError) when asked for a database that is not registered;
        // the catalog route must go through Request.databaseHandle and answer 503.
        let app = try await CatalogApp.makeWithoutDatabase()
        defer { Task { try? await app.asyncShutdown() } }
        let r = try await app.qaSend(.GET, Slice1.catalogPath)
        XCTAssertEqual(r.status, .serviceUnavailable)
        XCTAssertEqual(Slice1.envelopeProblems(r, code: "SERVICE_UNAVAILABLE", messageKey: "ERR_SERVER"), [])
    }

    func testExtra_ConditionalRequestDuringOutageStillNever304() async throws {
        // A 304 without checking the data would hide an outage; the app must see 503 and keep its cache silently.
        let app = try await CatalogApp.makeUnreachable()
        defer { Task { try? await app.asyncShutdown() } }
        for header in ["*", "\"abc\"", "W/\"abc\""] {
            let r = try await app.qaSend(.GET, Slice1.catalogPath, headers: ["If-None-Match": header])
            XCTAssertEqual(r.status, .serviceUnavailable, header)
        }
    }
}

final class ReadRateLimitTests: XCTestCase {
    private var app: Application!

    override func setUp() async throws {
        app = try await CatalogApp.makeWithoutDatabase()
    }

    override func tearDown() async throws { try await app.asyncShutdown() }

    /// TC-50, boundary 120 per minute. `/healthz` is in the read group (api.md 1).
    /// EXPECTED-FAIL until the limiter lands (slice 1).
    func testTC50_The121stReadInAMinuteIsRateLimited() async throws {
        for i in 1...120 {
            let r = try await app.qaSend(.GET, "healthz")
            XCTAssertEqual(r.status, .ok, "request \(i) is inside the budget")
            if r.status != .ok { return }
        }
        let limited = try await app.qaSend(.GET, "healthz")
        XCTAssertEqual(limited.status, .tooManyRequests)
        XCTAssertEqual(Slice1.envelopeProblems(limited, code: "RATE_LIMITED", messageKey: "ERR_RATE_LIMITED"), [])
        let after = try XCTUnwrap(limited.header("Retry-After").flatMap(Int.init), "Retry-After must be an integer number of seconds")
        XCTAssertTrue((1...60).contains(after), "Retry-After \(after) must be within the 60 s window")
        XCTAssertEqual(limited.json?["error"]?["details"]?["retry_after_seconds"]?.int, after)
        XCTAssertEqual(limited.header("Cache-Control")?.lowercased().contains("no-store") ?? true, true, "a 429 must not be cached")
        XCTAssertNil(limited.header("ETag"))
    }

    /// The table in api.md 1 gives one group: GET /v1/*, /healthz, /privacy and /assets/*
    /// share 120 per minute. (Document question: per route or shared; see test document Q-A17.)
    func testExtra_ReadGroupIsOneSharedBudget() async throws {
        let paths = ["healthz", "v1/catalog", "privacy", "assets/products/none.png"]
        for i in 0..<120 { _ = try await app.qaSend(.GET, paths[i % paths.count]) }
        let r = try await app.qaSend(.GET, "v1/catalog")
        XCTAssertEqual(r.status, .tooManyRequests, "121st read across the group")
    }

    /// Rate-limited and 304 answers still count; a client cannot dodge the limit with conditional requests.
    func testExtra_SpoofedForwardedForHeaderDoesNotResetTheBudgetByDefault() async throws {
        // TRUST_PROXY is off by default (ADR-0014): the forwarded header must be ignored.
        for i in 0..<120 { _ = try await app.qaSend(.GET, "healthz", headers: ["X-Forwarded-For": "203.0.113.\(i % 250)"]) }
        let r = try await app.qaSend(.GET, "healthz", headers: ["X-Forwarded-For": "198.51.100.77"])
        XCTAssertEqual(r.status, .tooManyRequests)
    }

    func testExtra_LimitedResponseIsStillTheContractEnvelopeForEveryReadRoute() async throws {
        for _ in 0..<130 { _ = try await app.qaSend(.GET, "healthz") }
        for path in ["healthz", "v1/catalog", "privacy", "assets/products/none.png", "v1/unknown"] {
            let r = try await app.qaSend(.GET, path)
            XCTAssertEqual(r.status, .tooManyRequests, path)
            XCTAssertEqual(r.errorCode, "RATE_LIMITED", path)
        }
    }
}
