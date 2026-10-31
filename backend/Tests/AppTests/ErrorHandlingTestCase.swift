import XCTVapor
import Logging
import BanhContracts
@testable import App

/// Shared fixture of the error-handling test files: an app with the extra
/// routes they raise from, a captured logger and the contract fixtures. It holds
/// no tests itself.
class ErrorHandlingTestCase: XCTestCase {
    var app: Application!
    let capture = LogCapture()

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
        app.get("abort-hinted") { req -> String in
            throw Abort(.tooManyRequests, headers: [HTTPHeaders.Name.retryAfter.description: req.query[String.self, at: "hint"] ?? ""])
        }
        app.get("abort-429") { _ -> String in throw Abort(.tooManyRequests) }
    }

    override func tearDown() async throws {
        try await app.asyncShutdown()
    }

    func fixture(_ name: String) throws -> APIErrorResponse {
        let data = try Data(contentsOf: TestPaths.contractFixtures.appendingPathComponent(name))
        return try JSONDecoder().decode(APIErrorResponse.self, from: data)
    }

    var accessLines: [(message: String, metadata: Logger.Metadata)] {
        capture.lines.filter { $0.message == "request" }
    }
}
