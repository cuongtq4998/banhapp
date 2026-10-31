import Foundation

/// Sends contract requests: adds the client headers the backend logs, and maps every outcome to a
/// success value or an `APIError`. `post` leaves the mapping of error answers to its caller.
nonisolated struct APIClient: Sendable {
    static let notModifiedStatus = 304

    private static let platformHeader = "X-Platform"
    private static let appVersionHeader = "X-App-Version"
    private static let platformName = "ios"
    private static let acceptHeader = "Accept"
    private static let contentTypeHeader = "Content-Type"
    private static let jsonContentType = "application/json"

    let baseURL: URL
    private let transport: any HTTPTransport
    private let appVersion: String

    init(baseURL: URL, appVersion: String, transport: any HTTPTransport) {
        self.baseURL = baseURL
        self.appVersion = appVersion
        self.transport = transport
    }

    /// Returns the response for a 2xx status and for 304 (a conditional GET answered "not modified").
    /// Any other status throws the typed error of the contract body.
    func get(
        path: String, query: [URLQueryItem] = [], headers: [String: String] = [:]
    ) async throws -> (data: Data, response: HTTPURLResponse) {
        let url = baseURL.appending(path: path)
        let request = makeRequest(method: "GET", url: query.isEmpty ? url : url.appending(queryItems: query), headers: headers)

        let (data, response) = try await transport.send(request)
        guard (200..<300).contains(response.statusCode) || response.statusCode == Self.notModifiedStatus else {
            throw APIErrorParser.parse(data, response: response)
        }
        return (data, response)
    }

    /// Sends a JSON body and returns the answer whatever its status: `POST /v1/orders` has to read the
    /// `fields` and `details` of its error bodies, which `APIError` does not carry. Only a failure to
    /// get an answer at all throws (`networkUnavailable`, `timeout`).
    func post(
        path: String, body: Data, headers: [String: String] = [:], timeout: TimeInterval? = nil
    ) async throws -> (data: Data, response: HTTPURLResponse) {
        var request = makeRequest(method: "POST", url: baseURL.appending(path: path), headers: headers)
        request.setValue(Self.jsonContentType, forHTTPHeaderField: Self.contentTypeHeader)
        request.httpBody = body
        if let timeout { request.timeoutInterval = timeout }
        return try await transport.send(request)
    }

    private func makeRequest(method: String, url: URL, headers: [String: String]) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(Self.platformName, forHTTPHeaderField: Self.platformHeader)
        request.setValue(appVersion, forHTTPHeaderField: Self.appVersionHeader)
        request.setValue(Self.jsonContentType, forHTTPHeaderField: Self.acceptHeader)
        for (name, value) in headers { request.setValue(value, forHTTPHeaderField: name) }
        return request
    }
}
