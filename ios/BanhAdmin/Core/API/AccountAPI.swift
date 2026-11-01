import BanhCore
import Foundation

/// Calls about the signed-in person and their sessions (api/06 10.6).
nonisolated protocol AccountAPI: Sendable {
    func me() async throws -> MeResponse
    func signOutOthers() async throws
}

nonisolated struct HTTPAccountAPI: AccountAPI {
    let client: APIClient
    let session: SessionManager

    func me() async throws -> MeResponse {
        try await session.authorized { token in
            try await client.decode(MeResponse.self, "GET", path: "/v1/admin/me", headers: ["Authorization": "Bearer \(token)"])
        }
    }

    func signOutOthers() async throws {
        _ = try await session.authorized { token in
            try await client.send("DELETE", path: "/v1/admin/sessions/others", headers: ["Authorization": "Bearer \(token)"])
        }
    }
}
