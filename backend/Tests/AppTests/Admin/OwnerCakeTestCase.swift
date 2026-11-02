import XCTVapor
import Foundation
@testable import App

/// Shared setup of the cake tests: the owner shop of `OwnerSettingsTestCase`
/// (one cake, "Banh Mau", from the sample files) and an upload helper.
class OwnerCakeTestCase: OwnerSettingsTestCase {
    var staffPhone: Phone!

    override func setUp() async throws {
        try await super.setUp()
        staffPhone = try await signedIn(try await addAccount(.staff, "Nhan Vien").email)
    }

    /// `POST /v1/owner/cakes` with the given text fields and files (name, bytes).
    func upload(_ fields: [(String, String)], files: [(String, [UInt8])], as phone: Phone? = nil) async throws -> Reply {
        var body = MultipartBody()
        for (name, value) in fields { body.text(name, value) }
        for (name, bytes) in files { body.file(name, bytes) }
        return try await Self.upload(app, body, access: (phone ?? ownerPhone).access)
    }

    /// Static so parallel tasks can call it without capturing the test case.
    static func upload(_ app: Application, _ body: MultipartBody, access: String) async throws -> Reply {
        let box = LockedBox<Reply?>(nil)
        let headers: HTTPHeaders = ["Authorization": "Bearer \(access)", "X-Platform": "ios", "X-App-Version": "1.0.0", "Content-Type": body.contentType]
        try await app.test(.POST, "v1/owner/cakes", headers: headers, body: ByteBuffer(data: body.closed), afterResponse: { res async throws in
            box.set(Reply(status: res.status, headers: res.headers, data: Data(res.body.readableBytesView)))
        })
        return try XCTUnwrap(box.value)
    }

    func fields(_ name: String = "Banh Dau", price: String = "50000") -> [(String, String)] {
        [("name", name), ("description", "Banh dau xanh"), ("price_vnd", price)]
    }

    func addCake(_ name: String) async throws -> Reply {
        try await upload(fields(name), files: [("image", TestImages.jpeg(width: 600, height: 400))])
    }

    /// Plain SQL rows for cakes of this shop that are not removed.
    func liveCakes() async throws -> Int {
        try await count("SELECT count(*)::int AS n FROM product WHERE shop_id = \(bind: shopID) AND removed_at IS NULL")
    }

    func images() async throws -> Int {
        try await count("SELECT count(*)::int AS n FROM product_image i JOIN product p ON p.id = i.product_id WHERE p.shop_id = \(bind: shopID)")
    }

    func get(_ path: String) async throws -> Reply {
        let box = LockedBox<Reply?>(nil)
        try await app.test(.GET, path, afterResponse: { res async throws in
            box.set(Reply(status: res.status, headers: res.headers, data: Data(res.body.readableBytesView)))
        })
        return try XCTUnwrap(box.value)
    }
}
