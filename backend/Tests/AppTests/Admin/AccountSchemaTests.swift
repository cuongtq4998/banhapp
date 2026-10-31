import XCTVapor
import Fluent
import FluentSQL
@testable import App

/// Operator command and the schema rules of migration 0002.
final class AccountSchemaTests: AdminDatabaseTestCase {
    private func createOwner(_ email: String, name: String? = nil) async throws {
        try await CreateOwnerCommand.create(on: app.db, shopID: shopID, email: email, name: name)
    }

    func testCreateOwnerThenTheOwnerCanSignIn() async throws {
        let email = "chu.mau\(UUID().uuidString.prefix(6).lowercased())@example.com"
        try await createOwner("  \(email.uppercased()) ", name: "Chu Mau")
        let phone = try await signedIn(email)
        let me = try await authed(.GET, "v1/admin/me", phone.access)
        XCTAssertEqual((me.json["account"] as? [String: String]), ["name": "Chu Mau", "role": "owner"])
    }

    func testCreateOwnerRefusesASecondOwnerBadAddressAndBadName() async throws {
        try await createOwner("first\(UUID().uuidString.prefix(6).lowercased())@example.com")
        do { try await createOwner("second\(UUID().uuidString.prefix(6).lowercased())@example.com"); XCTFail("second owner") }
        catch { XCTAssertEqual(error as? CreateOwnerError, .alreadyExists) }
        let other = try await shopWithoutOwner()
        for bad in ["", "no-at", "a@b"] {
            do { try await CreateOwnerCommand.create(on: app.db, shopID: other, email: bad, name: nil); XCTFail(bad) }
            catch { XCTAssertTrue("\(error)".contains("--email"), "\(error)"); XCTAssertFalse("\(error)".contains("no-at")) }
        }
        do { try await CreateOwnerCommand.create(on: app.db, shopID: other, email: "x@example.com", name: String(repeating: "n", count: 101)); XCTFail("name") }
        catch { XCTAssertEqual(error as? CreateOwnerError, .nameInvalid) }
        try await CreateOwnerCommand.create(on: app.db, shopID: other, email: "x@example.com", name: nil)
        let name = try await count("SELECT count(*)::int AS n FROM account WHERE shop_id = \(bind: other) AND display_name = 'Owner'")
        XCTAssertEqual(name, 1)
    }

    private func shopWithoutOwner() async throws -> UUID {
        let id = UUID()
        try await run("INSERT INTO shop (id, name, greeting, phone_contact, zalo_contact) VALUES (\(bind: id), 'Other', 'Hi', '+84900000000', 'zalo')")
        return id
    }

    func testDatabaseHoldsOneOwnerAndAUniqueAddressPerShop() async throws {
        let owner = try await addAccount(.owner)
        await assertRejected("INSERT INTO account (shop_id, role, email, display_name) VALUES (\(bind: shopID), 'owner', 'second@example.com', 'X')")
        await assertRejected("INSERT INTO account (shop_id, role, email, display_name) VALUES (\(bind: shopID), 'staff', \(bind: owner.email), 'X')")
        await assertRejected("UPDATE account SET is_active = false WHERE id = \(bind: owner.id)")
    }

    func testThirtyFirstActiveStaffIsRefusedAndReviewAccountsDoNotCount() async throws {
        try await run("INSERT INTO shop_setting (shop_id, daily_limit) VALUES (\(bind: shopID), 10)")
        for _ in 0..<30 { try await addAccount(.staff) }
        await assertRejected("INSERT INTO account (shop_id, role, email, display_name) VALUES (\(bind: shopID), 'staff', 'one.too.many@example.com', 'X')")
        try await run("INSERT INTO account (shop_id, role, kind, email, display_name) VALUES (\(bind: shopID), 'staff', 'review', 'review@example.com', 'R')")
        let off = try await addAccount(.staff, "Off", active: false).id
        await assertRejected("UPDATE account SET is_active = true WHERE id = \(bind: off)")
    }

    func testSecurityEventsCannotBeChangedOrDeleted() async throws {
        let staff = try await addAccount(.staff)
        _ = try await signedIn(staff.email)
        await assertRejected("UPDATE security_event SET platform = 'ios' WHERE account_id = \(bind: staff.id)")
        await assertRejected("DELETE FROM security_event WHERE account_id = \(bind: staff.id)")
        let columns = try await count("SELECT count(*)::int AS n FROM information_schema.columns WHERE table_name = 'security_event' AND column_name IN ('email', 'code')")
        XCTAssertEqual(columns, 0)
    }

    private func assertRejected(_ query: SQLQueryString, file: StaticString = #filePath, line: UInt = #line) async {
        do { try await run(query); XCTFail("statement was accepted", file: file, line: line) } catch {}
    }
}
