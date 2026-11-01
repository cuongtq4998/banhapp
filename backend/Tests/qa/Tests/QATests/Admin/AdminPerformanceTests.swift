import XCTest
import Vapor
import FluentSQL
@testable import AppUnderTest

/// TC-B105, TC-B106: about 9,000 orders (100 a day for 90 days) plus 200 open orders older than the window.
/// Targets: list page p95 at most 500 ms (architecture 07/08, PRD allows 1 s); status change p95 at most 1 s.
final class AdminPerformanceTests: AdminQABase {
    override var useRealClock: Bool { true } // the 90 day window compares created_at with the app clock
    private var phone = QAPhone(access: "", refresh: "", deviceID: "")
    private let alphabet = "23456789ABCDEFGHJKMNPQRSTUVWXYZ"

    private func bulk(count: Int, status: String, daysAgoModulo: Int, olderThan: Int, offset: Int, reason: String?) async throws {
        let base = Int.random(in: 0..<800_000_000) + offset
        let digits = (0..<6).map { "substr('\(alphabet)', ((s.i + \(base)) / \(Int(pow(31.0, Double($0)))) % 31)::int + 1, 1)" }.joined(separator: " || ")
        let query = """
            INSERT INTO customer_order (id, shop_id, order_code, status, cancel_reason, delivery_date, slot_id, slot_start_time, slot_end_time,
                district_id, district_name, delivery_fee_vnd, items_subtotal_vnd, total_vnd, total_cakes, customer_name, customer_phone,
                customer_address, note, idempotency_key, request_hash, client_platform, app_version, created_at)
            SELECT gen_random_uuid(), '\(shopID.uuidString)', 'BT-' || \(digits), '\(status)', \(reason.map { "'\($0)'" } ?? "NULL"),
                (now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date - (\(olderThan) + s.i % \(daysAgoModulo)), '\(slotID.uuidString)', '08:00', '10:00',
                '\(districtID.uuidString)', 'QA district', 20000, 100000, 120000, 2, 'Tran Thi ' || (s.i % 500), '+8490' || lpad((s.i % 10000000)::text, 7, '0'),
                '1 QA Street', 'note', gen_random_uuid(), repeat('a', 64), 'ios', '1.0.0',
                now() - ((\(olderThan) + s.i % \(daysAgoModulo)) || ' days')::interval + ((s.i % 86400) || ' seconds')::interval
            FROM generate_series(1, \(count)) AS s(i)
            """
        try await run(SQLQueryString(query))
    }

    override func setUp() async throws {
        try await super.setUp()
        try await bulk(count: 4_500, status: "Completed", daysAgoModulo: 85, olderThan: 0, offset: 0, reason: nil)
        try await bulk(count: 3_500, status: "Cancelled", daysAgoModulo: 85, olderThan: 0, offset: 10_000, reason: "customer_asked")
        try await bulk(count: 800, status: "New", daysAgoModulo: 20, olderThan: 0, offset: 20_000, reason: nil)
        try await bulk(count: 200, status: "Confirmed", daysAgoModulo: 60, olderThan: 95, offset: 30_000, reason: nil) // open, older than 90 days
        try await run(SQLQueryString("INSERT INTO customer_order_item (order_id, product_id, product_name, unit_price_vnd, quantity, line_total_vnd) SELECT id, '\(productID.uuidString)', 'QA cake', 50000, 2, 100000 FROM customer_order WHERE shop_id = '\(shopID.uuidString)'"))
        try await run("ANALYZE customer_order")
        phone = try await owner()
    }

    private func percentile95(_ query: String, runs: Int = 40, expect: Int = 200) async throws -> (p95: Double, bytes: Int) {
        var times: [Double] = [], bytes = 0
        for _ in 0..<runs {
            let started = Date()
            let reply = try await client.send("GET", query, token: phone.access)
            times.append(Date().timeIntervalSince(started))
            XCTAssertEqual(reply.status, expect, "\(query): \(reply.text.prefix(200))")
            bytes = max(bytes, reply.data.count)
        }
        times.sort()
        return (times[Int(Double(times.count) * 0.95) - 1], bytes)
    }

    func testTCB105_ListSearchAndDetailStayUnderTheTargetsWithNineThousandOrders() async throws {
        let total = try await count("SELECT count(*)::int AS n FROM customer_order WHERE shop_id = \(bind: shopID)")
        XCTAssertEqual(total, 9_000)
        let probes = ["v1/admin/orders", "v1/admin/orders?status=all", "v1/admin/orders?status=Completed", "v1/admin/orders?q=Tran%20Thi%20123",
                      "v1/admin/orders?q=0900000", "v1/admin/orders?q=BT-AB", "v1/admin/orders?status=all&q=zzz", "v1/admin/orders?date_preset=today"]
        var report: [String] = []
        for probe in probes {
            let result = try await percentile95(probe)
            report.append("\(probe) p95 \(Int(result.p95 * 1000)) ms, \(result.bytes) bytes")
            XCTAssertLessThan(result.p95, 0.5, "\(probe) p95 \(result.p95) s (target 0.5 s)")
            XCTAssertLessThan(result.bytes, 60_000, "page size of \(probe)")
        }
        let first = try await client.send("GET", "v1/admin/orders", token: phone.access)
        let code = ((first.json["items"] as? [[String: Any]])?.first?["order_code"] as? String) ?? ""
        let detail = try await percentile95("v1/admin/orders/\(code)")
        report.append("detail p95 \(Int(detail.p95 * 1000)) ms")
        XCTAssertLessThan(detail.p95, 0.5)
        let count = first.json["unfinished_count"] as? Int ?? -1
        XCTAssertEqual(count, 1_000, "badge: 800 New + 200 old Confirmed, all due today or earlier")
        print("QA-PERF " + report.joined(separator: " | "))
    }

    func testTCB105b_StatusChangeP95AndOldOpenOrdersAreStillInTheDefaultList() async throws {
        let rows = try await sql.raw("SELECT order_code FROM customer_order WHERE shop_id = \(bind: shopID) AND status = 'New' ORDER BY created_at LIMIT 30").all()
        let codes = try rows.map { try $0.decode(column: "order_code", as: String.self) }
        var times: [Double] = []
        for code in codes {
            let started = Date()
            let reply = try await changeStatus(phone, code, from: "New", to: "Confirmed")
            times.append(Date().timeIntervalSince(started))
            XCTAssertEqual(reply.status, 200, reply.text)
        }
        times.sort()
        let p95 = times[Int(Double(times.count) * 0.95) - 1]
        print("QA-PERF status change p95 \(Int(p95 * 1000)) ms over \(times.count)")
        XCTAssertLessThan(p95, 1.0)
        // 200 open orders older than 90 days are on the list (BR-9: open orders of any age) and page through without gaps.
        var seen = Set<String>(), cursor: String? = nil, pages = 0
        repeat {
            let suffix = cursor.map { "?cursor=" + ($0.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? $0) } ?? ""
            let reply = try await client.send("GET", "v1/admin/orders" + suffix, token: phone.access)
            XCTAssertEqual(reply.status, 200)
            let items = reply.json["items"] as? [[String: Any]] ?? []
            for item in items { XCTAssertTrue(seen.insert(item["order_code"] as? String ?? "").inserted, "duplicate row across pages") }
            cursor = reply.json["next_cursor"] as? String
            pages += 1
        } while cursor != nil && pages < 40
        XCTAssertEqual(seen.count, 1_000, "all open orders (800 New or confirmed now, 200 old Confirmed) in \(pages) pages")
    }

    /// TC-B106: the plan of the default list query on 9,000 rows (a copy of the service SQL, kept simple).
    func testTCB106_DefaultListQueryPlanUsesAnIndex() async throws {
        let rows = try await sql.raw(SQLQueryString("""
            EXPLAIN (ANALYZE, FORMAT TEXT) SELECT id FROM customer_order WHERE shop_id = '\(shopID.uuidString)' AND is_demo = false
            AND status IN ('New', 'Confirmed') ORDER BY delivery_date, slot_start_time, created_at, id LIMIT 51
            """)).all()
        let plan = try rows.map { try $0.decode(column: "QUERY PLAN", as: String.self) }.joined(separator: "\n")
        print("QA-PLAN\n" + plan)
        XCTAssertFalse(plan.contains("Seq Scan on customer_order"), "full scan of customer_order:\n" + plan)
    }
}
