import XCTest
import Crypto
@testable import App

final class ApnsPushSenderTests: XCTestCase {
    private let clock = MutableClock(PushTestData.now)

    private func make(_ transport: FakeOutboundTransport) throws -> ApnsPushSender {
        try ApnsPushSender(credentials: PushTestKeys.apnsCredentials, transport: transport, clock: clock)
    }

    func testRequestFollowsTheProviderRules() async throws {
        let transport = FakeOutboundTransport()
        let outcome = try await make(transport).send(PushTestData.message, to: PushTestData.ios)
        XCTAssertEqual(outcome, .delivered)
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.method, "POST")
        XCTAssertEqual(request.url, "https://api.sandbox.push.apple.com/3/device/abc123def456")
        XCTAssertEqual(request.header("apns-topic"), "app.example.admin")
        XCTAssertEqual(request.header("apns-push-type"), "alert")
        XCTAssertEqual(request.header("apns-priority"), "10")
        XCTAssertEqual(request.header("apns-expiration"), String(1_793_577_600 + 3_600))
        XCTAssertLessThanOrEqual(request.timeoutSeconds, 10)
    }

    func testProductionTokenGoesToTheProductionHost() async throws {
        let transport = FakeOutboundTransport()
        _ = try await make(transport).send(PushTestData.message, to: PushTestData.iosProduction)
        XCTAssertEqual(transport.requests.first?.url, "https://api.push.apple.com/3/device/abc123def456")
    }

    func testProviderTokenIsAnES256JWTThatVerifiesAndIsReusedFor40Minutes() async throws {
        let transport = FakeOutboundTransport()
        let sender = try make(transport)
        _ = try await sender.send(PushTestData.message, to: PushTestData.ios)
        clock.advance(39 * 60)
        _ = try await sender.send(PushTestData.message, to: PushTestData.ios)
        clock.advance(2 * 60)
        _ = try await sender.send(PushTestData.message, to: PushTestData.ios)
        let tokens = transport.requests.map { String(($0.header("authorization") ?? "").dropFirst("bearer ".count)) }
        XCTAssertEqual(tokens[0], tokens[1])
        XCTAssertNotEqual(tokens[1], tokens[2], "a new token after 40 minutes")
        let token = tokens[0]
        XCTAssertEqual(PushTestData.jwtPart(token, 0)["alg"] as? String, "ES256")
        XCTAssertEqual(PushTestData.jwtPart(token, 0)["kid"] as? String, "KEYID12345")
        XCTAssertEqual(PushTestData.jwtPart(token, 1)["iss"] as? String, "TEAMID1234")
        XCTAssertEqual(PushTestData.jwtPart(token, 1)["iat"] as? Int, 1_793_577_600)
        let input = token.split(separator: ".").prefix(2).joined(separator: ".")
        let signature = try P256.Signing.ECDSASignature(rawRepresentation: PushTestData.jwtSignature(token))
        XCTAssertTrue(PushTestKeys.apns.publicKey.isValidSignature(signature, for: Data(input.utf8)))
    }

    func testPayloadHoldsKeysAndArgumentsOnly() async throws {
        let transport = FakeOutboundTransport()
        _ = try await make(transport).send(PushTestData.message, to: PushTestData.ios)
        let body = PushTestData.json(try XCTUnwrap(transport.requests.first).body)
        XCTAssertEqual(body["order_code"] as? String, "BT-7K3M9Q")
        let aps = try XCTUnwrap(body["aps"] as? [String: Any])
        XCTAssertEqual(aps["thread-id"] as? String, "new_orders")
        XCTAssertEqual(aps["interruption-level"] as? String, "active")
        let alert = try XCTUnwrap(aps["alert"] as? [String: Any])
        XCTAssertEqual(alert["title-loc-key"] as? String, "PUSH_NEW_ORDER_TITLE")
        XCTAssertEqual(alert["loc-key"] as? String, "PUSH_NEW_ORDER_BODY")
        XCTAssertEqual(alert["loc-args"] as? [String], ["BT-7K3M9Q", "3", "05/11/2026"])
        XCTAssertEqual(Set(body.keys), ["aps", "order_code"])
        XCTAssertEqual(Set(alert.keys), ["title-loc-key", "loc-key", "loc-args"])
    }

    func testDeadTokenAnswers() async throws {
        let transport = FakeOutboundTransport { _ in FakeOutboundTransport.answer(410, #"{"reason":"Unregistered"}"#) }
        let gone = try await make(transport).send(PushTestData.message, to: PushTestData.ios)
        XCTAssertEqual(gone, .invalidToken)
        transport.respond { _ in FakeOutboundTransport.answer(400, #"{"reason":"BadDeviceToken"}"#) }
        let bad = try await make(transport).send(PushTestData.message, to: PushTestData.ios)
        XCTAssertEqual(bad, .invalidToken)
    }

    func testOtherRefusalsKeepTheToken() async throws {
        let transport = FakeOutboundTransport { _ in FakeOutboundTransport.answer(400, #"{"reason":"BadTopic"}"#) }
        let refused = try await make(transport).send(PushTestData.message, to: PushTestData.ios)
        XCTAssertEqual(refused, .rejected)
        transport.respond { _ in FakeOutboundTransport.answer(400, #"{"reason":"DeviceTokenNotForTopic"}"#) }
        let wrongTopic = try await make(transport).send(PushTestData.message, to: PushTestData.ios)
        XCTAssertEqual(wrongTopic, .rejected)
    }

    func testServerErrorsAndNetworkFailuresAreRetryable() async throws {
        for status in [429, 500, 503] {
            let transport = FakeOutboundTransport { _ in FakeOutboundTransport.answer(status) }
            do {
                _ = try await make(transport).send(PushTestData.message, to: PushTestData.ios)
                XCTFail("\(status) must throw")
            } catch is ApnsError {}
        }
        let down = FakeOutboundTransport { _ in throw URLError(.timedOut) }
        do {
            _ = try await make(down).send(PushTestData.message, to: PushTestData.ios)
            XCTFail("a timeout must throw")
        } catch is URLError {}
    }

    func testExpiredProviderTokenIsRenewedOnTheNextTry() async throws {
        let transport = FakeOutboundTransport { _ in FakeOutboundTransport.answer(403, #"{"reason":"ExpiredProviderToken"}"#) }
        let sender = try make(transport)
        do { _ = try await sender.send(PushTestData.message, to: PushTestData.ios) } catch is ApnsError {}
        clock.advance(1)
        transport.respond { _ in FakeOutboundTransport.answer(200) }
        let outcome = try await sender.send(PushTestData.message, to: PushTestData.ios)
        XCTAssertEqual(outcome, .delivered)
        let tokens = transport.requests.map { $0.header("authorization") }
        XCTAssertNotEqual(tokens[0], tokens[1])
    }

    func testBadKeyIsRefusedAtConstruction() {
        let bad = PushConfig.Apns(keyID: "K", teamID: "T", privateKey: "not a key", topic: "x")
        XCTAssertThrowsError(try ApnsPushSender(credentials: bad, transport: FakeOutboundTransport(), clock: clock))
    }
}
