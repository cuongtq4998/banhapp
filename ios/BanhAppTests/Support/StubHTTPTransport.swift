import Foundation
@testable import BanhApp

/// Answers requests from a script and records them, so tests see exactly what the client sent.
final class StubHTTPTransport: HTTPTransport, @unchecked Sendable {
    enum Reply {
        case response(status: Int, headers: [String: String] = [:], body: Data = Data())
        case failure(APIError)
    }

    // Guarded by the lock: the transport is Sendable and tests read it after awaiting the client.
    private let lock = NSLock()
    private var replies: [Reply]
    private var sent: [URLRequest] = []

    init(_ replies: [Reply]) {
        self.replies = replies
    }

    var requests: [URLRequest] { lock.withLock { sent } }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let reply: Reply = lock.withLock {
            sent.append(request)
            return replies.count > 1 ? replies.removeFirst() : replies[0]
        }
        switch reply {
        case .failure(let error):
            throw error
        case .response(let status, let headers, let body):
            let url = request.url ?? URL(fileURLWithPath: "/")
            let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: headers)!
            return (body, response)
        }
    }
}
