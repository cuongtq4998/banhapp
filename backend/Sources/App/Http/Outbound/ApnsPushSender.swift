import Foundation
import Crypto
import NIOConcurrencyHelpers

/// Apple push (APNs) with provider-token authentication over HTTP/2
/// (ADR-0024): an ES256 token from the `.p8` key, reused for 40 minutes (Apple
/// accepts 20 to 60). Written from Apple's public documentation; not yet run
/// against the real service.
final class ApnsPushSender: PushSender {
    static let tokenLifetime: TimeInterval = 40 * 60
    static let expirySeconds = 3_600

    private struct Header: Encodable { let alg = "ES256", kid: String }
    private struct Claims: Encodable { let iss: String, iat: Int }
    private struct Cached { let token: String; let issuedAt: Date }

    private let credentials: PushConfig.Apns
    private let key: P256.Signing.PrivateKey
    private let transport: any OutboundTransport
    private let clock: any WallClock
    private let cache = NIOLockedValueBox<Cached?>(nil)

    init(credentials: PushConfig.Apns, transport: any OutboundTransport, clock: any WallClock) throws {
        self.credentials = credentials
        self.key = try P256.Signing.PrivateKey(pemRepresentation: credentials.privateKey)
        self.transport = transport
        self.clock = clock
    }

    func send(_ message: PushMessage, to target: PushTarget) async throws -> PushOutcome {
        let response = try await transport.send(try request(for: message, to: target))
        switch response.status {
        case 200:
            return .delivered
        case 410:
            return .invalidToken
        case 400 where Self.reason(of: response) == "BadDeviceToken":
            return .invalidToken
        case 403 where Self.reason(of: response)?.hasSuffix("ProviderToken") == true:
            cache.withLockedValue { $0 = nil }
            throw ApnsError.retryable
        case 429, 500...599:
            throw ApnsError.retryable
        default:
            return .rejected
        }
    }

    func request(for message: PushMessage, to target: PushTarget) throws -> OutboundRequest {
        let host = target.apnsEnvironment == "sandbox" ? "api.sandbox.push.apple.com" : "api.push.apple.com"
        let encodedToken = target.token.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""
        let now = clock.now()
        return OutboundRequest(
            url: "https://\(host)/3/device/\(encodedToken)",
            headers: [
                "authorization": "bearer \(try providerToken(at: now))",
                "apns-topic": credentials.topic,
                "apns-push-type": "alert",
                "apns-priority": "10",
                "apns-expiration": String(Int(now.timeIntervalSince1970) + Self.expirySeconds),
                "content-type": "application/json"
            ],
            body: try Self.payload(for: message)
        )
    }

    /// Localisation keys only: the Vietnamese text lives in the app (ADR-0024).
    static func payload(for message: PushMessage) throws -> Data {
        struct Alert: Encodable {
            let titleKey: String, bodyKey: String, bodyArguments: [String]
            enum CodingKeys: String, CodingKey { case titleKey = "title-loc-key", bodyKey = "loc-key", bodyArguments = "loc-args" }
        }
        struct Aps: Encodable {
            let alert: Alert, sound = "default", threadID = "new_orders", interruptionLevel = "active"
            enum CodingKeys: String, CodingKey { case alert, sound, threadID = "thread-id", interruptionLevel = "interruption-level" }
        }
        struct Body: Encodable {
            let aps: Aps, orderCode: String
            enum CodingKeys: String, CodingKey { case aps, orderCode = "order_code" }
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let alert = Alert(titleKey: PushKeys.title, bodyKey: PushKeys.body, bodyArguments: message.bodyArguments)
        return try encoder.encode(Body(aps: Aps(alert: alert), orderCode: message.orderCode))
    }

    private func providerToken(at now: Date) throws -> String {
        if let cached = cache.withLockedValue({ $0 }), now.timeIntervalSince(cached.issuedAt) < Self.tokenLifetime { return cached.token }
        let token = try JSONWebToken.es256(
            header: Header(kid: credentials.keyID), claims: Claims(iss: credentials.teamID, iat: Int(now.timeIntervalSince1970)), key: key
        )
        cache.withLockedValue { $0 = Cached(token: token, issuedAt: now) }
        return token
    }

    private static func reason(of response: OutboundResponse) -> String? {
        (try? JSONSerialization.jsonObject(with: response.body) as? [String: Any])?["reason"] as? String
    }
}

enum ApnsError: Error { case retryable }

/// Keys of the notification text, shared by both services (api/06 10.12).
enum PushKeys {
    static let title = "PUSH_NEW_ORDER_TITLE"
    static let body = "PUSH_NEW_ORDER_BODY"
    static let androidChannel = "new_orders"
}
