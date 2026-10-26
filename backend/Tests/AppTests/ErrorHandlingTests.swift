import XCTVapor
import Logging
import BanhContracts
@testable import App

final class ErrorHandlingTests: XCTestCase {
    private var app: Application!
    private let capture = LogCapture()

    override func setUp() async throws {
        app = try await Application.make(.testing)
        app.logger = capture.makeLogger()
        try await configure(app, config: AppConfig(stage: .local, port: 8080, databaseURL: nil))
        app.get("raises-api-error") { _ -> String in throw APIError(.dateCapacity) }
        app.get("raises-unexpected") { _ -> String in throw DatabaseProbeError() }
        app.post("echo") { _ -> String in "ok" }
        app.get("rate-limited") { _ -> String in throw APIError.rateLimited(retryAfterSeconds: 30) }
        app.get("rate-limited-bare") { _ -> String in throw APIError(.rateLimited) }
        app.get("rate-limited-abort") { _ -> String in
            throw Abort(.tooManyRequests, headers: [HTTPHeaders.Name.retryAfter.description: "7"])
        }
        app.get("abort-429") { _ -> String in throw Abort(.tooManyRequests) }
    }

    override func tearDown() async throws {
        try await app.asyncShutdown()
    }

    private func fixture(_ name: String) throws -> APIErrorResponse {
        let data = try Data(contentsOf: TestPaths.contractFixtures.appendingPathComponent(name))
        return try JSONDecoder().decode(APIErrorResponse.self, from: data)
    }

    func testUnknownPathReturnsContractBody() async throws {
        try await app.test(.GET, "nope") { res async throws in
            XCTAssertEqual(res.status, .notFound)
            let body = try res.content.decode(APIErrorResponse.self)
            XCTAssertEqual(body.error, try self.fixture("error-not-found.json").error)
            XCTAssertEqual(res.headers.first(name: RequestIDLog.headerName), body.requestID)
            XCTAssertNotNil(UUID(uuidString: body.requestID))
        }
    }

    func testWrongMethodReturnsContractBody() async throws {
        try await app.test(.POST, "healthz") { res async throws in
            // Vapor answers an unmatched method on a known path with 404;
            // either way the body must be the contract envelope.
            XCTAssertTrue([.notFound, .methodNotAllowed].contains(res.status))
            XCTAssertNoThrow(try res.content.decode(APIErrorResponse.self))
        }
    }

    func testAPIErrorKeepsItsCodeStatusAndKey() async throws {
        try await app.test(.GET, "raises-api-error") { res async throws in
            XCTAssertEqual(res.status, .conflict)
            XCTAssertEqual(try res.content.decode(APIErrorResponse.self).error, try self.fixture("error-date-capacity.json").error)
        }
    }

    func testUnexpectedErrorIsInternalErrorWithoutDetail() async throws {
        try await app.test(.GET, "raises-unexpected") { res async throws in
            XCTAssertEqual(res.status, .internalServerError)
            let body = try res.content.decode(APIErrorResponse.self)
            XCTAssertEqual(body.error.code, APIErrorCode.internalError.rawValue)
            XCTAssertEqual(body.error.details, [:])
            XCTAssertFalse(res.body.string.contains("DatabaseProbeError"))
        }
    }

    func testRequestIDIsGeneratedNotTrustedFromClient() async throws {
        var headers = HTTPHeaders()
        headers.add(name: RequestIDLog.headerName, value: "attacker\ninjected")
        try await app.test(.GET, "healthz", headers: headers) { res async throws in
            let id = try XCTUnwrap(res.headers.first(name: RequestIDLog.headerName))
            XCTAssertNotNil(UUID(uuidString: id))
        }
    }

    func testAccessLogHasRouteStatusAndRequestIDButNoQueryOrPath() async throws {
        try await app.test(.GET, "healthz?deep=0&phone=0912345678") { _ async throws in }
        try await app.test(.GET, "secret-typed-path") { _ async throws in }
        let access = capture.lines.filter { $0.message == "request" }
        XCTAssertEqual(access.count, 2)
        let health = try XCTUnwrap(access.first)
        XCTAssertEqual(health.metadata["route"], .string("/healthz"))
        XCTAssertEqual(health.metadata["method"], .string("GET"))
        XCTAssertNotNil(health.metadata[RequestIDLog.metadataKey])
        XCTAssertEqual(access.last?.metadata["route"], .string(AccessLogMiddleware.unmatchedRoute))
        let everything = capture.lines.map { "\($0.message) \($0.metadata)" }.joined()
        XCTAssertFalse(everything.contains("0912345678"))
        XCTAssertFalse(everything.contains("secret-typed-path"))
    }

    func testRateLimitedCarriesRetryAfterHeaderAndDetail() async throws {
        try await app.test(.GET, "rate-limited") { res async throws in
            XCTAssertEqual(res.status, .tooManyRequests)
            XCTAssertEqual(res.headers.first(name: .retryAfter), "30")
            let body = try res.content.decode(APIErrorResponse.self)
            XCTAssertEqual(body.error, try self.fixture("error-rate-limited.json").error)
        }
    }

    func testRateLimitedWithoutHintUsesTheDefault() async throws {
        let expected = String(APIError.defaultRetryAfterSeconds)
        for path in ["rate-limited-bare", "abort-429"] {
            try await app.test(.GET, path) { res async throws in
                XCTAssertEqual(res.headers.first(name: .retryAfter), expected, path)
                let details = try res.content.decode(APIErrorResponse.self).error.details
                XCTAssertEqual(details, [APIError.retryAfterDetailKey: .int(APIError.defaultRetryAfterSeconds)], path)
            }
        }
    }

    func testRateLimitedAbortKeepsItsOwnHint() async throws {
        try await app.test(.GET, "rate-limited-abort") { res async throws in
            XCTAssertEqual(res.headers.first(name: .retryAfter), "7")
            XCTAssertEqual(try res.content.decode(APIErrorResponse.self).error.details, [APIError.retryAfterDetailKey: .int(7)])
        }
    }

    func testOtherErrorsHaveNoRetryAfter() async throws {
        try await app.test(.GET, "raises-api-error") { res async throws in
            XCTAssertNil(res.headers.first(name: .retryAfter))
        }
    }

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

    private var accessLines: [(message: String, metadata: Logger.Metadata)] {
        capture.lines.filter { $0.message == "request" }
    }

    func testAccessLogRecordsErrorCodePlatformAndVersion() async throws {
        let headers: HTTPHeaders = [ClientHeaderLog.platformHeader: "ios", ClientHeaderLog.appVersionHeader: "1.12.3"]
        try await app.test(.GET, "raises-api-error", headers: headers) { _ async throws in }
        let line = try XCTUnwrap(accessLines.last)
        XCTAssertEqual(line.metadata["error_code"], .string("DATE_CAPACITY"))
        XCTAssertEqual(line.metadata["platform"], .string("ios"))
        XCTAssertEqual(line.metadata["app_version"], .string("1.12.3"))
    }

    func testAccessLogUsesDashWhenThereIsNoErrorOrHeader() async throws {
        try await app.test(.GET, "healthz") { _ async throws in }
        let line = try XCTUnwrap(accessLines.last)
        XCTAssertEqual(line.metadata["error_code"], .string(ClientHeaderLog.absent))
        XCTAssertEqual(line.metadata["platform"], .string(ClientHeaderLog.absent))
        XCTAssertEqual(line.metadata["app_version"], .string(ClientHeaderLog.absent))
    }

    func testAccessLogDropsHostileOrMalformedClientHeaders() async throws {
        let hostile = [
            "ios\n{\"level\":\"error\",\"msg\":\"forged\"}",
            "ios\r\nX: y",
            "IOS",
            "windows",
            String(repeating: "a", count: 4_000)
        ]
        for value in hostile {
            let headers: HTTPHeaders = [ClientHeaderLog.platformHeader: value, ClientHeaderLog.appVersionHeader: value]
            try await app.test(.GET, "healthz", headers: headers) { _ async throws in }
        }
        let versions = ["1.0", "1.0.0-beta", "1.0.0\nforged", "v1.0.0", "1.0.0 ", "123456.0.0", "1.0.0.0"]
        for value in versions {
            try await app.test(.GET, "healthz", headers: [ClientHeaderLog.appVersionHeader: value]) { _ async throws in }
        }
        XCTAssertEqual(accessLines.count, hostile.count + versions.count)
        for line in accessLines {
            XCTAssertEqual(line.metadata["platform"], .string(ClientHeaderLog.absent))
            XCTAssertEqual(line.metadata["app_version"], .string(ClientHeaderLog.absent))
        }
    }

    func testEveryCodeHasAConsistentStatusAndKey() {
        for code in APIErrorCode.allCases {
            XCTAssertFalse(code.messageKey.isEmpty)
            XCTAssertTrue((400...599).contains(Int(code.status.code)), code.rawValue)
        }
        XCTAssertEqual(APIErrorCode.dateCapacity.status, .conflict)
        XCTAssertEqual(APIErrorCode.minQty.status, .unprocessableEntity)
        XCTAssertEqual(APIErrorCode.priceChanged.messageKey, "MSG_PRICE_CHANGED")
        XCTAssertEqual(APIErrorCode.rateLimited.messageKey, "ERR_RATE_LIMITED")
        XCTAssertEqual(APIErrorCode.internalError.messageKey, APIErrorCode.genericMessageKey)
    }

    func testAbortMapping() {
        XCTAssertEqual(APIError.from(Abort(.payloadTooLarge)).code, .payloadTooLarge)
        XCTAssertEqual(APIError.from(Abort(.unprocessableEntity)).code, .validationFailed)
        XCTAssertEqual(APIError.from(Abort(.badGateway)).code, .internalError)
        XCTAssertEqual(APIError.from(DatabaseProbeError()).code, .internalError)
    }
}
