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
    /// Admin sign-in; nil while it is not configured (routes answer 503).
    var adminAuth: AdminAuthConfig?
    var email: any EmailSender = UnavailableEmailSender()
    var mailRetryDelay: Duration = MailDispatcher.defaultRetryDelay
    /// Push to phones (ADR-0024); nil while `PUSH_PROVIDER=off`.
    var push: (any PushSender)?
    var pushRetryDelays: [Duration] = PushDispatcher.defaultRetryDelays
    /// Mail and other work that runs after the response; tests `drain()` it.
    var background = BackgroundWork()
    var lookup = LookupPolicy(environment: ProcessInfo.processInfo.environment)
    /// Limiters live as long as the services value, so counters persist.
    var lookupGuard = LookupGuard(policy: LookupPolicy(environment: ProcessInfo.processInfo.environment))
    var lookupMetrics = LookupMetrics()
    var makeLookupStore: @Sendable (any Database) -> any LookupStore = { PostgresLookupStore(database: $0) }

    /// Derived from `clock`, so replacing the clock also moves the calendar.
    var calendar: ShopCalendar { ShopCalendar(clock: clock) }

    var pushDispatcher: PushDispatcher { PushDispatcher(sender: push, work: background, retryDelays: pushRetryDelays) }

    var mail: MailDispatcher { MailDispatcher(sender: email, work: background, retryDelay: mailRetryDelay) }
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
