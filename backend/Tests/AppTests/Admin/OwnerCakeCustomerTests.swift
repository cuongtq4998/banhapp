import XCTVapor
@testable import App

/// What customers see of the owner's cake changes (ADR-0025, ADR-0031).
final class OwnerCakeCustomerTests: OwnerCakeTestCase {
    private func catalog() async throws -> [[String: Any]] { list("products", in: try await get("v1/catalog")) }

    private func names() async throws -> [String] { try await catalog().compactMap { $0["name"] as? String } }

    private func order(_ cakeID: String) async throws -> Reply {
        let payload = """
            {"items":[{"product_id":"\(cakeID)","quantity":2}],"delivery_date":"\(day(5))","slot_id":"\(slotID)",
             "customer":{"name":"Tran Thi B","phone":"0900 000 111","address":"1 Test Street","district_id":"\(districtID)"},
             "note":null,"expected_total_vnd":120000}
            """
        let box = LockedBox<Reply?>(nil)
        let headers: HTTPHeaders = ["Idempotency-Key": UUID().uuidString.lowercased(), "X-Platform": "ios", "X-App-Version": "1.0.0", "Content-Type": "application/json"]
        try await app.test(.POST, "v1/orders", headers: headers, body: ByteBuffer(string: payload), afterResponse: { res async throws in
            box.set(Reply(status: res.status, headers: res.headers, data: Data(res.body.readableBytesView)))
        })
        return try XCTUnwrap(box.value)
    }

    func testTheCatalogServesTheNewCakeItsPictureAndDropsItWhenHiddenOrRemoved() async throws {
        let bytes = TestImages.png(width: 640, height: 480, padTo: 3_000)
        let added = try await upload(fields(), files: [("image", bytes)])
        let id = added.string("cake_id"), url = added.string("image_url")
        let listed = try await names()
        XCTAssertEqual(listed, ["Banh Mau", "Banh Dau"])
        let products = try await catalog()
        let product = try XCTUnwrap(products.last)
        XCTAssertEqual(product["image_url"] as? String, url)
        let image = try await get(url)
        XCTAssertEqual(image.status, .ok)
        XCTAssertEqual(image.data, Data(bytes))
        XCTAssertEqual(image.headers.first(name: .contentType), "image/png")
        XCTAssertEqual(image.headers.first(name: "X-Content-Type-Options"), "nosniff")
        XCTAssertEqual(image.headers.first(name: .cacheControl), "public, max-age=31536000, immutable")
        let hidden = try await call(.PATCH, "v1/owner/cakes/\(id)", #"{"is_active":false}"#)
        XCTAssertEqual(hidden.status, .ok)
        let afterHide = try await names()
        XCTAssertEqual(afterHide, ["Banh Mau"])
        _ = try await call(.PATCH, "v1/owner/cakes/\(id)", #"{"is_active":true,"price_vnd":55000}"#)
        let back = try await catalog()
        XCTAssertEqual(back.last?["price_vnd"] as? Int, 55_000, "the next request shows the change")
        _ = try await call(.DELETE, "v1/owner/cakes/\(id)")
        let afterRemove = try await names()
        XCTAssertEqual(afterRemove, ["Banh Mau"])
        let gone = try await get(url)
        XCTAssertEqual(gone.status, .notFound)
    }

    func testTheCatalogHoldsTwelveCakesAndTheImageRouteRefusesStrangers() async throws {
        for index in 2...12 { _ = try await addCake("Cake \(index)") }
        let all = try await catalog()
        XCTAssertEqual(all.count, 12)
        let invalid = try await get("assets/cakes/not-an-id")
        let unknown = try await get("assets/cakes/\(UUID())")
        let fileCakeID = try XCTUnwrap(all.first?["product_id"] as? String)
        let fileCake = try await get("assets/cakes/\(fileCakeID)")
        XCTAssertEqual([invalid.status, unknown.status, fileCake.status], [.notFound, .notFound, .notFound])
        XCTAssertEqual(unknown.errorCode, "NOT_FOUND")
    }

    func testARemovedCakeCannotBeOrderedAndOldOrdersKeepTheirLines() async throws {
        let added = try await addCake("Banh Dau"), id = added.string("cake_id")
        let placed = try await order(id)
        XCTAssertEqual(placed.status, .created, String(decoding: placed.data, as: UTF8.self))
        let removed = try await call(.DELETE, "v1/owner/cakes/\(id)")
        XCTAssertEqual(removed.status, .noContent)
        let refused = try await order(id)
        XCTAssertEqual(refused.status, .conflict)
        XCTAssertEqual(refused.errorCode, "PRODUCT_UNAVAILABLE")
        let kept = try await sql.raw("SELECT product_name, quantity, unit_price_vnd FROM customer_order_item WHERE product_id = \(bind: UUID(uuidString: id)!)").first()
        XCTAssertEqual(try kept?.decode(column: "product_name", as: String.self), "Banh Dau")
        XCTAssertEqual(try kept?.decode(column: "quantity", as: Int.self), 2)
        XCTAssertEqual(try kept?.decode(column: "unit_price_vnd", as: Int.self), 50_000)
        let hiddenOne = try await addCake("Banh Khac")
        _ = try await call(.PATCH, "v1/owner/cakes/\(hiddenOne.string("cake_id"))", #"{"is_active":false}"#)
        let hiddenOrder = try await order(hiddenOne.string("cake_id"))
        XCTAssertEqual(hiddenOrder.errorCode, "PRODUCT_UNAVAILABLE")
    }
}
