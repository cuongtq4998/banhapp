import Foundation

extension AppConfig {
    /// Environment variable names, kept in one place so the code and
    /// `.env.example` stay in step.
    enum Key {
        static let appEnv = "APP_ENV"
        static let port = "PORT"
        static let databaseURL = "DATABASE_URL"
        static let databaseMigrationURL = "DATABASE_MIGRATION_URL"
        static let databasePoolMax = "DATABASE_POOL_MAX"
        static let shopID = "SHOP_ID"
        static let trustProxy = "TRUST_PROXY"
        static let rateLimitReadPerMinute = "RATE_LIMIT_READ_PER_MINUTE"
        static let publicAssetBaseURL = "PUBLIC_ASSET_BASE_URL"
        static let orderingEnabled = "ORDERING_ENABLED"
        static let rateLimitOrderPerHour = "RATE_LIMIT_ORDER_PER_HOUR"
        static let orderMaxPerPhonePerDay = "ORDER_MAX_PER_PHONE_PER_DAY"
    }

    enum Default {
        static let databasePoolMax = 5
        /// Seconds the deep health check waits for the database (api.md 4.4).
        static let healthDeepTimeoutSeconds = 2
        /// api.md section 1: reads per client address per minute.
        static let rateLimitReadPerMinute = 120
        static let rateLimitWindowSeconds: TimeInterval = 60
        /// Empty: `image_url` stays a path on the API host (api.md 4.1).
        static let publicAssetBaseURL = ""
    }

    enum Failure: Error, CustomStringConvertible, Equatable {
        case missing(String)
        case invalid(String)

        // Only the variable name is reported, never its value: values can be
        // connection strings with credentials.
        var description: String {
            switch self {
            case .missing(let name): return "Missing required environment variable \(name)"
            case .invalid(let name): return "Invalid value for environment variable \(name)"
            }
        }
    }
}
