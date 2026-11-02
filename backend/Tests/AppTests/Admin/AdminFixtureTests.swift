import XCTVapor
import BanhContracts
@testable import App

enum AdminFixtures {
    static func load(_ name: String) throws -> Data {
        try Data(contentsOf: TestPaths.contractFixtures.appendingPathComponent("admin/\(name).json"))
    }

    static func error(_ name: String) throws -> APIErrorResponse.Body {
        try JSONDecoder().decode(APIErrorResponse.self, from: load("error-\(name)")).error
    }

    /// Keys and value kinds of a fixture body, so placeholders and real values compare.
    static func shape(_ value: Any) -> Any {
        if let object = value as? [String: Any] { return object.mapValues(shape) }
        if value is String { return "string" }
        if let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() { return "number" }
        return "other"
    }

    static func bodyShape(_ name: String) throws -> NSDictionary {
        let object = try JSONSerialization.jsonObject(with: load(name)) as? [String: Any]
        return shape(object?["body"] ?? [:]) as? NSDictionary ?? [:]
    }
}

/// Errors that need no database, compared with the shared fixtures.
final class AdminAuthErrorFixtureTests: AdminRouteTestCase {
    private func error(_ headers: HTTPHeaders, path: String = "v1/admin/me") async throws -> APIErrorResponse.Body {
        let box = LockedBox<APIErrorResponse.Body?>(nil)
        try await app.test(.GET, path, headers: headers) { res async throws in
            box.set(try res.content.decode(APIErrorResponse.self).error)
        }
        return try XCTUnwrap(box.value)
    }

    func testSignInRequiredAndSessionEndedErrorsMatchTheFixtures() async throws {
        let live = FakeSession.make(role: .staff), revoked = FakeSession.make(role: .staff, revoked: true)
        let idle = FakeSession.make(role: .staff, refreshLife: 0), old = FakeSession.make(role: .staff, accessLife: 0)
        for session in [live, revoked, idle, old] { sessions.put(session.record) }
        let un = try await error(headers(nil)), expired = try await error(headers(old.token))
        let ended = try await error(headers(revoked.token)), idleError = try await error(headers(idle.token))
        XCTAssertEqual(un, try AdminFixtures.error("unauthenticated"))
        XCTAssertEqual(expired, try AdminFixtures.error("access-token-expired"))
        XCTAssertEqual(ended, try AdminFixtures.error("session-revoked"))
        XCTAssertEqual(idleError, try AdminFixtures.error("session-expired"))
        app.ownerGroup().get("settings") { _ in "ok" }
        let forbidden = try await error(headers(live.token), path: "v1/owner/settings")
        XCTAssertEqual(forbidden, try AdminFixtures.error("forbidden"))
    }

    func testMeAnswerHasTheFixtureShape() async throws {
        let live = FakeSession.make(role: .staff)
        sessions.put(live.record)
        let box = LockedBox<Data>(Data())
        try await app.test(.GET, "v1/admin/me", headers: headers(live.token)) { res async throws in
            box.set(Data(res.body.readableBytesView))
        }
        let actual = shapeOf(box.value)
        XCTAssertEqual(actual, try AdminFixtures.bodyShape("me"))
    }

    private func shapeOf(_ data: Data) -> NSDictionary {
        (try? JSONSerialization.jsonObject(with: data)).map(AdminFixtures.shape) as? NSDictionary ?? [:]
    }
}

/// Sign-in answers compared with the shared fixtures.
final class AdminSignInFixtureTests: AdminDatabaseTestCase {
    private func envelope(_ reply: Reply) throws -> APIErrorResponse.Body {
        try JSONDecoder().decode(APIErrorResponse.self, from: reply.data).error
    }

    func testSuccessBodiesHaveTheFixtureShape() async throws {
        let staff = try await addAccount(.staff)
        let requested = try await requestCode(staff.email)
        XCTAssertEqual(AdminFixtures.shape(requested.json) as? NSDictionary, try AdminFixtures.bodyShape("code-request"))
        await app.services.background.drain()
        let created = try await signIn(staff.email, try XCTUnwrap(mail.lastCode(to: staff.email)))
        XCTAssertEqual(AdminFixtures.shape(created.json) as? NSDictionary, try AdminFixtures.bodyShape("session-created"))
        let renewed = try await refresh(created.string("refresh_token"))
        XCTAssertEqual(AdminFixtures.shape(renewed.json) as? NSDictionary, try AdminFixtures.bodyShape("refresh-ok"))
    }

    func testCodeErrorsMatchTheFixtures() async throws {
        let staff = try await addAccount(.staff)
        _ = try await requestCode(staff.email)
        let wrong = try await signIn(staff.email, "000000"), bad = try await requestCode("a@b")
        XCTAssertEqual(try envelope(bad), try AdminFixtures.error("validation-email"))
        clock.advance(10)
        let wait = try await requestCode(staff.email)
        XCTAssertEqual(try envelope(wait), try AdminFixtures.error("code-resend-wait"))
        if wrong.errorCode == "CODE_INVALID" {
            XCTAssertEqual(try envelope(wrong), try AdminFixtures.error("code-invalid"))
        }
        for _ in 0..<4 { _ = try await signIn(staff.email, "000000") }
        let voided = try await signIn(staff.email, "000000")
        XCTAssertEqual(try envelope(voided), try AdminFixtures.error("code-expired"))
    }

    func testRequestLimitMatchesTheFixture() async throws {
        let staff = try await addAccount(.staff)
        for step in 0..<3 { _ = try await requestCode(staff.email); clock.advance(step == 2 ? 1_738 : 31) }
        let limited = try await requestCode(staff.email)
        XCTAssertEqual(try envelope(limited), try AdminFixtures.error("code-request-limit"))
    }
}
