import XCTVapor
import Fluent
import FluentSQL
import Foundation
@testable import App

/// Shared setup of the owner endpoint tests: real routes over a real database,
/// one shop with settings (limit 30, lead 2, minimum 2), a district, a slot and
/// a cake, and a signed-in owner phone. Dates follow the controlled clock.
class OwnerSettingsTestCase: AdminDatabaseTestCase {
    var districtID = UUID()
    var slotID = UUID()
    var ownerPhone: Phone!

    override func setUp() async throws {
        try await super.setUp()
        try await run("INSERT INTO shop_setting (shop_id, daily_limit, lead_days, min_qty, max_days_ahead) VALUES (\(bind: shopID), 30, 2, 2, 30)")
        try await run("INSERT INTO district (id, shop_id, name, delivery_fee_vnd, sort_order) VALUES (\(bind: districtID), \(bind: shopID), 'Quan An Phu', 20000, 1)")
        try await run("INSERT INTO delivery_slot (id, shop_id, start_time, end_time, sort_order) VALUES (\(bind: slotID), \(bind: shopID), '08:00', '10:00', 1)")
        try await run("INSERT INTO product (shop_id, slug, name, description, price_vnd, image_path) VALUES (\(bind: shopID), 'banh', 'Banh Mau', 'Mo ta', 50000, 'images/banana.png')")
        ownerPhone = try await signedIn(try await addAccount(.owner, "Chu Mau").email)
    }

    /// A JSON request from `phone` (the owner by default) with a raw body.
    func call(_ method: HTTPMethod, _ path: String, _ json: String? = nil, as phone: Phone? = nil) async throws -> Reply {
        try await Self.call(app, method, path, json, access: (phone ?? ownerPhone).access)
    }

    /// Static so parallel tasks can call it without capturing the test case.
    static func call(_ app: Application, _ method: HTTPMethod, _ path: String, _ json: String?, access: String) async throws -> Reply {
        let box = LockedBox<Reply?>(nil)
        let headers: HTTPHeaders = ["Authorization": "Bearer \(access)", "X-Platform": "ios", "X-App-Version": "1.0.0", "Content-Type": "application/json"]
        try await app.test(method, path, headers: headers, body: json.map { ByteBuffer(string: $0) }, afterResponse: { res async throws in
            box.set(Reply(status: res.status, headers: res.headers, data: Data(res.body.readableBytesView)))
        })
        return try XCTUnwrap(box.value)
    }

    func changeRows(_ entity: String) async throws -> Int {
        try await count("SELECT count(*)::int AS n FROM settings_change WHERE shop_id = \(bind: shopID) AND entity_type = \(bind: entity)")
    }

    func changeCount(field: String, old: String?, new: String?) async throws -> Int {
        try await count("""
            SELECT count(*)::int AS n FROM settings_change
            WHERE shop_id = \(bind: shopID) AND field = \(bind: field) AND old_value IS NOT DISTINCT FROM \(bind: old) AND new_value IS NOT DISTINCT FROM \(bind: new)
            """)
    }

    func problems(_ reply: Reply) -> [String] {
        ((reply.json["error"] as? [String: Any])?["fields"] as? [[String: Any]] ?? []).compactMap { $0["code"] as? String }
    }

    func list(_ key: String, in reply: Reply) -> [[String: Any]] { reply.json[key] as? [[String: Any]] ?? [] }

    func day(_ offset: Int) -> String { app.services.calendar.adding(days: offset, to: app.services.calendar.today()).description }

    func addLoad(_ date: String, _ cakes: Int) async throws {
        try await run("""
            INSERT INTO day_load (shop_id, delivery_date, cakes_accepted, capacity_limit) VALUES (\(bind: shopID), \(bind: date)::date, \(literal: cakes), 100)
            """)
    }
}
