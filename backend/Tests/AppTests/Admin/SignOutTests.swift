import XCTVapor
@testable import App

/// Sign out and "Sign out all other phones": FR-2, FR-4, BR-5 (TC-B22 to B25).
final class SignOutTests: AdminDatabaseTestCase {
    func testSignOutEndsOnlyThisPhone() async throws {
        let staff = try await addAccount(.staff)
        let phone1 = try await signedIn(staff.email), phone2 = try await signedIn(staff.email)
        let out = try await authed(.DELETE, "v1/admin/session", phone1.access)
        XCTAssertEqual(out.status, .noContent)
        let renew = try await refresh(phone1.refresh)
        XCTAssertEqual(renew.errorCode, "SESSION_REVOKED")
        let read = try await authed(.GET, "v1/admin/me", phone1.access)
        XCTAssertEqual(read.errorCode, "SESSION_REVOKED", "the access token is checked against the session row")
        let again = try await authed(.DELETE, "v1/admin/session", phone1.access)
        XCTAssertEqual(again.status, .unauthorized)
        let other = try await authed(.GET, "v1/admin/me", phone2.access)
        XCTAssertEqual(other.status, .ok)
        let events = try await count("SELECT count(*)::int AS n FROM security_event WHERE event_type = 'sign_out' AND account_id = \(bind: staff.id)")
        XCTAssertEqual(events, 1)
    }

    func testSignOutOthersKeepsTheCallerAndEndsTheRest() async throws {
        let staff = try await addAccount(.staff), bystander = try await addAccount(.staff, "Nhan Vien B")
        let phone1 = try await signedIn(staff.email), phone2 = try await signedIn(staff.email)
        let b = try await signedIn(bystander.email)
        await app.services.background.drain()
        let mailBefore = mail.sent.count

        let reply = try await authed(.DELETE, "v1/admin/sessions/others", phone1.access)
        XCTAssertEqual(reply.status, .noContent)
        let renew2 = try await refresh(phone2.refresh)
        XCTAssertEqual(renew2.errorCode, "SESSION_REVOKED", "renewal fails at once")
        let read2 = try await authed(.GET, "v1/admin/me", phone2.access)
        XCTAssertEqual(read2.errorCode, "SESSION_REVOKED", "data is refused at once, inside the 5 minutes")
        let renew1 = try await refresh(phone1.refresh)
        XCTAssertEqual(renew1.status, .ok, "the calling phone keeps working, renewal included")
        let readB = try await authed(.GET, "v1/admin/me", b.access)
        XCTAssertEqual(readB.status, .ok, "other accounts are untouched")
        XCTAssertEqual(mail.sent.count, mailBefore, "no mail")
        let events = try await count("SELECT count(*)::int AS n FROM security_event WHERE event_type = 'sign_out_others' AND device_session_id = \(bind: phone1.deviceID)")
        XCTAssertEqual(events, 1)
    }

    func testSignOutOthersWithNothingToDoAndRepeatsAreHarmless() async throws {
        let owner = try await addAccount(.owner)
        let only = try await signedIn(owner.email)
        for _ in 0..<2 {
            let reply = try await authed(.DELETE, "v1/admin/sessions/others", only.access)
            XCTAssertEqual(reply.status, .noContent)
        }
        let read = try await authed(.GET, "v1/admin/me", only.access)
        XCTAssertEqual(read.status, .ok)
    }

    func testSignOutOthersClearsPushTokensOfTheOtherPhones() async throws {
        let staff = try await addAccount(.staff)
        let phone1 = try await signedIn(staff.email), phone2 = try await signedIn(staff.email)
        try await run("UPDATE device_session SET push_token = 'token-two', push_apns_environment = 'sandbox' WHERE id = \(bind: phone2.deviceID)")
        _ = try await authed(.DELETE, "v1/admin/sessions/others", phone1.access)
        let left = try await count("SELECT count(*)::int AS n FROM device_session WHERE push_token IS NOT NULL AND account_id = \(bind: staff.id)")
        XCTAssertEqual(left, 0)
    }

    func testRenewalRacingWithSignOutOthersLeavesNoValidCredentialOnTheOtherPhone() async throws {
        let staff = try await addAccount(.staff)
        let phone1 = try await signedIn(staff.email), phone2 = try await signedIn(staff.email)
        let app = app!, token1 = phone1.access, refresh2 = phone2.refresh
        let renewed = try await withThrowingTaskGroup(of: Reply.self) { group in
            group.addTask { try await Self.send(app, .DELETE, "v1/admin/sessions/others", headers: ["Authorization": "Bearer \(token1)", "X-Platform": "ios", "X-App-Version": "1.0.0"]) }
            group.addTask { try await Self.send(app, .POST, "v1/auth/refresh", ["refresh_token": refresh2]) }
            return try await group.reduce(into: [Reply]()) { $0.append($1) }
        }
        XCTAssertTrue(renewed.contains { $0.status == .noContent })
        for token in renewed.compactMap({ $0.json["refresh_token"] as? String }) + [phone2.refresh] {
            let reply = try await refresh(token)
            XCTAssertEqual(reply.errorCode, "SESSION_REVOKED")
        }
        let alive = try await authed(.GET, "v1/admin/me", phone1.access)
        XCTAssertEqual(alive.status, .ok)
    }
}
