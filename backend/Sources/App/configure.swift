import Vapor
import Fluent
import FluentPostgresDriver

/// Relative to the working directory: `backend/` when run from source, `/app`
/// in the image (the Dockerfile copies `db/` next to the binary).
private let migrationsDirectory = "db/migrations/"
private let migrateCommandName = "migrate"

/// Builds the application from `config`. The caller owns the process
/// environment; nothing here reads it directly so tests can inject values.
func configure(_ app: Application, config: AppConfig, migrationFiles: [SQLFileMigration]? = nil) async throws {
    app.http.server.configuration.hostname = "0.0.0.0"
    app.http.server.configuration.port = config.port

    let isMigrating = app.environment.arguments.dropFirst().first == migrateCommandName
    try configureDatabase(app, config: config, isMigrating: isMigrating)

    let files = try migrationFiles
        ?? MigrationFiles.load(from: app.directory.workingDirectory + migrationsDirectory)
    for file in files { app.migrations.add(file) }

    HealthRoute.register(on: app)
}

private func configureDatabase(_ app: Application, config: AppConfig, isMigrating: Bool) throws {
    // `migrate` uses the migration role (DDL rights); the server runs with the
    // limited application role (deployment.md section 3).
    let url = isMigrating ? config.databaseMigrationURL : config.databaseURL
    if isMigrating && url == nil { throw AppConfig.Failure.missing(AppConfig.Key.databaseMigrationURL) }
    guard let url else {
        app.logger.warning("No database configured; only the shallow health check is available")
        return
    }

    // Fluent pools per event loop; spread the configured maximum across them.
    let loopCount = max(1, Array(app.eventLoopGroup.makeIterator()).count)
    let perLoop = max(1, config.databasePoolMax / loopCount)
    app.databases.use(
        try .postgres(url: url, maxConnectionsPerEventLoop: perLoop),
        as: .psql
    )
    app.databaseProbe = PostgresProbe(app: app)
}
