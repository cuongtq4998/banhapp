import XCTVapor
@testable import App

/// Limits on code requests and guesses: BR-4, auth.md 4.2 (TC-B06 to B13, B19).
final class SignInLimitTests: AdminDatabaseTestCase {
    func testResendWaitBoundaries() async throws {
        let staff = try await addAccount(.staff)
        let first = try await requestCode(staff.email)
        XCTAssertEqual(first.status, .accepted)
        await app.services.background.drain()
        let firstCode = try XCTUnwrap(mail.lastCode(to: staff.email))
        clock.advance(10)
        let early = try await requestCode(staff.email)
        XCTAssertEqual(early.status, .tooManyRequests)
        XCTAssertEqual(early.errorCode, "CODE_RESEND_WAIT")
        XCTAssertEqual(early.retryAfter, 20)
        XCTAssertEqual((early.json["error"] as? [String: Any])?["details"] as? [String: Int], ["retry_after_seconds": 20])
        clock.advance(19) // +29 s
        let still = try await requestCode(staff.email)
        XCTAssertEqual(still.errorCode, "CODE_RESEND_WAIT")
        XCTAssertEqual(still.retryAfter, 1)
        clock.advance(1) // +30 s exactly
        let allowed = try await requestCode(staff.email)
        XCTAssertEqual(allowed.status, .accepted)
        await app.services.background.drain()
        let oldCode = try await signIn(staff.email, firstCode)
        XCTAssertEqual(oldCode.status, .unprocessableEntity, "a newer code voids the older one")
        let secondCode = try XCTUnwrap(mail.lastCode(to: staff.email))
        let works = try await signIn(staff.email, secondCode)
        XCTAssertEqual(works.status, .created)
    }

    func testThreeCodesAnHourThenTheLookBackFrees() async throws {
        let staff = try await addAccount(.staff)
        let start = clock.now()
        for step in 0..<3 {
            let reply = try await requestCode(staff.email)
            XCTAssertEqual(reply.status, .accepted, "request \(step + 1)")
            clock.advance(31)
        }
        let fourth = try await requestCode(staff.email)
        XCTAssertEqual(fourth.errorCode, "CODE_REQUEST_LIMIT")
        XCTAssertEqual(fourth.status, .tooManyRequests)
        XCTAssertEqual(fourth.retryAfter, 3_600 - 93)
        clock.set(start.addingTimeInterval(3_599))
        let early = try await requestCode(staff.email)
        XCTAssertEqual(early.errorCode, "CODE_REQUEST_LIMIT")
        XCTAssertEqual(early.retryAfter, 1)
        clock.set(start.addingTimeInterval(3_600)) // the first code is exactly one hour old
        let later = try await requestCode(staff.email)
        XCTAssertEqual(later.status, .accepted)
    }

    func testUnregisteredAddressesAreLimitedTheSameWay() async throws {
        let ghost = "khong.co\(UUID().uuidString.prefix(6).lowercased())@example.com"
        var codes: [String?] = []
        for _ in 0..<4 { codes.append(try await requestCode(ghost).errorCode); clock.advance(31) }
        XCTAssertEqual(codes, [nil, nil, nil, "CODE_REQUEST_LIMIT"])
    }

    func testSignedInPhoneIsUnaffectedByAStrangersRequestsAndGuesses() async throws {
        let staff = try await addAccount(.staff)
        let phone = try await signedIn(staff.email)
        _ = try await requestCode(staff.email)
        for _ in 0..<5 { _ = try await signIn(staff.email, "000000") }
        for _ in 0..<4 { clock.advance(31); _ = try await requestCode(staff.email) }
        let renewed = try await refresh(phone.refresh)
        XCTAssertEqual(renewed.status, .ok)
        let me = try await authed(.GET, "v1/admin/me", renewed.string("access_token"))
        XCTAssertEqual(me.status, .ok)
    }

    func testDailyCapAnswersAsRequestLimitForEveryAddress() async throws {
        let before = try await count("SELECT count(*)::int AS n FROM auth_code WHERE created_at >= date_trunc('day', \(timestamp(clock.now())) AT TIME ZONE 'UTC') AT TIME ZONE 'UTC'")
        app.services.adminAuth = AdminAuthConfig(pepper: pepper, emailProvider: .recording, emailMaxPerDay: before + 2)
        let staff = try await addAccount(.staff)
        let ghost = "khong.co\(UUID().uuidString.prefix(6).lowercased())@example.com"
        let first = try await requestCode(staff.email), second = try await requestCode(ghost)
        XCTAssertEqual([first.status, second.status], [.accepted, .accepted])
        let blocked = try await requestCode(staff.email.replacingOccurrences(of: "@", with: "x@"))
        XCTAssertEqual(blocked.errorCode, "CODE_REQUEST_LIMIT")
        XCTAssertEqual(blocked.retryAfter, 3_600, "capped; the real wait is until 00:00 UTC")
        await app.services.background.drain()
        XCTAssertEqual(mail.sent.count, 1)
    }

    func testClientAddressLimitOn21stCodeRequestAnHour() async throws {
        var statuses: [HTTPStatus] = []
        for index in 0..<21 { statuses.append(try await requestCode("ghost\(index)\(UUID().uuidString.prefix(6).lowercased())@example.com").status) }
        XCTAssertEqual(Set(statuses.prefix(20)), [.accepted])
        XCTAssertEqual(statuses[20], .tooManyRequests)
        clock.advance(3_600)
        let after = try await requestCode("ghost-after\(UUID().uuidString.prefix(6).lowercased())@example.com")
        XCTAssertEqual(after.status, .accepted)
    }

    func testParallelWrongGuessesNeverPassFive() async throws {
        let staff = try await addAccount(.staff)
        _ = try await requestCode(staff.email)
        await app.services.background.drain()
        let code = try XCTUnwrap(mail.lastCode(to: staff.email))
        let wrong = code == "000000" ? "111111" : "000000"
        let email = staff.email, app = app!
        let replies = try await withThrowingTaskGroup(of: String?.self) { group in
            for _ in 0..<20 { group.addTask { try await Self.signIn(app, email, wrong).errorCode } }
            return try await group.reduce(into: [String?]()) { $0.append($1) }
        }
        XCTAssertEqual(replies.filter { $0 == "CODE_INVALID" }.count, 4)
        XCTAssertEqual(replies.filter { $0 == "CODE_EXPIRED" }.count, 16)
        let stored = try await count("SELECT max(wrong_count)::int AS n FROM auth_code WHERE email = \(bind: email)")
        XCTAssertEqual(stored, 5)
    }

    func testParallelUseOfTheRightCodeCreatesOneSession() async throws {
        let staff = try await addAccount(.staff)
        _ = try await requestCode(staff.email)
        await app.services.background.drain()
        let code = try XCTUnwrap(mail.lastCode(to: staff.email))
        let email = staff.email, app = app!
        let statuses = try await withThrowingTaskGroup(of: HTTPStatus.self) { group in
            for _ in 0..<5 { group.addTask { try await Self.signIn(app, email, code).status } }
            return try await group.reduce(into: [HTTPStatus]()) { $0.append($1) }
        }
        XCTAssertEqual(statuses.filter { $0 == .created }.count, 1)
        let sessions = try await count("SELECT count(*)::int AS n FROM device_session WHERE account_id = \(bind: staff.id)")
        XCTAssertEqual(sessions, 1)
    }
}
