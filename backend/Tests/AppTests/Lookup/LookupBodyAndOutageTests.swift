import XCTVapor
import BanhContracts
@testable import App

/// Body limit through a live listener, and the database-down answer.
final class LookupBodyAndOutageTests: LookupRouteTestCase {
    private func padded(bytes: Int) -> ByteBuffer {
        let head = #"{"phone":"0900000001","pad":""#, tail = #""}"#
        let fill = String(repeating: "a", count: max(0, bytes - head.utf8.count - tail.utf8.count))
        return ByteBuffer(string: head + fill + tail)
    }

    private func status(bytes: Int) async throws -> HTTPStatus {
        let body = padded(bytes: bytes)
        var result = HTTPStatus.ok
        try await app.testable(method: .running(port: 0)).test(
            .POST, "v1/orders/lookup",
            beforeRequest: { $0.headers.contentType = .json; $0.body = body }
        ) { res async throws in result = res.status }
        return result
    }

    func testBodyOverTheLimitIsPayloadTooLarge() async throws {
        try await start()
        let result = try await status(bytes: RequestLimits.maxBodyBytes + 1)
        XCTAssertEqual(result, .payloadTooLarge)
        XCTAssertEqual(store.calls, 0)
    }

    func testBodyAtTheLimitReachesTheRoute() async throws {
        try await start()
        let result = try await status(bytes: RequestLimits.maxBodyBytes)
        XCTAssertEqual(result, .ok)
    }

    func testDatabaseDownIsThe503ShapeWithoutThePhoneInTheLog() async throws {
        // Real store against a closed port: no fake.
        let real = try await Application.make(.testing)
        defer { Task { try? await real.asyncShutdown() } }
        let realCapture = LogCapture()
        real.logger = realCapture.makeLogger()
        try await configure(real, config: .localWithShop())
        var tuned = LookupPolicy()
        tuned.floorMilliseconds = 0
        real.services.lookup = tuned
        real.services.lookupGuard = LookupGuard(policy: tuned)
        try await real.test(.POST, "v1/orders/lookup", headers: ["Content-Type": "application/json"],
                            body: ByteBuffer(string: #"{"phone":"0900000077"}"#)) { res async throws in
            XCTAssertEqual(res.status, .serviceUnavailable)
            let envelope = try res.content.decode(APIErrorResponse.self)
            XCTAssertEqual(envelope.error.code, "SERVICE_UNAVAILABLE")
            XCTAssertEqual(envelope.error.messageKey, "ERR_SERVER")
        }
        let log = realCapture.lines.map { "\($0.message) \($0.metadata)" }.joined()
        for needle in ["0900000077", "900000077"] { XCTAssertFalse(log.contains(needle), needle) }
    }
}
