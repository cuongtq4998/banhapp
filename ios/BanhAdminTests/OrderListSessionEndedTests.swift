import BanhCore
import Foundation
import Testing
@testable import BanhAdmin

/// A staff member deactivated while the list is on screen: the next chip tap must end the session
/// through the session manager (the list itself stays silent, `SessionEnded` is the coordinator's job).
@MainActor
struct OrderListSessionEndedTests {
    @Test func aRevokedSessionOnAChipChangeEndsTheSessionAndShowsTheSignInMessage() async throws {
        let store = InMemoryTokenStore(refreshToken: "rt_old")
        let base = URL(string: "http://stub.invalid")!
        let transport = ScriptedTransport { request, _ in
            request.url?.path == "/v1/admin/orders" ? ScriptedTransport.error(401, "SESSION_REVOKED") : (200, ScriptedTransport.pair)
        }
        let client = APIClient(baseURL: base, appVersion: "1.0.0", transport: transport)
        let session = SessionManager(client: client, store: store)
        let ended = EndedFlag()
        await session.setOnEnded { ended.set() }
        let model = OrderListViewModel(api: HTTPOrdersAPI(client: client, session: session), debounce: .milliseconds(1))
        model.select(status: .processing)
        for _ in 0..<50 where !ended.value { try await Task.sleep(for: .milliseconds(20)) }
        #expect(ended.value, "the 401 reached the session manager and ended the session")
        #expect(store.refreshToken == nil)
        #expect(model.rows.isEmpty)
    }
}
