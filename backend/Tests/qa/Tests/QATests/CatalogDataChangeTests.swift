import XCTest
import XCTVapor
import Fluent
import FluentSQL
@testable import AppUnderTest

/// Tests that change rows; they skip unless QA_ALLOW_DB_MUTATION=1 and put the sample seed back afterwards.
final class CatalogDataChangeTests: CatalogTestBase {

    // MARK: Data changes (needs QA_ALLOW_DB_MUTATION=1)


    func testTC3_PriceChangeGivesNewEtagAndOldEtagIsNoLongerFresh() async throws {
        try XCTSkipUnless(Slice1.mutationAllowed, "set \(Slice1.mutationVariable)=1 on a throwaway database")
        let original = try await catalog()
        let etag = try XCTUnwrap(original.header("ETag"))
        let id = "'\(Slice1.Seed.products[0].4)'"
        try await execute("UPDATE product SET price_vnd = price_vnd + 1000 WHERE id = \(id)")
        do {
            let changed = try await catalog(["If-None-Match": etag])
            XCTAssertEqual(changed.status, .ok)
            XCTAssertNotEqual(changed.header("ETag"), etag)
            XCTAssertEqual(changed.json?["products"]?.array?.first?["price_vnd"]?.int, Slice1.Seed.products[0].3 + 1000)
        } catch {
            try await execute("UPDATE product SET price_vnd = \(Slice1.Seed.products[0].3) WHERE id = \(id)")
            throw error
        }
        try await execute("UPDATE product SET price_vnd = \(Slice1.Seed.products[0].3) WHERE id = \(id)")
        let restored = try await catalog(["If-None-Match": etag])
        XCTAssertEqual(restored.status, .notModified, "same content again must give the same ETag")
    }

    func testExtra_InactiveRowsAreHiddenAndOrderFollowsSortOrder() async throws {
        try XCTSkipUnless(Slice1.mutationAllowed, "set \(Slice1.mutationVariable)=1 on a throwaway database")
        let district = "'00000000-0000-4000-8000-000000000025'"
        let slot = "'00000000-0000-4000-8000-000000000034'"
        let product = "'00000000-0000-4000-8000-000000000014'"
        try await execute("UPDATE district SET is_active = false WHERE id = \(district)")
        try await execute("UPDATE delivery_slot SET is_active = false WHERE id = \(slot)")
        try await execute("UPDATE product SET sort_order = 0 WHERE id = \(product)")
        let (_, json) = try await okCatalog()
        XCTAssertEqual(json["districts"]?.array?.map { $0["name"]?.string }, ["Quận 1", "Quận 3", "Quận 5", "Phú Nhuận"])
        XCTAssertEqual(json["slots"]?.array?.count, 3)
        XCTAssertEqual(json["products"]?.array?.first?["slug"]?.string, "mung-bean-egg-yolk-pork-fat")
        try await restoreSample()
    }

    func testExtra_InactiveProductIsHiddenSoClientsSeeFewerThanFour() async throws {
        try XCTSkipUnless(Slice1.mutationAllowed, "set \(Slice1.mutationVariable)=1 on a throwaway database")
        let product = "'00000000-0000-4000-8000-000000000013'"
        try await execute("UPDATE product SET is_active = false WHERE id = \(product)")
        let (_, json) = try await okCatalog()
        XCTAssertEqual(json["products"]?.array?.count, 3, "api.md 4.1 v1.6: active products only, one to four are normal (AC-32)")
        try await restoreSample()
    }

    // MARK: AC-32, AC-33 (owner decision of 2026-10-26: 1 to 4 active cakes are normal, zero is the error screen)

    /// AC-32 at the API level: for 1, 2 and 3 active cakes exactly those are listed, in sort order, no padding.
    func testAC32_OneTwoOrThreeActiveCakesAreListedExactly() async throws {
        try XCTSkipUnless(Slice1.mutationAllowed, "set \(Slice1.mutationVariable)=1 on a throwaway database")
        let ids = Slice1.Seed.products.map { $0.4 }
        do {
            for keep in [3, 2, 1] {
                try await execute("UPDATE product SET is_active = (id IN (\(ids.prefix(keep).map { "'\($0)'" }.joined(separator: ","))))")
                let (_, json) = try await okCatalog()
                XCTAssertEqual(json["products"]?.array?.map { $0["slug"]?.string }, Slice1.Seed.products.prefix(keep).map { $0.0 }, "\(keep) active")
                XCTAssertEqual(Slice1.shapeProblems(json, productCount: keep), [], "\(keep) active")
                XCTAssertEqual(Slice1.forbiddenHits(in: json.allText), [])
            }
            // a hidden cake in the middle: the others keep their order
            try await execute("UPDATE product SET is_active = (id <> '\(ids[1])')")
            let (_, middle) = try await okCatalog()
            XCTAssertEqual(middle["products"]?.array?.map { $0["slug"]?.string }, ["banana", "mung-bean-vegetarian", "mung-bean-egg-yolk-pork-fat"])
        } catch {
            try await restoreSample()
            throw error
        }
        try await restoreSample()
    }

    /// AC-33 at the API level: zero active cakes is 200 with `products: []`, other lists intact, and one cake
    /// made active again shows up on the next request (new ETag, no restart).
    func testAC33_ZeroActiveCakesIsAnEmptyListNotAnError() async throws {
        try XCTSkipUnless(Slice1.mutationAllowed, "set \(Slice1.mutationVariable)=1 on a throwaway database")
        do {
            let before = try await catalog()
            try await execute("UPDATE product SET is_active = false")
            let (reply, json) = try await okCatalog()
            XCTAssertEqual(json["products"]?.array?.count, 0)
            XCTAssertEqual(Slice1.shapeProblems(json, productCount: 0), [])
            XCTAssertNotEqual(reply.header("ETag"), before.header("ETag"))
            XCTAssertEqual(json["districts"]?.array?.count, 5, "districts are not affected by hidden cakes")
            XCTAssertEqual(json["slots"]?.array?.count, 4)
            let conditional = try await catalog(["If-None-Match": try XCTUnwrap(before.header("ETag"))])
            XCTAssertEqual(conditional.status, .ok, "the old tag must not give 304 after the list became empty")

            try await execute("UPDATE product SET is_active = true WHERE id = '\(Slice1.Seed.products[2].4)'")
            let (_, again) = try await okCatalog()
            XCTAssertEqual(again["products"]?.array?.map { $0["slug"]?.string }, [Slice1.Seed.products[2].0])
        } catch {
            try await restoreSample()
            throw error
        }
        try await restoreSample()
    }

    /// Empty districts and slots (all inactive) are valid answers too; the apps decide what to show.
    func testExtra_AllDistrictsAndSlotsInactiveGiveEmptyLists() async throws {
        try XCTSkipUnless(Slice1.mutationAllowed, "set \(Slice1.mutationVariable)=1 on a throwaway database")
        do {
            try await execute("UPDATE district SET is_active = false")
            try await execute("UPDATE delivery_slot SET is_active = false")
            let (_, json) = try await okCatalog()
            XCTAssertEqual(Slice1.shapeProblems(json, minDistricts: 0, minSlots: 0), [])
            XCTAssertEqual(json["districts"]?.array?.count, 0)
            XCTAssertEqual(json["slots"]?.array?.count, 0)
        } catch {
            try await restoreSample()
            throw error
        }
        try await restoreSample()
    }

    /// api.md 4.1: `note_max_length` is a code constant, not a shop_setting; other settings follow the table.
    func testExtra_ChangedShopSettingIsServedAndNoteLengthStaysAConstant() async throws {
        try XCTSkipUnless(Slice1.mutationAllowed, "set \(Slice1.mutationVariable)=1 on a throwaway database")
        do {
            try await execute("UPDATE shop_setting SET min_qty = 3, lead_days = 1")
            let (_, json) = try await okCatalog()
            XCTAssertEqual(json["settings"]?["min_qty"]?.int, 3)
            XCTAssertEqual(json["settings"]?["lead_days"]?.int, 1)
            XCTAssertEqual(json["settings"]?["note_max_length"]?.int, 200)
        } catch {
            try await restoreSample()
            throw error
        }
        try await restoreSample()
    }

}
