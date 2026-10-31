import XCTVapor
import Logging
import BanhContracts
@testable import App

final class AccessLogTests: ErrorHandlingTestCase {
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
}
