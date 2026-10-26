import Vapor
import Fluent
import FluentPostgresDriver

/// Relative to the working directory: `backend/` when run from source, `/app`
/// in the image (the Dockerfile copies `db/` next to the binary).
private let migrationsDirectory = "db/migrations/"
private let listenHostname = "0.0.0.0"

/// Name of the Vapor command that applies migrations; the only command that
/// uses `configureMigrator` instead of `configure`.
let migrateCommandName = "migrate"

/// Builds the application for `serve` from `config`. The caller owns the
/// process environment; nothing here reads it directly so tests can inject
/// values.
func configure(_ app: Application, config: AppConfig) async throws {
    app.http.server.configuration.hostname = listenHostname
    app.http.server.configuration.port = config.port
    app.routes.defaultMaxBodySize = RequestLimits.maxBodySize

    configureMiddleware(app)
    try configureDatabase(app, config: config)
    app.services = AppServices(
        clock: SystemWallClock(),
        orderCodes: RandomOrderCodeGenerator(),
        repositories: .postgres
    )

    try app.register(collection: HealthRoutes())
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
/// failure is already a contract response by the time the others look.
private func configureMiddleware(_ app: Application) {
    // Drops Vapor's default error middleware, whose body is not the contract's.
    app.middleware = Middlewares()
    app.middleware.use(RequestIDMiddleware())
    app.middleware.use(AccessLogMiddleware())
    app.middleware.use(APIErrorMiddleware())
}

private func configureDatabase(_ app: Application, config: AppConfig) throws {
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
