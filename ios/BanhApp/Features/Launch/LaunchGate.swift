import Foundation

/// UI document 5.1: the logo shows for at least 1.0 s and at most 2.0 s (proposed values). The exit
/// waits for the start work to settle (data shown or failed) but never past the maximum: a slow start
/// moves on to S-2, which has its own loading state.
struct LaunchGate {
    static let defaultMinDuration: Duration = .milliseconds(1_000)
    static let defaultMaxDuration: Duration = .milliseconds(2_000)
    private static let pollInterval: Duration = .milliseconds(50)

    var minDuration: Duration = defaultMinDuration
    var maxDuration: Duration = defaultMaxDuration

    /// Returns when the gate opens, or early (without opening) if the calling task is cancelled.
    @MainActor
    func awaitExit(settled: @MainActor () -> Bool) async {
        let clock = ContinuousClock()
        let start = clock.now
        // Polling, not observation: it is cancellable, and 20 checks a second for two seconds cost nothing.
        do {
            try await clock.sleep(for: minDuration)
            while !settled(), start.duration(to: clock.now) < maxDuration {
                try await clock.sleep(for: Self.pollInterval)
            }
        } catch {
            return
        }
    }
}
