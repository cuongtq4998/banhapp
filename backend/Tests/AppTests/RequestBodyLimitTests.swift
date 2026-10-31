import XCTVapor
import Logging
import BanhContracts
@testable import App

final class RequestBodyLimitTests: ErrorHandlingTestCase {
    /// The in-memory test client skips the HTTP layer that enforces the body
    /// limit, so these two tests talk to a real listener on a free port.
    private func postOverLiveServer(bytes: Int, _ check: @escaping @Sendable (XCTHTTPResponse) throws -> Void) async throws {
        app.on(.POST, "collect", body: .collect) { _ -> String in "ok" }
        let body = ByteBuffer(repeating: UInt8(ascii: "a"), count: bytes)
        try await app.testable(method: .running(port: 0)).test(.POST, "collect", beforeRequest: { $0.body = body }) { res async throws in
            try check(res)
        }
    }

    func testOversizedBodyIsPayloadTooLarge() async throws {
        try await postOverLiveServer(bytes: RequestLimits.maxBodyBytes + 1) { res in
            XCTAssertEqual(res.status, .payloadTooLarge)
            let body = try res.content.decode(APIErrorResponse.self)
            XCTAssertEqual(body.error.code, APIErrorCode.payloadTooLarge.rawValue)
            XCTAssertEqual(body.error.messageKey, APIErrorCode.genericMessageKey)
        }
    }

    func testBodyAtTheLimitIsAccepted() async throws {
        try await postOverLiveServer(bytes: RequestLimits.maxBodyBytes) { res in
            XCTAssertEqual(res.status, .ok)
        }
    }
}
