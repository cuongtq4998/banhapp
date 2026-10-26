import Foundation

/// Settings of the `serve` command, read from environment variables. The
/// `migrate` command needs less and has its own type (`MigrationConfig`), so a
/// deploy step never has to set variables it does not use.
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
        static let shopID = "SHOP_ID"
        static let trustProxy = "TRUST_PROXY"
        static let rateLimitReadPerMinute = "RATE_LIMIT_READ_PER_MINUTE"
        static let publicAssetBaseURL = "PUBLIC_ASSET_BASE_URL"
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

    let stage: Stage
    let port: Int
    let databaseURL: String?
    let databasePoolMax: Int
    /// The single shop this instance serves. Nil only in a local run, where
    /// the catalogue then answers `SERVICE_UNAVAILABLE`.
    let shopID: UUID?
    /// Whether the client address comes from the proxy's `X-Forwarded-For`
    /// header. Off unless the host sits behind a proxy that sets it, because
    /// otherwise any client could pick its own address.
    let trustProxy: Bool
    let rateLimitReadPerMinute: Int
    let publicAssetBaseURL: String
    /// Not an environment variable: the api.md window is fixed at one minute;
    /// tests shorten it to see the reset.
    let rateLimitWindowSeconds: TimeInterval

    init(
        stage: Stage,
        port: Int,
        databaseURL: String?,
        databasePoolMax: Int = Default.databasePoolMax,
        shopID: UUID? = nil,
        trustProxy: Bool = false,
        rateLimitReadPerMinute: Int = Default.rateLimitReadPerMinute,
        publicAssetBaseURL: String = Default.publicAssetBaseURL,
        rateLimitWindowSeconds: TimeInterval = Default.rateLimitWindowSeconds
    ) {
        self.stage = stage
        self.port = port
        self.databaseURL = databaseURL
        self.databasePoolMax = databasePoolMax
        self.shopID = shopID
        self.trustProxy = trustProxy
        self.rateLimitReadPerMinute = rateLimitReadPerMinute
        self.publicAssetBaseURL = publicAssetBaseURL
        self.rateLimitWindowSeconds = rateLimitWindowSeconds
    }

    init(variables: [String: String]) throws {
        let environment = EnvironmentVariables(variables)
        let value = environment.value
        let stage = try environment.stage()

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

        let shopID = try Self.parseShopID(environment, stage: stage)
        let trustProxy = try Self.parseTrustProxy(environment)

        var readLimit = Default.rateLimitReadPerMinute
        if let limitText = value(Key.rateLimitReadPerMinute) {
            guard let parsed = Int(limitText), parsed >= 1 else { throw Failure.invalid(Key.rateLimitReadPerMinute) }
            readLimit = parsed
        }

        self.init(
            stage: stage,
            port: port,
            databaseURL: databaseURL,
            databasePoolMax: poolMax,
            shopID: shopID,
            trustProxy: trustProxy,
            rateLimitReadPerMinute: readLimit,
            publicAssetBaseURL: value(Key.publicAssetBaseURL).map(Self.trimmingTrailingSlashes)
                ?? Default.publicAssetBaseURL
        )
    }

    /// The hosted environments must name their shop; a local run may omit it.
    private static func parseShopID(_ environment: EnvironmentVariables, stage: Stage) throws -> UUID? {
        guard let text = environment.value(Key.shopID) else {
            if stage != .local { throw Failure.missing(Key.shopID) }
            return nil
        }
        guard let id = UUID(uuidString: text) else { throw Failure.invalid(Key.shopID) }
        return id
    }

    private static func parseTrustProxy(_ environment: EnvironmentVariables) throws -> Bool {
        guard let text = environment.value(Key.trustProxy) else { return false }
        switch text.lowercased() {
        case "true": return true
        case "false": return false
        default: throw Failure.invalid(Key.trustProxy)
        }
    }

    /// `image_url` is base + `/assets/...`, so a trailing slash would double up.
    private static func trimmingTrailingSlashes(_ base: String) -> String {
        var trimmed = Substring(base)
        while trimmed.hasSuffix("/") { trimmed = trimmed.dropLast() }
        return String(trimmed)
    }
}

/// Typed access to a plain dictionary of variables.
struct EnvironmentVariables {
    private let variables: [String: String]

    init(_ variables: [String: String]) {
        self.variables = variables
    }

    /// Trimmed of all whitespace and newlines (a value pasted into a host
    /// console or read from a file often ends with one); empty counts as unset.
    func value(_ key: String) -> String? {
        guard let raw = variables[key]?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }
        return raw
    }

    func stage() throws -> AppConfig.Stage {
        guard let text = value(AppConfig.Key.appEnv) else { throw AppConfig.Failure.missing(AppConfig.Key.appEnv) }
        guard let stage = AppConfig.Stage(rawValue: text) else { throw AppConfig.Failure.invalid(AppConfig.Key.appEnv) }
        return stage
    }
}

/// Settings of the `migrate` command: the stage and the migration role's URL,
/// nothing else (deployment.md section 3 lists what the deploy job passes).
struct MigrationConfig: Equatable, Sendable {
    let stage: AppConfig.Stage
    let databaseMigrationURL: String

    /// One connection is enough for forward-only DDL run one file at a time.
    static let poolSize = 1

    init(stage: AppConfig.Stage, databaseMigrationURL: String) {
        self.stage = stage
        self.databaseMigrationURL = databaseMigrationURL
    }

    init(variables: [String: String]) throws {
        let environment = EnvironmentVariables(variables)
        guard let url = environment.value(AppConfig.Key.databaseMigrationURL) else {
            throw AppConfig.Failure.missing(AppConfig.Key.databaseMigrationURL)
        }
        self.init(stage: try environment.stage(), databaseMigrationURL: url)
    }
}
