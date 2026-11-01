import XCTVapor
@testable import App

/// `PUT /v1/admin/push-token` (FR-25, api/06 10.8) and the removal of the token.
final class PushRegistrationTests: PushDatabaseTestCase {
    func testIOSAndAndroidPhonesRegisterOwnerAndStaff() async throws {
        let staff = try await addAccount(.staff)
        let ios = try await phoneOn("ios", of: staff.email), android = try await phoneOn("android", of: staff.email)
        let registeredIOS = try await register(ios, platform: "ios", token: "ios-token-1", environment: "sandbox")
        let registeredAndroid = try await register(android, platform: "android", token: "fcm:android-1")
        let registeredOwner = try await register(ownerPhone, platform: "ios", token: "owner-token", environment: "production")
        for reply in [registeredIOS, registeredAndroid, registeredOwner] { XCTAssertEqual(reply.status, .noContent) }
        let storedIOS = try await storedToken(of: ios), storedAndroid = try await storedToken(of: android)
        XCTAssertEqual(storedIOS, "ios-token-1")
        XCTAssertEqual(storedAndroid, "fcm:android-1")
        let iosEnvironment = try await storedEnvironment(of: ios), androidEnvironment = try await storedEnvironment(of: android)
        XCTAssertEqual(iosEnvironment, "sandbox")
        XCTAssertNil(androidEnvironment)
        let ownerEnvironment = try await storedEnvironment(of: ownerPhone)
        XCTAssertEqual(ownerEnvironment, "production")
    }

    func testRequiresASignedInSession() async throws {
        let body = #"{"platform":"ios","token":"t","apns_environment":"sandbox"}"#
        let none = try await put(body, nil)
        XCTAssertEqual(none.status, .unauthorized)
        XCTAssertEqual(none.errorCode, "UNAUTHENTICATED")
        let forged = try await put(body, Phone(installationID: UUID(), access: "not-a-token", refresh: "", deviceID: UUID()))
        XCTAssertEqual(forged.status, .unauthorized)
    }

    func testRevokedSessionIsRefusedAndStoresNothing() async throws {
        let staff = try await addAccount(.staff)
        let phone = try await phoneOn("ios", of: staff.email)
        _ = try await authed(.DELETE, "v1/admin/session", phone.access)
        let reply = try await register(phone, platform: "ios", token: "late", environment: "sandbox")
        XCTAssertEqual(reply.status, .unauthorized)
        XCTAssertEqual(reply.errorCode, "SESSION_REVOKED")
        let stored = try await count("SELECT count(*)::int AS n FROM device_session WHERE push_token = 'late'")
        XCTAssertEqual(stored, 0)
    }

    func testBadBodiesAre422AndStoreNothing() async throws {
        let bodies = [
            "{}", #"{"platform":"ios","token":"t"}"#, #"{"platform":"ios","token":"","apns_environment":"sandbox"}"#,
            #"{"platform":"windows","token":"t"}"#, #"{"platform":"android","token":"a b"}"#,
            #"{"platform":"android","token":"t","extra":1}"#, "[]", "not json",
            #"{"platform":"android","token":"\#(String(repeating: "z", count: 513))"}"#
        ]
        for body in bodies {
            let reply = try await put(body, ownerPhone)
            XCTAssertEqual(reply.status, .unprocessableEntity, body)
            XCTAssertEqual(reply.errorCode, "VALIDATION_FAILED", body)
        }
        let stored = try await storedToken(of: ownerPhone)
        XCTAssertNil(stored)
    }

    func testTheBodyPlatformMustBeThePhonesOwn() async throws {
        let reply = try await register(ownerPhone, platform: "android", token: "wrong-service")
        XCTAssertEqual(reply.status, .unprocessableEntity)
        let stored = try await storedToken(of: ownerPhone)
        XCTAssertNil(stored)
    }

    func testANewTokenReplacesTheOldOneOfTheSamePhone() async throws {
        _ = try await register(ownerPhone, platform: "ios", token: "first", environment: "sandbox")
        let again = try await register(ownerPhone, platform: "ios", token: "second", environment: "production")
        XCTAssertEqual(again.status, .noContent)
        let stored = try await storedToken(of: ownerPhone), environment = try await storedEnvironment(of: ownerPhone)
        XCTAssertEqual(stored, "second")
        XCTAssertEqual(environment, "production")
        let rows = try await count("SELECT count(*)::int AS n FROM device_session WHERE push_token IN ('first', 'second')")
        XCTAssertEqual(rows, 1)
        let repeated = try await register(ownerPhone, platform: "ios", token: "second", environment: "production")
        XCTAssertEqual(repeated.status, .noContent, "the same token again is harmless")
    }

    func testATokenSeenOnAnotherSessionMovesToTheCaller() async throws {
        let staff = try await addAccount(.staff)
        let old = try await phoneOn("ios", of: staff.email), reinstalled = try await phoneOn("ios", of: staff.email)
        _ = try await register(old, platform: "ios", token: "shared", environment: "sandbox")
        let moved = try await register(reinstalled, platform: "ios", token: "shared", environment: "sandbox")
        XCTAssertEqual(moved.status, .noContent)
        let oldToken = try await storedToken(of: old), newToken = try await storedToken(of: reinstalled)
        XCTAssertNil(oldToken)
        XCTAssertEqual(newToken, "shared")
        let oldEnvironment = try await storedEnvironment(of: old)
        XCTAssertNil(oldEnvironment)
    }

    func testSignOutDeletesTheTokenOfThatPhoneOnly() async throws {
        let staff = try await addAccount(.staff)
        let one = try await phoneOn("ios", of: staff.email), two = try await phoneOn("android", of: staff.email)
        _ = try await register(one, platform: "ios", token: "one", environment: "sandbox")
        _ = try await register(two, platform: "android", token: "two")
        let out = try await authed(.DELETE, "v1/admin/session", one.access)
        XCTAssertEqual(out.status, .noContent)
        let oneToken = try await storedToken(of: one), twoToken = try await storedToken(of: two)
        XCTAssertNil(oneToken)
        let oneEnvironment = try await storedEnvironment(of: one)
        XCTAssertNil(oneEnvironment)
        XCTAssertEqual(twoToken, "two")
    }

    func testSignOutOfOtherPhonesDeletesTheirTokens() async throws {
        let staff = try await addAccount(.staff)
        let caller = try await phoneOn("ios", of: staff.email), other = try await phoneOn("android", of: staff.email)
        _ = try await register(caller, platform: "ios", token: "caller", environment: "sandbox")
        _ = try await register(other, platform: "android", token: "other")
        _ = try await authed(.DELETE, "v1/admin/sessions/others", caller.access)
        let callerToken = try await storedToken(of: caller), otherToken = try await storedToken(of: other)
        XCTAssertEqual(callerToken, "caller")
        XCTAssertNil(otherToken)
    }

    func testDeactivatingAStaffAccountDeletesItsTokens() async throws {
        let staff = try await addAccount(.staff)
        let ios = try await phoneOn("ios", of: staff.email), android = try await phoneOn("android", of: staff.email)
        _ = try await register(ios, platform: "ios", token: "s-ios", environment: "sandbox")
        _ = try await register(android, platform: "android", token: "s-android")
        let off = try await call(.PATCH, "v1/owner/staff/\(staff.id)", #"{"is_active":false}"#)
        XCTAssertEqual(off.status, .ok)
        let left = try await count("SELECT count(*)::int AS n FROM device_session WHERE account_id = \(bind: staff.id) AND push_token IS NOT NULL")
        XCTAssertEqual(left, 0)
    }

    func testReuseOfARefreshTokenRevokesTheSessionAndItsToken() async throws {
        let staff = try await addAccount(.staff)
        let phone = try await phoneOn("ios", of: staff.email)
        _ = try await register(phone, platform: "ios", token: "reuse", environment: "sandbox")
        let first = try await refresh(phone.refresh)
        XCTAssertEqual(first.status, .ok)
        clock.advance(60)
        let replay = try await refresh(phone.refresh)
        XCTAssertEqual(replay.errorCode, "SESSION_REVOKED")
        let stored = try await storedToken(of: phone)
        XCTAssertNil(stored)
    }

    func testThereIsNoDeleteRoute() async throws {
        let reply = try await call(.DELETE, "v1/admin/push-token")
        XCTAssertEqual(reply.status, .notFound)
    }
}
