import XCTVapor
@testable import App

/// Adding a cake (api/07 10.17): fields, the picture rules of ADR-0025, the
/// limit of 12 and the all-or-nothing rule (BR-11, BR-12).
final class OwnerCakeCreateTests: OwnerCakeTestCase {
    private func assertNothingStored(_ message: String, file: StaticString = #filePath, line: UInt = #line) async throws {
        let live = try await liveCakes(), stored = try await images(), changes = try await changeRows("cake")
        XCTAssertEqual([live, stored, changes], [1, 0, 0], message, file: file, line: line)
    }

    func testAddingACakeStoresItWithItsPictureAndListsItAtOnce() async throws {
        let bytes = TestImages.jpeg(width: 600, height: 400)
        let reply = try await upload(fields("  Banh Dau  "), files: [("image", bytes)])
        XCTAssertEqual(reply.status, .created, String(decoding: reply.data, as: UTF8.self))
        XCTAssertEqual(reply.string("name"), "Banh Dau")
        XCTAssertEqual(reply.json["is_active"] as? Bool, true)
        XCTAssertEqual(reply.json["price_vnd"] as? Int, 50_000)
        let id = reply.string("cake_id")
        XCTAssertNotNil(reply.string("image_url").range(of: "^/assets/cakes/\(id.lowercased())\\?v=[0-9a-f]{8}$", options: .regularExpression), reply.string("image_url"))
        let listed = list("cakes", in: try await call(.GET, "v1/owner/settings"))
        XCTAssertEqual(listed.compactMap { $0["name"] as? String }, ["Banh Mau", "Banh Dau"])
        let stored = try await images(), changes = try await changeRows("cake")
        XCTAssertEqual(stored, 1)
        XCTAssertEqual(changes, 4)
        let sha = try await sql.raw("SELECT sha256, octet_length(bytes) AS n, width, height, content_type FROM product_image WHERE product_id = \(bind: UUID(uuidString: id)!)").first()
        XCTAssertEqual(try sha?.decode(column: "n", as: Int.self), bytes.count)
        XCTAssertEqual(try sha?.decode(column: "content_type", as: String.self), "image/jpeg")
        XCTAssertEqual([try sha?.decode(column: "width", as: Int.self), try sha?.decode(column: "height", as: Int.self)], [600, 400])
        XCTAssertTrue(reply.string("image_url").hasSuffix("?v=" + (try XCTUnwrap(sha).decode(column: "sha256", as: String.self).prefix(8))))
    }

    func testAPngIsAcceptedAndKeepsItsType() async throws {
        let reply = try await upload(fields(), files: [("image", TestImages.png(width: 200, height: 4_096))])
        XCTAssertEqual(reply.status, .created)
        let type = try await sql.raw("SELECT content_type FROM product_image WHERE product_id = \(bind: UUID(uuidString: reply.string("cake_id"))!)").first()?.decode(column: "content_type", as: String.self)
        XCTAssertEqual(type, "image/png")
    }

    func testThePictureRulesRefuseAndStoreNothing() async throws {
        let gif = Array("GIF89a".utf8) + [UInt8](repeating: 0, count: 100)
        let html = Array("<html><script>alert(1)</script></html>".utf8)
        let webp = Array("RIFF".utf8) + [0, 0, 0, 0] + Array("WEBP".utf8) + [UInt8](repeating: 0, count: 64)
        let cases: [(String, [UInt8], String)] = [
            ("gif", gif, "IMAGE_TYPE_UNSUPPORTED"), ("html", html, "IMAGE_TYPE_UNSUPPORTED"), ("webp", webp, "IMAGE_TYPE_UNSUPPORTED"),
            ("png cut short", Array(TestImages.png(width: 600, height: 400).prefix(20)), "IMAGE_TYPE_UNSUPPORTED"),
            ("jpeg with no frame", [0xFF, 0xD8, 0xFF, 0xD9], "IMAGE_TYPE_UNSUPPORTED"),
            ("width 199", TestImages.jpeg(width: 199, height: 400), "IMAGE_DIMENSIONS_INVALID"),
            ("height 199", TestImages.png(width: 400, height: 199), "IMAGE_DIMENSIONS_INVALID"),
            ("width 4097", TestImages.jpeg(width: 4_097, height: 400), "IMAGE_DIMENSIONS_INVALID"),
            ("height 4097", TestImages.png(width: 400, height: 4_097), "IMAGE_DIMENSIONS_INVALID"),
            ("huge claimed size", TestImages.png(width: 60_000, height: 60_000), "IMAGE_DIMENSIONS_INVALID"),
            ("empty file", [], "IMAGE_REQUIRED")
        ]
        for (label, bytes, code) in cases {
            let reply = try await upload(fields(label), files: [("image", bytes)])
            XCTAssertEqual(reply.status, .unprocessableEntity, label)
            XCTAssertEqual(problems(reply), [code], label)
            try await assertNothingStored(label)
        }
    }

    func testAPictureOverFiveMegabytesIs413AndOneAtTheLimitPasses() async throws {
        let over = try await upload(fields("Over"), files: [("image", TestImages.jpeg(width: 600, height: 400, padTo: ImageInspector.maxBytes + 1))])
        XCTAssertEqual(over.status, .payloadTooLarge)
        XCTAssertEqual(over.errorCode, "IMAGE_TOO_LARGE")
        try await assertNothingStored("over")
        let exact = try await upload(fields("Exact"), files: [("image", TestImages.jpeg(width: 600, height: 400, padTo: ImageInspector.maxBytes))])
        XCTAssertEqual(exact.status, .created)
        let size = try await sql.raw("SELECT octet_length(bytes) AS n FROM product_image WHERE product_id = \(bind: UUID(uuidString: exact.string("cake_id"))!)").first()?.decode(column: "n", as: Int.self)
        XCTAssertEqual(size, ImageInspector.maxBytes)
    }

    func testMissingAndDoubleImagesAreRefused() async throws {
        let none = try await upload(fields(), files: [])
        XCTAssertEqual(problems(none), ["IMAGE_REQUIRED"])
        let text = try await upload(fields() + [("image", "not a file")], files: [])
        XCTAssertEqual(problems(text), ["IMAGE_REQUIRED"])
        let other = try await upload(fields(), files: [("photo", TestImages.jpeg(width: 600, height: 400))])
        XCTAssertEqual(problems(other), ["IMAGE_REQUIRED"])
        let jpeg = TestImages.jpeg(width: 600, height: 400)
        let two = try await upload(fields(), files: [("image", jpeg), ("image", jpeg)])
        XCTAssertEqual(two.status, .unprocessableEntity)
        XCTAssertEqual(problems(two), ["IMAGE_INVALID"])
        try await assertNothingStored("no or two images")
    }

    func testEveryProblemOfTheFormIsListed() async throws {
        let long = String(repeating: "x", count: 101)
        let reply = try await upload([("name", ""), ("description", String(repeating: "d", count: 301)), ("price_vnd", "0"), ("colour", "red")], files: [("image", [1, 2, 3])])
        XCTAssertEqual(problems(reply), ["FIELD_UNKNOWN", "NAME_REQUIRED", "DESCRIPTION_TOO_LONG", "PRICE_VND_OUT_OF_RANGE", "IMAGE_TYPE_UNSUPPORTED"])
        let words = try await upload([("name", long), ("description", "d"), ("price_vnd", "ten")], files: [("image", TestImages.jpeg(width: 600, height: 400))])
        XCTAssertEqual(problems(words), ["NAME_TOO_LONG", "PRICE_VND_INVALID"])
        let high = try await upload([("name", "N"), ("description", "d"), ("price_vnd", "100000001")], files: [("image", TestImages.jpeg(width: 600, height: 400))])
        XCTAssertEqual(problems(high), ["PRICE_VND_OUT_OF_RANGE"])
        let notMultipart = try await call(.POST, "v1/owner/cakes", #"{"name":"x"}"#)
        XCTAssertEqual(notMultipart.errorCode, "VALIDATION_FAILED")
        try await assertNothingStored("form problems")
    }

    func testANameIsUniqueIgnoringCaseAmongCakesNotRemoved() async throws {
        let taken = try await addCake("BANH MAU")
        XCTAssertEqual(taken.status, .unprocessableEntity)
        XCTAssertEqual(problems(taken), ["NAME_TAKEN"])
        try await assertNothingStored("name taken")
        let other = try await addCake("Banh Khac")
        XCTAssertEqual(other.status, .created)
        let removed = try await call(.DELETE, "v1/owner/cakes/\(other.string("cake_id"))")
        XCTAssertEqual(removed.status, .noContent)
        let again = try await addCake("banh khac")
        XCTAssertEqual(again.status, .created, "a removed cake frees its name")
    }

    func testTheThirteenthCakeIsRefusedAndRemovedCakesDoNotCount() async throws {
        for index in 2...12 { let reply = try await addCake("Cake \(index)"); XCTAssertEqual(reply.status, .created, "\(index)") }
        let refused = try await addCake("Cake 13")
        XCTAssertEqual(refused.status, .conflict)
        XCTAssertEqual(refused.errorCode, "CAKE_LIMIT_REACHED")
        let live = try await liveCakes(), stored = try await images()
        XCTAssertEqual([live, stored], [12, 11])
        let first = list("cakes", in: try await call(.GET, "v1/owner/settings")).last?["cake_id"] as? String
        let removed = try await call(.DELETE, "v1/owner/cakes/\(try XCTUnwrap(first))")
        XCTAssertEqual(removed.status, .noContent)
        let fits = try await addCake("Cake 14")
        XCTAssertEqual(fits.status, .created)
        let max = (try await call(.GET, "v1/owner/settings")).json["cake_count_max"] as? Int
        XCTAssertEqual(max, 12)
    }

    func testTwoAddsAtElevenCakesLetExactlyOneWin() async throws {
        for index in 0..<10 {
            try await run("INSERT INTO product (shop_id, slug, name, description, price_vnd, image_path) VALUES (\(bind: shopID), \(bind: "s\(index)"), \(bind: "Seed \(index)"), 'd', 1000, 'images/banana.png')")
        }
        let live = try await liveCakes()
        XCTAssertEqual(live, 11)
        let (app, access) = (app!, ownerPhone.access)
        let replies = try await withThrowingTaskGroup(of: Reply.self) { group in
            for name in ["Racer A", "Racer B"] {
                group.addTask {
                    var body = MultipartBody()
                    body.text("name", name); body.text("description", "d"); body.text("price_vnd", "1000")
                    body.file("image", TestImages.jpeg(width: 600, height: 400))
                    return try await Self.upload(app, body, access: access)
                }
            }
            return try await group.reduce(into: []) { $0.append($1) }
        }
        XCTAssertEqual(replies.map(\.status.code).sorted(), [201, 409])
        XCTAssertEqual(replies.compactMap(\.errorCode), ["CAKE_LIMIT_REACHED"])
        let after = try await liveCakes(), stored = try await images()
        XCTAssertEqual([after, stored], [12, 1])
    }

    func testStaffAndStrangersAreRefusedBeforeAnythingIsRead() async throws {
        let staff = try await upload(fields(), files: [("image", TestImages.jpeg(width: 600, height: 400))], as: staffPhone)
        XCTAssertEqual(staff.status, .forbidden)
        XCTAssertEqual(staff.errorCode, "FORBIDDEN")
        let stranger = try await send(.POST, "v1/owner/cakes")
        XCTAssertEqual(stranger.status, .unauthorized)
        try await assertNothingStored("staff")
    }
}
