import XCTest
import XCTVapor
@testable import AppUnderTest

/// Slice 1, `GET /v1/catalog` against the sample seed (api.md 4.1, ADR-0011,
/// ADR-0013, ADR-0017). Needs DATABASE_MIGRATION_URL (a throwaway PostgreSQL
/// 14+); skips without it, so on a host without PostgreSQL these are NOT RUN,
/// and they run in the GitHub CI QA step.
final class CatalogContractTests: CatalogTestBase {

    // MARK: TC-1, AC-2, AC-4, AC-10, AC-11

    func testTC1_ShapeMatchesTheContract() async throws {
        let (reply, json) = try await okCatalog()
        XCTAssertEqual(Slice1.shapeProblems(json), [])
        XCTAssertTrue(reply.header("Content-Type")?.hasPrefix("application/json") ?? false)
        XCTAssertNotNil(reply.header("X-Request-Id"))
    }

    func testTC1_SampleCakesInSortOrderWithSeedContent() async throws {
        let (_, json) = try await okCatalog()
        let products = try XCTUnwrap(json["products"]?.array)
        XCTAssertEqual(products.map { $0["slug"]?.string }, Slice1.Seed.products.map { $0.0 })
        for (item, expected) in zip(products, Slice1.Seed.products) {
            XCTAssertEqual(item["name"]?.string, expected.1)
            XCTAssertEqual(item["description"]?.string, expected.2)
            XCTAssertEqual(item["price_vnd"]?.int, expected.3)
            XCTAssertEqual(item["product_id"]?.string?.lowercased(), expected.4)
        }
    }

    func testTC1_ShopSettingsDistrictsAndSlotsComeFromTheTables() async throws {
        let (_, json) = try await okCatalog()
        XCTAssertEqual(json["shop"]?["name"]?.string, Slice1.Seed.shopName)
        XCTAssertEqual(json["shop"]?["greeting"]?.string, Slice1.Seed.greeting)
        XCTAssertEqual(json["shop"]?["phone_contact"]?.string, Slice1.Seed.phone)
        XCTAssertEqual(json["shop"]?["zalo_contact"]?.string, Slice1.Seed.zalo)
        for (key, value) in Slice1.Seed.settings { XCTAssertEqual(json["settings"]?[key]?.int, value, key) }
        let districts = try XCTUnwrap(json["districts"]?.array)
        XCTAssertEqual(districts.map { $0["name"]?.string }, Slice1.Seed.districts.map { $0.0 })
        XCTAssertEqual(districts.map { $0["delivery_fee_vnd"]?.int }, Slice1.Seed.districts.map { $0.1 })
        let slots = try XCTUnwrap(json["slots"]?.array)
        XCTAssertEqual(slots.map { $0["start"]?.string }, Slice1.Seed.slots.map { $0.0 })
        XCTAssertEqual(slots.map { $0["end"]?.string }, Slice1.Seed.slots.map { $0.1 })
    }

    // MARK: TC-2, AC-27, AC-29

    func testTC2_NoSampleMarkerPaymentWordOrInternalFieldAnywhere() async throws {
        let (reply, json) = try await okCatalog()
        XCTAssertEqual(Slice1.forbiddenHits(in: json.allText), [])
        for key in ["is_sample", "daily_limit", "status", "payment", "remaining", "capacity"] {
            XCTAssertFalse(reply.text.contains("\"\(key)\""), "key \(key) leaked")
        }
    }

    // MARK: Vietnamese text (extra)

    func testExtra_VietnameseTextIsUtf8NotEscapedAndNotMangled() async throws {
        let reply = try await catalog()
        XCTAssertEqual(reply.status, .ok)
        let text = reply.text
        XCTAssertTrue(text.contains("Bánh đậu xanh nhân mỡ"), "diacritics must be literal UTF-8")
        XCTAssertFalse(text.contains("\\u"), "no \\u escapes needed for UTF-8 JSON")
        XCTAssertFalse(text.contains("\u{FFFD}"))
        let contentType = reply.header("Content-Type")?.lowercased() ?? ""
        XCTAssertTrue(contentType.contains("json"))
        XCTAssertTrue(contentType.contains("utf-8") || !contentType.contains("charset"), "if a charset is stated it is utf-8")
    }

    // MARK: server_date (TC-62 catalog part)

    func testTC62_ServerDateFollowsShopTimeAroundMidnight() async throws {
        let cases: [(String, String)] = [
            ("2026-11-02T16:59:59Z", "2026-11-02"),
            ("2026-11-02T17:00:00Z", "2026-11-03"),
            ("2026-11-02T17:30:00Z", "2026-11-03"),
            ("2026-12-31T16:59:59Z", "2026-12-31"),
            ("2026-12-31T17:00:00Z", "2027-01-01")
        ]
        for (instant, expected) in cases {
            let date = try XCTUnwrap(ISO8601DateFormatter().date(from: instant))
            app.services.clock = FixedWallClock(instant: date)
            let (_, json) = try await okCatalog()
            XCTAssertEqual(json["server_date"]?.string, expected, instant)
        }
    }

}
