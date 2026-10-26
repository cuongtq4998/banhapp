import Foundation

/// Sends contract requests: adds the client headers the backend logs, and maps every outcome to a
/// success value or an `APIError`. Slice 3 adds POST on top of the same entry point.
nonisolated struct APIClient: Sendable {
    static let notModifiedStatus = 304

    private static let platformHeader = "X-Platform"
    private static let appVersionHeader = "X-App-Version"
    private static let platformName = "ios"
    private static let acceptHeader = "Accept"
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
    func get(path: String, headers: [String: String] = [:]) async throws -> (data: Data, response: HTTPURLResponse) {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = "GET"
        request.setValue(Self.platformName, forHTTPHeaderField: Self.platformHeader)
        request.setValue(appVersion, forHTTPHeaderField: Self.appVersionHeader)
        request.setValue(Self.jsonContentType, forHTTPHeaderField: Self.acceptHeader)
        for (name, value) in headers { request.setValue(value, forHTTPHeaderField: name) }

        let (data, response) = try await transport.send(request)
        guard (200..<300).contains(response.statusCode) || response.statusCode == Self.notModifiedStatus else {
            throw APIErrorParser.parse(data, response: response)
        }
        return (data, response)
    }
}
