import Foundation

/// Runtime settings read from environment variables.
///
/// Variable names are listed in `backend/.env.example` and in
/// deployment.md section 3. The values are parsed from a plain dictionary so
/// tests never touch the real process environment.
struct AppConfig: Equatable, Sendable {
    enum Stage: String, Sendable {
        case local
        case staging
        case production
    }

    /// Environment variable names, kept in one place so the code and
    /// `.env.example` stay in step.
    enum Key {
        static let appEnv = "APP_ENV"
        static let port = "PORT"
        static let databaseURL = "DATABASE_URL"
        static let databaseMigrationURL = "DATABASE_MIGRATION_URL"
        static let databasePoolMax = "DATABASE_POOL_MAX"
    }

    enum Default {
        static let databasePoolMax = 5
        /// Seconds the deep health check waits for the database (api.md 4.4).
        static let healthDeepTimeoutSeconds = 2
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

    let stage: Stage
    let port: Int
    let databaseURL: String?
    let databaseMigrationURL: String?
    let databasePoolMax: Int

    init(
        stage: Stage,
        port: Int,
        databaseURL: String?,
        databaseMigrationURL: String? = nil,
        databasePoolMax: Int = Default.databasePoolMax
    ) {
        self.stage = stage
        self.port = port
        self.databaseURL = databaseURL
        self.databaseMigrationURL = databaseMigrationURL
        self.databasePoolMax = databasePoolMax
    }

    init(variables: [String: String]) throws {
        func value(_ key: String) -> String? {
            guard let raw = variables[key]?.trimmingCharacters(in: .whitespaces), !raw.isEmpty else {
                return nil
            }
            return raw
        }

        guard let stageText = value(Key.appEnv) else { throw Failure.missing(Key.appEnv) }
        guard let stage = Stage(rawValue: stageText) else { throw Failure.invalid(Key.appEnv) }

        guard let portText = value(Key.port) else { throw Failure.missing(Key.port) }
        guard let port = Int(portText), (1...65_535).contains(port) else { throw Failure.invalid(Key.port) }

        let databaseURL = value(Key.databaseURL)
        // A local run may start without a database (shallow health only); the
        // hosted environments must not.
        if databaseURL == nil && stage != .local { throw Failure.missing(Key.databaseURL) }

        var poolMax = Default.databasePoolMax
        if let poolText = value(Key.databasePoolMax) {
            guard let parsed = Int(poolText), parsed >= 1 else { throw Failure.invalid(Key.databasePoolMax) }
            poolMax = parsed
        }

        self.init(
            stage: stage,
            port: port,
            databaseURL: databaseURL,
            databaseMigrationURL: value(Key.databaseMigrationURL),
            databasePoolMax: poolMax
        )
    }
}
