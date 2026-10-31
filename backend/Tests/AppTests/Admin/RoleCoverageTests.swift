import XCTVapor
import BanhContracts
import NIOConcurrencyHelpers
@testable import App

/// BR-1: every `/v1/admin` and `/v1/owner` route is authenticated and
/// role-checked. The sweep reads the router, so a route added later is
/// covered without editing this test.
final class RoleCoverageTests: AdminRouteTestCase {
    private let checked = NIOLockedValueBox<[String: Bool]>([:])

    /// Records, per route, whether `RequireRole` ran. Innermost, so it sees every route.
    private struct Probe: AsyncMiddleware {
        let checked: NIOLockedValueBox<[String: Bool]>
        func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
            defer {
                if let route = request.route {
                    checked.withLockedValue { $0["\(route.method) \(route.path.map(\.description).joined(separator: "/"))"] = request.roleWasChecked }
                }
            }
            return try await next.respond(to: request)
        }
    }

    private func adminRoutes() -> [Route] {
        app.routes.all.filter {
            let first = $0.path.prefix(2).map(\.description)
            return first == ["v1", "admin"] || first == ["v1", "owner"]
        }
    }

    /// Routes under the protected prefixes that did not run `RequireRole`.
    private func unprotectedRoutes() async throws -> [String] {
        app.middleware.use(Probe(checked: checked))
        let staff = FakeSession.make(role: .staff), owner = FakeSession.make(role: .owner)
        sessions.put(staff.record); sessions.put(owner.record)
        for route in adminRoutes() {
            let path = route.path.map { $0.description.hasPrefix(":") ? "x" : $0.description }.joined(separator: "/")
            for token in [staff.token, owner.token] {
                try await app.test(route.method, path, headers: headers(token)) { _ async throws in }
            }
        }
        let seen = checked.withLockedValue { $0 }
        return adminRoutes()
            .map { "\($0.method) \($0.path.map(\.description).joined(separator: "/"))" }
            .filter { seen[$0] != true }
    }

    func testEveryAdminAndOwnerRouteIsRoleChecked() async throws {
        app.ownerGroup().get("probe") { _ in "ok" }
        app.ownerGroup().post("things", ":id") { _ in "ok" }
        XCTAssertGreaterThanOrEqual(adminRoutes().count, 5)
        let missing = try await unprotectedRoutes()
        XCTAssertEqual(missing, [], "routes without RequireRole")
    }

    func testSweepFailsForARouteRegisteredOutsideTheGroups() async throws {
        app.get("v1", "owner", "leak") { _ in "ok" }
        let missing = try await unprotectedRoutes()
        XCTAssertEqual(missing, ["GET v1/owner/leak"])
    }

    func testStaffGetsForbiddenOnOwnerRoutesAndNothingRuns() async throws {
        let ran = LockedBox(false)
        app.ownerGroup().get("settings") { _ in ran.set(true); return "ok" }
        let staff = FakeSession.make(role: .staff), owner = FakeSession.make(role: .owner)
        sessions.put(staff.record); sessions.put(owner.record)
        try await app.test(.GET, "v1/owner/settings", headers: headers(staff.token)) { res async throws in
            XCTAssertEqual(res.status, .forbidden)
            XCTAssertEqual(try res.content.decode(APIErrorResponse.self).error.code, "FORBIDDEN")
        }
        XCTAssertFalse(ran.value)
        try await app.test(.GET, "v1/owner/settings", headers: headers(owner.token)) { res async throws in XCTAssertEqual(res.status, .ok) }
        try await app.test(.GET, "v1/owner/settings", headers: headers(nil)) { res async throws in XCTAssertEqual(res.status, .unauthorized) }
        XCTAssertTrue(ran.value)
    }

    func testBothRolesReachAdminRoutes() async throws {
        for role in [AccountRole.staff, .owner] {
            let session = FakeSession.make(role: role)
            sessions.put(session.record)
            try await app.test(.GET, "v1/admin/me", headers: headers(session.token)) { res async throws in XCTAssertEqual(res.status, .ok, role.rawValue) }
        }
    }

    func testNoOrderEditOrDeleteRouteExists() {
        let paths = app.routes.all.map { "\($0.method) \($0.path.map(\.description).joined(separator: "/"))" }
        XCTAssertFalse(paths.contains { $0.hasPrefix("PUT v1/admin/orders") || $0.hasPrefix("PATCH v1/admin/orders") || $0.hasPrefix("DELETE v1/admin/orders") })
    }
}
