import XCTest
import XCTVapor
import Fluent
import FluentSQL
@testable import AppUnderTest

/// Slice 1, `GET /v1/catalog` against the sample seed (api.md 4.1, ADR-0011,
/// ADR-0013, ADR-0017). Needs DATABASE_MIGRATION_URL (a throwaway PostgreSQL
/// 14+); skips without it, so on a host without PostgreSQL these are NOT RUN,
/// and they run in the GitHub CI QA step.
final class CatalogContractTests: XCTestCase {
    private var app: Application!

    override func setUp() async throws {
        app = try await CatalogApp.make()
        // Start from the seed even when an earlier run was interrupted halfway through a data change.
        if Slice1.mutationAllowed { try await restoreSample() }
    }

    override func tearDown() async throws {
        if let app { try await app.asyncShutdown() }
    }

    private func catalog(_ headers: HTTPHeaders = [:]) async throws -> Reply {
        try await app.qaSend(.GET, Slice1.catalogPath, headers: headers)
    }

    private func okCatalog() async throws -> (Reply, J) {
        let reply = try await catalog()
        XCTAssertEqual(reply.status, .ok, "GET /v1/catalog: \(reply.text.prefix(200))")
        return (reply, try XCTUnwrap(reply.json, "catalog body is not JSON"))
    }

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

    // MARK: Caching headers, ETag, 304 (TC-3, ADR-0011)

    func testTC3_Headers200() async throws {
        let reply = try await catalog()
        XCTAssertEqual(reply.status, .ok)
        XCTAssertEqual(reply.header("Cache-Control")?.lowercased(), "no-cache")
        let etag = try XCTUnwrap(reply.header("ETag"), "ETag missing")
        XCTAssertNotNil(etag.range(of: "^\"[0-9a-f]{32}\"$", options: .regularExpression), "api.md 4.1 (ADR-0017): strong tag, quoted 32 lowercase hex: \(etag)")
    }

    func testTC3_SameDataSameEtagAndConditionalRequestIs304WithEmptyBody() async throws {
        let first = try await catalog()
        let second = try await catalog()
        let etag = try XCTUnwrap(first.header("ETag"))
        XCTAssertEqual(second.header("ETag"), etag, "ETag must be deterministic for equal content")
        XCTAssertEqual(first.body, second.body)
        let conditional = try await catalog(["If-None-Match": etag])
        XCTAssertEqual(conditional.status, .notModified)
        XCTAssertEqual(conditional.body.count, 0)
        XCTAssertEqual(conditional.header("ETag"), etag, "RFC 9110 15.4.5: 304 repeats the ETag")
        XCTAssertEqual(conditional.header("Cache-Control"), "no-cache", "api.md 4.1: a 304 repeats Cache-Control")
        XCTAssertNotNil(conditional.header("X-Request-Id"))
        XCTAssertNil(conditional.header("Content-Type"), "api.md 4.1: a 304 does not repeat Content-Type")
    }

    func testExtra_EtagChangesWhenOnlyServerDateChanges() async throws {
        app.services.clock = FixedWallClock(instant: try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-11-02T03:00:00Z")))
        let day1 = try await catalog()
        app.services.clock = FixedWallClock(instant: try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-11-03T03:00:00Z")))
        let day2 = try await catalog(["If-None-Match": try XCTUnwrap(day1.header("ETag"))])
        XCTAssertEqual(day2.status, .ok, "server_date changed, so the old ETag must not give 304 (clients rely on server_date)")
        XCTAssertNotEqual(day2.header("ETag"), day1.header("ETag"))
    }

    // MARK: Adversarial conditional requests (extra)

    func testExtra_ConditionalRequestVariants() async throws {
        let first = try await catalog()
        let etag = try XCTUnwrap(first.header("ETag"))
        let bare = etag.hasPrefix("W/") ? String(etag.dropFirst(2)) : etag
        let inner = bare.trimmingCharacters(in: CharacterSet(charactersIn: "\""))

        let notModified: [(String, String)] = [
            ("strong form", bare),
            ("weak form of the same tag (weak comparison, RFC 9110 13.1.2)", "W/" + bare),
            ("list containing the tag", "\"other\", \(bare), \"another\""),
            ("list with extra spaces and tabs", "\"other\" ,\t\(bare)\t"),
            ("star matches any current representation", "*")
        ]
        for (label, value) in notModified {
            let r = try await catalog(["If-None-Match": value])
            XCTAssertEqual(r.status, .notModified, label)
        }
        let fullBody: [(String, String)] = [
            ("different tag", "\"0000\""),
            ("unquoted tag value", inner),
            ("empty header", ""),
            ("only whitespace", "   "),
            ("tag with trailing garbage", bare + "x"),
            ("truncated quote", "\"" + inner),
            ("lowercase weak marker is not a marker", "w/" + bare),
            ("comma only", ","),
            ("null byte text", "\"a\\0b\"")
        ]
        for (label, value) in fullBody {
            let r = try await catalog(["If-None-Match": value])
            XCTAssertEqual(r.status, .ok, label)
            XCTAssertEqual(r.body, first.body, label)
        }
    }

    func testExtra_LargeIfNoneMatchNeverCausesAServerError() async throws {
        let first = try await catalog()
        let etag = try XCTUnwrap(first.header("ETag"))
        for size in [1_000, 7_000, 100_000, 1_000_000] {
            let filler = (0..<(size / 10)).map { _ in "\"abcdefgh\"" }.joined(separator: ",")
            let r = try await catalog(["If-None-Match": filler])
            XCTAssertEqual(r.status, .ok, "size \(size)")
            let withMatch = try await catalog(["If-None-Match": filler + "," + etag])
            XCTAssertEqual(withMatch.status, .notModified, "size \(size), matching tag last")
        }
    }

    func testExtra_HeaderNameCaseAndRepeatedHeaderLines() async throws {
        let base = try await catalog()
        let etag = try XCTUnwrap(base.header("ETag"))
        var lower = HTTPHeaders()
        lower.add(name: "if-none-match", value: etag)
        let a = try await catalog(lower)
        XCTAssertEqual(a.status, .notModified)
        var twoLines = HTTPHeaders()
        twoLines.add(name: "If-None-Match", value: "\"nope\"")
        twoLines.add(name: "If-None-Match", value: etag)
        let b = try await catalog(twoLines)
        XCTAssertEqual(b.status, .notModified, "repeated header lines combine as a list (RFC 9110 5.3)")
    }

    func testExtra_IfModifiedSinceAloneDoesNotProduce304() async throws {
        let r = try await catalog(["If-Modified-Since": "Wed, 21 Oct 2037 07:28:00 GMT"])
        XCTAssertEqual(r.status, .ok, "no Last-Modified is promised; validators are ETag only")
    }

    // MARK: Other methods, parameters, paths (extra)

    /// api.md 4.1 (v1.6): HEAD is not part of the contract; an unrouted method answers 404 NOT_FOUND.
    func testExtra_HeadIsNotPartOfTheContract() async throws {
        let head = try await app.qaSend(.HEAD, Slice1.catalogPath)
        XCTAssertLessThan(head.status.code, 500)
        if head.status != .ok { XCTAssertEqual(head.status, .notFound) }
    }

    func testExtra_OtherMethodsAreTheDocumentedNotFoundEnvelope() async throws {
        for method in [HTTPMethod.POST, .PUT, .DELETE, .PATCH] {
            let r = try await app.qaSend(method, Slice1.catalogPath)
            XCTAssertEqual(r.status, .notFound, "\(method)")
            XCTAssertEqual(Slice1.envelopeProblems(r, code: "NOT_FOUND", messageKey: "ERR_SERVER"), [], "\(method)")
        }
    }

    func testExtra_UnknownQueryParametersAreHarmlessAndDoNotForkTheCache() async throws {
        // api.md 4.1 (v1.6): any query parameter is ignored; 200 with the same body and ETag, never 422 or 5xx.
        let base = try await catalog()
        for query in ["?x=1", "?slot_id=00000000-0000-4000-8000-000000000031", "?cakes=2", "?%00=%00", "?a=" + String(repeating: "z", count: 5000), "?deep=1", "?page=2&limit=1"] {
            let r = try await app.qaSend(.GET, Slice1.catalogPath + query)
            XCTAssertLessThan(r.status.code, 500, query)
            XCTAssertEqual(r.status, .ok, query)
            XCTAssertEqual(r.body, base.body, "query \(query) changed the data")
            XCTAssertEqual(r.header("ETag"), base.header("ETag"), query)
        }
    }

    func testExtra_PathVariantsNeverReachAnErrorState() async throws {
        for path in ["v1/catalog/", "V1/catalog", "v1/Catalog", "v1//catalog", "v1/catalog/extra", "v2/catalog", "catalog", "v1/catalog%00", "v1/catalog.json"] {
            let r = try await app.qaSend(.GET, path)
            XCTAssertLessThan(r.status.code, 500, path)
            if r.status != .ok { XCTAssertEqual(r.status, .notFound, path); XCTAssertEqual(r.errorCode, "NOT_FOUND", path) }
        }
    }

    func testExtra_AcceptHeaderVariantsStillGetJsonOrNotAcceptable() async throws {
        for accept in ["text/html", "*/*", "application/xml", "application/json;q=0", "garbage"] {
            let r = try await catalog(["Accept": accept])
            XCTAssertLessThan(r.status.code, 500, accept)
            if r.status == .ok { XCTAssertTrue(r.header("Content-Type")?.contains("json") ?? false, accept) }
        }
    }

    func testExtra_ParallelReadsAreConsistent() async throws {
        let reference = try await catalog()
        let app: Application = self.app
        let replies = try await withThrowingTaskGroup(of: Reply.self) { group in
            for _ in 0..<40 { group.addTask { try await app.qaSend(.GET, Slice1.catalogPath) } }
            var all: [Reply] = []
            for try await r in group { all.append(r) }
            return all
        }
        XCTAssertEqual(replies.count, 40)
        for r in replies {
            XCTAssertEqual(r.status, .ok)
            XCTAssertEqual(r.body, reference.body)
            XCTAssertEqual(r.header("ETag"), reference.header("ETag"))
        }
    }

    // MARK: Images referenced by the catalog (FR-3, AC-4)

    func testTC67_EveryImageUrlOfTheCatalogServesAnImage() async throws {
        let (_, json) = try await okCatalog()
        for product in try XCTUnwrap(json["products"]?.array) {
            let url = try XCTUnwrap(product["image_url"]?.string)
            XCTAssertTrue(url.hasPrefix("/assets/images/"), url)
            XCTAssertNotNil(url.range(of: "\\?v=[0-9a-f]{8}$", options: .regularExpression), "version query missing: \(url)")
            let r = try await app.qaSend(.GET, String(url.dropFirst()))
            XCTAssertEqual(r.status, .ok, url)
            XCTAssertTrue(r.header("Content-Type")?.hasPrefix("image/") ?? false, "\(url): \(r.header("Content-Type") ?? "nil")")
            XCTAssertEqual(r.header("Cache-Control"), "public, max-age=31536000, immutable", url)
            XCTAssertGreaterThan(r.body.count, 0, url)
            XCTAssertLessThan(r.body.count, 1_000_000, "\(url) is larger than 1 MB (mobile data, FR-3)")
            let png = Data([0x89, 0x50, 0x4E, 0x47]), jpg = Data([0xFF, 0xD8, 0xFF])
            XCTAssertTrue(r.body.starts(with: png) || r.body.starts(with: jpg) || r.body.starts(with: Data("RIFF".utf8)), "\(url) is not a PNG, JPEG or WebP file")
        }
    }

    // MARK: Data changes (needs QA_ALLOW_DB_MUTATION=1)

    private func execute(_ sql: String) async throws {
        try await (app.db as! any SQLDatabase).raw(SQLQueryString(sql)).run()
    }

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

    /// A catalog for a SHOP_ID that has no rows: no crash, and no data of another shop (single-shop rule, ADR-0013).
    func testExtra_UnknownShopIdDoesNotLeakOrCrash() async throws {
        let other = try await CatalogApp.makeWithShop(UUID(uuidString: "00000000-0000-4000-8000-0000000000ff")!)
        defer { Task { try? await other.asyncShutdown() } }
        let r = try await other.qaSend(.GET, Slice1.catalogPath)
        XCTAssertEqual(r.status, .internalServerError, "CatalogRepository doc: a deployment mistake is answered as INTERNAL_ERROR")
        XCTAssertEqual(Slice1.envelopeProblems(r, code: "INTERNAL_ERROR", messageKey: "ERR_SERVER"), [])
        XCTAssertFalse(r.text.contains("Tiệm Bánh An Nhiên"), "another shop's data must not be served")
        XCTAssertNil(r.header("ETag"))
    }

    /// PUBLIC_ASSET_BASE_URL: `image_url` becomes base + path, still with the version query (api.md 4.6).
    func testExtra_AssetBaseUrlPrefixesEveryImageUrl() async throws {
        let cdn = try await CatalogApp.make(assetBaseURL: "https://cdn.example.test")
        defer { Task { try? await cdn.asyncShutdown() } }
        let r = try await cdn.qaSend(.GET, Slice1.catalogPath)
        XCTAssertEqual(r.status, .ok)
        for product in try XCTUnwrap(r.json?["products"]?.array) {
            let url = try XCTUnwrap(product["image_url"]?.string)
            XCTAssertTrue(url.hasPrefix("https://cdn.example.test/assets/images/"), url)
            XCTAssertNotNil(url.range(of: "\\?v=[0-9a-f]{8}$", options: .regularExpression), url)
        }
    }

    /// Puts every row a test in this file may have changed back to the sample seed, so a test never sees the
    /// leftovers of another one (the mutating tests share one database and run one after the other).
    private func restoreSample() async throws {
        try await execute("UPDATE district SET is_active = true")
        try await execute("UPDATE delivery_slot SET is_active = true")
        try await execute("UPDATE product SET is_active = true")
        for (position, product) in Slice1.Seed.products.enumerated() {
            try await execute("UPDATE product SET sort_order = \(position + 1), price_vnd = \(product.3) WHERE id = '\(product.4)'")
        }
        try await execute("UPDATE shop_setting SET min_qty = \(Slice1.Seed.settings["min_qty"]!), lead_days = \(Slice1.Seed.settings["lead_days"]!)")
    }
}
