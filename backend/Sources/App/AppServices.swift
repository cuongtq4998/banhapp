import Vapor

/// Composition root: every edge dependency of the application in one value.
///
/// `configure` builds it once; tests replace the whole value or one member
/// (`app.services.databaseProbe = StubProbe { ... }`). Repositories join it
/// in the slices that introduce them.
struct AppServices: Sendable {
    var clock: any WallClock
    var databaseProbe: any DatabaseProbe
    var orderCodes: any OrderCodeGenerator

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
