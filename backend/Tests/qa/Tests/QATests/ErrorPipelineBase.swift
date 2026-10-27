import XCTest
import XCTVapor
@testable import AppUnderTest

/// Round 2: adversarial cases for the refactored backend (error middleware,
/// access log, body limit, splitter, deadline race). Fake data only.
/// Shared application, log capture and envelope decoder; holds no test methods.
class ErrorPipelineBase: XCTestCase {
    var app: Application!
    let capture = QALogCapture()

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

    func envelope(_ res: XCTHTTPResponse) throws -> (code: String, requestID: String, raw: String) {
        struct Env: Decodable {
            struct E: Decodable { let code: String }
            let error: E
            let request_id: String
        }
        let data = Data(res.body.readableBytesView)
        let env = try JSONDecoder().decode(Env.self, from: data)
        return (env.error.code, env.request_id, String(decoding: data, as: UTF8.self))
    }
}
