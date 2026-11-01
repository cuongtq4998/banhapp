import XCTVapor
import BanhContracts
@testable import App

/// The shared cake fixtures (`contracts/fixtures/admin/`) against the real answers.
final class OwnerCakeFixtureTests: OwnerCakeTestCase {
    private func envelope(_ reply: Reply) throws -> APIErrorResponse.Body {
        try JSONDecoder().decode(APIErrorResponse.self, from: reply.data).error
    }

    private func shape(_ reply: Reply) -> NSDictionary { AdminFixtures.shape(reply.json) as? NSDictionary ?? [:] }

    func testSuccessBodiesHaveTheFixtureShape() async throws {
        let created = try await addCake("Banh Mau Hai")
        XCTAssertEqual(shape(created), try AdminFixtures.bodyShape("owner-cake-created"))
        let updated = try await call(.PATCH, "v1/owner/cakes/\(created.string("cake_id"))", #"{"price_vnd":160000,"is_active":false}"#)
        XCTAssertEqual(shape(updated), try AdminFixtures.bodyShape("owner-cake-updated"))
        let settings = try await call(.GET, "v1/owner/settings")
        XCTAssertEqual(AdminFixtures.shape(list("cakes", in: settings).last ?? [:]) as? NSDictionary, try AdminFixtures.bodyShape("owner-cake-created"))
    }

    func testErrorsMatchTheFixtures() async throws {
        let jpeg = TestImages.jpeg(width: 600, height: 400)
        let invalid = try await upload([("name", ""), ("description", "d"), ("price_vnd", "0")], files: [("image", Array("GIF89a".utf8))])
        XCTAssertEqual(try envelope(invalid), try AdminFixtures.error("cake-validation"))
        let taken = try await upload(fields("banh mau"), files: [("image", jpeg)])
        XCTAssertEqual(try envelope(taken), try AdminFixtures.error("cake-name-taken"))
        let last = try await call(.DELETE, "v1/owner/cakes/\(try await onlyCakeID())")
        XCTAssertEqual(try envelope(last), try AdminFixtures.error("last-active-cake"))
        let large = try await upload(fields(), files: [("image", TestImages.jpeg(width: 600, height: 400, padTo: ImageInspector.maxBytes + 1))])
        XCTAssertEqual(try envelope(large), try AdminFixtures.error("image-too-large"))
        for index in 2...12 { _ = try await addCake("Cake \(index)") }
        let limit = try await addCake("Cake 13")
        XCTAssertEqual(try envelope(limit), try AdminFixtures.error("cake-limit-reached"))
    }

    private func onlyCakeID() async throws -> UUID {
        let row = try await sql.raw("SELECT id FROM product WHERE shop_id = \(bind: shopID)").first()
        return try XCTUnwrap(row).decode(column: "id", as: UUID.self)
    }
}
