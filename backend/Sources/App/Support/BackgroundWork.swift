import Foundation
import NIOConcurrencyHelpers

/// Work that runs after the response was decided (mail). Tracked so a test can
/// wait for it with `drain()`; production never calls that.
final class BackgroundWork: Sendable {
    private let tasks = NIOLockedValueBox<[UUID: Task<Void, Never>]>([:])

    func run(_ work: @escaping @Sendable () async -> Void) {
        let id = UUID()
        // The entry is added under the lock before the task can remove it.
        tasks.withLockedValue { table in
            table[id] = Task { [self] in
                await work()
                tasks.withLockedValue { _ = $0.removeValue(forKey: id) }
            }
        }
    }

    func drain() async {
        while let task = tasks.withLockedValue({ $0.values.first }) { await task.value }
    }
}
