import BanhCore
import Foundation

/// A transport that answers from a closure and records every request.
final class ScriptedTransport: HTTPTransport, @unchecked Sendable {
    typealias Handler = @Sendable (URLRequest, Int) throws -> (Int, String)

    private let lock = NSLock()
    private var log: [URLRequest] = []
    private let handler: Handler

    init(_ handler: @escaping Handler) { self.handler = handler }

    var requests: [URLRequest] { lock.withLock { log } }
    func count(path: String) -> Int { requests.filter { $0.url?.path == path }.count }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let index = lock.withLock { () -> Int in log.append(request); return log.count - 1 }
        let (status, body) = try handler(request, index)
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        return (Data(body.utf8), response)
    }

    static func error(_ status: Int, _ code: String, details: String = "{}") -> (Int, String) {
        (status, #"{"error":{"code":"\#(code)","message_key":"K","details":\#(details)},"request_id":"r"}"#)
    }

    static let pair = #"{"access_token":"at_new","refresh_token":"rt_new","access_expires_in":300}"#
}
