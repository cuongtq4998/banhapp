import BanhContracts
import Foundation
import Testing
@testable import BanhCore

private final class Recorder: HTTPTransport, @unchecked Sendable {
    var requests: [URLRequest] = []
    var status = 200
    var body = Data("{}".utf8)
    var headers: [String: String] = [:]

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: headers)!
        return (body, response)
    }
}

struct APIClientTests {
    private let base = URL(string: "http://127.0.0.1:8080")!

    @Test func addsClientHeadersAndQuery() async throws {
        let recorder = Recorder()
        let client = APIClient(baseURL: base, appVersion: "1.2.3", transport: recorder)
        _ = try await client.send("GET", path: "/v1/admin/orders", query: [URLQueryItem(name: "status", value: "New")])
        let request = try #require(recorder.requests.first)
        #expect(request.url?.absoluteString == "http://127.0.0.1:8080/v1/admin/orders?status=New")
        #expect(request.value(forHTTPHeaderField: "X-Platform") == "ios")
        #expect(request.value(forHTTPHeaderField: "X-App-Version") == "1.2.3")
    }

    @Test func parsesTheErrorEnvelope() async throws {
        let recorder = Recorder()
        recorder.status = 429
        recorder.body = Data(#"{"error":{"code":"CODE_REQUEST_LIMIT","message_key":"K","details":{"retry_after_seconds":1800}},"request_id":"r"}"#.utf8)
        let client = APIClient(baseURL: base, appVersion: "1.0.0", transport: recorder)
        do {
            _ = try await client.send("POST", path: "/v1/auth/code-requests", body: Data("{}".utf8))
            Issue.record("expected an error")
        } catch let error as APIError {
            #expect(error.code == "CODE_REQUEST_LIMIT")
            #expect(error.httpStatus == 429)
            #expect(error.retryAfterSeconds == 1800)
        }
    }

    @Test func nonEnvelopeBodyFallsBackToStatusAndRetryAfterHeader() async throws {
        let recorder = Recorder()
        recorder.status = 503
        recorder.body = Data("<html>".utf8)
        recorder.headers = ["Retry-After": "30"]
        let client = APIClient(baseURL: base, appVersion: "1.0.0", transport: recorder)
        do {
            _ = try await client.send("GET", path: "/x")
            Issue.record("expected an error")
        } catch let error as APIError {
            #expect(error.httpStatus == 503)
            #expect(error.retryAfterSeconds == 30)
        }
    }

    @Test func decodesSnakeCaseAndFlagsBadBodies() async throws {
        struct Sample: Decodable { let totalVnd: Int }
        let recorder = Recorder()
        recorder.body = Data(#"{"total_vnd":120000}"#.utf8)
        let client = APIClient(baseURL: base, appVersion: "1.0.0", transport: recorder)
        #expect(try await client.decode(Sample.self, "GET", path: "/x").totalVnd == 120_000)
        recorder.body = Data(#"{"nope":1}"#.utf8)
        await #expect(throws: APIError.invalidResponse) { try await client.decode(Sample.self, "GET", path: "/x") }
    }
}
