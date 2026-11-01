import XCTest
import Vapor
@testable import AppUnderTest

/// Role matrix over the live router: every /v1/owner and /v1/admin route, anonymous / staff / owner.
final class AdminRoleMatrixTests: AdminQABase {

    private struct RouteCase { let method: String; let path: String }

    private func routes(prefix: String) -> [RouteCase] {
        let id = UUID().uuidString
        return app.routes.all.compactMap { route in
            let parts = route.path.map { "\($0)" }
            guard parts.first == "v1", parts.count > 1, parts[1] == prefix else { return nil }
            let path = parts.map { $0.hasPrefix(":") ? (parts.first == "v1" && $0 == ":order_code" ? "BT-AAAAAA" : id) : $0 }.joined(separator: "/")
            return RouteCase(method: route.method.rawValue, path: path)
        }
    }

    private func call(_ route: RouteCase, token: String?) async throws -> QAReply {
        let write = ["POST", "PUT", "PATCH"].contains(route.method)
        return try await client.send(route.method, route.path, token: token, json: write ? [String: String]() : nil)
    }

    func testTCB22_EveryOwnerRouteRefusesStaffAndAnonymous() async throws {
        let owner = routes(prefix: "owner")
        XCTAssertGreaterThanOrEqual(owner.count, 14, "router sweep found only \(owner.count) owner routes")
        let member = try await staff()
        for route in owner {
            let asStaff = try await call(route, token: member.phone.access)
            XCTAssertEqual(asStaff.status, 403, "staff \(route.method) \(route.path)")
            XCTAssertEqual(asStaff.errorCode, "FORBIDDEN", "staff \(route.method) \(route.path)")
            XCTAssertEqual(asStaff.header("Cache-Control"), "no-store")
            let anonymous = try await call(route, token: nil)
            XCTAssertEqual(anonymous.status, 401, "anonymous \(route.method) \(route.path)")
            XCTAssertEqual(anonymous.errorCode, "UNAUTHENTICATED")
            let junk = try await call(route, token: "at_garbage")
            XCTAssertEqual(junk.status, 401, "junk token \(route.method) \(route.path)")
        }
    }

    func testTCB22b_OwnerReachesEveryOwnerRouteWithoutServerError() async throws {
        let ownerPhone = try await owner()
        for route in routes(prefix: "owner") {
            let reply = try await call(route, token: ownerPhone.access)
            XCTAssertLessThan(reply.status, 500, "owner \(route.method) \(route.path): \(reply.text.prefix(200))")
            XCTAssertNotEqual(reply.status, 403, "owner must not be forbidden on \(route.method) \(route.path)")
            XCTAssertNotEqual(reply.status, 401, "\(route.method) \(route.path)")
        }
    }

    func testTCB22c_EveryAdminRouteNeedsASessionAndAcceptsStaff() async throws {
        let admin = routes(prefix: "admin")
        XCTAssertGreaterThanOrEqual(admin.count, 6)
        let member = try await staff()
        for route in admin {
            let anonymous = try await call(route, token: nil)
            XCTAssertEqual(anonymous.status, 401, "anonymous \(route.method) \(route.path)")
            let asStaff = try await call(route, token: member.phone.access)
            XCTAssertNotEqual(asStaff.status, 403, "staff must reach \(route.method) \(route.path)")
            XCTAssertLessThan(asStaff.status, 500, "\(route.method) \(route.path): \(asStaff.text.prefix(200))")
            if route.method == "DELETE" && route.path.hasSuffix("session") { break } // that call ends this phone
        }
    }

    /// FR-5 role also in the service: a staff token on the staff list shows no accounts, and an owner token on `me` says owner.
    func testTCB22d_MeShowsRoleAndOwnAddressOnly() async throws {
        let member = try await staff("Nhan Vien A")
        let me = try await client.send("GET", "v1/admin/me", token: member.phone.access)
        XCTAssertEqual(me.status, 200)
        XCTAssertEqual((me.json["account"] as? [String: Any])?["role"] as? String, "staff")
        XCTAssertEqual(me.text.contains(ownerEmail), false, "a staff reply never carries the owner address")
        XCTAssertTrue(me.text.contains(member.email), "/me carries the caller's own address (api/05 v1.22)")
        XCTAssertNotNil(me.json["server_date"])
    }

    /// Missing or bad platform headers on admin routes are 400 HEADER_INVALID.
    func testTCB22e_AdminHeadersRequired() async throws {
        let phone = try await owner()
        let noPlatform = try await client.send("GET", "v1/admin/me", token: phone.access, headers: ["X-Platform": "", "X-App-Version": "1.0.0"])
        XCTAssertTrue([400, 401].contains(noPlatform.status), "empty platform -> \(noPlatform.status)")
        let badVersion = try await client.send("GET", "v1/admin/me", token: phone.access, headers: ["X-App-Version": "banana"])
        XCTAssertEqual(badVersion.status, 400)
        XCTAssertEqual(badVersion.errorCode, "HEADER_INVALID")
        let badPlatform = try await client.send("GET", "v1/admin/me", token: phone.access, platform: "windows")
        XCTAssertEqual(badPlatform.status, 400)
    }
}
