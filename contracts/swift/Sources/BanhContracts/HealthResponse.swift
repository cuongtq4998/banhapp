import Foundation

/// Body of `GET /healthz` (api.md 4.4).
public struct HealthResponse: Codable, Equatable, Sendable {
    public enum Status: String, Codable, Sendable {
        case ok
        case degraded
    }

    public let status: Status

    public init(status: Status) {
        self.status = status
    }
}
