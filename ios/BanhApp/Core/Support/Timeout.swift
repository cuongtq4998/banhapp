import Foundation

/// Runs `operation` and gives up after `limit`: the loser of the race is cancelled, which also
/// cancels a URLSession call in flight. Throws `APIError.timeout` when the limit wins.
nonisolated func withTimeout<Value: Sendable>(
    _ limit: Duration, operation: @escaping @Sendable () async throws -> Value
) async throws -> Value {
    try await withThrowingTaskGroup(of: Value.self) { group in
        group.addTask { try await operation() }
        group.addTask {
            try await Task.sleep(for: limit)
            throw APIError.timeout
        }
        defer { group.cancelAll() }
        guard let first = try await group.next() else { throw APIError.timeout }
        return first
    }
}
