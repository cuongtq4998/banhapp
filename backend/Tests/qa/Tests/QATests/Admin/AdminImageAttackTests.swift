import XCTest
import Vapor
@testable import AppUnderTest

/// Cake picture upload attacks (FR-21, ADR-0025) over real HTTP: TC-B107 to TC-B121 area.
final class AdminImageAttackTests: AdminQABase {
    private var fields: [String: String] { ["name": "Banh QA \(UUID().uuidString.prefix(6))", "description": "Mo ta", "price_vnd": "150000"] }

    private func upload(_ phone: QAPhone, fields: [String: String]? = nil, files: [(name: String, type: String, data: Data)]) async throws -> QAReply {
        let form = QAImages.multipart(fields: fields ?? self.fields, files: files)
        return try await client.send("POST", "v1/owner/cakes", token: phone.access, rawBody: form.body, contentType: form.type)
    }

    private func cakeCount() async throws -> Int {
        try await count("SELECT count(*)::int AS n FROM product WHERE shop_id = \(bind: shopID) AND removed_at IS NULL")
    }

    func testTCB110_ValidPngAndJpegAreAcceptedAndServedWithSafeHeaders() async throws {
        let phone = try await owner()
        for (type, data) in [("image/png", QAImages.png()), ("image/jpeg", QAImages.jpeg())] {
            let reply = try await upload(phone, files: [("cake", type, data)])
            XCTAssertEqual(reply.status, 201, reply.text)
            let cake = reply.json["cake"] as? [String: Any] ?? reply.json
            let url = (cake["image_url"] as? String) ?? ""
            XCTAssertTrue(url.hasPrefix("/assets/cakes/"), url)
            let image = try await client.send("GET", String(url.dropFirst()))
            XCTAssertEqual(image.status, 200)
            XCTAssertEqual(image.data, data)
            XCTAssertEqual(image.header("X-Content-Type-Options"), "nosniff")
            XCTAssertEqual(image.header("Content-Type"), type)
        }
    }

    func testTCB111_WrongSignatureZeroByteAndTextAreRefusedWithNothingStored() async throws {
        let phone = try await owner()
        let before = try await cakeCount()
        let attacks: [(String, Data, String)] = [
            ("zero byte", Data(), "IMAGE_REQUIRED"),
            ("gif as png", Data("GIF89a".utf8) + Data(repeating: 0, count: 100), "IMAGE_TYPE_UNSUPPORTED"),
            ("html as jpeg", Data("<html><script>alert(1)</script></html>".utf8), "IMAGE_TYPE_UNSUPPORTED"),
            ("svg", Data("<svg xmlns='http://www.w3.org/2000/svg'><script>alert(1)</script></svg>".utf8), "IMAGE_TYPE_UNSUPPORTED"),
            ("exe", Data([0x4D, 0x5A, 0x90, 0x00]) + Data(repeating: 1, count: 64), "IMAGE_TYPE_UNSUPPORTED"),
            ("png signature only", Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]), "IMAGE_TYPE_UNSUPPORTED"),
            ("jpeg soi only", Data([0xFF, 0xD8, 0xFF]), "IMAGE_TYPE_UNSUPPORTED"),
            ("truncated ihdr", QAImages.png().prefix(20), "IMAGE_TYPE_UNSUPPORTED")
        ]
        for (label, data, code) in attacks {
            for type in ["image/png", "image/jpeg"] {
                let reply = try await upload(phone, files: [("evil.png", type, Data(data))])
                XCTAssertEqual(reply.status, 422, "\(label) as \(type): \(reply.text)")
                XCTAssertTrue(reply.fieldCodes.contains(code), "\(label) as \(type): \(reply.fieldCodes)")
            }
        }
        let after = try await cakeCount()
        XCTAssertEqual(after, before, "an error stores nothing")
    }

    func testTCB112_DimensionsOutsideTheRangeAreRefused() async throws {
        let phone = try await owner()
        let bad: [(UInt32, UInt32)] = [(0, 0), (199, 600), (600, 199), (4_097, 600), (600, 4_097), (65_535, 65_535), (0xFFFF_FFFF, 0xFFFF_FFFF), (1, 1)]
        for (w, h) in bad {
            let reply = try await upload(phone, files: [("x.png", "image/png", QAImages.png(width: w, height: h))])
            XCTAssertEqual(reply.status, 422, "png \(w)x\(h): \(reply.text)")
            XCTAssertTrue(reply.fieldCodes.contains("IMAGE_DIMENSIONS_INVALID"), "png \(w)x\(h): \(reply.fieldCodes)")
        }
        for (w, h) in [(UInt16(199), UInt16(300)), (4_097, 300), (65_535, 65_535), (0, 0)] {
            let reply = try await upload(phone, files: [("x.jpg", "image/jpeg", QAImages.jpeg(width: w, height: h))])
            XCTAssertEqual(reply.status, 422, "jpeg \(w)x\(h): \(reply.text)")
        }
        // Boundaries are accepted.
        for (w, h) in [(UInt32(200), UInt32(200)), (4_096, 4_096)] {
            let reply = try await upload(phone, files: [("x.png", "image/png", QAImages.png(width: w, height: h))])
            XCTAssertEqual(reply.status, 201, "png \(w)x\(h): \(reply.text)")
        }
    }

    func testTCB113_PolyglotIsStoredAsPictureButNeverServedAsAnythingElse() async throws {
        let phone = try await owner()
        let script = Data("<script>alert('qa')</script><?php echo 1; ?>".utf8)
        let polyglot = QAImages.png() + script
        let reply = try await upload(phone, files: [("shell.php.png", "text/html", polyglot)])
        XCTAssertEqual(reply.status, 201, "signature and header are valid; content is not decoded: \(reply.text)")
        let cake = reply.json["cake"] as? [String: Any] ?? reply.json
        let url = String((cake["image_url"] as? String ?? "").dropFirst())
        let image = try await client.send("GET", url)
        XCTAssertEqual(image.header("Content-Type"), "image/png", "type comes from the signature, not from the client's header")
        XCTAssertEqual(image.header("X-Content-Type-Options"), "nosniff")
        XCTAssertFalse(reply.text.contains("shell.php"), "the client file name is never stored or echoed")
    }

    func testTCB114_SizeLimitsAndTwoFilesAndMissingImage() async throws {
        let phone = try await owner()
        let atLimit = QAImages.png(pad: 5_242_880 - QAImages.png().count)
        XCTAssertEqual(atLimit.count, 5_242_880)
        let ok = try await upload(phone, files: [("big.png", "image/png", atLimit)])
        XCTAssertEqual(ok.status, 201, String(ok.text.prefix(300)))
        let over = try await upload(phone, files: [("big.png", "image/png", atLimit + Data([0]))])
        XCTAssertEqual(over.status, 413)
        XCTAssertEqual(over.errorCode, "IMAGE_TOO_LARGE")
        let two = try await upload(phone, files: [("a.png", "image/png", QAImages.png()), ("b.png", "image/png", QAImages.png())])
        XCTAssertEqual(two.status, 422)
        XCTAssertTrue(two.fieldCodes.contains("IMAGE_INVALID"), two.text)
        let none = try await upload(phone, files: [])
        XCTAssertEqual(none.status, 422)
        XCTAssertTrue(none.fieldCodes.contains("IMAGE_REQUIRED"))
        // Several problems are listed together (name empty, price text, no image).
        let many = try await upload(phone, fields: ["name": "", "description": "", "price_vnd": "abc"], files: [])
        XCTAssertEqual(many.status, 422)
        XCTAssertGreaterThanOrEqual(many.fieldCodes.count, 3, many.text)
    }

    /// 413 before the body is read: a declared 6 MB with no body returns at once; the role is checked first.
    func testTCB115_OversizedContentLengthIsRefusedBeforeTheBodyIsRead() async throws {
        let ownerPhone = try await owner()
        let member = try await staff()
        func head(_ token: String?, length: Int) -> String {
            "POST /v1/owner/cakes HTTP/1.1\r\nHost: 127.0.0.1\r\nX-Platform: ios\r\nX-App-Version: 1.0.0\r\n" + (token.map { "Authorization: Bearer \($0)\r\n" } ?? "")
                + "Content-Type: multipart/form-data; boundary=x\r\nContent-Length: \(length)\r\nConnection: close\r\n\r\n"
        }
        // The server answers once the first bytes of the body arrive (a bare head gets no answer; that is the
        // transport, not the route), so every probe sends ten bytes of a body that announces six megabytes.
        let tenBytes = Data(repeating: 0x41, count: 10)
        let owned = client.rawStatus(head: head(ownerPhone.access, length: 6_000_000), body: tenBytes)
        XCTAssertEqual(owned.status, 413)
        XCTAssertLessThan(owned.seconds, 3, "refused without waiting for 6 MB")
        let boundary = client.rawStatus(head: head(ownerPhone.access, length: 5_308_417), body: tenBytes)
        XCTAssertEqual(boundary.status, 413, "one byte over 5,308,416")
        XCTAssertEqual(client.rawStatus(head: head(member.phone.access, length: 6_000_000), body: tenBytes).status, 403, "role first")
        XCTAssertEqual(client.rawStatus(head: head(nil, length: 6_000_000), body: tenBytes).status, 401, "authentication first")
        let negative = client.rawStatus(head: head(nil, length: 6_000_000).replacingOccurrences(of: "Content-Length: 6000000", with: "Content-Length: -5"), body: tenBytes).status
        XCTAssertTrue(negative == nil || (400..<500).contains(negative!), "malformed length: closed or 4xx, got \(String(describing: negative))")
        // Any other admin route keeps the 8 KB limit.
        let small = try await client.send("PUT", "v1/owner/settings/shop", token: ownerPhone.access, rawBody: Data(repeating: 0x20, count: 9_000), contentType: "application/json")
        XCTAssertEqual(small.status, 413)
        // Not multipart, and a truncated multipart body, are refused cleanly.
        let json = try await client.send("POST", "v1/owner/cakes", token: ownerPhone.access, json: ["name": "x"])
        XCTAssertEqual(json.status, 422)
        let truncated = Data("--b\r\nContent-Disposition: form-data; name=\"name\"\r\n\r\nabc".utf8)
        let cut = try await client.send("POST", "v1/owner/cakes", token: ownerPhone.access, rawBody: truncated, contentType: "multipart/form-data; boundary=b")
        XCTAssertTrue((400..<500).contains(cut.status), "truncated multipart -> \(cut.status)")
    }
}
