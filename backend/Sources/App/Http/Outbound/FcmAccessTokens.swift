import Foundation

/// OAuth2 access tokens for FCM: an RS256 assertion from the service account,
/// exchanged at Google's token endpoint and kept until a minute before expiry.
/// An actor, so parallel sends share one exchange.
actor FcmAccessTokens {
    private struct Header: Encodable { let alg = "RS256", typ = "JWT" }
    private struct Claims: Encodable {
        let iss: String, scope: String, aud: String, iat: Int, exp: Int
    }
    private struct Answer: Decodable {
        let accessToken: String
        let expiresIn: Int
        enum CodingKeys: String, CodingKey { case accessToken = "access_token", expiresIn = "expires_in" }
    }

    static let scope = "https://www.googleapis.com/auth/firebase.messaging"
    static let assertionLifetime = 3_600
    static let renewMarginSeconds: TimeInterval = 60

    private let account: FcmServiceAccount
    private let transport: any OutboundTransport
    private let clock: any WallClock
    private var cached: (token: String, expiresAt: Date)?

    init(account: FcmServiceAccount, transport: any OutboundTransport, clock: any WallClock) {
        self.account = account
        self.transport = transport
        self.clock = clock
    }

    func token() async throws -> String {
        let now = clock.now()
        if let cached, now < cached.expiresAt.addingTimeInterval(-Self.renewMarginSeconds) { return cached.token }
        let issued = Int(now.timeIntervalSince1970)
        let assertion = try JSONWebToken.rs256(
            header: Header(),
            claims: Claims(iss: account.clientEmail, scope: Self.scope, aud: FcmPushSender.tokenEndpoint, iat: issued, exp: issued + Self.assertionLifetime),
            key: account.key
        )
        let form = "grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=\(assertion)"
        let response = try await transport.send(OutboundRequest(
            url: FcmPushSender.tokenEndpoint, headers: ["content-type": "application/x-www-form-urlencoded"], body: Data(form.utf8)
        ))
        guard response.status == 200, let answer = try? JSONDecoder().decode(Answer.self, from: response.body) else {
            throw FcmError.retryable
        }
        cached = (answer.accessToken, now.addingTimeInterval(TimeInterval(answer.expiresIn)))
        return answer.accessToken
    }

    func forget() { cached = nil }
}
