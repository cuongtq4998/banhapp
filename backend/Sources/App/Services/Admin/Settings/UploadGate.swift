import Foundation

/// At most `limit` uploads are processed at once; another waits up to `wait`
/// and then gets 503, so memory stays bounded on the small host (ADR-0025).
actor UploadGate {
    private let limit: Int
    private let wait: Duration
    private var running = 0

    init(limit: Int = 2, wait: Duration = .seconds(5)) {
        self.limit = limit
        self.wait = wait
    }

    func run<T: Sendable>(_ work: @Sendable () async throws -> T) async throws -> T {
        let deadline = ContinuousClock.now + wait
        while running >= limit {
            if ContinuousClock.now >= deadline { throw APIError(.serviceUnavailable) }
            try await Task.sleep(for: .milliseconds(25))
        }
        running += 1
        defer { running -= 1 }
        return try await work()
    }
}
