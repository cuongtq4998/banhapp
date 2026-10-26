import Vapor
import Logging
import NIOCore
import NIOPosix
import Foundation

@main
enum Entrypoint {
    /// One event loop: the migration pool holds a single connection
    /// (`MigrationConfig.poolSize`).
    private static let migrationLoopCount = 1

    static func main() async throws {
        var env = try Environment.detect()
        try LoggingSystem.bootstrap(from: &env)

        // Configuration is read per command, before the app exists, because
        // the event loop count depends on it: `migrate` must not need the
        // variables only `serve` uses.
        let variables = ProcessInfo.processInfo.environment
        let isMigrating = env.arguments.dropFirst().first == migrateCommandName
        let loops: Int
        let setUp: (Application) async throws -> Void
        if isMigrating {
            let config = try MigrationConfig(variables: variables)
            loops = migrationLoopCount
            setUp = { try configureMigrator($0, config: config) }
        } else {
            let config = try AppConfig(variables: variables)
            loops = DatabasePoolSizing.eventLoopCount(poolMax: config.databasePoolMax, coreCount: System.coreCount)
            setUp = { try await configure($0, config: config) }
        }
        let group = MultiThreadedEventLoopGroup(numberOfThreads: loops)

        let app = try await Application.make(env, .shared(group))
        do {
            try await setUp(app)
            try await app.execute()
        } catch {
            app.logger.report(error: error)
            try? await app.asyncShutdown()
            try? await group.shutdownGracefully()
            throw error
        }
        try await app.asyncShutdown()
        try await group.shutdownGracefully()
    }
}
