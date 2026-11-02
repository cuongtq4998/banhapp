import XCTest
import Vapor
@testable import AppUnderTest

/// FR-25, FR-26, BR-7, AC-42 to AC-45 with the recording push sender (real APNs and FCM stay unverified).
final class AdminPushTests: AdminQABase {

    private func register(_ phone: QAPhone, platform: String, token: String, env: String? = nil) async throws -> QAReply {
        var body = ["platform": platform, "token": token]
        if let env { body["apns_environment"] = env }
        return try await client.send("PUT", "v1/admin/push-token", token: phone.access, json: body, platform: platform)
    }

    private func settle() async { await app.services.background.drain() }

    private func storedTokens() async throws -> Int {
        try await count("SELECT count(*)::int AS n FROM device_session s JOIN account a ON a.id = s.account_id WHERE a.shop_id = \(bind: shopID) AND s.push_token IS NOT NULL")
    }

    func testTCB88_OnePushPerRegisteredPhoneWithOnlyCodeCakesAndDate() async throws {
        let ownerPhone = try await signedIn(ownerEmail, platform: "ios")
        let a = try await addAccount("staff", "Nhan Vien A"), b = try await addAccount("staff", "Nhan Vien B")
        let phoneA = try await signedIn(a.1, platform: "android"), phoneB = try await signedIn(b.1, platform: "ios")
        try await aeq(try await register(ownerPhone, platform: "ios", token: "tokOwnerIOS", env: "sandbox").status, 204)
        try await aeq(try await register(phoneA, platform: "android", token: "tokStaffAndroid").status, 204)
        _ = phoneB // no permission, no token
        let date = dayOffset(5)
        let reply = try await customerOrder(date: date, cakes: 3, phone: "0900000070", note: "Giao truoc 8h, goi chi Lan 0911222333")
        XCTAssertEqual(reply.status, 201, reply.text)
        await settle()
        XCTAssertEqual(Set(pushSender.tokens), ["tokOwnerIOS", "tokStaffAndroid"])
        XCTAssertEqual(pushSender.sent.count, 2)
        let message = try XCTUnwrap(pushSender.sent.first?.message)
        XCTAssertEqual(message.orderCode, reply.string("order_code"))
        XCTAssertEqual(message.cakes, 3)
        XCTAssertEqual(message.deliveryDate.description, date)
        let dump = "\(pushSender.sent)"
        for secret in ["Tran Thi B", "0900000070", "+84900000070", "1 QA Street", "Giao truoc", "Lan", "0911222333", "QA district"] {
            XCTAssertFalse(dump.contains(secret), "push dump leaks \(secret)")
        }
    }

    func testTCB91_NoPushAfterSignOutDeactivationOrRefusedOrder() async throws {
        let ownerPhone = try await signedIn(ownerEmail)
        let a = try await staff("Nhan Vien A"), b = try await staff("Nhan Vien B"), c = try await staff("Nhan Vien C")
        for (tag, phone) in [("A", a.phone), ("B", b.phone), ("C", c.phone), ("O", ownerPhone)] {
            try await aeq(try await register(phone, platform: "ios", token: "tok\(tag)", env: "production").status, 204)
        }
        try await aeq(try await client.send("DELETE", "v1/admin/session", token: a.phone.access).status, 204)
        try await aeq(try await client.send("PATCH", "v1/owner/staff/\(b.id.uuidString)", token: ownerPhone.access, json: ["is_active": false]).status, 200)
        try await aeq(try await storedTokens(), 2, "sign-out and deactivation remove the token")
        try await aeq(try await customerOrder(date: dayOffset(6), phone: "0900000071").status, 201)
        await settle()
        XCTAssertEqual(Set(pushSender.tokens), ["tokC", "tokO"])
        // Refused orders and replays send nothing.
        let before = pushSender.sent.count
        let key = UUID()
        try await aeq(try await customerOrder(date: dayOffset(7), phone: "0900000072", key: key).status, 201)
        try await aeq(try await customerOrder(date: dayOffset(7), phone: "0900000072", key: key).status, 200)
        try await aeq(try await customerOrder(date: dayOffset(0), phone: "0900000073").status, 422, "too soon")
        try await aeq(try await customerOrder(date: dayOffset(8), cakes: 1, phone: "0900000074").status, 422, "under the minimum")
        await settle()
        XCTAssertEqual(pushSender.sent.count, before + 2, "one push per stored order and phone, none for replay or refusals")
        // Sign out all others removes the others' tokens.
        let c2 = try await signedIn(c.email)
        try await aeq(try await client.send("DELETE", "v1/admin/sessions/others", token: c2.access).status, 204)
        try await aeq(try await storedTokens(), 1, "only the owner token is left")
    }

    func testTCB92_TokenMovesBetweenAccountsAndDeadTokensAreRemoved() async throws {
        let a = try await staff("Nhan Vien A", platform: "android"), b = try await staff("Nhan Vien B", platform: "android")
        try await aeq(try await register(a.phone, platform: "android", token: "sharedToken").status, 204)
        try await aeq(try await register(b.phone, platform: "android", token: "sharedToken").status, 204)
        try await aeq(try await register(b.phone, platform: "android", token: "sharedToken").status, 204)
        try await aeq(try await storedTokens(), 1, "one token has one owner")
        pushSender.markDead("sharedToken")
        try await aeq(try await customerOrder(date: dayOffset(5), phone: "0900000075").status, 201)
        await settle()
        try await aeq(try await storedTokens(), 0, "an invalid token is deleted")
        pushSender.failNext()
        let started = Date()
        try await aeq(try await register(a.phone, platform: "android", token: "tokenAfter").status, 204)
        try await aeq(try await customerOrder(date: dayOffset(6), phone: "0900000076").status, 201, "a failing provider never fails the order")
        XCTAssertLessThan(Date().timeIntervalSince(started), 5)
        await settle()
    }

    func testTCB93_TokenRequestValidation() async throws {
        let phone = try await signedIn(ownerEmail, platform: "ios")
        let bad: [[String: Any]] = [
            ["platform": "ios", "token": "", "apns_environment": "sandbox"], ["platform": "ios", "token": "has space", "apns_environment": "sandbox"],
            ["platform": "ios", "token": String(repeating: "t", count: 513), "apns_environment": "sandbox"], ["platform": "ios", "token": "ok"],
            ["platform": "ios", "token": "ok", "apns_environment": "moon"], ["platform": "android", "token": "ok"],
            ["platform": "windows", "token": "ok"], ["token": "ok"], ["platform": "ios", "token": 5, "apns_environment": "sandbox"],
            ["platform": "ios", "token": "ok", "apns_environment": "sandbox", "extra": 1]
        ]
        for body in bad {
            let reply = try await client.send("PUT", "v1/admin/push-token", token: phone.access, json: body, platform: "ios")
            XCTAssertEqual(reply.status, 422, "\(body): \(reply.text)")
            XCTAssertEqual(reply.errorCode, "VALIDATION_FAILED")
        }
        try await aeq(try await storedTokens(), 0)
        let arrayBody = try await client.send("PUT", "v1/admin/push-token", token: phone.access, rawBody: Data("[]".utf8), contentType: "application/json")
        XCTAssertEqual(arrayBody.status, 422)
        try await aeq(try await client.send("DELETE", "v1/admin/push-token", token: phone.access).status, 404, "the DELETE route was removed")
    }

    func testTCB95_NoReminderPushForOldUnconfirmedOrders() async throws {
        let ownerPhone = try await signedIn(ownerEmail)
        try await aeq(try await register(ownerPhone, platform: "ios", token: "tokOwner", env: "production").status, 204)
        _ = try await seedOrder(date: dayOffset(1))
        clock.advance(3 * 86_400)
        await settle()
        XCTAssertEqual(pushSender.sent.count, 0, "only the new-order push exists")
    }
}
