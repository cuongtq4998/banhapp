import Vapor
import Fluent
import FluentPostgresDriver

/// Relative to the working directory: `backend/` when run from source, `/app`
/// in the image (the Dockerfile copies `db/` next to the binary).
private let migrationsDirectory = "db/migrations/"
private let listenHostname = "0.0.0.0"
/// Product images and the privacy page; relative to the working directory like
/// the migrations (the Dockerfile copies `assets/` next to the binary).
private let assetsDirectory = "assets/"

/// Builds the application for `serve` from `config`. The caller owns the
/// process environment; nothing here reads it directly so tests can inject
/// values.
func configure(_ app: Application, config: AppConfig) async throws {
    app.http.server.configuration.hostname = listenHostname
    app.http.server.configuration.port = config.port
    app.routes.defaultMaxBodySize = RequestLimits.maxBodySize

    configureMiddleware(app, config: config)
    try configureDatabase(app, config: config)
    app.services = AppServices(
        clock: SystemWallClock(),
        orderCodes: RandomOrderCodeGenerator(),
        repositories: .postgres
    )

    try registerRoutes(app, config: config)
}

private func registerRoutes(_ app: Application, config: AppConfig) throws {
    let assetsPath = app.directory.workingDirectory + assetsDirectory
    let assets = AssetURLBuilder(
        baseURL: config.publicAssetBaseURL,
        versions: AssetVersions.load(fromAssetsDirectory: assetsPath)
    )
    try app.register(collection: HealthRoutes())
    try app.register(collection: CatalogRoutes(shopID: config.shopID, assets: assets))
    try app.register(collection: AvailabilityRoutes(shopID: config.shopID))
    try app.register(collection: AssetRoutes(directory: assetsPath))
    try app.register(collection: PrivacyRoutes(directory: assetsPath))
}

/// Builds the application for `migrate`: the migration role's database and the
/// SQL files, no routes. `migrationFiles` is injectable for tests.
func configureMigrator(
    _ app: Application,
    config: MigrationConfig,
    migrationFiles: [SQLFileMigration]? = nil
) throws {
    // The migration role has DDL rights; the server runs with the limited
    // application role (deployment.md section 3).
    app.databases.use(
        try .postgres(url: config.databaseMigrationURL, maxConnectionsPerEventLoop: MigrationConfig.poolSize),
        as: .psql
    )
    let files = try migrationFiles
        ?? MigrationFiles.load(from: app.directory.workingDirectory + migrationsDirectory)
    for file in files { app.migrations.add(file) }
}

/// Order matters: the request id exists before anything logs, the access log
/// sees the final status, and the error middleware sits innermost so every
/// failure is already a contract response by the time the others look. The
/// rate limiter sits inside the error middleware, which turns its `RATE_LIMITED`
/// error into the response, and outside the router, so unrouted reads count too.
private func configureMiddleware(_ app: Application, config: AppConfig) {
    // Drops Vapor's default error middleware, whose body is not the contract's.
    app.middleware = Middlewares()
    app.middleware.use(RequestIDMiddleware())
    app.middleware.use(AccessLogMiddleware())
    app.middleware.use(APIErrorMiddleware())
    app.middleware.use(RateLimitMiddleware(
        limiter: FixedWindowRateLimiter(limit: config.rateLimitReadPerMinute, windowSeconds: config.rateLimitWindowSeconds),
        trustProxy: config.trustProxy
    ))
}

private func configureDatabase(_ app: Application, config: AppConfig) throws {
    if config.shopID == nil {
        app.logger.warning("SHOP_ID is not set; the catalog endpoint answers SERVICE_UNAVAILABLE")
    }
    guard let url = config.databaseURL else {
        app.logger.warning("No database configured; only the shallow health check is available")
        return
    }

    // The entrypoint sizes the event loop group so the product below stays
    // within the budget (DatabasePoolSizing); a group created elsewhere (tests)
    // may exceed it, which is worth a warning.
    let loopCount = max(1, Array(app.eventLoopGroup.makeIterator()).count)
    if loopCount > config.databasePoolMax {
        app.logger.warning("More event loops than DATABASE_POOL_MAX; the pool limit cannot be honoured")
    }
    let perLoop = DatabasePoolSizing.connectionsPerLoop(poolMax: config.databasePoolMax, eventLoopCount: loopCount)
    app.databases.use(try .postgres(url: url, maxConnectionsPerEventLoop: perLoop), as: .psql)
}
