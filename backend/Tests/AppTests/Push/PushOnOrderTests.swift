import XCTVapor
@testable import App

/// FR-25, FR-26: a stored customer order is announced to every signed-in owner
/// and staff phone, after the commit, without ever touching the order's answer.
final class PushOnOrderTests: PushDatabaseTestCase {
    private func register(_ phone: Phone, ios: Bool, _ token: String) async throws {
        let reply = ios ? try await register(phone, platform: "ios", token: token, environment: "sandbox")
                        : try await register(phone, platform: "android", token: token)
        XCTAssertEqual(reply.status, .noContent)
    }

    private func place(cakes: Int = 3) async throws -> String {
        let reply = try await placeOrder(try orderBody(cakes: cakes))
        XCTAssertEqual(reply.status, .created, String(decoding: reply.data, as: UTF8.self))
        await app.services.background.drain()
        return reply.string("order_code")
    }

    func testEverySignedInPhoneWithATokenGetsOnePush() async throws {
        let staff = try await addAccount(.staff)
        let staffIOS = try await phoneOn("ios", of: staff.email), staffAndroid = try await phoneOn("android", of: staff.email)
        try await register(staffIOS, ios: true, "staff-ios")
        try await register(staffAndroid, ios: false, "staff-android")
        try await register(ownerPhone, ios: true, "owner-ios")
        let code = try await place(cakes: 3)
        XCTAssertEqual(Set(pushSender.tokens), ["staff-ios", "staff-android", "owner-ios"])
        XCTAssertEqual(pushSender.tokens.count, 3)
        let first = try XCTUnwrap(pushSender.sent.first)
        XCTAssertEqual(first.message.orderCode, code)
        XCTAssertEqual(first.message.cakes, 3)
        XCTAssertEqual(first.message.deliveryDate, app.services.calendar.adding(days: 5, to: app.services.calendar.today()))
        let ios = try XCTUnwrap(pushSender.sent.first { $0.target.token == "staff-ios" })
        XCTAssertEqual(ios.target, PushTarget(platform: .ios, token: "staff-ios", apnsEnvironment: "sandbox"))
        let android = try XCTUnwrap(pushSender.sent.first { $0.target.token == "staff-android" })
        XCTAssertEqual(android.target.platform, .android)
    }

    func testPhonesWithoutATokenAreSkipped() async throws {
        _ = try await place()
        XCTAssertEqual(pushSender.attempts, 0)
    }

    func testSignedOutPhonesGetNothing() async throws {
        let staff = try await addAccount(.staff)
        let out = try await phoneOn("ios", of: staff.email), others = try await phoneOn("android", of: staff.email)
        let kept = try await phoneOn("ios", of: staff.email)
        try await register(out, ios: true, "out")
        try await register(others, ios: false, "others")
        try await register(kept, ios: true, "kept")
        _ = try await authed(.DELETE, "v1/admin/session", out.access)
        _ = try await authed(.DELETE, "v1/admin/sessions/others", kept.access)
        _ = try await place()
        XCTAssertEqual(pushSender.tokens, ["kept"])
    }

    func testDeactivatedStaffGetsNothingButTheOwnerStillDoes() async throws {
        let staff = try await addAccount(.staff)
        let phone = try await phoneOn("android", of: staff.email)
        try await register(phone, ios: false, "gone")
        try await register(ownerPhone, ios: true, "owner")
        _ = try await call(.PATCH, "v1/owner/staff/\(staff.id)", #"{"is_active":false}"#)
        _ = try await place()
        XCTAssertEqual(pushSender.tokens, ["owner"])
    }

    func testExpiredSessionsGetNothing() async throws {
        try await register(ownerPhone, ios: true, "owner")
        try await run("UPDATE device_session SET refresh_expires_at = \(timestamp(clock.now().addingTimeInterval(-1))) WHERE id = \(bind: ownerPhone.deviceID)")
        _ = try await place()
        XCTAssertEqual(pushSender.attempts, 0)
    }

    func testReviewAccountsNeverGetAPush() async throws {
        let review = UUID(), session = UUID()
        try await run("INSERT INTO account (id, shop_id, role, kind, email, display_name) VALUES (\(bind: review), \(bind: shopID), 'staff', 'review', 'review@example.com', 'Review')")
        try await run("""
            INSERT INTO device_session (id, account_id, installation_id, platform, device_name, push_token, sign_in_method,
                access_token_hash, access_expires_at, refresh_token_hash, refresh_expires_at)
            VALUES (\(bind: session), \(bind: review), \(bind: UUID()), 'android', 'Review phone', \(bind: "review-\(session)"), 'review',
                decode(repeat('ab', 32), 'hex'), \(timestamp(clock.now().addingTimeInterval(300))),
                decode(repeat('cd', 32), 'hex'), \(timestamp(clock.now().addingTimeInterval(86_400))))
            """)
        try await register(ownerPhone, ios: true, "owner")
        _ = try await place()
        XCTAssertEqual(pushSender.tokens, ["owner"])
    }

    func testAReplayAndAFailedOrderSendNothing() async throws {
        try await register(ownerPhone, ios: true, "owner")
        let key = UUID(), body = try orderBody()
        let first = try await placeOrder(body, key: key)
        XCTAssertEqual(first.status, .created)
        await app.services.background.drain()
        let replay = try await placeOrder(body, key: key)
        XCTAssertEqual(replay.status, .ok)
        let invalid = try await placeOrder(Data(#"{"items":[]}"#.utf8))
        XCTAssertEqual(invalid.status, .unprocessableEntity)
        let tooSoon = try await placeOrder(try orderBody(daysAhead: 0))
        XCTAssertEqual(tooSoon.status, .unprocessableEntity)
        await app.services.background.drain()
        XCTAssertEqual(pushSender.sent.count, 1)
    }

    func testTheOrderSucceedsWhenTheSenderFails() async throws {
        try await register(ownerPhone, ios: true, "owner")
        pushSender.failNext()
        let reply = try await placeOrder()
        XCTAssertEqual(reply.status, .created)
        await app.services.background.drain()
        XCTAssertEqual(pushSender.attempts, 4, "one try and three retries")
        let stored = try await count("SELECT count(*)::int AS n FROM customer_order WHERE shop_id = \(bind: shopID)")
        XCTAssertEqual(stored, 1)
        let token = try await storedToken(of: ownerPhone)
        XCTAssertEqual(token, "owner", "a failure does not delete the token")
    }

    func testTheOrderDoesNotWaitForASlowSender() async throws {
        try await register(ownerPhone, ios: true, "owner")
        let gate = GatedPushSender()
        app.services.push = gate
        let reply = try await placeOrder()
        XCTAssertEqual(reply.status, .created, "answered while the push is still waiting")
        XCTAssertTrue(gate.opened.value == false)
        gate.open()
        await app.services.background.drain()
        XCTAssertEqual(gate.delivered.value, 1)
    }

    func testPushOffStillStoresTheOrder() async throws {
        try await register(ownerPhone, ios: true, "owner")
        app.services.push = nil
        let reply = try await placeOrder()
        XCTAssertEqual(reply.status, .created)
        await app.services.background.drain()
        XCTAssertEqual(pushSender.attempts, 0)
    }

    func testADeadTokenIsDeletedOnSend() async throws {
        let staff = try await addAccount(.staff)
        let phone = try await phoneOn("ios", of: staff.email)
        try await register(phone, ios: true, "dead")
        try await register(ownerPhone, ios: true, "alive")
        pushSender.markDead("dead")
        _ = try await place()
        let deadToken = try await storedToken(of: phone), aliveToken = try await storedToken(of: ownerPhone)
        XCTAssertNil(deadToken)
        XCTAssertEqual(aliveToken, "alive")
        let environment = try await storedEnvironment(of: phone)
        XCTAssertNil(environment)
    }
}

/// Holds the push until the test opens the gate.
final class GatedPushSender: PushSender, @unchecked Sendable {
    let opened = LockedBox(false)
    let delivered = LockedBox(0)
    func open() { opened.set(true) }
    func send(_ message: PushMessage, to target: PushTarget) async throws -> PushOutcome {
        while !opened.value { try await Task.sleep(for: .milliseconds(5)) }
        delivered.set(delivered.value + 1)
        return .delivered
    }
}
