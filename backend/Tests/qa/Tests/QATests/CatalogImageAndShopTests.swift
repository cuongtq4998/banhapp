import XCTest
import XCTVapor
@testable import AppUnderTest

/// Images referenced by the catalog, other shop ids and the public asset base URL.
final class CatalogImageAndShopTests: CatalogTestBase {

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

}
