import Vapor
import Logging
import NIOCore
import NIOPosix
import Foundation

@main
enum Entrypoint {
    static func main() async throws {
        var env = try Environment.detect()
        try LoggingSystem.bootstrap(from: &env)

        // Read before the app exists: the event loop count depends on the
        // pool budget (DatabasePoolSizing).
        let config = try AppConfig(variables: ProcessInfo.processInfo.environment)
        let loops = DatabasePoolSizing.eventLoopCount(
            poolMax: config.databasePoolMax,
            coreCount: System.coreCount
        )
        let group = MultiThreadedEventLoopGroup(numberOfThreads: loops)

        let app = try await Application.make(env, .shared(group))
        do {
            try await configure(app, config: config)
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
