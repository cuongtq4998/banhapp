import XCTVapor
@testable import App

/// The body limit of the one big route (api/05 section 9, ADR-0025): 5,308,416
/// bytes, refused on `Content-Length` after the role and before the body is read.
final class OwnerCakeUploadLimitTests: OwnerCakeTestCase {
    private let limit = RequestLimits.maxUploadBytes

    /// The in-memory test client skips the HTTP layer that streams and limits
    /// bodies, so the limit tests talk to a real listener on a free port.
    private func post(_ body: Data, to path: String = "v1/owner/cakes", access: String? = nil, type: String) async throws -> Reply {
        let box = LockedBox<Reply?>(nil)
        let headers: HTTPHeaders = ["Authorization": "Bearer \(access ?? ownerPhone.access)", "X-Platform": "ios", "X-App-Version": "1.0.0", "Content-Type": type]
        try await app.testable(method: .running(port: 0)).test(.POST, path, headers: headers, body: ByteBuffer(data: body), afterResponse: { res async throws in
            box.set(Reply(status: res.status, headers: res.headers, data: Data(res.body.readableBytesView)))
        })
        return try XCTUnwrap(box.value)
    }

    /// A form with a 5 MB picture and filler text, `extra` bytes bigger than the limit.
    private func bigForm(extra: Int) -> MultipartBody {
        var body = MultipartBody()
        body.text("name", "Banh Lon"); body.text("description", "d"); body.text("price_vnd", "1000")
        body.file("image", TestImages.jpeg(width: 600, height: 400, padTo: ImageInspector.maxBytes))
        let overhead = Data("--\(body.boundary)\r\nContent-Disposition: form-data; name=\"pad\"\r\n\r\n\r\n".utf8).count
        let closing = Data("--\(body.boundary)--\r\n".utf8).count
        body.text("pad", String(repeating: "p", count: limit + extra - body.data.count - overhead - closing))
        return body
    }

    func testAFivePictureWithItsFormPassesTheLimit() async throws {
        let reply = try await upload(fields("Banh Lon"), files: [("image", TestImages.jpeg(width: 600, height: 400, padTo: ImageInspector.maxBytes))])
        XCTAssertEqual(reply.status, .created, String(decoding: reply.data.prefix(300), as: UTF8.self))
    }

    func testTheBodyLimitIsExactToTheByte() async throws {
        let atLimit = bigForm(extra: 0)
        XCTAssertEqual(atLimit.closed.count, limit)
        let passes = try await post(atLimit.closed, type: atLimit.contentType)
        XCTAssertEqual(passes.status, .unprocessableEntity, "the size is fine; the unknown `pad` field is what fails")
        XCTAssertEqual(problems(passes), ["FIELD_UNKNOWN"])
        let over = bigForm(extra: 1)
        XCTAssertEqual(over.closed.count, limit + 1)
        let refused = try await post(over.closed, type: over.contentType)
        XCTAssertEqual(refused.status, .payloadTooLarge)
        XCTAssertEqual(refused.errorCode, "PAYLOAD_TOO_LARGE")
        let stored = try await liveCakes()
        XCTAssertEqual(stored, 1)
    }

    /// The guard answers from the header alone: the route behind it never runs.
    func testALargerDeclaredLengthIsRefusedBeforeTheBodyIsRead() async throws {
        struct MustNotRun: AsyncResponder {
            func respond(to request: Request) async throws -> Response { XCTFail("the body would be read"); return Response() }
        }
        for length in [limit + 1, 50_000_000] {
            let request = Request(application: app, method: .POST, url: "/v1/owner/cakes", headers: ["Content-Length": String(length)], on: app.eventLoopGroup.next())
            do {
                _ = try await UploadSizeGuard().respond(to: request, chainingTo: MustNotRun())
                XCTFail("accepted \(length)")
            } catch let error as APIError {
                XCTAssertEqual(error.code, .payloadTooLarge)
            }
        }
        let fine = Request(application: app, method: .POST, url: "/v1/owner/cakes", headers: ["Content-Length": String(limit)], on: app.eventLoopGroup.next())
        struct Passes: AsyncResponder { func respond(to request: Request) async throws -> Response { Response(status: .accepted) } }
        let passed = try await UploadSizeGuard().respond(to: fine, chainingTo: Passes())
        XCTAssertEqual(passed.status, .accepted)
    }

    func testTheRoleAndTheSessionAreCheckedBeforeTheLength() async throws {
        let big = bigForm(extra: 1)
        let staff = try await post(big.closed, access: staffPhone.access, type: big.contentType)
        XCTAssertEqual(staff.status, .forbidden)
        let stranger = try await post(big.closed, access: "at_nope", type: big.contentType)
        XCTAssertEqual(stranger.status, .unauthorized)
    }

    func testEveryOtherRouteKeepsTheSmallLimit() async throws {
        let big = String(repeating: "x", count: 9_000)
        let reply = try await post(Data(#"{"name":"\#(big)"}"#.utf8), to: "v1/owner/districts", type: "application/json")
        XCTAssertEqual(reply.status, .payloadTooLarge)
    }
}
