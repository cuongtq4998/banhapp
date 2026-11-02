import XCTVapor
@testable import App

/// Sign-in codes: FR-1, BR-4 (TC-B01 to B18).
final class SignInCodeTests: AdminDatabaseTestCase {
    func testRegisteredAndUnregisteredAddressesGetTheSameAnswer() async throws {
        let staff = try await addAccount(.staff, "Nhan Vien A")
        let registered = try await requestCode(staff.email)
        clock.advance(30)
        let mixedCase = try await requestCode(staff.email.uppercased())
        let unknown = try await requestCode("khong.co\(UUID().uuidString.prefix(6).lowercased())@example.com")
        await app.services.background.drain()
        XCTAssertEqual(registered.status, .accepted)
        XCTAssertEqual(registered.json["resend_after_seconds"] as? Int, 30)
        XCTAssertEqual(registered.json["expires_in_seconds"] as? Int, 600)
        XCTAssertEqual(registered.json as NSDictionary, unknown.json as NSDictionary)
        XCTAssertEqual(registered.headers.first(name: .contentType), unknown.headers.first(name: .contentType))
        XCTAssertEqual(registered.headers.first(name: .cacheControl), "no-store")
        XCTAssertEqual(mixedCase.status, .accepted, "letter case is ignored")
        XCTAssertEqual(mail.sent.count, 2, "mail only for the registered address, one per request")
        XCTAssertEqual(Set(mail.sent.map(\.to)), [staff.email])
        XCTAssertNotNil(mail.lastCode(to: staff.email))
    }

    func testInactiveAddressGetsTheSameAnswerAndNoMail() async throws {
        let off = try await addAccount(.staff, "Nhan Vien B", active: false)
        let reply = try await requestCode(off.email)
        await app.services.background.drain()
        XCTAssertEqual(reply.status, .accepted)
        XCTAssertTrue(mail.sent.isEmpty)
        let signIn = try await signIn(off.email, "123456")
        XCTAssertEqual(signIn.errorCode, "CODE_INVALID")
    }

    func testCodeWorksStrictlyBeforeTenMinutesAndOnlyOnce() async throws {
        let owner = try await addAccount(.owner, "Chu Mau")
        for (offset, expected) in [(599.0, HTTPStatus.created), (600.0, .unprocessableEntity), (601.0, .unprocessableEntity)] {
            _ = try await requestCode(owner.email)
            await app.services.background.drain()
            let code = try XCTUnwrap(mail.lastCode(to: owner.email))
            clock.advance(offset)
            let reply = try await signIn(owner.email, code)
            XCTAssertEqual(reply.status, expected, "at +\(offset)")
            if expected != .created { XCTAssertEqual(reply.errorCode, "CODE_EXPIRED") }
            if expected == .created {
                let again = try await signIn(owner.email, code)
                XCTAssertEqual(again.errorCode, "CODE_INVALID", "a code is used once")
                XCTAssertEqual(reply.json["account"] as? [String: String], ["name": "Chu Mau", "role": "owner"])
            }
        }
        let sessions = try await count("SELECT count(*)::int AS n FROM device_session WHERE account_id = \(bind: owner.id)")
        XCTAssertEqual(sessions, 1)
    }

    func testFiveWrongEntriesVoidTheCodeAndANewOneWorksAtOnce() async throws {
        let staff = try await addAccount(.staff)
        _ = try await requestCode(staff.email)
        await app.services.background.drain()
        let code = try XCTUnwrap(mail.lastCode(to: staff.email))
        let wrong = code == "000000" ? "111111" : "000000"
        for attempt in 1...4 {
            let reply = try await signIn(staff.email, wrong)
            XCTAssertEqual(reply.errorCode, "CODE_INVALID", "entry \(attempt)")
        }
        let fifth = try await signIn(staff.email, wrong)
        XCTAssertEqual(fifth.errorCode, "CODE_EXPIRED")
        let right = try await signIn(staff.email, code)
        XCTAssertEqual(right.errorCode, "CODE_EXPIRED", "the right digits of a void code are refused")
        clock.advance(30)
        _ = try await requestCode(staff.email)
        await app.services.background.drain()
        let fresh = try await signIn(staff.email, try XCTUnwrap(mail.lastCode(to: staff.email)))
        XCTAssertEqual(fresh.status, .created, "no lock on the address")
    }

    func testUnregisteredAddressFollowsTheSameWrongEntryRules() async throws {
        let ghost = "khong.co\(UUID().uuidString.prefix(6).lowercased())@example.com"
        let before = try await signIn(ghost, "123456")
        XCTAssertEqual(before.errorCode, "CODE_INVALID", "no code requested yet")
        _ = try await requestCode(ghost)
        var codes: [String?] = []
        for _ in 1...5 { codes.append(try await signIn(ghost, "123456").errorCode) }
        XCTAssertEqual(codes, ["CODE_INVALID", "CODE_INVALID", "CODE_INVALID", "CODE_INVALID", "CODE_EXPIRED"])
    }

    func testCodeForOneAddressIsNotUsableWithAnother() async throws {
        let a = try await addAccount(.staff, "Nhan Vien A"), b = try await addAccount(.staff, "Nhan Vien B")
        _ = try await requestCode(a.email)
        await app.services.background.drain()
        let code = try XCTUnwrap(mail.lastCode(to: a.email))
        let reply = try await signIn(b.email, code)
        XCTAssertEqual(reply.errorCode, "CODE_INVALID")
        let wrongA = try await count("SELECT coalesce(max(wrong_count), 0)::int AS n FROM auth_code WHERE email = \(bind: a.email)")
        XCTAssertEqual(wrongA, 0)
        let ok = try await signIn(a.email, code)
        XCTAssertEqual(ok.status, .created)
    }

    func testMalformedCodesAreValidationErrorsAndNotCounted() async throws {
        let staff = try await addAccount(.staff)
        _ = try await requestCode(staff.email)
        for bad in ["12345", "1234567", "abcdef", "", " 123456", "1' OR 1=1"] {
            let reply = try await signIn(staff.email, bad)
            XCTAssertEqual(reply.status, .unprocessableEntity, bad)
            XCTAssertEqual(reply.errorCode, "VALIDATION_FAILED", bad)
        }
        let wrong = try await count("SELECT max(wrong_count)::int AS n FROM auth_code WHERE email = \(bind: staff.email)")
        XCTAssertEqual(wrong, 0)
    }

    func testAddressValidation() async throws {
        for bad in ["", "a", "a@b", "a b@example.com", "a@@example.com", String(repeating: "a", count: 250) + "@b.co"] {
            let reply = try await requestCode(bad)
            XCTAssertEqual(reply.errorCode, "VALIDATION_FAILED", bad)
            let fields = (reply.json["error"] as? [String: Any])?["fields"] as? [[String: String]]
            XCTAssertEqual(fields?.first?["field"], "email")
        }
        let padded = try await addAccount(.staff)
        let spaced = try await requestCode("  \(padded.email.uppercased()) ")
        XCTAssertEqual(spaced.status, .accepted)
        await app.services.background.drain()
        XCTAssertNotNil(mail.lastCode(to: padded.email))
    }

    func testMailFailureNeverChangesTheAnswer() async throws {
        let staff = try await addAccount(.staff)
        mail.failNext()
        let reply = try await requestCode(staff.email)
        await app.services.background.drain()
        XCTAssertEqual(reply.status, .accepted)
        XCTAssertTrue(mail.sent.isEmpty)
        XCTAssertEqual(mail.attempts, 2, "one try and one retry")
    }

    func testOnlyHashesAreStored() async throws {
        let owner = try await addAccount(.owner)
        let phone = try await signedIn(owner.email)
        for token in [phone.access, phone.refresh] {
            let found = try await count("SELECT count(*)::int AS n FROM device_session s WHERE s::text LIKE '%' || \(bind: token) || '%'")
            XCTAssertEqual(found, 0)
        }
        let lengths = try await count("SELECT count(*)::int AS n FROM auth_code WHERE email = \(bind: owner.email) AND octet_length(code_hmac) = 32")
        XCTAssertEqual(lengths, 1)
    }
}
