import XCTVapor
@testable import App

/// Changing, hiding and removing cakes (api/07 10.17; BR-11, BR-12, ADR-0031).
final class OwnerCakeChangeTests: OwnerCakeTestCase {
    private var firstID: String {
        get async throws {
            let row = try await sql.raw("SELECT id FROM product WHERE shop_id = \(bind: shopID)").first()
            return try XCTUnwrap(row).decode(column: "id", as: UUID.self).uuidString
        }
    }

    func testAChangeKeepsTheOtherFieldsAndIsRecorded() async throws {
        let id = try await firstID
        let reply = try await call(.PATCH, "v1/owner/cakes/\(id)", #"{"price_vnd":60000,"name":"Banh Moi"}"#)
        XCTAssertEqual(reply.status, .ok)
        XCTAssertEqual(reply.json["price_vnd"] as? Int, 60_000)
        XCTAssertEqual(reply.string("description"), "Mo ta")
        XCTAssertTrue(reply.string("image_url").hasPrefix("/assets/images/banana.png"), reply.string("image_url"))
        let price = try await changeCount(field: "price_vnd", old: "50000", new: "60000")
        let name = try await changeCount(field: "name", old: "Banh Mau", new: "Banh Moi")
        let rows = try await changeRows("cake")
        XCTAssertEqual([price, name, rows], [1, 1, 2])
    }

    func testBadChangesAreRefusedAndTheImageCannotBeEdited() async throws {
        let id = try await firstID
        for body in ["{}", #"{"image":"x"}"#, #"{"price_vnd":0}"#, #"{"name":""}"#, #"{"is_active":"no"}"#] {
            let reply = try await call(.PATCH, "v1/owner/cakes/\(id)", body)
            XCTAssertEqual(reply.status, .unprocessableEntity, body)
        }
        let unknown = try await call(.PATCH, "v1/owner/cakes/\(UUID())", #"{"price_vnd":5}"#)
        XCTAssertEqual(unknown.status, .notFound)
        let bad = try await call(.PATCH, "v1/owner/cakes/not-an-id", #"{"price_vnd":5}"#)
        XCTAssertEqual(bad.status, .notFound)
        let staff = try await call(.PATCH, "v1/owner/cakes/\(id)", #"{"price_vnd":5}"#, as: staffPhone)
        XCTAssertEqual(staff.status, .forbidden)
        let staffDelete = try await call(.DELETE, "v1/owner/cakes/\(id)", as: staffPhone)
        XCTAssertEqual(staffDelete.status, .forbidden)
        let changes = try await changeRows("cake")
        XCTAssertEqual(changes, 0)
    }

    func testANameClashOnChangeIsRefused() async throws {
        _ = try await addCake("Banh Dau")
        let reply = try await call(.PATCH, "v1/owner/cakes/\(try await firstID)", #"{"name":"banh dau"}"#)
        XCTAssertEqual(problems(reply), ["NAME_TAKEN"])
    }

    func testTheLastActiveCakeCannotBeHiddenOrRemoved() async throws {
        let id = try await firstID
        let hide = try await call(.PATCH, "v1/owner/cakes/\(id)", #"{"is_active":false}"#)
        XCTAssertEqual(hide.errorCode, "LAST_ACTIVE_CAKE")
        XCTAssertEqual(hide.status, .conflict)
        let remove = try await call(.DELETE, "v1/owner/cakes/\(id)")
        XCTAssertEqual(remove.errorCode, "LAST_ACTIVE_CAKE")
        let second = try await addCake("Banh Dau")
        let hidden = try await call(.PATCH, "v1/owner/cakes/\(id)", #"{"is_active":false}"#)
        XCTAssertEqual(hidden.status, .ok)
        let lastAgain = try await call(.PATCH, "v1/owner/cakes/\(second.string("cake_id"))", #"{"is_active":false}"#)
        XCTAssertEqual(lastAgain.errorCode, "LAST_ACTIVE_CAKE")
        let removeHidden = try await call(.DELETE, "v1/owner/cakes/\(id)")
        XCTAssertEqual(removeHidden.status, .noContent, "a hidden cake can go while another is active")
        let rows = try await liveCakes()
        XCTAssertEqual(rows, 1)
    }

    func testRemovalIsFinalDeletesThePictureAndHidesTheCake() async throws {
        let added = try await addCake("Banh Dau"), id = added.string("cake_id")
        let removed = try await call(.DELETE, "v1/owner/cakes/\(id)")
        XCTAssertEqual(removed.status, .noContent)
        XCTAssertTrue(removed.data.isEmpty)
        let stored = try await images()
        XCTAssertEqual(stored, 0)
        let cakes = list("cakes", in: try await call(.GET, "v1/owner/settings"))
        XCTAssertEqual(cakes.count, 1)
        for reply in [try await call(.DELETE, "v1/owner/cakes/\(id)"), try await call(.PATCH, "v1/owner/cakes/\(id)", #"{"price_vnd":5}"#)] {
            XCTAssertEqual(reply.status, .notFound)
        }
        let gone = try await count("SELECT count(*)::int AS n FROM product WHERE id = \(bind: UUID(uuidString: id)!) AND removed_at IS NOT NULL AND NOT is_active")
        XCTAssertEqual(gone, 1)
        let recorded = try await changeCount(field: "removed", old: "false", new: "true")
        XCTAssertEqual(recorded, 1)
        let image = try await get(String(added.string("image_url").prefix { $0 != "?" }))
        XCTAssertEqual(image.status, .notFound)
    }
}
