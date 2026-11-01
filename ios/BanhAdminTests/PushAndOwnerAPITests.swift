import BanhCore
import Foundation
import Testing
@testable import BanhAdmin

@MainActor
struct PushTests {
    private struct RecordingPush: PushAPI {
        let log: PushLog
        func register(token: String, environment: String) async throws {
            if log.fail { throw APIError.networkUnavailable }
            log.sent.append((token, environment))
        }
    }

    final class PushLog: @unchecked Sendable {
        var sent: [(String, String)] = []
        var fail = false
    }

    @Test func tokenIsSentWithTheEnvironmentAfterSignIn() async {
        let log = PushLog()
        let provider = FakeTokenProvider()
        let registrar = PushRegistrar(provider: provider, api: RecordingPush(log: log), environment: "sandbox")
        await registrar.register(prompt: true)
        #expect(provider.prompts == 1)
        #expect(log.sent.first?.0 == "fake-token-0001" && log.sent.first?.1 == "sandbox")
    }

    @Test func deniedPermissionSendsNothingAndLaterLaunchesDoNotPrompt() async {
        let log = PushLog()
        let provider = FakeTokenProvider()
        provider.result = nil
        let registrar = PushRegistrar(provider: provider, api: RecordingPush(log: log), environment: "sandbox")
        await registrar.register(prompt: true)
        await registrar.register(prompt: false)
        #expect(log.sent.isEmpty && provider.prompts == 1)
    }

    @Test func aFailedCallIsSilentAndSignOutUnregisters() async {
        let log = PushLog()
        log.fail = true
        let provider = FakeTokenProvider()
        let registrar = PushRegistrar(provider: provider, api: RecordingPush(log: log), environment: "production")
        await registrar.register(prompt: false)
        #expect(registrar.lastSent == nil)
        log.fail = false
        await registrar.register(prompt: false)
        #expect(registrar.lastSent == "fake-token-0001")
        registrar.unregister()
        #expect(registrar.lastSent == nil && provider.unregisterCount == 1)
    }

    @Test func routerKeepsAnEventUntilSomeoneListens() {
        let router = NotificationRouter()
        router.deliver(.tapped(orderCode: "BT-1"))
        var seen: [NotificationEvent] = []
        router.listen { seen.append($0) }
        router.deliver(.foreground(orderCode: "BT-2"))
        #expect(seen == [.tapped(orderCode: "BT-1"), .foreground(orderCode: "BT-2")])
    }

    @Test func orderCodeComesFromThePayloadOnly() {
        #expect(NotificationRouter.orderCode(from: ["order_code": "BT-7K3M9Q", "aps": ["alert": "x"]]) == "BT-7K3M9Q")
        #expect(NotificationRouter.orderCode(from: ["order_code": ""]) == nil)
        #expect(NotificationRouter.orderCode(from: [:]) == nil)
    }
}

struct OwnerAPITests {
    private func api(_ transport: ScriptedTransport) -> HTTPOwnerAPI {
        let client = APIClient(baseURL: URL(string: "http://stub.invalid")!, appVersion: "1.0.0", transport: transport)
        let session = SessionManager(client: client, store: InMemoryTokenStore(refreshToken: "rt"))
        return HTTPOwnerAPI(client: client, session: session)
    }

    private let cake = #"{"cake_id":"c1","name":"B","description":"D","price_vnd":1,"is_active":true,"image_url":"/a"}"#

    @Test func cakeUploadIsOneMultipartRequestWithTheBearerToken() async throws {
        let transport = ScriptedTransport { request, _ in
            request.url?.path == "/v1/auth/refresh" ? (200, ScriptedTransport.pair) : (201, self.cake)
        }
        _ = try await api(transport).addCake(name: "B", description: "D", priceVnd: 150_000, jpeg: Data([0xFF, 0xD8, 0xFF, 1]))
        let request = try #require(transport.requests.last)
        #expect(request.httpMethod == "POST" && request.url?.path == "/v1/owner/cakes")
        #expect(request.value(forHTTPHeaderField: "Content-Type")?.hasPrefix("multipart/form-data; boundary=") == true)
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer at_new")
        let body = String(decoding: try #require(request.httpBody), as: UTF8.self)
        #expect(body.contains("name=\"price_vnd\"\r\n\r\n150000"))
        #expect(body.contains("filename=\"cake.jpg\""))
    }

    @Test func impactAsksForTheDailyLimit() async throws {
        let transport = ScriptedTransport { request, _ in
            request.url?.path == "/v1/auth/refresh" ? (200, ScriptedTransport.pair)
                : (200, #"{"daily_limit":40,"over_limit":[{"date":"2026-11-05","cakes_accepted":98}],"count":1}"#)
        }
        let impact = try await api(transport).impact(dailyLimit: 40)
        #expect(transport.requests.last?.url?.query == "daily_limit=40")
        #expect(impact.overLimit.first?.cakesAccepted == 98)
    }

    @Test func pushTokenBodyHasPlatformTokenAndEnvironment() async throws {
        let transport = ScriptedTransport { request, _ in
            request.url?.path == "/v1/auth/refresh" ? (200, ScriptedTransport.pair) : (204, "")
        }
        let client = APIClient(baseURL: URL(string: "http://stub.invalid")!, appVersion: "1.0.0", transport: transport)
        let session = SessionManager(client: client, store: InMemoryTokenStore(refreshToken: "rt"))
        try await HTTPPushAPI(client: client, session: session).register(token: "abc", environment: "sandbox")
        let request = try #require(transport.requests.last)
        #expect(request.httpMethod == "PUT" && request.url?.path == "/v1/admin/push-token")
        let data = try #require(request.httpBody)
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: String])
        #expect(json == ["platform": "ios", "token": "abc", "apns_environment": "sandbox"])
    }

    @Test func conflictErrorsKeepTheirCodeAndFields() async throws {
        let transport = ScriptedTransport { request, _ in
            request.url?.path == "/v1/auth/refresh" ? (200, ScriptedTransport.pair) : ScriptedTransport.error(409, "STAFF_LIMIT_REACHED")
        }
        await #expect(throws: APIError.self) { try await api(transport).addStaff(name: "A", email: "a@example.com") }
    }
}
