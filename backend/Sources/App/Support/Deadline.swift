import NIOConcurrencyHelpers
import NIOCore
import NIOPosix

struct DeadlineExceededError: Error {}

/// The first of three outcomes wins: the operation finished, the timer fired,
/// or the caller was cancelled. It resumes the caller's continuation exactly
/// once and then runs every registered cleanup, so a successful call leaves
/// no timer behind.
///
/// `@unchecked Sendable` is sound because every access to the mutable state
/// goes through `lock`; continuations and cleanups are only used after being
/// taken out of that state.
final class DeadlineRace<T: Sendable>: @unchecked Sendable {
    typealias Cleanup = @Sendable () -> Void

    private let lock = NIOLock()
    private var continuation: CheckedContinuation<T, Error>?
    private var outcome: Result<T, Error>?
    private var cleanups: [Cleanup] = []

    /// Called once the caller is suspended. An outcome that arrived earlier
    /// (an immediate cancellation, a very fast operation) is delivered now.
    func attach(_ continuation: CheckedContinuation<T, Error>) {
        let early = lock.withLock { () -> Result<T, Error>? in
            if let outcome { return outcome }
            self.continuation = continuation
            return nil
        }
        if let early { continuation.resume(with: early) }
    }

    /// Registers what to undo when the race ends; runs it at once if the race
    /// already ended.
    func onFinish(_ cleanup: @escaping Cleanup) {
        let alreadyOver = lock.withLock { () -> Bool in
            if outcome != nil { return true }
            cleanups.append(cleanup)
            return false
        }
        if alreadyOver { cleanup() }
    }

    func finish(with result: Result<T, Error>) {
        let (waiting, pending) = lock.withLock { () -> (CheckedContinuation<T, Error>?, [Cleanup]) in
            guard outcome == nil else { return (nil, []) }
            outcome = result
            defer { continuation = nil; cleanups = [] }
            return (continuation, cleanups)
        }
        for cleanup in pending { cleanup() }
        waiting?.resume(with: result)
    }
}

/// Fails with `DeadlineExceededError` when `operation` takes longer than `limit`,
/// and with `CancellationError` when the caller is cancelled.
///
/// A task group would wait for the slow child even after cancelling it, because
/// a database query on the event loop does not observe cancellation. A
/// continuation resumed once by whichever side finishes first gives a real
/// deadline; a loser that ignores cancellation finishes later without effect.
///
/// The timer is a NIO scheduled task, not a sleeping Swift task: cancelling a
/// sleeping `Task` here crashed release builds of the running server
/// ("freed pointer was not the last allocation", Swift 6.2.4), while a NIO
/// timer cancels without involving task cancellation.
func withDeadline<T: Sendable>(
    _ limit: Duration,
    _ operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    let race = DeadlineRace<T>()
    return try await withTaskCancellationHandler {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<T, Error>) in
            race.attach(continuation)
            let timer = MultiThreadedEventLoopGroup.singleton.next().scheduleTask(in: TimeAmount(limit)) {
                race.finish(with: .failure(DeadlineExceededError()))
            }
            race.onFinish { timer.cancel() }
            let work = Task.detached {
                do {
                    race.finish(with: .success(try await operation()))
                } catch {
                    race.finish(with: .failure(error))
                }
            }
            race.onFinish { work.cancel() }
        }
    } onCancel: {
        race.finish(with: .failure(CancellationError()))
    }
}
