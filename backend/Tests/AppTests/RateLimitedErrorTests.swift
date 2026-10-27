import XCTVapor
import Logging
import BanhContracts
@testable import App

final class RateLimitedErrorTests: ErrorHandlingTestCase {
    func testRetryAfterHintIsClampedToTheSaneRange() async throws {
        let cases: [(hint: String, seconds: Int)] = [
            ("0", 0), ("7", 7), ("3600", 3_600), ("3601", 3_600), ("99999999999", 3_600),
            ("-5", 60), ("-1", 60), ("abc", 60), ("", 60), ("1.5", 60), ("99999999999999999999999", 60)
        ]
        for (hint, seconds) in cases {
            try await app.test(.GET, "abort-hinted?hint=\(hint)") { res async throws in
                XCTAssertEqual(res.headers.first(name: .retryAfter), String(seconds), "hint \(hint)")
                let body = try res.content.decode(APIErrorResponse.self)
                XCTAssertEqual(body.error.details["retry_after_seconds"], .int(seconds), "hint \(hint)")
            }
        }
    }

    func testRateLimitedFactoryClampsItsArgument() {
        XCTAssertEqual(APIError.rateLimited(retryAfterSeconds: -1).retryAfterSeconds, APIError.defaultRetryAfterSeconds)
        XCTAssertEqual(APIError.rateLimited(retryAfterSeconds: Int.max).retryAfterSeconds, APIError.maxRetryAfterSeconds)
        XCTAssertEqual(APIError.rateLimited(retryAfterSeconds: 30).retryAfterSeconds, 30)
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
}
