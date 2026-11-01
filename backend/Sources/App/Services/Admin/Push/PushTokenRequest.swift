import BanhContracts

/// The body of `PUT /v1/admin/push-token` (api/06 10.8), checked field by field.
struct PushTokenRequest: Sendable, Equatable {
    static let maxTokenLength = 512
    private static let allowedKeys: Set<String> = ["platform", "token", "apns_environment"]
    private static let environments: Set<String> = ["production", "sandbox"]

    let platform: PushTarget.Platform
    let token: String
    /// Set for iOS only; an Android phone's value is ignored.
    let apnsEnvironment: String?

    /// - Throws: `VALIDATION_FAILED` naming the first bad field: an unknown
    ///   key, a platform that is not `ios` or `android`, a token that is empty,
    ///   longer than 512 characters or holds spaces or control characters,
    ///   an iOS phone without a valid `apns_environment`.
    static func parse(_ body: [String: JSONValue]) throws -> PushTokenRequest {
        func invalid(_ field: String, _ code: String) -> APIError {
            APIError(.validationFailed, fields: [.init(field: field, code: code, messageKey: APIErrorCode.genericMessageKey)])
        }
        if let unknown = body.keys.filter({ !allowedKeys.contains($0) }).sorted().first { throw invalid(unknown, "UNKNOWN_FIELD") }
        guard case .string(let platformText)? = body["platform"], let platform = PushTarget.Platform(rawValue: platformText) else {
            throw invalid("platform", "PLATFORM_INVALID")
        }
        guard case .string(let token)? = body["token"], (1...maxTokenLength).contains(token.count),
              !token.unicodeScalars.contains(where: { $0.properties.isWhitespace || $0.properties.generalCategory == .control }) else {
            throw invalid("token", "TOKEN_INVALID")
        }
        var environment: String?
        switch body["apns_environment"] {
        case nil, .null?:
            if platform == .ios { throw invalid("apns_environment", "APNS_ENVIRONMENT_INVALID") }
        case .string(let text)? where environments.contains(text):
            environment = platform == .ios ? text : nil
        default:
            throw invalid("apns_environment", "APNS_ENVIRONMENT_INVALID")
        }
        return PushTokenRequest(platform: platform, token: token, apnsEnvironment: environment)
    }
}
