import Foundation

/// Settings of the `review-account` command: the stage, the database, the
/// shop, and (only for `on`) the two review variables.
struct ReviewCommandConfig: Sendable {
    let stage: AppConfig.Stage
    let databaseURL: String
    let shopID: UUID
    private let variables: [String: String]

    init(variables: [String: String]) throws {
        let environment = EnvironmentVariables(variables)
        guard let url = environment.value(AppConfig.Key.databaseURL) else { throw AppConfig.Failure.missing(AppConfig.Key.databaseURL) }
        guard let shopText = environment.value(AppConfig.Key.shopID) else { throw AppConfig.Failure.missing(AppConfig.Key.shopID) }
        guard let shopID = UUID(uuidString: shopText) else { throw AppConfig.Failure.invalid(AppConfig.Key.shopID) }
        self.stage = try environment.stage()
        self.databaseURL = url
        self.shopID = shopID
        self.variables = variables
    }

    /// Read when `on` runs, so `off` works after the variables were removed.
    func review() throws -> ReviewAccountConfig? {
        try ReviewAccountConfig(environment: EnvironmentVariables(variables))
    }
}
