import XCTest
import _CryptoExtras
@testable import App

final class FcmPushSenderTests: XCTestCase {
    private let clock = MutableClock(PushTestData.now)
    private let tokenAnswer = #"{"access_token":"ya29.fake","expires_in":3600,"token_type":"Bearer"}"#

    private func make(_ transport: FakeOutboundTransport) throws -> FcmPushSender {
        try FcmPushSender(credentials: PushTestKeys.fcmCredentials, transport: transport, clock: clock)
    }

    private func script(send: @escaping @Sendable () -> OutboundResponse) -> FakeOutboundTransport {
        FakeOutboundTransport { [tokenAnswer] request in
            request.url == FcmPushSender.tokenEndpoint ? FakeOutboundTransport.answer(200, tokenAnswer) : send()
        }
    }

    func testTokenExchangeSignsAnRS256AssertionForTheMessagingScope() async throws {
        let transport = script { FakeOutboundTransport.answer(200, "{}") }
        let outcome = try await make(transport).send(PushTestData.message, to: PushTestData.android)
        XCTAssertEqual(outcome, .delivered)
        let exchange = try XCTUnwrap(transport.requests.first)
        let form = String(decoding: exchange.body, as: UTF8.self)
        XCTAssertTrue(form.hasPrefix("grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion="))
        let assertion = String(form.dropFirst("grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=".count))
        XCTAssertEqual(PushTestData.jwtPart(assertion, 0)["alg"] as? String, "RS256")
        let claims = PushTestData.jwtPart(assertion, 1)
        XCTAssertEqual(claims["iss"] as? String, "push@example-project.iam.example.com")
        XCTAssertEqual(claims["scope"] as? String, "https://www.googleapis.com/auth/firebase.messaging")
        XCTAssertEqual(claims["aud"] as? String, "https://oauth2.googleapis.com/token")
        XCTAssertEqual(claims["exp"] as? Int, 1_793_577_600 + 3_600)
        let input = assertion.split(separator: ".").prefix(2).joined(separator: ".")
        let signature = _RSA.Signing.RSASignature(rawRepresentation: PushTestData.jwtSignature(assertion))
        XCTAssertTrue(PushTestKeys.google.publicKey.isValidSignature(signature, for: Data(input.utf8), padding: .insecurePKCS1v1_5))
    }

    func testMessageRequestAndPayload() async throws {
        let transport = script { FakeOutboundTransport.answer(200, "{}") }
        _ = try await make(transport).send(PushTestData.message, to: PushTestData.android)
        let request = try XCTUnwrap(transport.requests.last)
        XCTAssertEqual(request.url, "https://fcm.googleapis.com/v1/projects/example-project/messages:send")
        XCTAssertEqual(request.header("authorization"), "Bearer ya29.fake")
        let message = try XCTUnwrap(PushTestData.json(request.body)["message"] as? [String: Any])
        XCTAssertEqual(message["token"] as? String, "fcm:token-1_a")
        XCTAssertEqual((message["data"] as? [String: String]), ["order_code": "BT-7K3M9Q"])
        let android = try XCTUnwrap(message["android"] as? [String: Any])
        XCTAssertEqual(android["priority"] as? String, "high")
        XCTAssertEqual(android["ttl"] as? String, "3600s")
        let notification = try XCTUnwrap(android["notification"] as? [String: Any])
        XCTAssertEqual(notification["channel_id"] as? String, "new_orders")
        XCTAssertEqual(notification["title_loc_key"] as? String, "PUSH_NEW_ORDER_TITLE")
        XCTAssertEqual(notification["body_loc_key"] as? String, "PUSH_NEW_ORDER_BODY")
        XCTAssertEqual(notification["body_loc_args"] as? [String], ["BT-7K3M9Q", "3", "05/11/2026"])
        XCTAssertEqual(Set(message.keys), ["token", "data", "android"])
    }

    func testAccessTokenIsReusedUntilAMinuteBeforeExpiry() async throws {
        let transport = script { FakeOutboundTransport.answer(200, "{}") }
        let sender = try make(transport)
        _ = try await sender.send(PushTestData.message, to: PushTestData.android)
        clock.advance(3_000)
        _ = try await sender.send(PushTestData.message, to: PushTestData.android)
        XCTAssertEqual(transport.requests.filter { $0.url == FcmPushSender.tokenEndpoint }.count, 1)
        clock.advance(560) // 3,560 s: inside the last minute
        _ = try await sender.send(PushTestData.message, to: PushTestData.android)
        XCTAssertEqual(transport.requests.filter { $0.url == FcmPushSender.tokenEndpoint }.count, 2)
    }

    func testUnregisteredTokenIsDead() async throws {
        let body = #"{"error":{"code":404,"status":"NOT_FOUND","details":[{"errorCode":"UNREGISTERED"}]}}"#
        let transport = script { FakeOutboundTransport.answer(404, body) }
        let outcome = try await make(transport).send(PushTestData.message, to: PushTestData.android)
        XCTAssertEqual(outcome, .invalidToken)
    }

    func testOtherRefusalKeepsTheToken() async throws {
        let transport = script { FakeOutboundTransport.answer(400, #"{"error":{"status":"INVALID_ARGUMENT"}}"#) }
        let outcome = try await make(transport).send(PushTestData.message, to: PushTestData.android)
        XCTAssertEqual(outcome, .rejected)
    }

    func testServerErrorsAndTokenFailuresAreRetryable() async throws {
        for status in [429, 500, 503] {
            let transport = script { FakeOutboundTransport.answer(status) }
            do {
                _ = try await make(transport).send(PushTestData.message, to: PushTestData.android)
                XCTFail("\(status) must throw")
            } catch is FcmError {}
        }
        let noToken = FakeOutboundTransport { _ in FakeOutboundTransport.answer(401, #"{"error":"invalid_grant"}"#) }
        do {
            _ = try await make(noToken).send(PushTestData.message, to: PushTestData.android)
            XCTFail("a failed exchange must throw")
        } catch is FcmError {}
        XCTAssertEqual(noToken.requests.count, 1, "no message is sent without an access token")
    }

    func testRejectedAccessTokenIsExchangedAgainOnTheNextTry() async throws {
        let calls = LockedBox(0)
        let transport = script { calls.set(calls.value + 1); return FakeOutboundTransport.answer(calls.value == 1 ? 401 : 200) }
        let sender = try make(transport)
        do { _ = try await sender.send(PushTestData.message, to: PushTestData.android) } catch is FcmError {}
        let outcome = try await sender.send(PushTestData.message, to: PushTestData.android)
        XCTAssertEqual(outcome, .delivered)
        XCTAssertEqual(transport.requests.filter { $0.url == FcmPushSender.tokenEndpoint }.count, 2)
    }

    func testBrokenServiceAccountIsRefused() {
        let bad = PushConfig.Fcm(projectID: "p", serviceAccountJSON: #"{"client_email":"a","private_key":"nope"}"#)
        XCTAssertThrowsError(try FcmPushSender(credentials: bad, transport: FakeOutboundTransport(), clock: clock))
    }
}
