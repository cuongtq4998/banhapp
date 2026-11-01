import XCTVapor
@testable import App

/// Staff accounts (api/07 10.18; FR-5, BR-6, BR-3).
final class OwnerStaffTests: OwnerSettingsTestCase {
    private func add(_ name: String, _ email: String) async throws -> Reply {
        try await call(.POST, "v1/owner/staff", #"{"name":"\#(name)","email":"\#(email)"}"#)
    }

    private func fillStaff(_ count: Int) async throws {
        for index in 0..<count {
            try await run("INSERT INTO account (shop_id, role, email, display_name) VALUES (\(bind: shopID), 'staff', \(bind: "fill\(index)-\(UUID().uuidString.prefix(6).lowercased())@example.com"), \(bind: "Fill \(index)"))")
        }
    }

    func testAddingStaffStoresTheNormalisedAddressAndTheNewPersonCanSignIn() async throws {
        let address = "nv.\(UUID().uuidString.prefix(8).lowercased())@example.com"
        let reply = try await add("Nhan Vien A", "  \(address.uppercased()) ")
        XCTAssertEqual(reply.status, .created)
        XCTAssertEqual(reply.json["email"] as? String, address)
        XCTAssertEqual(reply.json["role"] as? String, "staff")
        XCTAssertEqual(reply.json["is_active"] as? Bool, true)
        let phone = try await signedIn(address)
        let me = try await authed(.GET, "v1/admin/me", phone.access)
        XCTAssertEqual((me.json["account"] as? [String: String])?["role"], "staff")
        let recorded = try await changeCount(field: "is_active", old: nil, new: "true")
        XCTAssertEqual(recorded, 1)
        let leaked = try await count("SELECT count(*)::int AS n FROM settings_change WHERE shop_id = \(bind: shopID) AND (old_value LIKE '%@%' OR new_value LIKE '%@%')")
        XCTAssertEqual(leaked, 0, "an address is never part of the change record")
    }

    func testListShowsTheOwnerFirstThenTheOthers() async throws {
        _ = try await add("Zed", "zed@example.com")
        _ = try await add("Anh", "anh@example.com")
        let reply = try await call(.GET, "v1/owner/staff")
        XCTAssertEqual(reply.status, .ok)
        let accounts = list("accounts", in: reply)
        XCTAssertEqual(accounts.compactMap { $0["name"] as? String }, ["Chu Mau", "Anh", "Zed"])
        XCTAssertEqual(accounts.first?["role"] as? String, "owner")
        XCTAssertEqual(Set(accounts.first?.keys.map { $0 } ?? []), ["account_id", "name", "email", "role", "is_active"])
    }

    func testReviewAccountsAreNeitherListedNorPatched() async throws {
        let id = UUID()
        try await run("INSERT INTO account (id, shop_id, role, kind, email, display_name) VALUES (\(bind: id), \(bind: shopID), 'staff', 'review', 'review@example.com', 'Review')")
        let names = list("accounts", in: try await call(.GET, "v1/owner/staff")).compactMap { $0["name"] as? String }
        XCTAssertEqual(names, ["Chu Mau"])
        let patched = try await call(.PATCH, "v1/owner/staff/\(id)", #"{"is_active":false}"#)
        XCTAssertEqual(patched.status, .notFound)
    }

    func testBadInputListsEveryProblem() async throws {
        let both = try await call(.POST, "v1/owner/staff", #"{"name":"","email":"no-at"}"#)
        XCTAssertEqual(both.status, .unprocessableEntity)
        XCTAssertEqual(both.errorCode, "VALIDATION_FAILED")
        XCTAssertEqual(problems(both), ["NAME_REQUIRED", "EMAIL_INVALID"])
        let missing = try await call(.POST, "v1/owner/staff", "{}")
        XCTAssertEqual(problems(missing), ["NAME_REQUIRED", "EMAIL_REQUIRED"])
        let wrongType = try await call(.POST, "v1/owner/staff", #"{"name":"A","email":5}"#)
        XCTAssertEqual(problems(wrongType), ["EMAIL_INVALID"])
        let long = try await add(String(repeating: "n", count: 101), "ok@example.com")
        XCTAssertEqual(problems(long), ["NAME_TOO_LONG"])
        let rows = try await changeRows("account")
        XCTAssertEqual(rows, 0)
    }

    func testAnAddressAlreadyUsedIsRefusedWhateverTheLetterCase() async throws {
        _ = try await add("A", "same@example.com")
        let again = try await add("B", "SAME@example.com")
        XCTAssertEqual(again.status, .conflict)
        XCTAssertEqual(again.errorCode, "EMAIL_TAKEN")
        let accounts = try await count("SELECT count(*)::int AS n FROM account WHERE shop_id = \(bind: shopID) AND email = 'same@example.com'")
        XCTAssertEqual(accounts, 1)
        try await run("UPDATE account SET email = 'owner@example.com' WHERE role = 'owner' AND shop_id = \(bind: shopID)")
        let ownerAddress = try await add("C", "Owner@Example.com")
        XCTAssertEqual(ownerAddress.errorCode, "EMAIL_TAKEN")
    }

    func testThirtyOneActiveStaffAreRefusedAndDeactivatedOnesDoNotCount() async throws {
        try await fillStaff(29)
        let thirtieth = try await add("Thirtieth", "t30@example.com")
        XCTAssertEqual(thirtieth.status, .created)
        let refused = try await add("Thirty-first", "t31@example.com")
        XCTAssertEqual(refused.status, .conflict)
        XCTAssertEqual(refused.errorCode, "STAFF_LIMIT_REACHED")
        let off = try await call(.PATCH, "v1/owner/staff/\(thirtieth.string("account_id"))", #"{"is_active":false}"#)
        XCTAssertEqual(off.status, .ok)
        let fits = try await add("Thirty-first", "t31@example.com")
        XCTAssertEqual(fits.status, .created)
        let back = try await call(.PATCH, "v1/owner/staff/\(thirtieth.string("account_id"))", #"{"is_active":true}"#)
        XCTAssertEqual(back.errorCode, "STAFF_LIMIT_REACHED", "reactivation counts too")
    }

    func testTwoAdditionsAtTheLimitLetExactlyOneIn() async throws {
        try await fillStaff(29)
        let access = ownerPhone.access, app = app!
        let replies = try await withThrowingTaskGroup(of: Reply.self) { group in
            for index in 0..<2 {
                group.addTask {
                    try await Self.call(app, .POST, "v1/owner/staff", #"{"name":"Racer \#(index)","email":"racer\#(index)@example.com"}"#, access: access)
                }
            }
            return try await group.reduce(into: []) { $0.append($1) }
        }
        XCTAssertEqual(replies.map(\.status.code).sorted(), [201, 409])
        XCTAssertEqual(replies.compactMap(\.errorCode), ["STAFF_LIMIT_REACHED"])
        let active = try await count("SELECT count(*)::int AS n FROM account WHERE shop_id = \(bind: shopID) AND role = 'staff' AND is_active")
        XCTAssertEqual(active, 30)
    }

    func testTheOwnerCannotBeSwitchedOff() async throws {
        let ownerID = try await ownerAccountID()
        for body in [#"{"is_active":false}"#, #"{"is_active":true}"#] {
            let reply = try await call(.PATCH, "v1/owner/staff/\(ownerID)", body)
            XCTAssertEqual(reply.status, .conflict)
            XCTAssertEqual(reply.errorCode, "OWNER_PROTECTED")
        }
        let me = try await authed(.GET, "v1/admin/me", ownerPhone.access)
        XCTAssertEqual(me.status, .ok)
    }

    func testSwitchingOffEndsEveryPhoneAtOnceAndSwitchingOnLetsThePersonSignInAgain() async throws {
        let account = try await addAccount(.staff, "Nhan Vien B")
        let first = try await signedIn(account.email), second = try await signedIn(account.email)
        try await run("UPDATE device_session SET push_token = 'fake-token', push_apns_environment = 'sandbox' WHERE id = \(bind: first.deviceID)")
        let off = try await call(.PATCH, "v1/owner/staff/\(account.id)", #"{"is_active":false}"#)
        XCTAssertEqual(off.status, .ok)
        XCTAssertEqual(off.json["is_active"] as? Bool, false)
        for phone in [first, second] {
            let me = try await authed(.GET, "v1/admin/me", phone.access)
            XCTAssertEqual(me.status, .unauthorized)
            XCTAssertEqual(me.errorCode, "SESSION_REVOKED")
            let renewed = try await refresh(phone.refresh)
            XCTAssertEqual(renewed.status, .unauthorized, "refresh fails for a deactivated person")
            XCTAssertEqual(renewed.errorCode, "SESSION_REVOKED")
        }
        let ended = try await count("SELECT count(*)::int AS n FROM device_session WHERE account_id = \(bind: account.id) AND revoked_reason = 'account_deactivated' AND push_token IS NULL")
        XCTAssertEqual(ended, 2)
        let lastCode = mail.lastCode(to: account.email)
        let code = try await requestCode(account.email)
        XCTAssertEqual(code.status, .accepted)
        await app.services.background.drain()
        XCTAssertEqual(mail.lastCode(to: account.email), lastCode, "no mail goes to an inactive account")
        let on = try await call(.PATCH, "v1/owner/staff/\(account.id)", #"{"is_active":true}"#)
        XCTAssertEqual(on.json["is_active"] as? Bool, true)
        clock.advance(3_700) // the hourly limit of code requests
        let phone = try await signedIn(account.email)
        let me = try await authed(.GET, "v1/admin/me", phone.access)
        XCTAssertEqual(me.status, .ok)
        let record = try await changeCount(field: "is_active", old: "true", new: "false")
        XCTAssertEqual(record, 1)
    }

    func testRepeatingTheSameChangeAndBadBodiesChangeNothing() async throws {
        let account = try await addAccount(.staff, "Nhan Vien C")
        let same = try await call(.PATCH, "v1/owner/staff/\(account.id)", #"{"is_active":true}"#)
        XCTAssertEqual(same.status, .ok)
        for body in ["{}", #"{"is_active":"no"}"#, #"{"is_active":false,"name":"X"}"#] {
            let reply = try await call(.PATCH, "v1/owner/staff/\(account.id)", body)
            XCTAssertEqual(reply.errorCode, "VALIDATION_FAILED", body)
        }
        let unknown = try await call(.PATCH, "v1/owner/staff/\(UUID())", #"{"is_active":false}"#)
        XCTAssertEqual(unknown.status, .notFound)
        let rows = try await changeRows("account")
        XCTAssertEqual(rows, 0)
    }

    private func ownerAccountID() async throws -> UUID {
        let row = try await sql.raw("SELECT id FROM account WHERE shop_id = \(bind: shopID) AND role = 'owner'").first()
        return try XCTUnwrap(row).decode(column: "id", as: UUID.self)
    }
}
