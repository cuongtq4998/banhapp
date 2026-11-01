import XCTVapor
import BanhContracts
@testable import App

/// The shared owner fixtures (`contracts/fixtures/admin/`) against the real answers.
final class OwnerSettingsFixtureTests: OwnerSettingsTestCase {
    private func shape(_ reply: Reply) -> NSDictionary { AdminFixtures.shape(reply.json) as? NSDictionary ?? [:] }

    private func envelope(_ reply: Reply) throws -> APIErrorResponse.Body {
        try JSONDecoder().decode(APIErrorResponse.self, from: reply.data).error
    }

    private func expectShape(_ reply: Reply, _ fixture: String, file: StaticString = #filePath, line: UInt = #line) throws {
        XCTAssertEqual(shape(reply), try AdminFixtures.bodyShape(fixture), fixture, file: file, line: line)
    }

    func testSuccessBodiesHaveTheFixtureShape() async throws {
        try await addLoad(day(5), 98)
        try expectShape(try await call(.GET, "v1/owner/settings"), "owner-settings")
        try expectShape(try await call(.PUT, "v1/owner/settings/shop", #"{"name":"A","greeting":"B","phone_contact":"+84911111111","zalo_contact":"zalo"}"#), "owner-shop-saved")
        try expectShape(try await call(.PUT, "v1/owner/settings/ordering", #"{"daily_limit":60,"lead_days":2,"min_qty":2}"#), "owner-ordering-saved")
        try expectShape(try await call(.GET, "v1/owner/settings/ordering/impact?daily_limit=60"), "owner-ordering-impact")
        try expectShape(try await call(.POST, "v1/owner/districts", #"{"name":"Quan B","delivery_fee_vnd":20000}"#), "owner-district-created")
        try expectShape(try await call(.POST, "v1/owner/slots", #"{"start":"13:00","end":"15:00"}"#), "owner-slot-created")
        let created = try await call(.POST, "v1/owner/staff", #"{"name":"Nhan Vien A","email":"a.\#(UUID().uuidString.prefix(6).lowercased())@example.com"}"#)
        try expectShape(created, "owner-staff-created")
        try expectShape(try await call(.GET, "v1/owner/staff"), "owner-staff-list")
        let item = (try await call(.GET, "v1/owner/staff")).json["accounts"] as? [Any]
        XCTAssertEqual(AdminFixtures.shape(item?.first ?? [:]) as? NSDictionary, AdminFixtures.shape(try listItem("owner-staff-list")) as? NSDictionary)
        try expectShape(try await call(.PATCH, "v1/owner/staff/\(created.string("account_id"))", #"{"is_active":false}"#), "owner-staff-deactivated")
    }

    private func listItem(_ fixture: String) throws -> Any {
        let body = (try JSONSerialization.jsonObject(with: AdminFixtures.load(fixture)) as? [String: Any])?["body"] as? [String: Any]
        return (body?["accounts"] as? [Any])?.first ?? [:]
    }

    func testErrorsMatchTheFixtures() async throws {
        let long = String(repeating: "x", count: 301)
        let settings = try await call(.PUT, "v1/owner/settings/shop", #"{"name":"","greeting":"\#(long)","phone_contact":"0911111111","zalo_contact":"zalo"}"#)
        XCTAssertEqual(try envelope(settings), try AdminFixtures.error("settings-validation"))
        let staff = try await call(.POST, "v1/owner/staff", #"{"name":"","email":"no-at"}"#)
        XCTAssertEqual(try envelope(staff), try AdminFixtures.error("staff-validation"))
        let district = try await call(.PATCH, "v1/owner/districts/\(districtID)", #"{"is_active":false}"#)
        XCTAssertEqual(try envelope(district), try AdminFixtures.error("last-active-district"))
        let slotOff = try await call(.PATCH, "v1/owner/slots/\(slotID)", #"{"is_active":false}"#)
        XCTAssertEqual(try envelope(slotOff), try AdminFixtures.error("last-active-slot"))
        let twin = try await call(.POST, "v1/owner/slots", #"{"start":"08:00","end":"10:00"}"#)
        XCTAssertEqual(try envelope(twin), try AdminFixtures.error("slot-duplicate"))
        _ = try await call(.POST, "v1/owner/staff", #"{"name":"A","email":"dup@example.com"}"#)
        let taken = try await call(.POST, "v1/owner/staff", #"{"name":"A","email":"dup@example.com"}"#)
        XCTAssertEqual(try envelope(taken), try AdminFixtures.error("email-taken"))
        let protected = try await call(.PATCH, "v1/owner/staff/\(try await ownerID())", #"{"is_active":false}"#)
        XCTAssertEqual(try envelope(protected), try AdminFixtures.error("owner-protected"))
    }

    func testStaffLimitMatchesItsFixture() async throws {
        for index in 0..<30 {
            try await run("INSERT INTO account (shop_id, role, email, display_name) VALUES (\(bind: shopID), 'staff', \(bind: "f\(index).\(UUID().uuidString.prefix(6).lowercased())@example.com"), 'F')")
        }
        let refused = try await call(.POST, "v1/owner/staff", #"{"name":"A","email":"late@example.com"}"#)
        XCTAssertEqual(try envelope(refused), try AdminFixtures.error("staff-limit-reached"))
    }

    private func ownerID() async throws -> UUID {
        let row = try await sql.raw("SELECT id FROM account WHERE shop_id = \(bind: shopID) AND role = 'owner'").first()
        return try XCTUnwrap(row).decode(column: "id", as: UUID.self)
    }
}
