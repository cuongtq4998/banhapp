import Foundation

/// A code that must be mailed after the response (registered, active address).
struct CodeMail: Sendable {
    let codeID: UUID
    let to: String
    let code: String
}

/// Step 1 of sign-in: `POST /v1/auth/code-requests` (api/05 10.1).
struct CodeRequestService: Sendable {
    let store: AuthStore
    let clock: any WallClock
    let codes: SignInCodes
    let shopID: UUID
    /// Requests per UTC day, registered or not (auth.md 4.2 "Global mail cap").
    let maxPerDay: Int

    private static var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }

    /// Limits first, then the row. Unregistered addresses get the same row and
    /// the same limits, so nothing but the mail differs.
    func requestCode(_ email: EmailAddress) async throws -> CodeMail? {
        let now = clock.now(), shopID = shopID, maxPerDay = maxPerDay
        let code = SignInCodes.makeCode()
        let realHash = codes.hmac(email: email, code: code)
        let expires = now.addingTimeInterval(AuthPolicy.codeLifetime)
        let utc = Self.utc
        let dayStart = utc.startOfDay(for: now)
        let nextDay = utc.date(byAdding: .day, value: 1, to: dayStart) ?? now.addingTimeInterval(86_400)

        return try await store.transaction { tx in
            try await tx.lockAddress(email.value)
            let last = try await tx.latestCodeCreatedAt(email: email.value)
            if let wait = AuthRules.resendWait(lastCreatedAt: last, now: now) {
                throw APIError.waiting(.codeResendWait, seconds: wait)
            }
            let recent = try await tx.codeTimes(email: email.value, since: now.addingTimeInterval(-AuthPolicy.hourWindow))
            if let wait = AuthRules.hourlyWait(createdInWindow: recent, now: now) {
                throw APIError.waiting(.codeRequestLimit, seconds: wait)
            }
            if try await tx.codeCount(since: dayStart) >= maxPerDay {
                throw APIError.waiting(.codeRequestLimit, seconds: Int(nextDay.timeIntervalSince(now).rounded(.up)))
            }
            let account = try await tx.activeAccount(shopID: shopID, email: email.value)
            let id = UUID()
            try await tx.consumeOpenCodes(email: email.value, at: now)
            try await tx.insertCode(
                id: id, email: email.value, accountID: account?.id,
                hmac: account == nil ? SignInCodes.phantomHash() : realHash, createdAt: now, expiresAt: expires
            )
            return account.map { _ in CodeMail(codeID: id, to: email.value, code: code) }
        }
    }
}
