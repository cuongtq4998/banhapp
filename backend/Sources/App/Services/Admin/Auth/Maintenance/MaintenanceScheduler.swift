import Vapor

/// Runs the purge at start-up and then every `policy.interval`.
struct MaintenanceScheduler: LifecycleHandler {
    let policy: MaintenancePolicy

    func didBootAsync(_ application: Application) async throws {
        let app = application
        let policy = policy
        let task = Task {
            while !Task.isCancelled {
                await runOnce(app, policy)
                try? await Task.sleep(for: policy.interval)
            }
        }
        app.storage[TaskKey.self] = task
    }

    func shutdownAsync(_ application: Application) async {
        application.storage[TaskKey.self]?.cancel()
    }

    // A failed run is logged and retried next day; it must not stop the server.
    private func runOnce(_ app: Application, _ policy: MaintenancePolicy) async {
        do {
            let report = try await MaintenancePurge.run(on: app.db, now: app.services.clock.now(), policy: policy)
            app.logger.info("Maintenance purge", metadata: [
                "authCodes": "\(report.authCodes)", "sessions": "\(report.sessions)",
                "securityEvents": "\(report.securityEvents)"
            ])
        } catch {
            app.logger.error("Maintenance purge failed", metadata: ["error": "\(type(of: error))"])
        }
    }

    private struct TaskKey: StorageKey { typealias Value = Task<Void, Never> }
}
