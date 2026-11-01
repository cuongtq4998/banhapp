import XCTVapor
import Logging
@testable import App

/// D-4 (BR-7, api/05 section 9): whatever the log level, no personal data, no
/// credential and no query string reaches a log line. Runs at `trace`, the most
/// talkative level, against a real PostgreSQL and a real listening socket (the
/// in-memory test transport skips the HTTP decoder that logs request heads).
final class LogPrivacyTests: AdminOrderTestCase {
    let capture = LogCapture()
    override var testLogger: Logger? { capture.makeLogger() }

    private func everythingLogged() -> String {
        capture.lines.map { "\($0.message) \($0.metadata)" }.joined(separator: "\n")
    }

    func testTraceLevelLogHoldsNoPersonalDataAndNoCredential() async throws {
        let owner = try await addAccount(.owner, "Chu Mau")
        let staffName = "Le Thi Nhat Ky"
        try await place(.init(name: staffName, phone: "+84900000077"))
        let requested = try await requestCode(owner.email)
        XCTAssertEqual(requested.status, .accepted)
        await app.services.background.drain()
        let code = try XCTUnwrap(mail.lastCode(to: owner.email))
        let reply = try await signIn(owner.email, code)
        XCTAssertEqual(reply.status, .created)
        let access = reply.string("access_token"), refresh = reply.string("refresh_token")
        let listed = try await authed(.GET, "v1/admin/orders?q=Nhat%20Ky", access)
        XCTAssertEqual(listed.status, .ok)
        XCTAssertTrue(String(decoding: listed.data, as: UTF8.self).contains(staffName), "the order is really listed")
        let refreshed = try await self.refresh(refresh)
        XCTAssertEqual(refreshed.status, .ok)
        await app.services.background.drain()

        let log = everythingLogged()
        XCTAssertGreaterThan(capture.lines.count, 3, "the capture works")
        let secrets = ["e-mail address": owner.email, "customer name": staffName, "customer name part": "Nhat Ky",
                       "customer phone": "+84900000077", "access token": access, "refresh token": refresh,
                       "sign-in code": code, "pepper": pepper, "owner name": "Chu Mau", "search text": "Nhat%20Ky"]
        for (what, needle) in secrets { XCTAssertFalse(log.contains(needle), "the log holds the \(what)") }
        XCTAssertFalse(log.lowercased().contains("authorization"), "the log holds the Authorization header")
        XCTAssertFalse(log.contains("Bearer"), "the log holds a bearer credential")
    }

    /// Vapor logs every decoded request head (Authorization header, query string) at
    /// `trace` through the HTTP server's own logger; `configure` must route it through the filter.
    func testTheHttpServerLoggerIsFiltered() async throws {
        let server = app.http.server.configuration.logger
        server.trace("Decoded HTTP part: head GET /v1/admin/orders?q=Nguyen Authorization: Bearer abc")
        server.debug("Invalid HTTP request: Authorization Bearer abc")
        server.warning("Something", metadata: ["head": "Authorization: Bearer abc", "database-id": "psql"])
        let lines = capture.lines.filter { !$0.message.hasPrefix("Executing") }
        let decoded = lines.filter { $0.message.contains("Decoded") || $0.message.contains("Invalid HTTP") }
        XCTAssertTrue(decoded.isEmpty, "trace and debug lines of the server are dropped")
        let warned = try XCTUnwrap(lines.last { $0.message == "Something" })
        XCTAssertEqual(warned.metadata["database-id"], "psql", "harmless keys stay")
        XCTAssertNil(warned.metadata["head"], "other metadata of a library line is dropped")
    }

    func testOwnEventsPassUnchangedAtEveryLevel() async throws {
        app.logger.log(level: .trace, "own trace", metadata: ["route": "/v1/orders"], source: RedactingLogHandler.ownSource)
        let own = try XCTUnwrap(capture.lines.last { $0.message == "own trace" })
        XCTAssertEqual(own.metadata["route"], "/v1/orders")
    }
}
