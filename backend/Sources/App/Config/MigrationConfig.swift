import Foundation

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

