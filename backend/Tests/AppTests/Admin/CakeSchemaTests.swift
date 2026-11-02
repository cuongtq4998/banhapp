import XCTVapor
import FluentSQL
@testable import App

/// Migration 0005 (data-model/05 section 12): what the database refuses even
/// when the service is bypassed.
final class CakeSchemaTests: OwnerSettingsTestCase {
    private func rejected(_ statement: SQLQueryString, _ message: String) async throws {
        do {
            try await sql.raw(statement).run()
            XCTFail("accepted: \(message)")
        } catch {
            let text = String(reflecting: error)
            XCTAssertTrue(text.contains("sqlState: 23514") || text.contains("sqlState: 23505") || text.contains("sqlState: 23502"), "\(message): \(text.prefix(200))")
        }
    }

    private func insert(_ name: String) -> SQLQueryString {
        "INSERT INTO product (shop_id, slug, name, description, price_vnd, image_path) VALUES (\(bind: shopID), \(bind: UUID().uuidString.prefix(12).lowercased()), \(bind: name), 'd', 1000, 'images/banana.png')"
    }

    func testProductRules() async throws {
        try await rejected("UPDATE product SET price_vnd = 100000001 WHERE shop_id = \(bind: shopID)", "price above the maximum")
        try await rejected("UPDATE product SET removed_at = now() WHERE shop_id = \(bind: shopID)", "removed but active")
        try await rejected("UPDATE product SET image_path = NULL WHERE shop_id = \(bind: shopID)", "file cake without a path")
        try await rejected("UPDATE product SET image_source = 'cloud' WHERE shop_id = \(bind: shopID)", "unknown source")
        try await rejected(insert("BANH MAU"), "name used by a live cake, other letter case")
        try await run("UPDATE product SET is_active = false, removed_at = now() WHERE shop_id = \(bind: shopID)")
        try await run(insert("banh mau"))
    }

    func testTheThirteenthLiveCakeIsRefusedByTheDatabase() async throws {
        for index in 1...11 { try await run(insert("Cake \(index)")) }
        let live = try await count("SELECT count(*)::int AS n FROM product WHERE shop_id = \(bind: shopID) AND removed_at IS NULL")
        XCTAssertEqual(live, 12)
        try await rejected(insert("Cake 12"), "the 13th cake")
        try await run("UPDATE product SET is_active = false, removed_at = now() WHERE shop_id = \(bind: shopID) AND name = 'Cake 1'")
        try await run(insert("Cake 12"))
        try await rejected("UPDATE product SET removed_at = NULL WHERE shop_id = \(bind: shopID) AND name = 'Cake 1'", "restoring a cake over the limit")
    }

    func testPictureRules() async throws {
        let id = UUID(), sha = String(repeating: "a", count: 64)
        try await run("INSERT INTO product (id, shop_id, slug, name, description, price_vnd, image_source) VALUES (\(bind: id), \(bind: shopID), 'cake-x', 'Up', 'd', 1000, 'upload')")
        func image(_ type: String = "image/png", bytes: Int = 10, width: Int = 300, height: Int = 300, hash: String? = nil) -> SQLQueryString {
            "INSERT INTO product_image (product_id, content_type, bytes, width, height, sha256) VALUES (\(bind: id), \(bind: type), decode(repeat('00', \(literal: bytes)), 'hex'), \(literal: width), \(literal: height), \(bind: hash ?? sha))"
        }
        try await rejected(image("image/gif"), "type")
        try await rejected(image(bytes: 0), "empty")
        try await rejected(image(bytes: 5_242_881), "over 5 MB")
        try await rejected(image(width: 199), "narrow")
        try await rejected(image(height: 4_097), "tall")
        try await rejected(image(hash: "abc"), "hash length")
        try await run(image(bytes: 5_242_880))
        try await rejected(image(), "one picture per cake")
    }
}
