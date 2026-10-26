import BanhContracts

/// Decides the verdict of `GET /healthz` (api.md 4.4).
struct HealthService: Sendable {
    let probe: any DatabaseProbe
    let deepTimeout: Duration

    /// The shallow verdict never touches the database, so an uptime monitor
    /// polling every few minutes does not wake the free-tier database.
    func shallowStatus() -> HealthResponse {
        HealthResponse(status: .ok)
    }

    /// Runs one database round trip under a hard deadline.
    func deepStatus() async -> HealthResponse {
        let probe = self.probe
        do {
            try await withDeadline(deepTimeout) { try await probe.ping() }
            return HealthResponse(status: .ok)
        } catch {
            return HealthResponse(status: .degraded)
        }
    }
}
