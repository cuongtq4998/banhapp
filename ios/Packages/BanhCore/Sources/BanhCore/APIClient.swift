import Foundation

/// Sends contract requests: adds the client headers the backend requires on admin routes and maps every
/// non-2xx answer to an `APIError`. No tokens here; `SessionManager` of the app adds them.
public struct APIClient: Sendable {
    public let baseURL: URL
    private let transport: any HTTPTransport
    private let appVersion: String

    public init(baseURL: URL, appVersion: String, transport: any HTTPTransport) {
        self.baseURL = baseURL
        self.appVersion = appVersion
        self.transport = transport
    }

    public func send(
        _ method: String, path: String, query: [URLQueryItem] = [], body: Data? = nil, headers: [String: String] = [:]
    ) async throws -> (data: Data, response: HTTPURLResponse) {
        var url = baseURL.appending(path: path)
        if !query.isEmpty { url = url.appending(queryItems: query) }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("ios", forHTTPHeaderField: "X-Platform")
        request.setValue(appVersion, forHTTPHeaderField: "X-App-Version")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        for (name, value) in headers { request.setValue(value, forHTTPHeaderField: name) }
        let (data, response) = try await transport.send(request)
        guard (200..<300).contains(response.statusCode) else { throw APIErrorParser.parse(data, response: response) }
        return (data, response)
    }

    /// Sends and decodes a JSON answer (snake_case keys map to camelCase properties).
    public func decode<T: Decodable>(
        _ type: T.Type, _ method: String, path: String, query: [URLQueryItem] = [],
        body: Data? = nil, headers: [String: String] = [:]
    ) async throws -> T {
        let (data, _) = try await send(method, path: path, query: query, body: body, headers: headers)
        do {
            return try Self.decoder.decode(T.self, from: data)
        } catch {
            throw APIError.invalidResponse
        }
    }

    public static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }

    public static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }
}
