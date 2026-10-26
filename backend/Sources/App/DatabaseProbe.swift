import Vapor
import Fluent
import FluentSQL
import NIOConcurrencyHelpers

/// The one question the deep health check asks the database.
///
/// A protocol so tests can answer without a running PostgreSQL.
protocol DatabaseProbe: Sendable {
    func ping() async throws
}

struct DatabaseProbeError: Error {}

/// Runs a trivial query on the configured Fluent database.
struct PostgresProbe: DatabaseProbe {
    let app: Application

    func ping() async throws {
        guard let sql = app.db as? SQLDatabase else { throw DatabaseProbeError() }
        try await sql.raw("SELECT 1").run()
    }
}

/// Probe used when no database URL is configured (local runs only).
struct UnconfiguredProbe: DatabaseProbe {
    func ping() async throws { throw DatabaseProbeError() }
}

struct ProbeTimeoutError: Error {}

/// Resumes a continuation at most once, whichever side calls first.
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

/// Fails with `ProbeTimeoutError` when `operation` takes longer than `limit`.
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
            once.resume(with: .failure(ProbeTimeoutError()))
        }
    }
}

extension Application {
    private struct ProbeKey: StorageKey {
        typealias Value = any DatabaseProbe
    }

    var databaseProbe: any DatabaseProbe {
        get { storage[ProbeKey.self] ?? UnconfiguredProbe() }
        set { storage[ProbeKey.self] = newValue }
    }
}
