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
}
