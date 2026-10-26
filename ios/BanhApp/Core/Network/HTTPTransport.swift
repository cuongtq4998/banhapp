import Foundation

/// The one place bytes leave the app. Everything above depends on this protocol, so tests replace it
/// with a stub and never touch the network.
nonisolated protocol HTTPTransport: Sendable {
    /// Throws `APIError.networkUnavailable` or `.timeout`; any HTTP status is returned, not thrown.
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

nonisolated struct URLSessionTransport: HTTPTransport {
    /// Reads give up after 15 s (api.md section 1, ADR-0007).
    static let readTimeout: TimeInterval = 15

    private let session: URLSession

    init(session: URLSession = URLSessionTransport.makeSession()) {
        self.session = session
    }

    /// Ephemeral and without a URL cache: the catalog has its own cache with a 7 day rule (ADR-0011)
    /// and a second layer would hide a 304 from the revalidation logic.
    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.timeoutIntervalForRequest = readTimeout
        configuration.timeoutIntervalForResource = readTimeout
        return URLSession(configuration: configuration)
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
            return (data, http)
        } catch let error as URLError {
            throw error.code == .timedOut ? APIError.timeout : APIError.networkUnavailable
        }
    }
}
