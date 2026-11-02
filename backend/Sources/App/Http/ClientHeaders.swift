import Vapor

/// `X-Platform` and `X-App-Version`, required on admin routes (api/05 section 9).
struct ClientHeaders: Equatable, Sendable {
    let platform: String
    let appVersion: String

    private static let platforms: Set<String> = ["ios", "android"]
    private static var versionPattern: Regex<Substring> { /[0-9]{1,5}\.[0-9]{1,5}\.[0-9]{1,5}/ }

    /// - Throws: 400 `HEADER_INVALID` for a missing, repeated or malformed value.
    static func parse(_ headers: HTTPHeaders) throws -> ClientHeaders {
        let platform = headers[ClientHeaderLog.platformHeader], version = headers[ClientHeaderLog.appVersionHeader]
        guard platform.count == 1, platforms.contains(platform[0]),
              version.count == 1, version[0].wholeMatch(of: versionPattern) != nil
        else { throw APIError(.headerInvalid) }
        return ClientHeaders(platform: platform[0], appVersion: version[0])
    }
}
