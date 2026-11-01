import BanhCore
import Foundation

/// `PUT /v1/admin/push-token` (api/06 10.8). There is no delete: the server clears the token when the
/// session ends.
nonisolated protocol PushAPI: Sendable {
    func register(token: String, environment: String) async throws
}

nonisolated struct HTTPPushAPI: PushAPI {
    let client: APIClient
    let session: SessionManager

    func register(token: String, environment: String) async throws {
        let body = try JSONEncoder().encode(["platform": "ios", "token": token, "apns_environment": environment])
        _ = try await session.authorized { bearer in
            try await client.send("PUT", path: "/v1/admin/push-token", body: body, headers: ["Authorization": "Bearer \(bearer)"])
        }
    }
}
