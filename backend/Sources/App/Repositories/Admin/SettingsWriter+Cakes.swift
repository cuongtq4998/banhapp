import Foundation
import FluentSQL

/// Cake writes. All run after `SettingsWriter.lock`, so the counts below are
/// true until the transaction ends (ADR-0031).
extension SettingsWriter {
    func liveCakeCount(shopID: UUID) async throws -> Int {
        try await sql.raw("SELECT count(*)::int AS n FROM product WHERE shop_id = \(bind: shopID) AND removed_at IS NULL")
            .first()?.decode(column: "n", as: Int.self) ?? 0
    }

    /// Names are unique ignoring letter case among cakes that are not removed.
    func cakeNameTaken(shopID: UUID, name: String, excluding id: UUID?) async throws -> Bool {
        try await sql.raw("""
            SELECT 1 AS one FROM product
            WHERE shop_id = \(bind: shopID) AND removed_at IS NULL AND lower(name) = lower(\(bind: name)) AND id IS DISTINCT FROM \(bind: id)
            """).first() != nil
    }

    func otherActiveCakes(shopID: UUID, besides id: UUID) async throws -> Int {
        try await sql.raw("""
            SELECT count(*)::int AS n FROM product
            WHERE shop_id = \(bind: shopID) AND removed_at IS NULL AND is_active AND id <> \(bind: id)
            """).first()?.decode(column: "n", as: Int.self) ?? 0
    }

    /// The cake and its picture go in together; the slug is `cake-` and the
    /// first 8 hex characters of the id.
    func insertCake(shopID: UUID, id: UUID, name: String, description: String, priceVND: Int, image: StoredImage, at now: Date) async throws {
        try await sql.raw("""
            INSERT INTO product (id, shop_id, slug, name, description, price_vnd, image_path, image_source, sort_order, is_active, created_at, updated_at)
            VALUES (\(bind: id), \(bind: shopID), 'cake-' || left(\(bind: id.uuidString.lowercased()), 8), \(bind: name), \(bind: description),
                    \(bind: priceVND), NULL, 'upload', (SELECT coalesce(max(sort_order), 0) + 1 FROM product WHERE shop_id = \(bind: shopID)),
                    true, \(timestamp(now)), \(timestamp(now)))
            """).run()
        try await sql.raw("""
            INSERT INTO product_image (product_id, content_type, bytes, width, height, sha256, created_at)
            VALUES (\(bind: id), \(bind: image.contentType), \(bind: Data(image.bytes)), \(bind: image.width), \(bind: image.height),
                    \(bind: image.sha256), \(timestamp(now)))
            """).run()
    }

    func updateCake(id: UUID, name: String, description: String, priceVND: Int, isActive: Bool, at now: Date) async throws {
        try await sql.raw("""
            UPDATE product SET name = \(bind: name), description = \(bind: description), price_vnd = \(bind: priceVND),
                is_active = \(bind: isActive), updated_at = \(timestamp(now))
            WHERE id = \(bind: id)
            """).run()
    }

    /// Removal is final: the cake leaves every list, its picture bytes are
    /// deleted, earlier orders keep their own copy of name and price.
    func removeCake(id: UUID, at now: Date) async throws {
        try await sql.raw("DELETE FROM product_image WHERE product_id = \(bind: id)").run()
        try await sql.raw("UPDATE product SET is_active = false, removed_at = \(timestamp(now)), updated_at = \(timestamp(now)) WHERE id = \(bind: id)").run()
    }
}

/// A checked picture, ready to store.
struct StoredImage: Sendable {
    let contentType: String
    let bytes: [UInt8]
    let width: Int
    let height: Int
    let sha256: String
}
