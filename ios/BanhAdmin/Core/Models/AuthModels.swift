import Foundation

nonisolated enum AccountRole: String, Codable, Equatable, Sendable {
    case owner
    case staff
}

nonisolated struct AdminAccount: Codable, Equatable, Sendable {
    let name: String
    let role: AccountRole
}

/// `POST /v1/auth/sessions` 201.
nonisolated struct SessionResponse: Codable, Equatable, Sendable {
    let accessToken: String
    let refreshToken: String
    let accessExpiresIn: Int
    let deviceId: String
    let account: AdminAccount
    let serverDate: String
}

/// `POST /v1/auth/refresh` 200.
nonisolated struct RefreshResponse: Codable, Equatable, Sendable {
    let accessToken: String
    let refreshToken: String
    let accessExpiresIn: Int
}

/// `POST /v1/auth/code-requests` 202.
nonisolated struct CodeRequestResponse: Codable, Equatable, Sendable {
    let resendAfterSeconds: Int
    let expiresInSeconds: Int
}

/// `GET /v1/admin/me` 200.
nonisolated struct MeResponse: Codable, Equatable, Sendable {
    let account: AdminAccount
    let deviceId: String
    let serverDate: String
}

/// What the app keeps in memory for a signed-in person. Never written to disk.
nonisolated struct SignedInUser: Equatable, Sendable {
    let account: AdminAccount
    /// Known only right after sign-in: `GET /v1/admin/me` does not return it, and it is not stored.
    let email: String?
    let serverDate: String
}
