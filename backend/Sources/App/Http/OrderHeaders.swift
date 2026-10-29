import Vapor

/// The three headers `POST /v1/orders` requires (api.md section 1 and 4.3).
struct OrderHeaders: Equatable, Sendable {
    static let idempotencyKeyName = "Idempotency-Key"
    static let replayHeaderName = "Idempotent-Replay"

    let idempotencyKey: UUID
    let platform: String
    let appVersion: String

    private static let platforms: Set<String> = ["ios", "android"]
    /// Numbers only and bounded, like `ClientHeaderLog`; always within the
    /// 1 to 20 characters the `app_version` column allows.
    private static var versionPattern: Regex<Substring> { /[0-9]{1,5}\.[0-9]{1,5}\.[0-9]{1,5}/ }

    /// - Throws: 400 `IDEMPOTENCY_KEY_REQUIRED` when the key is missing or
    ///   blank; 400 `HEADER_INVALID` for a key that is not a UUID v4 and for
    ///   a missing, repeated or malformed platform or version.
    static func parse(_ headers: HTTPHeaders) throws -> OrderHeaders {
        let keys = headers[idempotencyKeyName]
        guard let key = keys.first, !key.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw APIError(.idempotencyKeyRequired)
        }
        guard keys.count == 1, let uuid = uuidV4(key),
              let platform = single(headers, ClientHeaderLog.platformHeader), platforms.contains(platform),
              let version = single(headers, ClientHeaderLog.appVersionHeader), version.wholeMatch(of: versionPattern) != nil
        else { throw APIError(.headerInvalid) }
        return OrderHeaders(idempotencyKey: uuid, platform: platform, appVersion: version)
    }

    private static func single(_ headers: HTTPHeaders, _ name: String) -> String? {
        let values = headers[name]
        return values.count == 1 ? values[0] : nil
    }

    /// RFC 4122 version 4: the version nibble is 4 and the variant is 8, 9, a or b.
    private static func uuidV4(_ text: String) -> UUID? {
        let characters = Array(text)
        guard characters.count == 36, characters[14] == "4", "89abAB".contains(characters[19]) else { return nil }
        return UUID(uuidString: text)
    }
}
