import XCTVapor
@testable import App

/// PUT /v1/owner/settings/shop (api/07 10.14; FR-24, BR-3, BR-11).
final class OwnerShopSettingsTests: OwnerSettingsTestCase {
    private let valid = #"{"name":"Tiem Banh","greeting":"Xin chao","phone_contact":"+84911111111","zalo_contact":"zalo.me/tiem"}"#

    func testSaveReturnsTheSectionAndRecordsEachChangedField() async throws {
        let reply = try await call(.PUT, "v1/owner/settings/shop", valid)
        XCTAssertEqual(reply.status, .ok)
        XCTAssertEqual(reply.json["name"] as? String, "Tiem Banh")
        XCTAssertEqual(reply.json["phone_contact"] as? String, "+84911111111")
        let stored = try await call(.GET, "v1/owner/settings")
        XCTAssertEqual((stored.json["shop"] as? [String: String])?["greeting"], "Xin chao")
        let rows = try await changeRows("shop")
        XCTAssertEqual(rows, 4)
        let named = try await changeCount(field: "name", old: "Test", new: "Tiem Banh")
        XCTAssertEqual(named, 1)
        let actor = try await count("SELECT count(*)::int AS n FROM settings_change WHERE shop_id = \(bind: shopID) AND actor_name = 'Chu Mau' AND actor_account_id IS NOT NULL")
        XCTAssertEqual(actor, 4)
        let batches = try await count("SELECT count(DISTINCT batch_id)::int AS n FROM settings_change WHERE shop_id = \(bind: shopID)")
        XCTAssertEqual(batches, 1)
    }

    func testUnchangedFieldsAreNotRecorded() async throws {
        _ = try await call(.PUT, "v1/owner/settings/shop", valid)
        _ = try await call(.PUT, "v1/owner/settings/shop", valid.replacingOccurrences(of: "Tiem Banh", with: "Tiem Banh 2"))
        let rows = try await changeRows("shop")
        XCTAssertEqual(rows, 5)
    }

    func testEveryProblemIsListedAndNothingChanges() async throws {
        let long = String(repeating: "x", count: 301)
        let reply = try await call(.PUT, "v1/owner/settings/shop", #"{"name":"  ","greeting":"\#(long)","phone_contact":"0911111111","zalo_contact":"ab"}"#)
        XCTAssertEqual(reply.status, .unprocessableEntity)
        XCTAssertEqual(reply.errorCode, "VALIDATION_FAILED")
        XCTAssertEqual(problems(reply), ["NAME_REQUIRED", "GREETING_TOO_LONG", "PHONE_CONTACT_INVALID", "ZALO_CONTACT_INVALID"])
        let keys = ((reply.json["error"] as? [String: Any])?["fields"] as? [[String: Any]] ?? []).compactMap { $0["message_key"] as? String }
        XCTAssertEqual(keys, ["ERR_FIELD_REQUIRED", "ERR_FIELD_TOO_LONG", "ERR_FIELD_INVALID", "ERR_FIELD_INVALID"])
        let rows = try await changeRows("shop")
        XCTAssertEqual(rows, 0)
        let name = try await count("SELECT count(*)::int AS n FROM shop WHERE id = \(bind: shopID) AND name = 'Test'")
        XCTAssertEqual(name, 1)
    }

    func testMissingFieldsAndUnknownFieldsAreProblems() async throws {
        let reply = try await call(.PUT, "v1/owner/settings/shop", #"{"name":"A","extra":1}"#)
        XCTAssertEqual(problems(reply), ["FIELD_UNKNOWN", "GREETING_REQUIRED", "PHONE_CONTACT_REQUIRED", "ZALO_CONTACT_REQUIRED"])
        let notObject = try await call(.PUT, "v1/owner/settings/shop", "[1]")
        XCTAssertEqual(notObject.errorCode, "VALIDATION_FAILED")
    }

    func testTheCustomerCatalogShowsTheNewShopTextAtOnce() async throws {
        _ = try await call(.PUT, "v1/owner/settings/shop", valid)
        let catalog = try await send(.GET, "v1/catalog")
        XCTAssertEqual((catalog.json["shop"] as? [String: Any])?["name"] as? String, "Tiem Banh")
    }
}
