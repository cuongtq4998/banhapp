import Foundation

struct SignInAttempt: Sendable {
    let email: EmailAddress
    let code: String
    let installationID: UUID
    let platform: String
    let deviceName: String
}

/// Owner signed in on a phone not used before (FR-7, BR-13).
struct NewDeviceNotice: Sendable {
    let to: String
    let deviceName: String
    let at: Date
}

struct SignInResult: Sendable {
    let access: SessionToken
    let refresh: SessionToken
    let sessionID: UUID
    let accountName: String
    let role: AccountRole
    let serverDate: String
    let notice: NewDeviceNotice?
}

/// Step 2 of sign-in: `POST /v1/auth/sessions` (api/05 10.2).
struct SignInVerifyService: Sendable {
    let store: AuthStore
    let clock: any WallClock
    let codes: SignInCodes

    private enum Outcome: Sendable {
        case signedIn(SignInResult)
        case invalid
        case expired
    }

    func verify(_ attempt: SignInAttempt) async throws -> SignInResult {
        let now = clock.now(), codes = codes
        let serverDate = ShopCalendar(clock: clock).today().description
        let outcome = try await store.transaction { tx -> Outcome in
            // Unknown and unregistered addresses have phantom rows, so they take this path too.
            guard let stored = try await tx.lockOpenCode(email: attempt.email.value) else { return .invalid }
            if AuthRules.isVoid(wrongCount: stored.wrongCount) || AuthRules.isExpired(expiresAt: stored.expiresAt, now: now) {
                return .expired
            }
            guard codes.matches(stored.hmac, email: attempt.email, code: attempt.code) else {
                // The wrong entry is kept (the commit happens); the 5th voids the code.
                let count = try await tx.addWrongEntry(codeID: stored.id)
                return AuthRules.isVoid(wrongCount: count) ? .expired : .invalid
            }
            guard let accountID = stored.accountID, let account = try await tx.activeAccount(id: accountID) else {
                return .invalid
            }
            try await tx.consumeCode(id: stored.id, at: now)
            var isNewDevice = false
            if account.role == .owner {
                let live = try await tx.liveSessionCount(accountID: account.id, installationID: attempt.installationID, now: now)
                isNewDevice = live == 0
            }
            try await tx.revokeInstallation(attempt.installationID, now: now)

            let sessionID = UUID()
            let access = SessionToken.issue(.access, sessionID: sessionID)
            let refresh = SessionToken.issue(.refresh, sessionID: sessionID)
            try await tx.insertSession(NewSession(
                id: sessionID, accountID: account.id, installationID: attempt.installationID,
                platform: attempt.platform, deviceName: attempt.deviceName,
                accessHash: access.hash, refreshHash: refresh.hash, now: now
            ))
            try await tx.insertEvent(.signIn, accountID: account.id, sessionID: sessionID, platform: attempt.platform, at: now)
            return .signedIn(SignInResult(
                access: access, refresh: refresh, sessionID: sessionID, accountName: account.displayName,
                role: account.role, serverDate: serverDate,
                notice: isNewDevice ? NewDeviceNotice(to: account.email, deviceName: attempt.deviceName, at: now) : nil
            ))
        }
        switch outcome {
        case .signedIn(let result): return result
        case .invalid: throw APIError(.codeInvalid)
        case .expired: throw APIError(.codeExpired)
        }
    }
}
