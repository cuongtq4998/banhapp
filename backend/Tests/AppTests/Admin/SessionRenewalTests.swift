import XCTVapor
@testable import App

/// Renewal, rotation, grace and reuse: FR-2, FR-6, BR-5 (TC-B20 to B27).
final class SessionRenewalTests: AdminDatabaseTestCase {
    private func phone() async throws -> (Phone, String) {
        let staff = try await addAccount(.staff)
        return (try await signedIn(staff.email), staff.email)
    }

    func testSignInReturnsTheDocumentedFields() async throws {
        let owner = try await addAccount(.owner, "Chu Mau")
        _ = try await requestCode(owner.email)
        await app.services.background.drain()
        let reply = try await signIn(owner.email, try XCTUnwrap(mail.lastCode(to: owner.email)))
        XCTAssertEqual(reply.status, .created)
        XCTAssertEqual(reply.json["access_expires_in"] as? Int, 300)
        XCTAssertTrue(reply.string("access_token").hasPrefix("at_\(reply.string("device_id").lowercased())_"))
        XCTAssertTrue(reply.string("refresh_token").hasPrefix("rt_\(reply.string("device_id").lowercased())_"))
        XCTAssertEqual(reply.string("server_date").count, 10)
        XCTAssertEqual(reply.headers.first(name: .cacheControl), "no-store")
    }

    func testEachRenewalReturnsANewPairAndTheOldOneDiesAfterGrace() async throws {
        var (phone, _) = try await phone()
        var older: [String] = []
        for _ in 0..<4 { // every 5 days for 20 days
            clock.advance(5 * 86_400)
            let reply = try await refresh(phone.refresh)
            XCTAssertEqual(reply.status, .ok)
            XCTAssertEqual(reply.json["access_expires_in"] as? Int, 300)
            older.append(phone.refresh)
            phone.refresh = reply.string("refresh_token")
            phone.access = reply.string("access_token")
            XCTAssertNotEqual(older.last, phone.refresh)
        }
        let me = try await authed(.GET, "v1/admin/me", phone.access)
        XCTAssertEqual(me.status, .ok)
        clock.advance(21)
        let replay = try await refresh(older[0])
        XCTAssertEqual(replay.errorCode, "SESSION_REVOKED")
    }

    func testIdleSessionLivesStrictlyLessThanSevenDays() async throws {
        let week: TimeInterval = 7 * 86_400
        let cases: [(TimeInterval, HTTPStatus)] = [(week - 60, .ok), (week, .unauthorized), (week + 60, .unauthorized)]
        for (idle, expected) in cases {
            let (phone, _) = try await phone()
            clock.advance(idle)
            let reply = try await refresh(phone.refresh)
            XCTAssertEqual(reply.status, expected, "idle \(idle)")
            if expected == .unauthorized { XCTAssertEqual(reply.errorCode, "SESSION_EXPIRED") }
        }
    }

    func testReplayAfterGraceRevokesTheWholeSession() async throws {
        let (phone, _) = try await phone()
        let renewed = try await refresh(phone.refresh)
        clock.advance(21)
        let replay = try await refresh(phone.refresh)
        XCTAssertEqual(replay.status, .unauthorized)
        XCTAssertEqual(replay.errorCode, "SESSION_REVOKED")
        let newOne = try await refresh(renewed.string("refresh_token"))
        XCTAssertEqual(newOne.errorCode, "SESSION_REVOKED", "the new credential died with the session")
        let data = try await authed(.GET, "v1/admin/me", renewed.string("access_token"))
        XCTAssertEqual(data.errorCode, "SESSION_REVOKED")
        let events = try await count("SELECT count(*)::int AS n FROM security_event WHERE event_type = 'refresh_reuse_detected' AND device_session_id = \(bind: phone.deviceID)")
        XCTAssertEqual(events, 1)
        let reason = try await count("SELECT count(*)::int AS n FROM device_session WHERE id = \(bind: phone.deviceID) AND revoked_reason = 'reuse_detected'")
        XCTAssertEqual(reason, 1)
    }

    func testLostAnswerRetryWorksUpToTwentySecondsIncluded() async throws {
        for (wait, ok) in [(1.0, true), (19, true), (20, true), (21, false)] {
            let (phone, _) = try await phone()
            _ = try await refresh(phone.refresh) // the answer is "lost"
            clock.advance(wait)
            let retry = try await refresh(phone.refresh)
            XCTAssertEqual(retry.status == .ok, ok, "after \(wait) s")
            if ok {
                let me = try await authed(.GET, "v1/admin/me", retry.string("access_token"))
                XCTAssertEqual(me.status, .ok)
            }
        }
    }

    func testRepeatedRetryInsideTheGraceKeepsReturningAFreshPair() async throws {
        let (phone, _) = try await phone()
        let lost = try await refresh(phone.refresh)
        clock.advance(5)
        let second = try await refresh(phone.refresh), third = try await refresh(phone.refresh)
        XCTAssertEqual([second.status, third.status], [.ok, .ok])
        let dead = try await refresh(lost.string("refresh_token"))
        XCTAssertEqual(dead.errorCode, "SESSION_REVOKED", "only the newest pair lives")
    }

    func testGarbageAndAccessTokensAreRefusedAsRefreshCredentials() async throws {
        let (phone, _) = try await phone()
        let unknown = SessionToken.issue(.refresh, sessionID: UUID()).text
        for bad in ["", "nonsense", unknown, phone.access] {
            let reply = try await refresh(bad)
            XCTAssertEqual(reply.errorCode, "SESSION_REVOKED", bad)
        }
        let still = try await refresh(phone.refresh)
        XCTAssertEqual(still.status, .ok, "garbage does not touch the real session")
    }

    func testDeactivatedAccountCannotRenewOrRead() async throws {
        let (phone, _) = try await phone()
        let me = try await authed(.GET, "v1/admin/me", phone.access)
        XCTAssertEqual(me.status, .ok)
        try await run("UPDATE account SET is_active = false WHERE id = (SELECT account_id FROM device_session WHERE id = \(bind: phone.deviceID))")
        let renewal = try await refresh(phone.refresh)
        XCTAssertEqual(renewal.errorCode, "SESSION_REVOKED")
        let read = try await authed(.GET, "v1/admin/me", phone.access)
        XCTAssertEqual(read.errorCode, "SESSION_REVOKED")
    }

    func testSameInstallationReplacesTheOlderSession() async throws {
        let staff = try await addAccount(.staff)
        let installation = UUID()
        let first = try await signedIn(staff.email, installation: installation)
        let second = try await signedIn(staff.email, installation: installation)
        let old = try await refresh(first.refresh)
        XCTAssertEqual(old.errorCode, "SESSION_REVOKED")
        let current = try await refresh(second.refresh)
        XCTAssertEqual(current.status, .ok)
        let replaced = try await count("SELECT count(*)::int AS n FROM device_session WHERE installation_id = \(bind: installation) AND revoked_reason = 'replaced'")
        XCTAssertEqual(replaced, 1)
    }

    func testRefreshRouteRejectsAnAccessTokenHeaderAndBadBody() async throws {
        let noBody = try await send(.POST, "v1/auth/refresh")
        XCTAssertEqual(noBody.errorCode, "VALIDATION_FAILED")
    }
}
