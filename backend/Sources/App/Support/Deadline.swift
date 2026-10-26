import NIOConcurrencyHelpers

struct DeadlineExceededError: Error {}

/// Resumes a continuation at most once, whichever side calls first.
///
/// `@unchecked Sendable` is sound because every access to the continuation
/// goes through `lock`.
private final class OnceResumer<T: Sendable>: @unchecked Sendable {
    private let lock = NIOLock()
    private var continuation: CheckedContinuation<T, Error>?

    init(_ continuation: CheckedContinuation<T, Error>) {
        self.continuation = continuation
    }

    func resume(with result: Result<T, Error>) {
        let taken = lock.withLock { () -> CheckedContinuation<T, Error>? in
            defer { continuation = nil }
            return continuation
        }
        taken?.resume(with: result)
    }
}

/// Fails with `DeadlineExceededError` when `operation` takes longer than `limit`.
///
/// A task group would wait for the slow child even after cancelling it, because
/// a database query on the event loop does not observe cancellation. A
/// continuation resumed once by whichever side finishes first gives a real
/// deadline.
func withDeadline<T: Sendable>(
    _ limit: Duration,
    _ operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<T, Error>) in
        let once = OnceResumer(continuation)
        Task.detached {
            do {
                once.resume(with: .success(try await operation()))
            } catch {
                once.resume(with: .failure(error))
            }
        }
        Task.detached {
            try? await Task.sleep(for: limit)
            once.resume(with: .failure(DeadlineExceededError()))
        }
    }
}
