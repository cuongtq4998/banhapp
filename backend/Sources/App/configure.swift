import Vapor
import Fluent
import FluentPostgresDriver

/// Relative to the working directory: `backend/` when run from source, `/app`
/// in the image (the Dockerfile copies `db/` next to the binary).
private let migrationsDirectory = "db/migrations/"
private let migrateCommandName = "migrate"
private let listenHostname = "0.0.0.0"

/// Builds the application from `config`. The caller owns the process
/// environment; nothing here reads it directly so tests can inject values.
func configure(_ app: Application, config: AppConfig, migrationFiles: [SQLFileMigration]? = nil) async throws {
    app.http.server.configuration.hostname = listenHostname
    app.http.server.configuration.port = config.port

    configureMiddleware(app)

    let isMigrating = app.environment.arguments.dropFirst().first == migrateCommandName
    let databaseProbe = try configureDatabase(app, config: config, isMigrating: isMigrating)
    app.services = AppServices(
        clock: SystemWallClock(),
        databaseProbe: databaseProbe,
        orderCodes: RandomOrderCodeGenerator()
    )

    let files = try migrationFiles
        ?? MigrationFiles.load(from: app.directory.workingDirectory + migrationsDirectory)
    for file in files { app.migrations.add(file) }

    try app.register(collection: HealthRoutes())
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

private func configureDatabase(_ app: Application, config: AppConfig, isMigrating: Bool) throws -> any DatabaseProbe {
    // `migrate` uses the migration role (DDL rights); the server runs with the
    // limited application role (deployment.md section 3).
    let url = isMigrating ? config.databaseMigrationURL : config.databaseURL
    if isMigrating && url == nil { throw AppConfig.Failure.missing(AppConfig.Key.databaseMigrationURL) }
    guard let url else {
        app.logger.warning("No database configured; only the shallow health check is available")
        return UnconfiguredProbe()
    }

    // The entrypoint sizes the event loop group so the product below stays
    // within the budget (DatabasePoolSizing); a group created elsewhere (tests)
    // may exceed it, which is worth a warning.
    let loopCount = max(1, Array(app.eventLoopGroup.makeIterator()).count)
    if loopCount > config.databasePoolMax {
        app.logger.warning("More event loops than DATABASE_POOL_MAX; the pool limit cannot be honoured")
    }
    let perLoop = DatabasePoolSizing.connectionsPerLoop(poolMax: config.databasePoolMax, eventLoopCount: loopCount)
    app.databases.use(
        try .postgres(url: url, maxConnectionsPerEventLoop: perLoop),
        as: .psql
    )
    return PostgresProbe(app: app)
}
