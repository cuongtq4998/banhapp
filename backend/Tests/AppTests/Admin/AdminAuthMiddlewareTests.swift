import XCTVapor
import BanhContracts
@testable import App

/// Access-token checks (api/05 section 9) over fake session rows.
final class AdminAuthMiddlewareTests: AdminRouteTestCase {
    private func get(_ token: SessionToken?, headers custom: HTTPHeaders? = nil, _ check: (XCTHTTPResponse) throws -> Void) async throws {
        try await app.test(.GET, "v1/admin/me", headers: custom ?? headers(token)) { res async throws in try check(res) }
    }

    private func code(_ res: XCTHTTPResponse) throws -> String {
        try res.content.decode(APIErrorResponse.self).error.code
    }

    func testValidTokenReadsMe() async throws {
        let (record, token) = FakeSession.make(role: .staff)
        sessions.put(record)
        try await get(token) { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.headers.first(name: .cacheControl), "no-store")
            XCTAssertEqual(res.headers.first(name: .vary), "Authorization")
            let body = try res.content.decode(MeResponse.self)
            XCTAssertEqual(body.account.role, "staff")
            XCTAssertEqual(body.deviceID, record.sessionID)
            XCTAssertEqual(body.serverDate, "2026-11-02")
        }
    }

    func testMissingMalformedUnknownAndWrongSecretAreUnauthenticated() async throws {
        let (record, token) = FakeSession.make(role: .staff)
        sessions.put(record)
        let unknown = SessionToken.issue(.access, sessionID: UUID())
        let wrongSecret = SessionToken(kind: .access, sessionID: record.sessionID, text: SessionToken.issue(.access, sessionID: record.sessionID).text)
        let asRefresh = SessionToken.parse(token.text.replacingOccurrences(of: "at_", with: "rt_"))
        for candidate in [nil, unknown, wrongSecret, asRefresh] {
            try await get(candidate) { res in
                XCTAssertEqual(res.status, .unauthorized)
                XCTAssertEqual(try self.code(res), "UNAUTHENTICATED")
                XCTAssertEqual(res.headers.first(name: .cacheControl), "no-store")
            }
        }
        var garbage = HTTPHeaders()
        garbage.bearerAuthorization = BearerAuthorization(token: "alg=none.e30.")
        try await get(nil, headers: garbage) { XCTAssertEqual(try self.code($0), "UNAUTHENTICATED") }
    }

    func testAccessTokenLivesStrictlyLessThan300Seconds() async throws {
        let (record, token) = FakeSession.make(role: .staff)
        sessions.put(record)
        clock.advance(299)
        try await get(token) { XCTAssertEqual($0.status, .ok) }
        clock.advance(1)
        try await get(token) { res in
            XCTAssertEqual(res.status, .unauthorized)
            XCTAssertEqual(try self.code(res), "ACCESS_TOKEN_EXPIRED")
        }
    }

    func testRevokedInactiveAndIdleSessionsAreRefused() async throws {
        let revoked = FakeSession.make(role: .staff, revoked: true)
        let inactive = FakeSession.make(role: .staff, active: false)
        let idle = FakeSession.make(role: .staff, refreshLife: 0)
        for (session, expected) in [(revoked, "SESSION_REVOKED"), (inactive, "SESSION_REVOKED"), (idle, "SESSION_EXPIRED")] {
            sessions.put(session.record)
            try await get(session.token) { res in
                XCTAssertEqual(res.status, .unauthorized)
                XCTAssertEqual(try self.code(res), expected)
            }
        }
    }

    func testClientHeadersAreRequiredOnAdminRoutes() async throws {
        let (record, token) = FakeSession.make(role: .owner)
        sessions.put(record)
        for custom in [headers(token, platform: nil), headers(token, platform: "web"), headers(token, version: nil), headers(token, version: "1.0")] {
            try await get(token, headers: custom) { res in
                XCTAssertEqual(res.status, .badRequest)
                XCTAssertEqual(try self.code(res), "HEADER_INVALID")
            }
        }
    }
}
