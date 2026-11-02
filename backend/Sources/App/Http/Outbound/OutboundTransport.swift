import Foundation
import AsyncHTTPClient
import NIOCore
import NIOHTTP1

/// One HTTPS call to a provider. A plain value so the push clients are tested
/// with a fake transport and no network.
struct OutboundRequest: Sendable, Equatable {
    var method = "POST"
    let url: String
    var headers: [String: String] = [:]
    var body = Data()
    var timeoutSeconds: Int64 = 10

    /// Header lookup that ignores case.
    func header(_ name: String) -> String? { headers.first { $0.key.lowercased() == name.lowercased() }?.value }
}

struct OutboundResponse: Sendable, Equatable {
    let status: Int
    let body: Data
}

/// Throws when no answer arrived (connection, TLS, timeout); any HTTP status
/// is an answer.
protocol OutboundTransport: Sendable {
    func send(_ request: OutboundRequest) async throws -> OutboundResponse
}

/// The real transport: the application's shared `HTTPClient`, which speaks
/// HTTP/2 when the server offers it (APNs requires it).
struct AsyncHTTPOutboundTransport: OutboundTransport {
    static let maxResponseBytes = 64 * 1024

    let client: HTTPClient

    func send(_ request: OutboundRequest) async throws -> OutboundResponse {
        var call = HTTPClientRequest(url: request.url)
        call.method = HTTPMethod(rawValue: request.method)
        for (name, value) in request.headers { call.headers.add(name: name, value: value) }
        call.body = .bytes(ByteBuffer(data: request.body))
        let response = try await client.execute(call, timeout: .seconds(request.timeoutSeconds))
        let body = try await response.body.collect(upTo: Self.maxResponseBytes)
        return OutboundResponse(status: Int(response.status.code), body: Data(body.readableBytesView))
    }
}
