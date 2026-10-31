import Vapor

// Request and response bodies of api/05 sections 10.1 to 10.3 (snake_case).

struct CodeRequestBody: Content {
    let email: String
}

struct CodeRequestResponse: Content {
    let resendAfterSeconds: Int
    let expiresInSeconds: Int
    enum CodingKeys: String, CodingKey {
        case resendAfterSeconds = "resend_after_seconds", expiresInSeconds = "expires_in_seconds"
    }
}

struct SignInBody: Content {
    let email: String
    let code: String
    let installationID: String
    let deviceName: String
    enum CodingKeys: String, CodingKey {
        case email, code, installationID = "installation_id", deviceName = "device_name"
    }
}

struct AccountSummary: Content {
    let name: String
    let role: String
}

struct SignInResponse: Content {
    let accessToken: String
    let refreshToken: String
    let accessExpiresIn: Int
    let deviceID: UUID
    let account: AccountSummary
    let serverDate: String
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token", refreshToken = "refresh_token", accessExpiresIn = "access_expires_in"
        case deviceID = "device_id", account, serverDate = "server_date"
    }
}

struct RefreshBody: Content {
    let refreshToken: String
    enum CodingKeys: String, CodingKey { case refreshToken = "refresh_token" }
}

struct RefreshResponse: Content {
    let accessToken: String
    let refreshToken: String
    let accessExpiresIn: Int
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token", refreshToken = "refresh_token", accessExpiresIn = "access_expires_in"
    }
}

struct MeResponse: Content {
    let account: AccountSummary
    let deviceID: UUID
    let serverDate: String
    enum CodingKeys: String, CodingKey { case account, deviceID = "device_id", serverDate = "server_date" }
}
