import Foundation
import Crypto
import _CryptoExtras
import NIOConcurrencyHelpers
@testable import App

/// Answers the calls of a sender from a script and keeps the requests. No network.
final class FakeOutboundTransport: OutboundTransport, @unchecked Sendable {
    typealias Handler = @Sendable (OutboundRequest) throws -> OutboundResponse
    // Invariant: both fields are only touched under `lock`.
    private let lock = NIOLock()
    private var recorded: [OutboundRequest] = []
    private var handler: Handler

    init(_ handler: @escaping Handler = { _ in OutboundResponse(status: 200, body: Data()) }) { self.handler = handler }

    var requests: [OutboundRequest] { lock.withLock { recorded } }
    func respond(_ handler: @escaping Handler) { lock.withLock { self.handler = handler } }

    func send(_ request: OutboundRequest) async throws -> OutboundResponse {
        let current = lock.withLock { () -> Handler in recorded.append(request); return handler }
        return try current(request)
    }

    static func answer(_ status: Int, _ json: String = "") -> OutboundResponse { OutboundResponse(status: status, body: Data(json.utf8)) }
}

/// Keys made fresh for each run: no key material is committed.
enum PushTestKeys {
    static let apns = P256.Signing.PrivateKey()
    static let google = try! _RSA.Signing.PrivateKey(keySize: .bits2048) // swiftlint:disable:this force_try

    static var apnsCredentials: PushConfig.Apns {
        PushConfig.Apns(keyID: "KEYID12345", teamID: "TEAMID1234", privateKey: apns.pemRepresentation, topic: "app.example.admin")
    }

    static var fcmCredentials: PushConfig.Fcm {
        let json = #"{"client_email":"push@example-project.iam.example.com","private_key":\#(quoted(google.pemRepresentation))}"#
        return PushConfig.Fcm(projectID: "example-project", serviceAccountJSON: json)
    }

    static func quoted(_ text: String) -> String {
        let data = (try? JSONSerialization.data(withJSONObject: [text])) ?? Data()
        return String(decoding: data.dropFirst().dropLast(), as: UTF8.self)
    }
}

enum PushTestData {
    static let message = PushMessage(orderCode: "BT-7K3M9Q", cakes: 3, deliveryDate: BusinessDate(year: 2026, month: 11, day: 5))
    static let ios = PushTarget(platform: .ios, token: "abc123def456", apnsEnvironment: "sandbox")
    static let iosProduction = PushTarget(platform: .ios, token: "abc123def456", apnsEnvironment: "production")
    static let android = PushTarget(platform: .android, token: "fcm:token-1_a", apnsEnvironment: nil)
    static let now = Date(timeIntervalSince1970: 1_793_577_600)

    /// Text before the first "." decoded from base64url.
    static func jwtPart(_ token: String, _ index: Int) -> [String: Any] {
        var text = token.split(separator: ".")[index].replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while text.count % 4 != 0 { text += "=" }
        return (Data(base64Encoded: text).flatMap { try? JSONSerialization.jsonObject(with: $0) } as? [String: Any]) ?? [:]
    }

    static func jwtSignature(_ token: String) -> Data {
        var text = token.split(separator: ".")[2].replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while text.count % 4 != 0 { text += "=" }
        return Data(base64Encoded: text) ?? Data()
    }

    static func json(_ data: Data) -> [String: Any] { (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:] }
}
