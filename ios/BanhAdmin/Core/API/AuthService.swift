import BanhCore
import Foundation

/// Sign-in calls the sign-in screens use (api/05 10.1, 10.2).
nonisolated protocol AuthService: Sendable {
    func requestCode(email: String) async throws -> CodeRequestResponse
    func signIn(email: String, code: String) async throws -> SignedInUser
}

nonisolated struct HTTPAuthService: AuthService {
    let client: APIClient
    let session: SessionManager
    let installationID: String
    let deviceName: String

    func requestCode(email: String) async throws -> CodeRequestResponse {
        try await client.decode(
            CodeRequestResponse.self, "POST", path: "/v1/auth/code-requests",
            body: try JSONEncoder().encode(["email": email])
        )
    }

    func signIn(email: String, code: String) async throws -> SignedInUser {
        let response = try await session.signIn(
            email: email, code: code, installationID: installationID, deviceName: deviceName
        )
        return SignedInUser(account: response.account, email: email, serverDate: response.serverDate)
    }
}
