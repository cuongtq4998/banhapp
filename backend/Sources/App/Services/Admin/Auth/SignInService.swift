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
    /// The store-review account (ADR-0027); nil while it is off.
    var review: ReviewAccountConfig?

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
        let review = review
        let fixedHash = review.map { codes.hmac(email: email, code: $0.code) }
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
            // A review account is a registered address only while the switch is on.
            let account = try await tx.activeAccount(shopID: shopID, email: email.value)
                .flatMap { $0.isReview && !(review?.isReviewAddress(email) ?? false) ? nil : $0 }
            let id = UUID()
            try await tx.consumeOpenCodes(email: email.value, at: now)
            try await tx.insertCode(
                id: id, email: email.value, accountID: account?.id,
                hmac: hash(for: account, real: realHash, fixed: fixedHash), createdAt: now, expiresAt: expires
            )
            // The review address gets the same answer and limits, but no mail: its code is fixed.
            return account.flatMap { $0.isReview ? nil : CodeMail(codeID: id, to: email.value, code: code) }
        }
    }

    /// Registered normal account: the hash of the mailed code. Review account:
    /// the hash of the fixed code. Unregistered: a random hash that never matches.
    private func hash(for account: AccountRecord?, real: Data, fixed: Data?) -> Data {
        guard let account else { return SignInCodes.phantomHash() }
        return account.isReview ? (fixed ?? SignInCodes.phantomHash()) : real
    }
}
