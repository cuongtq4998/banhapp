import XCTest
import Vapor
import Fluent
import FluentSQL
@testable import AppUnderTest

/// Sign-in abuse over HTTP: TC-B01 to TC-B19 area (code limits, wrong codes, refresh reuse, deactivation).
final class AdminAuthAbuseTests: AdminQABase {

    private func deactivate(_ id: UUID, by phone: QAPhone) async throws -> QAReply {
        try await client.send("PATCH", "v1/owner/staff/\(id.uuidString)", token: phone.access, json: ["is_active": false])
    }

    /// AC-1/AC-2 and BR-4: same answer for a registered and an unknown address, mail only to the registered one.
    func testTCB01_CodeRequestAnswersAreIdenticalAndMailGoesOnlyToRegistered() async throws {
        // A fresh unknown address per run: code rows of unknown addresses are kept per address across shops and clocks.
        let stranger = "khong.co.\(UUID().uuidString.prefix(8).lowercased())@example.com"
        let known = try await requestCode(ownerEmail)
        let unknown = try await requestCode(stranger)
        XCTAssertEqual(known.status, 202)
        XCTAssertEqual(unknown.status, 202)
        XCTAssertEqual(known.json as NSDictionary, unknown.json as NSDictionary)
        XCTAssertEqual(mail.sent.filter { $0.to == ownerEmail }.count, 1)
        XCTAssertEqual(mail.sent.filter { $0.to == stranger }.count, 0)
        // An unknown address behaves exactly as a wrong code.
        let attempt = try await signInReply(stranger, code: "123456")
        XCTAssertEqual(attempt.status, 422)
        XCTAssertEqual(attempt.errorCode, "CODE_INVALID")
    }

    /// BR-4: wait of 30 s and 3 codes an hour per address.
    func testTCB14_ResendWaitAndHourlyLimit() async throws {
        try await aeq(try await requestCode(ownerEmail).status, 202)
        let early = try await requestCode(ownerEmail)
        XCTAssertEqual(early.status, 429)
        XCTAssertEqual(early.errorCode, "CODE_RESEND_WAIT")
        XCTAssertNotNil(early.header("Retry-After"))
        clock.advance(31)
        try await aeq(try await requestCode(ownerEmail).status, 202)
        clock.advance(31)
        try await aeq(try await requestCode(ownerEmail).status, 202)
        clock.advance(31)
        let fourth = try await requestCode(ownerEmail)
        XCTAssertEqual(fourth.status, 429)
        XCTAssertEqual(fourth.errorCode, "CODE_REQUEST_LIMIT")
        let wait = Int(fourth.header("Retry-After") ?? "") ?? 0
        XCTAssertTrue((1...3600).contains(wait), "Retry-After \(wait)")
        clock.advance(3_700)
        try await aeq(try await requestCode(ownerEmail).status, 202, "allowed again after the hour")
    }

    /// AC-4 / BR-4: the 5th wrong entry voids the code; the right digits of a void code are refused; no lock on the address.
    func testTCB08_FiveWrongCodesVoidTheCodeButDoNotLockTheAddress() async throws {
        try await aeq(try await requestCode(ownerEmail).status, 202)
        let right = try XCTUnwrap(mail.lastCode(to: ownerEmail))
        let wrong = right == "000000" ? "111111" : "000000"
        for attempt in 1...4 {
            let reply = try await signInReply(ownerEmail, code: wrong)
            XCTAssertEqual(reply.errorCode, "CODE_INVALID", "wrong entry \(attempt)")
        }
        try await aeq(try await signInReply(ownerEmail, code: wrong).errorCode, "CODE_EXPIRED", "5th wrong entry voids the code")
        let afterVoid = try await signInReply(ownerEmail, code: right)
        XCTAssertEqual(afterVoid.status, 422)
        XCTAssertEqual(afterVoid.errorCode, "CODE_EXPIRED")
        clock.advance(31)
        try await aeq(try await requestCode(ownerEmail).status, 202)
        let fresh = try XCTUnwrap(mail.lastCode(to: ownerEmail))
        try await aeq(try await signInReply(ownerEmail, code: fresh).status, 201, "no lock on the address")
        // A used code cannot be used twice.
        let replay = try await signInReply(ownerEmail, code: fresh)
        XCTAssertEqual(replay.status, 422)
    }

    /// AC-1: format problems are 422 VALIDATION_FAILED and do not count as wrong entries.
    func testTCB09_FormatErrorsAreNotCountedAsWrongEntries() async throws {
        try await aeq(try await requestCode(ownerEmail).status, 202)
        let right = try XCTUnwrap(mail.lastCode(to: ownerEmail))
        for bad in ["12345", "1234567", "12 456", "abcdef", "１２３４５６", ""] {
            let reply = try await signInReply(ownerEmail, code: bad)
            XCTAssertEqual(reply.status, 422, bad)
            XCTAssertEqual(reply.errorCode, "VALIDATION_FAILED", bad)
            XCTAssertTrue(reply.fieldCodes.contains("CODE_FORMAT"), "\(bad) \(reply.text)")
        }
        try await aeq(try await signInReply(ownerEmail, code: right).status, 201, "ten format errors left the code intact")
        let badMail = try await client.send("POST", "v1/auth/code-requests", json: ["email": "not-an-address"])
        XCTAssertEqual(badMail.status, 422)
        XCTAssertTrue(badMail.fieldCodes.contains("EMAIL_INVALID"))
        let tooLong = try await client.send("POST", "v1/auth/code-requests", json: ["email": String(repeating: "a", count: 250) + "@example.com"])
        XCTAssertEqual(tooLong.status, 422)
    }

    /// AC-3 / BR-5: refresh rotates; an old token after the 20 s grace is reuse and kills the whole family.
    func testTCB10_RefreshReuseRevokesTheFamily() async throws {
        let phone = try await owner()
        let first = try await client.send("POST", "v1/auth/refresh", json: ["refresh_token": phone.refresh])
        XCTAssertEqual(first.status, 200, first.text)
        let newRefresh = first.string("refresh_token"), newAccess = first.string("access_token")
        XCTAssertNotEqual(newRefresh, phone.refresh)
        clock.advance(25)  // past the 20 s grace of the first rotation
        let reuse = try await client.send("POST", "v1/auth/refresh", json: ["refresh_token": phone.refresh])
        XCTAssertEqual(reuse.status, 401)
        XCTAssertEqual(reuse.errorCode, "SESSION_REVOKED")
        let second = try await client.send("POST", "v1/auth/refresh", json: ["refresh_token": newRefresh])
        XCTAssertEqual(second.errorCode, "SESSION_REVOKED", "the legitimate holder is cut off too")
        let me = try await client.send("GET", "v1/admin/me", token: newAccess)
        XCTAssertEqual(me.status, 401)
        XCTAssertEqual(me.errorCode, "SESSION_REVOKED")
    }

    /// BR-5: inside the 20 s window a lost-response retry gets a fresh pair; the window does not move forward.
    func testTCB11_RefreshGraceWindowDoesNotSlide() async throws {
        let phone = try await owner()
        let a = try await client.send("POST", "v1/auth/refresh", json: ["refresh_token": phone.refresh])
        clock.advance(10)
        let b = try await client.send("POST", "v1/auth/refresh", json: ["refresh_token": phone.refresh])
        XCTAssertEqual(b.status, 200, "lost-response retry inside 20 s")
        clock.advance(15) // 25 s after the first rotation
        let c = try await client.send("POST", "v1/auth/refresh", json: ["refresh_token": phone.refresh])
        XCTAssertEqual(c.status, 401, "the window is counted from the first rotation, not the retry")
        _ = a
    }

    /// BR-5, FR-6: deactivated staff lose the session at once, refresh included.
    func testTCB12_DeactivatedStaffCannotRefreshOrCallAdminRoutes() async throws {
        let ownerPhone = try await owner()
        let member = try await staff()
        try await aeq(try await client.send("GET", "v1/admin/me", token: member.phone.access).status, 200)
        let off = try await deactivate(member.id, by: ownerPhone)
        XCTAssertEqual(off.status, 200, off.text)
        let refresh = try await client.send("POST", "v1/auth/refresh", json: ["refresh_token": member.phone.refresh])
        XCTAssertEqual(refresh.status, 401)
        XCTAssertEqual(refresh.errorCode, "SESSION_REVOKED")
        let me = try await client.send("GET", "v1/admin/me", token: member.phone.access)
        XCTAssertEqual(me.status, 401)
        let list = try await client.send("GET", "v1/admin/orders", token: member.phone.access)
        XCTAssertEqual(list.status, 401)
        // The deactivated address gets no mail and cannot sign in.
        let before = mail.sent.count
        try await aeq(try await requestCode(member.email).status, 202)
        XCTAssertEqual(mail.sent.count, before, "no code mail to a deactivated account")
        // The owner cannot be deactivated.
        let self1 = try await deactivate(ownerID, by: ownerPhone)
        XCTAssertEqual(self1.status, 409)
        XCTAssertEqual(self1.errorCode, "OWNER_PROTECTED")
    }

    /// Token hygiene: garbage, wrong prefix, expired access token, malformed refresh token.
    func testTCB13_TokenAbuse() async throws {
        let phone = try await owner()
        for token in ["", "garbage", "Bearer x", "at_", "at_00000000-0000-4000-8000-000000000000_zzzz", phone.refresh, "rt_" + String(repeating: "a", count: 5_000)] {
            let reply = try await client.send("GET", "v1/admin/me", token: token.isEmpty ? nil : token)
            XCTAssertEqual(reply.status, 401, "token \(token.prefix(20))")
            XCTAssertEqual(reply.header("Cache-Control"), "no-store")
        }
        for body in ["{}", #"{"refresh_token":"x"}"#, #"{"refresh_token":null}"#, "[]", "not json"] {
            let reply = try await client.send("POST", "v1/auth/refresh", rawBody: Data(body.utf8), contentType: "application/json")
            XCTAssertTrue([401, 422].contains(reply.status), "\(body) -> \(reply.status)")
            XCTAssertLessThan(reply.status, 500)
        }
        clock.advance(301)
        let expired = try await client.send("GET", "v1/admin/me", token: phone.access)
        XCTAssertEqual(expired.status, 401)
        XCTAssertEqual(expired.errorCode, "ACCESS_TOKEN_EXPIRED")
        try await aeq(try await client.send("POST", "v1/auth/refresh", json: ["refresh_token": phone.refresh]).status, 200)
    }

    /// FR-4 / BR-5: sign out all other phones keeps this one; the others die including their refresh tokens.
    func testTCB23_SignOutOthersKeepsCurrentPhoneOnly() async throws {
        let first = try await signedIn(ownerEmail), second = try await signedIn(ownerEmail)
        let out = try await client.send("DELETE", "v1/admin/sessions/others", token: second.access)
        XCTAssertEqual(out.status, 204, out.text)
        try await aeq(try await client.send("GET", "v1/admin/me", token: second.access).status, 200)
        try await aeq(try await client.send("GET", "v1/admin/me", token: first.access).status, 401)
        try await aeq(try await client.send("POST", "v1/auth/refresh", json: ["refresh_token": first.refresh]).errorCode, "SESSION_REVOKED")
        try await aeq(try await client.send("DELETE", "v1/admin/session", token: second.access).status, 204)
        try await aeq(try await client.send("GET", "v1/admin/me", token: second.access).status, 401)
    }

    /// AC-3: after the 30 s a new code can be requested and the older one stops working.
    func testTCB15_ANewCodeConsumesTheOlderOne() async throws {
        try await aeq(try await requestCode(ownerEmail).status, 202)
        let older = try XCTUnwrap(mail.lastCode(to: ownerEmail))
        clock.advance(31)
        try await aeq(try await requestCode(ownerEmail).status, 202)
        let newer = try XCTUnwrap(mail.lastCode(to: ownerEmail))
        if older != newer {
            let reply = try await signInReply(ownerEmail, code: older)
            XCTAssertEqual(reply.status, 422, "the older code must stop working")
        }
        try await aeq(try await signInReply(ownerEmail, code: newer).status, 201)
    }
}
