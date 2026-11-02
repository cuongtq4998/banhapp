import XCTest
import Vapor
@testable import AppUnderTest

/// AC-45, BR-7, TC-B96: nothing personal or secret reaches the server log or an error body.
final class AdminLogPrivacyTests: AdminQABase {

    func testTCB96_LogsAndErrorBodiesHoldNoPersonalDataOrSecrets() async throws {
        let name = "Nguyen Thi Kin", phone = "0900000099", address = "77 Duong Bi Mat", note = "ghi chu rieng tu", search = "kin%20ng"
        var bodies: [String] = []
        var secrets: [String] = [name, phone, "+84900000099", address, note, pepper, ownerEmail, "tokPrivatePush"]

        // Sign-in: code request, wrong codes, right code, new-device notice.
        let wrongCode = "000000"
        bodies.append(try await requestCode(ownerEmail).text)
        let realCode = try XCTUnwrap(mail.lastCode(to: ownerEmail))
        secrets.append(realCode)
        for _ in 0..<2 { bodies.append(try await signInReply(ownerEmail, code: realCode == wrongCode ? "111111" : wrongCode).text) }
        let signIn = try await signInReply(ownerEmail, code: realCode)
        XCTAssertEqual(signIn.status, 201)
        secrets += [signIn.string("access_token"), signIn.string("refresh_token")]
        let phoneSession = QAPhone(access: signIn.string("access_token"), refresh: signIn.string("refresh_token"), deviceID: signIn.string("device_id"))
        let stranger = "khong.co.\(UUID().uuidString.prefix(8).lowercased())@example.com"
        bodies.append(try await requestCode(stranger).text)
        secrets.append(stranger)
        bodies.append(try await signInReply(stranger, code: "123456").text)
        clock.advance(31)

        // Order placed by a customer, listed, searched, detailed, changed; push registered.
        _ = try await client.send("PUT", "v1/admin/push-token", token: phoneSession.access, json: ["platform": "ios", "token": "tokPrivatePush", "apns_environment": "sandbox"])
        let placed = try await shopRef.order(date: dayOffset(5), cakes: 2, phone: phone, note: note, name: name, address: address)
        XCTAssertEqual(placed.status, 201, placed.text)
        let orderCode = placed.string("order_code")
        _ = try await shopRef.order(date: dayOffset(5), cakes: 2, phone: "12345", name: name, address: address) // validation error
        await app.services.background.drain()
        for query in ["", "q=\(search)", "q=\(phone)", "cursor=garbage-\(name.replacingOccurrences(of: " ", with: ""))", "status=\(name.replacingOccurrences(of: " ", with: "_"))"] {
            bodies.append(try await client.send("GET", "v1/admin/orders" + (query.isEmpty ? "" : "?" + query), token: phoneSession.access).text.replacingOccurrences(of: name, with: "").replacingOccurrences(of: phone, with: "").replacingOccurrences(of: "+84900000099", with: ""))
        }
        _ = try await client.send("GET", "v1/admin/orders/\(orderCode)", token: phoneSession.access)
        _ = try await changeStatus(phoneSession, orderCode, from: "Received", to: "Processing")
        _ = try await changeStatus(phoneSession, orderCode, from: "Received", to: "Cancelled", reason: "customer_asked")
        let form = QAImages.multipart(fields: ["name": "Banh Rieng Tu", "description": "d", "price_vnd": "1"], files: [("x.png", "image/png", QAImages.png(width: 5, height: 5))])
        _ = try await client.send("POST", "v1/owner/cakes", token: phoneSession.access, rawBody: form.body, contentType: form.type)
        _ = try await client.send("GET", "v1/owner/settings", token: phoneSession.access)
        _ = try await client.send("GET", "v1/admin/me", token: "at_nonsense_secretvalue")
        _ = try await client.send("POST", "v1/auth/refresh", json: ["refresh_token": "rt_nonsense_secretvalue"])
        _ = try await client.send("POST", "v1/auth/refresh", json: ["refresh_token": phoneSession.refresh])
        _ = try await client.send("POST", "v1/orders", rawBody: Data("{\"customer\":{\"name\":\"\(name)\"".utf8), contentType: "application/json", headers: ["Idempotency-Key": UUID().uuidString])
        await app.services.background.drain()

        let log = logs.lines.map { "\($0.message) \($0.metadata)" }.joined(separator: "\n")
        XCTAssertGreaterThan(logs.lines.count, 10, "the capture must have seen the requests")
        for secret in secrets where !secret.isEmpty {
            XCTAssertFalse(log.contains(secret), "log contains \(secret.prefix(6))...")
            for body in bodies { XCTAssertFalse(body.contains(secret), "error body contains \(secret.prefix(6))...") }
        }
        for forbidden in ["at_", "rt_", "Bearer", "customer_phone", "customer_name", "SELECT ", "INSERT ", "password"] {
            XCTAssertFalse(log.contains(forbidden), "log contains '\(forbidden)'")
        }
        XCTAssertFalse(log.contains("@example.com"), "no e-mail address in the log")
        // The mail sink got the sign-in code, which is the only place the code may appear.
        XCTAssertTrue(mail.sent.contains { $0.body.contains(realCode) })
    }

    func testTCB96b_ErrorBodiesNeverEchoInternals() async throws {
        let phone = try await owner()
        let probes: [(String, String, Data?)] = [
            ("GET", "v1/admin/orders/BT-%27%3B%20DROP%20TABLE", nil), ("GET", "v1/admin/orders/not-a-code", nil), ("POST", "v1/admin/orders/BT-AAAAAA/status", Data("{{{".utf8)),
            ("PUT", "v1/owner/settings/shop", Data("{\"name\":1}".utf8)), ("GET", "v1/owner/nothing-here", nil), ("PATCH", "v1/owner/staff/not-a-uuid", Data("{}".utf8))
        ]
        for (method, path, body) in probes {
            let reply = try await client.send(method, path, token: phone.access, rawBody: body, contentType: body == nil ? nil : "application/json")
            XCTAssertLessThan(reply.status, 500, "\(method) \(path): \(reply.text.prefix(200))")
            for leak in ["Fluent", "PSQL", "postgres", "SELECT", "stack", "Swift.", "/Users/", "customer_order"] {
                XCTAssertFalse(reply.text.contains(leak), "\(path) leaks \(leak): \(reply.text.prefix(200))")
            }
            XCTAssertNotNil(reply.json["request_id"], "every error carries request_id")
        }
    }
}
