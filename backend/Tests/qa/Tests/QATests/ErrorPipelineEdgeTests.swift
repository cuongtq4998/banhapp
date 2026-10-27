import XCTest
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import XCTVapor
import NIOConcurrencyHelpers
@testable import AppUnderTest

// MARK: - Error middleware and body limit

final class ErrorPipelineEdgeTests: ErrorPipelineBase {

    func testUnexpectedErrorIsInternalErrorAndNothingLeaks() async throws {
        try await app.test(.GET, "qa/boom?name=Nguyen&phone=0900000000") { res async throws in
            XCTAssertEqual(res.status, .internalServerError)
            let env = try self.envelope(res)
            XCTAssertEqual(env.code, "INTERNAL_ERROR")
            XCTAssertFalse(env.raw.contains("hunter2"))
            XCTAssertEqual(res.headers.first(name: "X-Request-Id"), env.requestID)
        }
        let all = capture.lines.map { "\($0.message) \($0.metadata)" }.joined(separator: "\n")
        for forbidden in ["hunter2", "0900000000", "customer_order", "Nguyen", "phone="] {
            XCTAssertFalse(all.contains(forbidden), "log leaks \(forbidden)")
        }
    }

    func testCancellationErrorIsAnInternalError() async throws {
        try await app.test(.GET, "qa/cancel") { res async throws in
            XCTAssertEqual(res.status, .internalServerError)
            XCTAssertEqual(try self.envelope(res).code, "INTERNAL_ERROR")
        }
    }

    func testAbortStatusTable() async throws {
        let expected: [(UInt, HTTPResponseStatus, String)] = [
            (400, .unprocessableEntity, "VALIDATION_FAILED"),
            (404, .notFound, "NOT_FOUND"),
            (405, .methodNotAllowed, "METHOD_NOT_ALLOWED"),
            (413, .payloadTooLarge, "PAYLOAD_TOO_LARGE"),
            (415, .unprocessableEntity, "VALIDATION_FAILED"),
            (422, .unprocessableEntity, "VALIDATION_FAILED"),
            (429, .tooManyRequests, "RATE_LIMITED"),
            (500, .internalServerError, "INTERNAL_ERROR"),
            (502, .internalServerError, "INTERNAL_ERROR"),
            (503, .serviceUnavailable, "SERVICE_UNAVAILABLE"),
            (504, .internalServerError, "INTERNAL_ERROR")
        ]
        for (code, status, name) in expected {
            try await app.test(.GET, "qa/abort/\(code)") { res async throws in
                XCTAssertEqual(res.status, status, "abort \(code)")
                let env = try self.envelope(res)
                XCTAssertEqual(env.code, name, "abort \(code)")
                XCTAssertFalse(env.raw.contains("hunter2"), "abort reason must not leak (\(code))")
            }
        }
    }

    /// 401, 403, 408, 409 and 410 are not in the catalogue; the documented rule
    /// is "other 4xx are VALIDATION_FAILED". Recorded so a change is noticed.
    func testOtherClientErrorsFollowTheDocumentedRule() async throws {
        for code in [401, 403, 408, 409, 410, 418] {
            try await app.test(.GET, "qa/abort/\(code)") { res async throws in
                XCTAssertEqual(try self.envelope(res).code, "VALIDATION_FAILED", "\(code)")
            }
        }
    }

    func testRetryAfterHintVariants() async throws {
        let cases: [(hint: String, header: String)] = [
            ("5", "5"), ("0", "0"), ("abc", "60"), ("", "60"), ("1.5", "60")
        ]
        for (hint, header) in cases {
            try await app.test(.GET, "qa/abort/429?retry=\(hint)") { res async throws in
                XCTAssertEqual(res.headers.first(name: .retryAfter), header, "hint \(hint)")
            }
        }
    }

    /// A negative or absurd upstream hint must not be forwarded as is.
    func testDefectRetryAfterHintIsSane() async throws {
        for hint in ["-5", "99999999999"] {
            try await app.test(.GET, "qa/abort/429?retry=\(hint)") { res async throws in
                let value = Int(res.headers.first(name: .retryAfter) ?? "") ?? -1
                XCTAssertTrue((0...3600).contains(value), "Retry-After \(hint) forwarded as \(value)")
            }
        }
    }

    func testMalformedJsonBodyIsValidationFailed() async throws {
        try await app.test(.POST, "qa/decode", headers: ["Content-Type": "application/json"], body: ByteBuffer(string: "{not json")) { res async throws in
            XCTAssertEqual(res.status, .unprocessableEntity)
            XCTAssertEqual(try self.envelope(res).code, "VALIDATION_FAILED")
        }
        try await app.test(.POST, "qa/decode", headers: ["Content-Type": "application/json"], body: ByteBuffer(string: "{\"name\": 5}")) { res async throws in
            XCTAssertEqual(try self.envelope(res).code, "VALIDATION_FAILED")
        }
        try await app.test(.POST, "qa/decode", headers: ["Content-Type": "text/plain"], body: ByteBuffer(string: "x")) { res async throws in
            XCTAssertEqual(res.status, .unprocessableEntity)
        }
    }

    // ---- body limit ----

    /// The in-memory client skips the HTTP layer that enforces the limit, so
    /// this goes through Vapor's own live-server tester.
    func testBodyLimitBoundaryThroughTheLiveTester() async throws {
        let limit = RequestLimits.maxBodyBytes
        XCTAssertEqual(limit, 8_192)
        let tester = try app.testable(method: .running(port: 0))
        for (size, status) in [(0, HTTPResponseStatus.ok), (1, .ok), (limit - 1, .ok), (limit, .ok), (limit + 1, .payloadTooLarge), (limit * 4, .payloadTooLarge)] {
            try await tester.test(.POST, "qa/echo", beforeRequest: { $0.body = ByteBuffer(repeating: 0x61, count: size) }) { res async throws in
                XCTAssertEqual(res.status, status, "body of \(size) bytes")
                if status == .payloadTooLarge {
                    let env = try self.envelope(res)
                    XCTAssertEqual(env.code, "PAYLOAD_TOO_LARGE")
                    XCTAssertEqual(res.headers.first(name: "X-Request-Id"), env.requestID)
                } else {
                    XCTAssertEqual(String(buffer: res.body), String(size))
                }
            }
        }
    }

    func testBodyLimitOverRealHttpWithContentLengthAndChunked() async throws {
        try await app.startup()
        let port = try XCTUnwrap(app.http.server.shared.localAddress?.port)
        let url = try XCTUnwrap(URL(string: "http://127.0.0.1:\(port)/qa/echo"))
        let limit = RequestLimits.maxBodyBytes

        func send(_ size: Int, chunked: Bool) async throws -> Int {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
            let payload = Data(repeating: 0x61, count: size)
            if chunked {
                let stream = InputStream(data: payload)
                request.httpBodyStream = stream
                let (_, response) = try await URLSession.shared.data(for: request)
                return (response as! HTTPURLResponse).statusCode
            }
            let (_, response) = try await URLSession.shared.upload(for: request, from: payload)
            return (response as! HTTPURLResponse).statusCode
        }

        for chunked in [false, true] {
            let atLimit = try await send(limit, chunked: chunked)
            let over = try await send(limit + 1, chunked: chunked)
            XCTAssertEqual(atLimit, 200, "exactly 8 KB, chunked=\(chunked)")
            XCTAssertEqual(over, 413, "8 KB + 1, chunked=\(chunked)")
        }
    }

    // ---- routing ----

    /// api.md v1.5 section 5: an unrouted method and path pair answers 404 NOT_FOUND (405 only when raised by framework or handler).
    func testWrongMethodOnExistingPathIsNotFound() async throws {
        for method in [HTTPMethod.POST, .PUT, .DELETE, .PATCH] {
            try await app.test(method, "healthz") { res async throws in
                XCTAssertEqual(res.status, .notFound, "\(method)")
                XCTAssertEqual(try self.envelope(res).code, "NOT_FOUND")
            }
        }
    }

    func testUnknownPathsReturnTheEnvelope() async throws {
        for path in ["nothing", "v1/orders", "healthz/extra", "%00", "a%2Fb", String(repeating: "a", count: 4000)] {
            try await app.test(.GET, path) { res async throws in
                XCTAssertEqual(res.status, .notFound, path.prefix(20).description)
                XCTAssertEqual(try self.envelope(res).code, "NOT_FOUND")
            }
        }
    }

    // ---- request id ----

}
