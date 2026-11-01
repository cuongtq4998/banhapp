import XCTVapor
@testable import App

/// GET /v1/owner/settings (api/07 10.13) and the owner-only rule (BR-1).
final class OwnerSettingsReadTests: OwnerSettingsTestCase {
    func testOverviewListsEverySectionAndTheLimits() async throws {
        let reply = try await call(.GET, "v1/owner/settings")
        XCTAssertEqual(reply.status, .ok)
        XCTAssertEqual(reply.json["shop"] as? [String: String], [
            "name": "Test", "greeting": "Hi", "phone_contact": "+84900000000", "zalo_contact": "zalo"])
        let ordering = try XCTUnwrap(reply.json["ordering"] as? [String: Int])
        XCTAssertEqual(ordering, ["daily_limit": 30, "lead_days": 2, "min_qty": 2, "max_days_ahead": 30])
        let cakes = list("cakes", in: reply)
        XCTAssertEqual(cakes.count, 1)
        XCTAssertEqual(cakes.first?["name"] as? String, "Banh Mau")
        XCTAssertEqual(cakes.first?["price_vnd"] as? Int, 50_000)
        XCTAssertEqual(cakes.first?["is_active"] as? Bool, true)
        XCTAssertTrue((cakes.first?["image_url"] as? String ?? "").contains("/assets/images/banana.png"))
        XCTAssertEqual(list("districts", in: reply).first?["delivery_fee_vnd"] as? Int, 20_000)
        XCTAssertEqual(list("slots", in: reply).first?["start"] as? String, "08:00")
        XCTAssertEqual(reply.json["cake_count_max"] as? Int, 12)
        XCTAssertEqual(reply.json["staff_count_max"] as? Int, 30)
        XCTAssertEqual(reply.headers.first(name: .cacheControl), "no-store")
    }

    func testSlotsAreSortedByTime() async throws {
        for (start, end) in [("14:00", "16:00"), ("06:00", "07:00")] {
            try await run("INSERT INTO delivery_slot (shop_id, start_time, end_time) VALUES (\(bind: shopID), \(bind: start)::time, \(bind: end)::time)")
        }
        let starts = list("slots", in: try await call(.GET, "v1/owner/settings")).compactMap { $0["start"] as? String }
        XCTAssertEqual(starts, ["06:00", "08:00", "14:00"])
    }

    func testStaffAndSignedOutCallersAreRefusedOnEveryOwnerRoute() async throws {
        let staff = try await signedIn(try await addAccount(.staff).email)
        let routes: [(HTTPMethod, String)] = [
            (.GET, "v1/owner/settings"), (.PUT, "v1/owner/settings/shop"), (.GET, "v1/owner/settings/ordering"),
            (.PUT, "v1/owner/settings/ordering"), (.GET, "v1/owner/settings/ordering/impact?daily_limit=5"),
            (.POST, "v1/owner/districts"), (.PATCH, "v1/owner/districts/\(districtID)"),
            (.POST, "v1/owner/slots"), (.PATCH, "v1/owner/slots/\(slotID)"),
            (.GET, "v1/owner/staff"), (.POST, "v1/owner/staff"), (.PATCH, "v1/owner/staff/\(UUID())")
        ]
        for (method, path) in routes {
            let reply = try await call(method, path, "{}", as: staff)
            XCTAssertEqual(reply.status, .forbidden, "\(method) \(path)")
            XCTAssertEqual(reply.errorCode, "FORBIDDEN")
            let anonymous = try await send(method, path)
            XCTAssertEqual(anonymous.status, .unauthorized, "\(method) \(path)")
        }
        let written = try await count("SELECT count(*)::int AS n FROM settings_change WHERE shop_id = \(bind: shopID)")
        XCTAssertEqual(written, 0)
    }
}
