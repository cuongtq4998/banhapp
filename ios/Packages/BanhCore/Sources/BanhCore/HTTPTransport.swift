import Foundation

/// The one place bytes leave the app. Everything above depends on this protocol, so tests and the
/// debug stub replace it and never touch the network.
public protocol HTTPTransport: Sendable {
    /// Throws `APIError.networkUnavailable` or `.timeout`; any HTTP status is returned, not thrown.
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

public struct URLSessionTransport: HTTPTransport {
    public static let readTimeout: TimeInterval = 15
    private let session: URLSession

    public init(session: URLSession = URLSessionTransport.makeSession()) {
        self.session = session
    }

    /// Ephemeral and without a URL cache: admin answers are personal data (`Cache-Control: no-store`).
    public static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.timeoutIntervalForRequest = readTimeout
        configuration.timeoutIntervalForResource = readTimeout
        return URLSession(configuration: configuration)
    }

    public func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
            return (data, http)
        } catch let error as URLError {
            throw error.code == .timedOut ? APIError.timeout : APIError.networkUnavailable
        }
    }
}
