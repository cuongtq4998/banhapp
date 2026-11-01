import XCTVapor
@testable import App

/// BR-7, FR-26: what really leaves for APNs and FCM holds no personal data.
/// The real senders run over a fake transport; the order has a name, phone,
/// address and note, and every byte of every request is searched for them.
final class PushPayloadPrivacyTests: PushDatabaseTestCase {
    func testSerialisedRequestsHoldNoPersonalData() async throws {
        let transport = FakeOutboundTransport { request in
            request.url == FcmPushSender.tokenEndpoint
                ? FakeOutboundTransport.answer(200, #"{"access_token":"ya29.fake","expires_in":3600}"#) : FakeOutboundTransport.answer(200)
        }
        let live = LivePushSender(
            apns: try ApnsPushSender(credentials: PushTestKeys.apnsCredentials, transport: transport, clock: clock),
            fcm: try FcmPushSender(credentials: PushTestKeys.fcmCredentials, transport: transport, clock: clock)
        )
        app.services.push = live
        let staff = try await addAccount(.staff)
        let android = try await phoneOn("android", of: staff.email)
        _ = try await register(ownerPhone, platform: "ios", token: "owner-ios-token", environment: "sandbox")
        _ = try await register(android, platform: "android", token: "android-token")

        let body = try orderBody(cakes: 4)
        let digits = String(decoding: body, as: UTF8.self).split(whereSeparator: { !$0.isNumber }).map(String.init).first { $0.count == 10 } ?? "?"
        let reply = try await placeOrder(body)
        XCTAssertEqual(reply.status, .created)
        await app.services.background.drain()

        let sends = transport.requests.filter { $0.url != FcmPushSender.tokenEndpoint }
        XCTAssertEqual(sends.count, 2)
        let secrets = [Self.customerName, "Hương", "Ngõ Hoa Mai", "12 Ngõ", Self.customerAddress, Self.customerNote, "chiều", digits, String(digits.dropFirst()), "Test"]
        for request in sends {
            let everything = request.url + request.headers.map { "\($0.key)=\($0.value)" }.joined() + String(decoding: request.body, as: UTF8.self)
            for secret in secrets { XCTAssertFalse(everything.contains(secret), "\(secret) leaked into \(request.url)") }
            let code = reply.string("order_code")
            XCTAssertTrue(String(decoding: request.body, as: UTF8.self).contains(code))
        }
        let apnsBody = PushTestData.json(try XCTUnwrap(sends.first { $0.url.contains("apple.com") }).body)
        let alert = try XCTUnwrap((apnsBody["aps"] as? [String: Any])?["alert"] as? [String: Any])
        XCTAssertEqual((alert["loc-args"] as? [String])?[1], "4")
    }
}
