import Vapor
import Fluent

/// Composition root: every edge dependency of the application in one value.
///
/// `configure` builds it once; tests replace the whole value or one member
/// (`app.services.clock = FixedWallClock(...)`). Repositories are factories
/// that take a database handle (see `RepositoryFactories`).
struct AppServices: Sendable {
    var clock: any WallClock
    var orderCodes: any OrderCodeGenerator
    var repositories: RepositoryFactories

    /// Derived from `clock`, so replacing the clock also moves the calendar.
    var calendar: ShopCalendar { ShopCalendar(clock: clock) }
}

extension Application {
    private struct ServicesKey: StorageKey {
        typealias Value = AppServices
    }

    var services: AppServices {
        get {
            guard let services = storage[ServicesKey.self] else {
                fatalError("AppServices is not set; call configure(_:config:) first")
            }
            return services
        }
        set { storage[ServicesKey.self] = newValue }
    }
}

extension Request {
    /// The request's database handle, or nil when no database is configured
    /// (local runs only). Asking Fluent without one is a fatal error, so the
    /// registered ids are checked first.
    var databaseHandle: (any Database)? {
        guard !application.databases.ids().isEmpty else { return nil }
        return application.databases.database(logger: logger, on: eventLoop)
    }
}
