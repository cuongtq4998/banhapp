import Foundation

/// Google push (FCM HTTP v1) with a service-account OAuth2 token (ADR-0024).
/// Written from Google's public documentation; not yet run against the real
/// service. Android receives the keys through `android.notification` so the
/// text comes from the app's resources.
final class FcmPushSender: PushSender {
    static let ttlSeconds = 3_600
    static let tokenEndpoint = "https://oauth2.googleapis.com/token"

    private let projectID: String
    private let transport: any OutboundTransport
    private let tokens: FcmAccessTokens

    init(credentials: PushConfig.Fcm, transport: any OutboundTransport, clock: any WallClock) throws {
        projectID = credentials.projectID
        self.transport = transport
        tokens = FcmAccessTokens(account: try FcmServiceAccount.parse(credentials.serviceAccountJSON), transport: transport, clock: clock)
    }

    func send(_ message: PushMessage, to target: PushTarget) async throws -> PushOutcome {
        let access = try await tokens.token()
        let response = try await transport.send(OutboundRequest(
            url: "https://fcm.googleapis.com/v1/projects/\(projectID)/messages:send",
            headers: ["authorization": "Bearer \(access)", "content-type": "application/json"],
            body: try Self.payload(for: message, token: target.token)
        ))
        switch response.status {
        case 200:
            return .delivered
        case 404 where Self.errorCode(of: response) == "UNREGISTERED", 400 where Self.errorCode(of: response) == "UNREGISTERED":
            return .invalidToken
        case 401:
            await tokens.forget()
            throw FcmError.retryable
        case 429, 500...599:
            throw FcmError.retryable
        default:
            return .rejected
        }
    }

    static func payload(for message: PushMessage, token: String) throws -> Data {
        struct Notification: Encodable {
            let channelID = PushKeys.androidChannel, titleKey = PushKeys.title, bodyKey = PushKeys.body
            let bodyArguments: [String]
            enum CodingKeys: String, CodingKey {
                case channelID = "channel_id", titleKey = "title_loc_key", bodyKey = "body_loc_key", bodyArguments = "body_loc_args"
            }
        }
        struct Android: Encodable { let priority = "high", ttl = "\(FcmPushSender.ttlSeconds)s", notification: Notification }
        struct Custom: Encodable {
            let orderCode: String
            enum CodingKeys: String, CodingKey { case orderCode = "order_code" }
        }
        struct Inner: Encodable { let token: String, data: Custom, android: Android }
        struct Outer: Encodable { let message: Inner }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let android = Android(notification: Notification(bodyArguments: message.bodyArguments))
        return try encoder.encode(Outer(message: Inner(token: token, data: Custom(orderCode: message.orderCode), android: android)))
    }

    private static func errorCode(of response: OutboundResponse) -> String? {
        guard let root = try? JSONSerialization.jsonObject(with: response.body) as? [String: Any],
              let error = root["error"] as? [String: Any] else { return nil }
        let details = error["details"] as? [[String: Any]] ?? []
        return details.compactMap { $0["errorCode"] as? String }.first
    }
}

enum FcmError: Error { case retryable }
