import XCTest
import XCTVapor
@testable import AppUnderTest

/// Slice 1 tests that need no database: 503 mapping (api.md 5, rule "Database
/// outage"), rate limit (api.md 1 v1.6, ADR-0014, ADR-0017), cache headers of
/// static routes.
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

    /// api.md 4.1 says an unrouted HEAD answers 404, but Vapor serves HEAD with the GET handler (RFC 9110 9.3.2
    /// requires it). Observed behaviour is pinned here; the document is the one to change (see test document, DOC-S1-3).
    func testExtra_HeadIsAnsweredLikeGetNotAs404() async throws {
        let app = try await CatalogApp.makeWithoutDatabase()
        defer { Task { try? await app.asyncShutdown() } }
        let get = try await app.qaSend(.GET, Slice1.catalogPath)
        let head = try await app.qaSend(.HEAD, Slice1.catalogPath)
        XCTAssertEqual(head.status, get.status)
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
