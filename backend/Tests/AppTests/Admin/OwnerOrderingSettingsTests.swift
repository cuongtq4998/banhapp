import XCTVapor
import FluentSQL
@testable import App

/// Ordering rules and the impact preview (api/07 10.15; FR-22, BR-3, BR-11).
final class OwnerOrderingSettingsTests: OwnerSettingsTestCase {
    private func ordering(_ limit: Int, lead: Int = 2, min: Int = 2) -> String {
        #"{"daily_limit":\#(limit),"lead_days":\#(lead),"min_qty":\#(min)}"#
    }

    func testSaveReturnsTheSectionWithTheListAndRecordsOldAndNewValues() async throws {
        let reply = try await call(.PUT, "v1/owner/settings/ordering", ordering(50, lead: 3, min: 4))
        XCTAssertEqual(reply.status, .ok)
        XCTAssertEqual(reply.json["daily_limit"] as? Int, 50)
        XCTAssertEqual(reply.json["max_days_ahead"] as? Int, 30)
        XCTAssertEqual(reply.json["count"] as? Int, 0)
        XCTAssertEqual((reply.json["over_limit"] as? [Any])?.count, 0)
        let again = try await call(.GET, "v1/owner/settings/ordering")
        XCTAssertEqual(again.json["min_qty"] as? Int, 4)
        XCTAssertNil(again.json["over_limit"])
        for (field, old, new) in [("daily_limit", "30", "50"), ("lead_days", "2", "3"), ("min_qty", "2", "4")] {
            let rows = try await changeCount(field: field, old: old, new: new)
            XCTAssertEqual(rows, 1, field)
        }
    }

    func testLoweringBelowAcceptedCakesSucceedsCancelsNothingAndListsTheDates() async throws {
        try await addLoad(day(5), 40)
        try await addLoad(day(6), 10)
        try await addLoad(day(-1), 90)
        let preview = try await call(.GET, "v1/owner/settings/ordering/impact?daily_limit=20")
        XCTAssertEqual(preview.status, .ok)
        XCTAssertEqual(preview.json["daily_limit"] as? Int, 20)
        XCTAssertEqual(preview.json["count"] as? Int, 1)
        let item = try XCTUnwrap(list("over_limit", in: preview).first)
        XCTAssertEqual(item["date"] as? String, day(5))
        XCTAssertEqual(item["cakes_accepted"] as? Int, 40)
        let untouched = try await changeRows("ordering")
        XCTAssertEqual(untouched, 0, "the preview writes nothing")

        let saved = try await call(.PUT, "v1/owner/settings/ordering", ordering(20))
        XCTAssertEqual(saved.status, .ok)
        XCTAssertEqual(saved.json["count"] as? Int, 1)
        XCTAssertEqual(list("over_limit", in: saved).first?["cakes_accepted"] as? Int, 40)
        let load = try await count("SELECT coalesce(sum(cakes_accepted), 0)::int AS n FROM day_load WHERE shop_id = \(bind: shopID)")
        XCTAssertEqual(load, 140, "no order or load row is touched")
    }

    func testEveryRangeIsChecked() async throws {
        let cases: [(String, [String])] = [
            (ordering(0), ["DAILY_LIMIT_OUT_OF_RANGE"]),
            (ordering(10_000, lead: 15, min: 21), ["DAILY_LIMIT_OUT_OF_RANGE", "LEAD_DAYS_OUT_OF_RANGE", "MIN_QTY_OUT_OF_RANGE"]),
            (ordering(5, min: 6), ["MIN_QTY_OUT_OF_RANGE"]),
            (#"{"daily_limit":"5","lead_days":1.5}"#, ["DAILY_LIMIT_INVALID", "LEAD_DAYS_INVALID", "MIN_QTY_REQUIRED"]),
            ("{}", ["DAILY_LIMIT_REQUIRED", "LEAD_DAYS_REQUIRED", "MIN_QTY_REQUIRED"])
        ]
        for (body, expected) in cases {
            let reply = try await call(.PUT, "v1/owner/settings/ordering", body)
            XCTAssertEqual(reply.status, .unprocessableEntity, body)
            XCTAssertEqual(problems(reply), expected, body)
        }
        _ = try await call(.PUT, "v1/owner/settings/ordering", ordering(9_999, lead: 14, min: 20))
        let edge = try await call(.GET, "v1/owner/settings/ordering")
        XCTAssertEqual(edge.json["daily_limit"] as? Int, 9_999)
        let rows = try await count("SELECT count(*)::int AS n FROM settings_change WHERE shop_id = \(bind: shopID)")
        XCTAssertEqual(rows, 3, "the refusals wrote nothing")
    }

    func testImpactChecksItsParameter() async throws {
        for query in ["", "?daily_limit=abc", "?daily_limit=0", "?daily_limit=10000", "?daily_limit=5&x=1"] {
            let reply = try await call(.GET, "v1/owner/settings/ordering/impact" + query)
            XCTAssertEqual(reply.errorCode, "VALIDATION_FAILED", query)
        }
    }

    func testDatabaseChecksStandBehindTheService() async throws {
        for statement: SQLQueryString in [
            "UPDATE shop_setting SET daily_limit = 10000", "UPDATE shop_setting SET lead_days = 15",
            "UPDATE shop_setting SET min_qty = 21", "UPDATE shop_setting SET daily_limit = 1, min_qty = 2",
            "UPDATE district SET delivery_fee_vnd = 10000001"
        ] {
            do { try await run(statement); XCTFail("accepted: \(statement)") } catch {}
        }
    }

    func testCustomerCatalogAndAvailabilityReadTheChangedRules() async throws {
        let before = try await send(.GET, "v1/catalog")
        let settings = before.json["settings"] as? [String: Any]
        XCTAssertEqual(settings?["min_qty"] as? Int, 2)
        XCTAssertEqual(settings?["lead_days"] as? Int, 2)
        let firstOpen = { (reply: Reply) in
            (reply.json["dates"] as? [[String: Any]] ?? []).first { $0["available"] as? Bool == true }?["date"] as? String
        }
        let openBefore = try await send(.GET, "v1/availability?cakes=1")
        XCTAssertEqual(firstOpen(openBefore), day(2))
        try await addLoad(day(9), 25)
        let fits = try await send(.GET, "v1/availability?cakes=5")
        XCTAssertEqual((fits.json["dates"] as? [[String: Any]])?.first { $0["date"] as? String == day(9) }?["available"] as? Bool, true)

        _ = try await call(.PUT, "v1/owner/settings/ordering", ordering(26, lead: 5, min: 4))

        let after = try await send(.GET, "v1/catalog")
        let changed = after.json["settings"] as? [String: Any]
        XCTAssertEqual(changed?["min_qty"] as? Int, 4)
        XCTAssertEqual(changed?["lead_days"] as? Int, 5)
        XCTAssertNotEqual(after.headers.first(name: .eTag), before.headers.first(name: .eTag))
        let openAfter = try await send(.GET, "v1/availability?cakes=1")
        XCTAssertEqual(firstOpen(openAfter), day(5))
        let tight = try await send(.GET, "v1/availability?cakes=5")
        XCTAssertEqual((tight.json["dates"] as? [[String: Any]])?.first { $0["date"] as? String == day(9) }?["available"] as? Bool, false,
                       "25 accepted of 26 leaves room for 1, not 5")
    }
}
