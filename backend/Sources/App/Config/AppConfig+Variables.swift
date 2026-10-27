import Foundation

extension AppConfig {
    init(variables: [String: String]) throws {
        let environment = EnvironmentVariables(variables)
        let value = environment.value
        let stage = try environment.stage()

        guard let portText = value(Key.port) else { throw Failure.missing(Key.port) }
        guard let port = Int(portText), (1...65_535).contains(port) else { throw Failure.invalid(Key.port) }

        let databaseURL = value(Key.databaseURL)
        // A local run may start without a database (shallow health only); the
        // hosted environments must not.
        if databaseURL == nil && stage != .local { throw Failure.missing(Key.databaseURL) }

        var poolMax = Default.databasePoolMax
        if let poolText = value(Key.databasePoolMax) {
            guard let parsed = Int(poolText), parsed >= 1 else { throw Failure.invalid(Key.databasePoolMax) }
            poolMax = parsed
        }

        let shopID = try Self.parseShopID(environment, stage: stage)
        let trustProxy = try Self.parseTrustProxy(environment)

        var readLimit = Default.rateLimitReadPerMinute
        if let limitText = value(Key.rateLimitReadPerMinute) {
            guard let parsed = Int(limitText), parsed >= 1 else { throw Failure.invalid(Key.rateLimitReadPerMinute) }
            readLimit = parsed
        }

        self.init(
            stage: stage,
            port: port,
            databaseURL: databaseURL,
            databasePoolMax: poolMax,
            shopID: shopID,
            trustProxy: trustProxy,
            rateLimitReadPerMinute: readLimit,
            publicAssetBaseURL: value(Key.publicAssetBaseURL).map(Self.trimmingTrailingSlashes)
                ?? Default.publicAssetBaseURL
        )
    }

    /// The hosted environments must name their shop; a local run may omit it.
    private static func parseShopID(_ environment: EnvironmentVariables, stage: Stage) throws -> UUID? {
        guard let text = environment.value(Key.shopID) else {
            if stage != .local { throw Failure.missing(Key.shopID) }
            return nil
        }
        guard let id = UUID(uuidString: text) else { throw Failure.invalid(Key.shopID) }
        return id
    }

    private static func parseTrustProxy(_ environment: EnvironmentVariables) throws -> Bool {
        guard let text = environment.value(Key.trustProxy) else { return false }
        switch text.lowercased() {
        case "true": return true
        case "false": return false
        default: throw Failure.invalid(Key.trustProxy)
        }
    }

    /// `image_url` is base + `/assets/...`, so a trailing slash would double up.
    private static func trimmingTrailingSlashes(_ base: String) -> String {
        var trimmed = Substring(base)
        while trimmed.hasSuffix("/") { trimmed = trimmed.dropLast() }
        return String(trimmed)
    }
}
