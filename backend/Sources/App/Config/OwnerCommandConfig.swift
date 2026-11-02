import Foundation

/// Settings of the `create-owner` command: the stage, the database and the
/// shop. Nothing else, so the operator sets no unrelated variable.
struct OwnerCommandConfig: Equatable, Sendable {
    let stage: AppConfig.Stage
    let databaseURL: String
    let shopID: UUID

    init(stage: AppConfig.Stage, databaseURL: String, shopID: UUID) {
        self.stage = stage
        self.databaseURL = databaseURL
        self.shopID = shopID
    }

    init(variables: [String: String]) throws {
        let environment = EnvironmentVariables(variables)
        guard let url = environment.value(AppConfig.Key.databaseURL) else { throw AppConfig.Failure.missing(AppConfig.Key.databaseURL) }
        guard let shopText = environment.value(AppConfig.Key.shopID) else { throw AppConfig.Failure.missing(AppConfig.Key.shopID) }
        guard let shopID = UUID(uuidString: shopText) else { throw AppConfig.Failure.invalid(AppConfig.Key.shopID) }
        self.init(stage: try environment.stage(), databaseURL: url, shopID: shopID)
    }
}
