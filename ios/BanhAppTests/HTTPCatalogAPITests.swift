import BanhContracts
import XCTest
@testable import BanhApp

final class HTTPCatalogAPITests: XCTestCase {
    private let baseURL = URL(string: "http://localhost:8080")!
    private let etag = "\"3f9a1c0de2b54a6e8c7d1b2a0f4e5d6c\""

    private func makeAPI(_ replies: [StubHTTPTransport.Reply]) -> (HTTPCatalogAPI, StubHTTPTransport) {
        let transport = StubHTTPTransport(replies)
        let client = APIClient(baseURL: baseURL, appVersion: "9.9", transport: transport)
        return (HTTPCatalogAPI(client: client), transport)
    }

    func testOkFixtureDecodesAndKeepsTheQuotedETagAsReceived() async throws {
        let body = try Fixtures.data("catalog-ok.json")
        let (api, transport) = makeAPI([.response(status: 200, headers: ["ETag": etag], body: body)])

        let result = try await api.fetchCatalog(etag: nil)

        XCTAssertEqual(result, .modified(try CatalogTestData.okCatalog(), etag: etag))
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.url?.absoluteString, "http://localhost:8080/v1/catalog")
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertNil(request.value(forHTTPHeaderField: "If-None-Match"))
    }

    func testSendsTheClientHeadersTheBackendLogs() async throws {
        let (api, transport) = makeAPI([.response(status: 200, body: try Fixtures.data("catalog-empty.json"))])
        _ = try await api.fetchCatalog(etag: nil)
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Platform"), "ios")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-App-Version"), "9.9")
    }

    func testSendsTheStoredETagAsIfNoneMatchAndReadsA304AsNotModified() async throws {
        let (api, transport) = makeAPI([.response(status: 304, headers: ["ETag": etag])])

        let result = try await api.fetchCatalog(etag: etag)

        XCTAssertEqual(result, .notModified)
        XCTAssertEqual(transport.requests.first?.value(forHTTPHeaderField: "If-None-Match"), etag)
    }

    func testAnEmptyCatalogIsStillASuccessfulAnswer() async throws {
        let (api, _) = makeAPI([.response(status: 200, body: try Fixtures.data("catalog-empty.json"))])
        guard case .modified(let catalog, _) = try await api.fetchCatalog(etag: nil) else {
            return XCTFail("Expected a modified catalog")
        }
        XCTAssertTrue(catalog.products.isEmpty)
    }

    func testRateLimitedCarriesRetryAfterFromTheContractBody() async throws {
        let body = try Fixtures.data("error-rate-limited.json")
        let (api, _) = makeAPI([.response(status: 429, headers: ["Retry-After": "99"], body: body)])
        await assertThrows(APIError.rateLimited(retryAfterSeconds: 30, requestID: "7f1c1a52-0c1e-4d6c-9a54-2d7f3d6a0004")) {
            _ = try await api.fetchCatalog(etag: nil)
        }
    }

    func testRateLimitedFallsBackToTheHeaderWhenTheBodyIsNotTheEnvelope() async {
        let (api, _) = makeAPI([.response(status: 429, headers: ["Retry-After": "12"], body: Data("<html>".utf8))])
        await assertThrows(APIError.rateLimited(retryAfterSeconds: 12, requestID: nil)) {
            _ = try await api.fetchCatalog(etag: nil)
        }
    }

    func testRateLimitedWithoutAnyHintUsesTheDefault() async {
        let (api, _) = makeAPI([.response(status: 429)])
        await assertThrows(APIError.rateLimited(retryAfterSeconds: APIErrorParser.defaultRetryAfterSeconds, requestID: nil)) {
            _ = try await api.fetchCatalog(etag: nil)
        }
    }

    func testServiceUnavailableEnvelopeBecomesATypedError() async throws {
        let body = try Fixtures.data("error-service-unavailable.json")
        let (api, _) = makeAPI([.response(status: 503, body: body)])
        await assertThrows(APIError.service(
            code: .serviceUnavailable, messageKey: "ERR_SERVER", httpStatus: 503,
            requestID: "7f1c1a52-0c1e-4d6c-9a54-2d7f3d6a0005"
        )) { _ = try await api.fetchCatalog(etag: nil) }
    }

    func testAnUnknownErrorCodeBehavesLikeAnInternalError() {
        XCTAssertEqual(APIErrorCode(wire: "SOMETHING_NEW"), .internalError)
        XCTAssertEqual(APIErrorCode(wire: "RATE_LIMITED"), .rateLimited)
    }

    func testASuccessBodyThatBreaksTheContractIsInvalid() async {
        let (api, _) = makeAPI([.response(status: 200, body: Data("{}".utf8))])
        await assertThrows(APIError.invalidResponse) { _ = try await api.fetchCatalog(etag: nil) }
    }

    func testATransientFailureIsRetriedOnce() async throws {
        let body = try Fixtures.data("catalog-ok.json")
        let (api, transport) = makeAPI([.failure(.timeout), .response(status: 200, body: body)])

        _ = try await api.fetchCatalog(etag: nil)

        XCTAssertEqual(transport.requests.count, 2)
    }

    func testTwoTransientFailuresGiveUp() async {
        let (api, transport) = makeAPI([.failure(.networkUnavailable)])
        await assertThrows(APIError.networkUnavailable) { _ = try await api.fetchCatalog(etag: nil) }
        XCTAssertEqual(transport.requests.count, 2)
    }

    func testAServerAnswerIsNotRetried() async {
        let (api, transport) = makeAPI([.response(status: 503)])
        do {
            _ = try await api.fetchCatalog(etag: nil)
            XCTFail("Expected an error")
        } catch {}
        XCTAssertEqual(transport.requests.count, 1)
    }

    private func assertThrows(
        _ expected: APIError, file: StaticString = #filePath, line: UInt = #line,
        _ operation: () async throws -> Void
    ) async {
        do {
            try await operation()
            XCTFail("Expected \(expected)", file: file, line: line)
        } catch {
            XCTAssertEqual(error as? APIError, expected, file: file, line: line)
        }
    }
}
