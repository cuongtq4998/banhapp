import XCTVapor
import BanhContracts
@testable import App

final class ErrorHandlingTests: XCTestCase {
    private var app: Application!
    private let capture = LogCapture()

    override func setUp() async throws {
        app = try await Application.make(.testing)
        app.logger = capture.makeLogger()
        try await configure(app, config: AppConfig(stage: .local, port: 8080, databaseURL: nil), migrationFiles: [])
        app.get("raises-api-error") { _ -> String in throw APIError(.dateCapacity) }
        app.get("raises-unexpected") { _ -> String in throw DatabaseProbeError() }
        app.post("echo") { _ -> String in "ok" }
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

    func testEveryCodeHasAConsistentStatusAndKey() {
        for code in APIErrorCode.allCases {
            XCTAssertFalse(code.messageKey.isEmpty)
            XCTAssertTrue((400...599).contains(Int(code.status.code)), code.rawValue)
        }
        XCTAssertEqual(APIErrorCode.dateCapacity.status, .conflict)
        XCTAssertEqual(APIErrorCode.minQty.status, .unprocessableEntity)
        XCTAssertEqual(APIErrorCode.priceChanged.messageKey, "MSG_PRICE_CHANGED")
        XCTAssertEqual(APIErrorCode.internalError.messageKey, APIErrorCode.genericMessageKey)
    }

    func testAbortMapping() {
        XCTAssertEqual(APIError.from(Abort(.payloadTooLarge)).code, .payloadTooLarge)
        XCTAssertEqual(APIError.from(Abort(.unprocessableEntity)).code, .validationFailed)
        XCTAssertEqual(APIError.from(Abort(.badGateway)).code, .internalError)
        XCTAssertEqual(APIError.from(DatabaseProbeError()).code, .internalError)
    }
}
