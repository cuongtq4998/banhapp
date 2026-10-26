import XCTest
import XCTVapor
import Logging
import NIOConcurrencyHelpers
@testable import AppUnderTest

/// Round 2: adversarial cases for the refactored backend (error middleware,
/// access log, body limit, splitter, deadline race). Fake data only.

// MARK: - Log capture

private final class QALogCapture: @unchecked Sendable {
    // Invariant: `entries` is only touched under `lock`.
    private let lock = NIOLock()
    private var entries: [(message: String, metadata: Logger.Metadata)] = []
    var lines: [(message: String, metadata: Logger.Metadata)] { lock.withLock { entries } }
    func append(_ m: String, _ md: Logger.Metadata) { lock.withLock { entries.append((m, md)) } }
    func makeLogger() -> Logger { Logger(label: "qa") { _ in QAHandler(capture: self) } }
}

private struct QAHandler: LogHandler {
    let capture: QALogCapture
    var metadata: Logger.Metadata = [:]
    var logLevel: Logger.Level = .trace
    subscript(metadataKey key: String) -> Logger.Metadata.Value? {
        get { metadata[key] }
        set { metadata[key] = newValue }
    }
    func log(event: LogEvent) { capture.append("\(event.message)", metadata.merging(event.metadata ?? [:]) { $1 }) }
}

private struct SecretError: Error, CustomStringConvertible {
    var description: String { "SELECT * FROM customer_order WHERE phone='0900000000' password=hunter2" }
}

// MARK: - Error middleware, access log, body limit

final class ErrorPipelineEdgeTests: XCTestCase {
    private var app: Application!
    private let capture = QALogCapture()

    override func setUp() async throws {
        app = try await Application.make(.testing)
        app.logger = capture.makeLogger()
        try await configure(app, config: AppConfig(stage: .local, port: 8080, databaseURL: nil))
        // Registered after configure so they get the configured default body size.
        app.get("qa", "boom") { _ -> String in throw SecretError() }
        app.get("qa", "cancel") { _ -> String in throw CancellationError() }
        app.get("qa", "abort", ":code") { req -> String in
            let code = try XCTUnwrap(req.parameters.get("code", as: UInt.self))
            var headers = HTTPHeaders()
            if let hint = req.query[String.self, at: "retry"] { headers.add(name: .retryAfter, value: hint) }
            throw Abort(HTTPResponseStatus(statusCode: Int(code)), headers: headers, reason: "reason with hunter2")
        }
        app.on(.POST, "qa", "echo", body: .collect) { req -> String in String(req.body.data?.readableBytes ?? 0) }
        struct Payload: Content { let name: String }
        app.post("qa", "decode") { req -> String in try req.content.decode(Payload.self).name }
    }

    override func tearDown() async throws { try await app.asyncShutdown() }

    private func envelope(_ res: XCTHTTPResponse) throws -> (code: String, requestID: String, raw: String) {
        struct Env: Decodable {
            struct E: Decodable { let code: String }
            let error: E
            let request_id: String
        }
        let data = Data(res.body.readableBytesView)
        let env = try JSONDecoder().decode(Env.self, from: data)
        return (env.error.code, env.request_id, String(decoding: data, as: UTF8.self))
    }

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

    /// api.md section 5: "The path exists, the HTTP method does not" is 405.
    func testDefectWrongMethodOnExistingPathIsMethodNotAllowed() async throws {
        for method in [HTTPMethod.POST, .PUT, .DELETE, .PATCH] {
            try await app.test(method, "healthz") { res async throws in
                XCTAssertEqual(res.status, .methodNotAllowed, "\(method)")
                XCTAssertEqual(try self.envelope(res).code, "METHOD_NOT_ALLOWED")
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

    func testClientRequestIdIsIgnoredAndIdsAreUnique() async throws {
        let ids = NIOLockedValueBox(Set<String>())
        for _ in 0..<20 {
            try await app.test(.GET, "healthz", headers: ["X-Request-Id": "forged\nline"]) { res async throws in
                let id = try XCTUnwrap(res.headers.first(name: "X-Request-Id"))
                XCTAssertNotNil(UUID(uuidString: id))
                ids.withLockedValue { _ = $0.insert(id) }
            }
        }
        XCTAssertEqual(ids.withLockedValue { $0.count }, 20)
    }

    // ---- access log injection ----

    func testAccessLogNeverCarriesRawClientText() async throws {
        let hostile: [HTTPHeaders] = [
            ["X-Platform": "ios\r\nFORGED", "X-App-Version": "1.2.3 extra"],
            ["X-Platform": "IOS", "X-App-Version": "1.2.3\t"],
            ["X-Platform": "android", "X-App-Version": "123456.1.1"],
            ["X-Platform": "ios", "X-App-Version": "1.2.3.4"],
            ["X-Platform": "", "X-App-Version": ""],
            ["X-Platform": "iosandroid", "X-App-Version": "../../1.2.3"],
            ["X-Platform": "ios", "X-App-Version": "١.٢.٣"]
        ]
        for headers in hostile {
            try await app.test(.GET, "healthz?phone=0900000000&name=Nguyen", headers: headers) { _ async throws in }
        }
        try await app.test(.GET, "%0A%0Dforged%20line%20status=200") { _ async throws in }
        let lines = capture.lines.filter { $0.message == "request" }
        XCTAssertEqual(lines.count, hostile.count + 1, "exactly one access line per request")
        for line in lines {
            for (key, value) in line.metadata {
                let text = "\(value)"
                XCTAssertFalse(text.contains("\n") || text.contains("\r"), "\(key) holds a line break")
                XCTAssertFalse(text.contains("0900000000") || text.contains("Nguyen") || text.contains("forged"), "\(key) leaks client text")
            }
            XCTAssertTrue(["ios", "android", "-"].contains("\(line.metadata["platform"] ?? "")"))
        }
        XCTAssertEqual("\(lines.last?.metadata["route"] ?? "")", "-")
    }

    func testAccessLogCarriesErrorCodeStatusAndDuration() async throws {
        try await app.test(.GET, "qa/abort/429") { _ async throws in }
        let line = try XCTUnwrap(capture.lines.last { $0.message == "request" })
        XCTAssertEqual("\(line.metadata["error_code"] ?? "")", "RATE_LIMITED")
        XCTAssertEqual("\(line.metadata["status"] ?? "")", "429")
        XCTAssertNotNil(Int("\(line.metadata["duration_ms"] ?? "")"))
        XCTAssertEqual("\(line.metadata["route"] ?? "")", "/qa/abort/:code")
    }

    func testParallelRequestsKeepOneRequestIdPerLogLine() async throws {
        let app: Application = self.app
        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<40 { group.addTask { try await app.test(.GET, "healthz") { _ async throws in } } }
            try await group.waitForAll()
        }
        let lines = capture.lines.filter { $0.message == "request" }
        XCTAssertEqual(lines.count, 40)
        let ids = lines.compactMap { "\($0.metadata["request-id"] ?? "")" }
        XCTAssertEqual(Set(ids).count, 40)
        XCTAssertTrue(ids.allSatisfy { UUID(uuidString: $0) != nil })
    }
}

// MARK: - Splitter, second pass

final class SplitterReviewTests: XCTestCase {
    private func split(_ s: String) -> [String] { SQLScriptSplitter.statements(in: s) }

    func testStandardStringBackslashIsLiteral() {
        XCTAssertEqual(split("SELECT 'a\\'; SELECT 2"), ["SELECT 'a\\'", "SELECT 2"])
    }

    func testEscapedBackslashBeforeClosingQuoteInEscapeString() {
        XCTAssertEqual(split("SELECT E'\\\\'; SELECT 2"), ["SELECT E'\\\\'", "SELECT 2"])
        XCTAssertEqual(split("SELECT e'x\\'y;z'; SELECT 2").count, 2)
    }

    func testIdentifierEndingInEIsNotAnEscapeString() {
        // `name'..'` is not valid SQL, but `somee` followed by a string must not turn on backslash escapes
        XCTAssertEqual(split("SELECT tablee, 'a\\'; SELECT 2").count, 2)
    }

    func testDoubledQuoteInsideIdentifier() {
        XCTAssertEqual(split("CREATE TABLE \"a\"\"b;c\" (x int); SELECT 2").count, 2)
    }

    func testDollarTagVariants() {
        XCTAssertEqual(split("DO $a1$ BEGIN PERFORM 1; END $a1$; SELECT 2").count, 2)
        XCTAssertEqual(split("DO $é$ BEGIN PERFORM 1; END $é$; SELECT 2").count, 2)
        XCTAssertEqual(split("DO $x$ a $$ ; $$ b $x$; SELECT 2").count, 2)
        XCTAssertEqual(split("DO $_t$ a ; $_t$; SELECT 2").count, 2)
    }

    func testCommentsInsideDollarBodyAreBodyText() {
        XCTAssertEqual(split("DO $$ -- it's a trap; $$ ;\nSELECT 2").count, 1 + 1)
    }

    func testDefectDollarSignInsideAnIdentifierIsNotAQuote() {
        // PostgreSQL allows `$` inside an identifier: `a$b$c` is one name.
        XCTAssertEqual(split("SELECT a$b$c; SELECT 2"), ["SELECT a$b$c", "SELECT 2"])
    }

    func testStatementsKeepInnerComments() {
        XCTAssertEqual(split("SELECT 1 /* a;b */ + 2; -- x;y\nSELECT 3"), ["SELECT 1 /* a;b */ + 2", "-- x;y\nSELECT 3"])
    }

    func testOnlyCommentsAndSemicolons() {
        XCTAssertEqual(split("-- a\n/* b */;;; /* c */ ;"), [])
    }

    func testSeparatorWithoutSpacesAndManySemicolons() {
        XCTAssertEqual(split("SELECT 1;SELECT 2;;SELECT 3;"), ["SELECT 1", "SELECT 2", "SELECT 3"])
    }

    func testByteOrderMarkAndNul() {
        _ = split("\u{FEFF}SELECT 1; SELECT 2")
        _ = split("SELECT 1;\u{0}SELECT 2")
    }

    func testRealMigrationFilesSplitIntoWholeStatements() throws {
        let files = try MigrationFiles.load(from: QAPaths.migrations)
        XCTAssertFalse(files.isEmpty)
        for file in files {
            XCTAssertFalse(file.statements.isEmpty, file.fileName)
            for statement in file.statements {
                XCTAssertFalse(statement.hasSuffix(";") && !statement.uppercased().contains("$$") && statement.hasSuffix(";;"), file.fileName)
                // Quotes and dollar markers must be balanced in every piece.
                XCTAssertEqual(statement.filter { $0 == "'" }.count % 2, 0, "\(file.fileName): unbalanced quotes in a statement")
                XCTAssertEqual(statement.components(separatedBy: "$$").count % 2, 1, "\(file.fileName): unbalanced $$")
            }
        }
    }

    func testBadMigrationFileNamesAreRejected() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("qa-mig-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        for name in ["1_init.sql", "0001_Init.sql", "0001-init.sql", "0001_init.SQL.sql", "00001_a.sql"] {
            let path = dir.appendingPathComponent(name)
            try "SELECT 1;".write(to: path, atomically: true, encoding: .utf8)
            XCTAssertThrowsError(try MigrationFiles.load(from: dir.path + "/"), name)
            try FileManager.default.removeItem(at: path)
        }
        try "SELECT 1;".write(to: dir.appendingPathComponent("0002_b.sql"), atomically: true, encoding: .utf8)
        try "SELECT 2;".write(to: dir.appendingPathComponent("0001_a.sql"), atomically: true, encoding: .utf8)
        try "ignored".write(to: dir.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)
        XCTAssertEqual(try MigrationFiles.load(from: dir.path).map(\.fileName), ["0001_a.sql", "0002_b.sql"])
    }

    func testMissingMigrationDirectoryThrows() {
        XCTAssertThrowsError(try MigrationFiles.load(from: "/nonexistent-qa-dir/"))
    }
}

// MARK: - Deadline race

final class DeadlineEdgeTests: XCTestCase {
    func testFastOperationsLeaveNothingBehind() async throws {
        let started = ContinuousClock.now
        for i in 0..<2_000 {
            let value = try await withDeadline(.seconds(5)) { i }
            XCTAssertEqual(value, i)
        }
        XCTAssertLessThan(ContinuousClock.now - started, .seconds(10))
    }

    func testOperationErrorPropagatesUnchanged() async {
        struct Boom: Error {}
        do { _ = try await withDeadline(.seconds(5)) { () async throws -> Int in throw Boom() }; XCTFail() }
        catch { XCTAssertTrue(error is Boom) }
    }

    func testSlowOperationTimesOutOnTime() async {
        let started = ContinuousClock.now
        do { try await withDeadline(.milliseconds(200)) { try await Task.sleep(for: .seconds(10)) }; XCTFail() }
        catch { XCTAssertTrue(error is DeadlineExceededError) }
        let elapsed = ContinuousClock.now - started
        XCTAssertGreaterThan(elapsed, .milliseconds(150))
        XCTAssertLessThan(elapsed, .seconds(2))
    }

    func testOperationIgnoringCancellationStillTimesOut() async {
        let started = ContinuousClock.now
        do {
            try await withDeadline(.milliseconds(150)) {
                await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
                    DispatchQueue.global().asyncAfter(deadline: .now() + 1.5) { c.resume() }
                }
            }
            XCTFail()
        } catch { XCTAssertTrue(error is DeadlineExceededError) }
        XCTAssertLessThan(ContinuousClock.now - started, .seconds(1))
    }

    func testCallerCancellationIsPrompt() async {
        let task = Task { try await withDeadline(.seconds(30)) { try await Task.sleep(for: .seconds(30)) } }
        try? await Task.sleep(for: .milliseconds(100))
        let started = ContinuousClock.now
        task.cancel()
        do { _ = try await task.value; XCTFail() } catch { XCTAssertTrue(error is CancellationError, "\(error)") }
        XCTAssertLessThan(ContinuousClock.now - started, .seconds(1))
    }

    func testAlreadyCancelledCallerFailsFastWithoutHanging() async {
        let task = Task { () async throws -> Int in
            try await Task.sleep(for: .milliseconds(1)) // lets the cancel below land first
            return try await withDeadline(.seconds(30)) { try await Task.sleep(for: .seconds(30)); return 1 }
        }
        task.cancel()
        do { _ = try await task.value; XCTFail() } catch { /* CancellationError either way */ }
    }

    func testZeroAndNegativeLimitsNeverHang() async {
        for limit in [Duration.zero, .milliseconds(-5)] {
            do { _ = try await withDeadline(limit) { try await Task.sleep(for: .seconds(5)) } ; XCTFail() }
            catch { XCTAssertTrue(error is DeadlineExceededError, "\(limit): \(error)") }
        }
    }

    func testRacingFinishAndTimerNeverResumesTwice() async throws {
        // 600 concurrent races where the operation ends about when the timer fires.
        let outcomes = try await withThrowingTaskGroup(of: Bool.self) { group in
            for i in 0..<600 {
                group.addTask {
                    do {
                        try await withDeadline(.milliseconds(10)) { try await Task.sleep(for: .milliseconds(8 + (i % 5))) }
                        return true
                    } catch is DeadlineExceededError { return false }
                }
            }
            var all: [Bool] = []
            for try await o in group { all.append(o) }
            return all
        }
        XCTAssertEqual(outcomes.count, 600)
    }
}
