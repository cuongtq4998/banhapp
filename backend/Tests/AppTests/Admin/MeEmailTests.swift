import XCTVapor
@testable import App

/// `GET /v1/admin/me` hands back the caller's own address, and only that one.
final class MeEmailTests: AdminDatabaseTestCase {
    private func account(_ reply: Reply) -> [String: String] { reply.json["account"] as? [String: String] ?? [:] }

    func testStaffAndOwnerGetTheirOwnAddress() async throws {
        let staff = try await addAccount(.staff, "Nhan Vien A"), owner = try await addAccount(.owner, "Chu Mau")
        let staffPhone = try await signedIn(staff.email), ownerPhone = try await signedIn(owner.email)
        let staffMe = try await authed(.GET, "v1/admin/me", staffPhone.access)
        let ownerMe = try await authed(.GET, "v1/admin/me", ownerPhone.access)
        XCTAssertEqual(staffMe.status, .ok)
        XCTAssertEqual(account(staffMe), ["name": "Nhan Vien A", "role": "staff", "email": staff.email])
        XCTAssertEqual(account(ownerMe), ["name": "Chu Mau", "role": "owner", "email": owner.email])
        XCTAssertEqual(staffMe.headers.first(name: .cacheControl), "no-store")
    }

    func testNoOtherAccountsAddressAppears() async throws {
        let staff = try await addAccount(.staff, "Nhan Vien A"), other = try await addAccount(.staff, "Nhan Vien B")
        let owner = try await addAccount(.owner, "Chu Mau")
        let phone = try await signedIn(staff.email)
        let body = String(decoding: try await authed(.GET, "v1/admin/me", phone.access).data, as: UTF8.self)
        XCTAssertTrue(body.contains(staff.email))
        XCTAssertFalse(body.contains(other.email))
        XCTAssertFalse(body.contains(owner.email))
    }
}
