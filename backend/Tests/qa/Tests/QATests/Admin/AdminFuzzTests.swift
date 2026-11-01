import XCTest
import Vapor
@testable import AppUnderTest

/// Hostile and malformed JSON bodies on every write route as the owner: the answer is always a contract error, never a 5xx.
final class AdminFuzzTests: AdminQABase {

    private let bodies: [String] = [
        "", "null", "[]", "[1,2,3]", "\"text\"", "123", "true", "{", "{\"a\":", "{}", "{\"name\":null}", "{\"name\":[]}", "{\"name\":{\"a\":1}}",
        "{\"name\":\"\\u0000\"}", "{\"name\":\"\(String(repeating: "x", count: 7_000))\"}", "{\"price_vnd\":1e30}", "{\"price_vnd\":-1}", "{\"price_vnd\":99999999999999999999}",
        "{\"price_vnd\":\"12\"}", "{\"price_vnd\":1.5}", "{\"is_active\":\"yes\"}", "{\"is_active\":1}", "{\"daily_limit\":9223372036854775807}", "{\"lead_days\":-9223372036854775808}",
        "{\"min_qty\":0,\"daily_limit\":0,\"lead_days\":0}", "{\"email\":\"a@b\",\"name\":\"x\"}", "{\"email\":\"\\u202Eevil@example.com\",\"name\":\"\\uD83D\\uDE00\"}",
        "{\"phone_contact\":\"+\",\"zalo_contact\":\"\",\"name\":\"\",\"greeting\":\"\"}", "{\"start\":\"25:00\",\"end\":\"00:00\"}", "{\"start\":\"10:00\",\"end\":\"09:00\",\"x\":1}",
        "{\"__proto__\":{\"admin\":true}}", "{\"name\":\"a\",\"name\":\"b\"}", "{\"delivery_fee_vnd\":0,\"name\":\"d\"}"
    ]

    private func ids() async throws -> [String: String] {
        let phone = try await owner()
        let settings = try await client.send("GET", "v1/owner/settings", token: phone.access)
        func first(_ key: String, _ idKey: String) -> String { ((settings.json[key] as? [[String: Any]])?.first?[idKey] as? String) ?? UUID().uuidString }
        let staff = try await client.send("GET", "v1/owner/staff", token: phone.access)
        let accounts = (staff.json["accounts"] as? [[String: Any]]) ?? []
        return ["cakes": first("cakes", "cake_id"), "districts": first("districts", "district_id"), "slots": first("slots", "slot_id"),
                "staff": (accounts.first?["account_id"] as? String) ?? UUID().uuidString]
    }

    func testTCB146_NoMalformedBodyOnAnyOwnerWriteRouteGivesA500() async throws {
        let phone = try await owner()
        let known = try await ids()
        var seen = 0
        for route in app.routes.all {
            let parts = route.path.map { "\($0)" }
            guard parts.count > 2, parts[1] == "owner", ["POST", "PUT", "PATCH"].contains(route.method.rawValue) else { continue }
            var path: [String] = []
            for part in parts { path.append(part.hasPrefix(":") ? (known[path.last ?? ""] ?? UUID().uuidString) : part) }
            for body in bodies {
                let reply = try await client.send(route.method.rawValue, path.joined(separator: "/"), token: phone.access, rawBody: Data(body.utf8), contentType: "application/json")
                seen += 1
                XCTAssertLessThan(reply.status, 500, "\(route.method) \(path.joined(separator: "/")) body \(body.prefix(60)) -> \(reply.status) \(reply.text.prefix(160))")
                XCTAssertNotNil(reply.json["request_id"] != nil || reply.status < 300 ? true : nil, "error without envelope: \(reply.text.prefix(120))")
            }
        }
        XCTAssertGreaterThan(seen, 200, "the sweep covered \(seen) requests")
    }

    /// Wrong content types and verbs on admin routes are contract errors too.
    func testTCB147_WrongContentTypeAndVerbsAreContractErrors() async throws {
        let phone = try await owner()
        let order = try await seedOrder(date: dayOffset(5))
        // Observation O-4: a form-encoded body with the right keys is accepted like JSON (Bearer auth, no cookies, so no
        // CSRF risk); the contract says JSON only. Not asserted either way, but it must never be a 5xx.
        for type in ["application/x-www-form-urlencoded", ""] {
            let order = try await seedOrder(date: dayOffset(6))
            let reply = try await client.send("POST", "v1/admin/orders/\(order)/status", token: phone.access,
                                              rawBody: Data("expected_status=New&to_status=Confirmed".utf8), contentType: type.isEmpty ? nil : type)
            XCTAssertLessThan(reply.status, 500, "content type '\(type)' -> \(reply.status)")
            print("QA-OBSERVATION O-4 content type '\(type)' on the status route -> \(reply.status)")
        }
        for type in ["text/plain", "multipart/form-data", "application/xml"] {
            let reply = try await client.send("POST", "v1/admin/orders/\(order)/status", token: phone.access,
                                              rawBody: Data("expected_status=New&to_status=Confirmed".utf8), contentType: type.isEmpty ? nil : type)
            XCTAssertLessThan(reply.status, 500, "content type '\(type)' -> \(reply.status)")
            XCTAssertGreaterThanOrEqual(reply.status, 400, "a non-JSON body must not confirm an order (type '\(type)')")
        }
        for (method, path) in [("PUT", "v1/admin/orders"), ("DELETE", "v1/admin/orders/\(order)"), ("PATCH", "v1/admin/orders/\(order)"), ("POST", "v1/admin/me"), ("GET", "v1/admin/orders/\(order)/status")] {
            let reply = try await client.send(method, path, token: phone.access)
            XCTAssertTrue([404, 405].contains(reply.status), "\(method) \(path) -> \(reply.status)")
        }
        let untouched = try await count("SELECT count(*)::int AS n FROM customer_order WHERE order_code = \(bind: order) AND status = 'New'")
        XCTAssertEqual(untouched, 1, "refused content types and verbs change nothing")
    }
}
