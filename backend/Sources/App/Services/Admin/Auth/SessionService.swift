import Foundation

/// The signed-in caller, set by `AdminAuthMiddleware`.
struct AdminPrincipal: Sendable {
    let sessionID: UUID
    let accountID: UUID
    let role: AccountRole
    let isReview: Bool
    let displayName: String
    let platform: String
}

/// Renewal and sign-out (api/05 10.3, api/06 10.6).
struct SessionService: Sendable {
    let store: AuthStore
    let clock: any WallClock

    private enum Outcome: Sendable {
        case renewed(access: SessionToken, refresh: SessionToken)
        case failed(APIErrorCode)
    }

    /// Rotates the pair. The failures that must be kept (reuse revokes the
    /// session) are returned and thrown after the commit.
    func refresh(_ presented: SessionToken) async throws -> (access: SessionToken, refresh: SessionToken) {
        guard presented.kind == .refresh else { throw APIError(.sessionRevoked) }
        let now = clock.now()
        let outcome = try await store.transaction { tx -> Outcome in
            guard let session = try await tx.lockSession(id: presented.sessionID),
                  !session.isRevoked, session.accountActive else { return .failed(.sessionRevoked) }
            let decision = AuthRules.refreshDecision(
                presented: presented.hash, current: session.refreshHash, previous: session.previousHash,
                rotatedAt: session.rotatedAt, expiresAt: session.refreshExpiresAt, now: now
            )
            switch decision {
            case .expired:
                return .failed(.sessionExpired)
            case .reuse:
                try await tx.revoke(sessionID: presented.sessionID, reason: .reuseDetected, now: now)
                try await tx.insertEvent(.refreshReuseDetected, accountID: session.accountID, sessionID: presented.sessionID, platform: session.platform, at: now)
                return .failed(.sessionRevoked)
            case .rotate, .rotateAgain:
                let access = SessionToken.issue(.access, sessionID: presented.sessionID)
                let refresh = SessionToken.issue(.refresh, sessionID: presented.sessionID)
                try await tx.rotate(
                    sessionID: presented.sessionID, access: access.hash, refresh: refresh.hash,
                    replacing: session.refreshHash, keepPrevious: decision == .rotateAgain, now: now
                )
                return .renewed(access: access, refresh: refresh)
            }
        }
        switch outcome {
        case .renewed(let access, let refresh): return (access, refresh)
        case .failed(let code): throw APIError(code)
        }
    }

    func signOut(_ principal: AdminPrincipal) async throws {
        let now = clock.now()
        try await store.transaction { tx in
            try await tx.revoke(sessionID: principal.sessionID, reason: .signedOut, now: now)
            try await tx.insertEvent(.signOut, accountID: principal.accountID, sessionID: principal.sessionID, platform: principal.platform, at: now)
        }
    }

    /// Ends every other phone of the caller's own account; the caller stays.
    func signOutOthers(_ principal: AdminPrincipal) async throws {
        let now = clock.now()
        try await store.transaction { tx in
            try await tx.revokeOthers(accountID: principal.accountID, keeping: principal.sessionID, now: now)
            try await tx.insertEvent(.signOutOthers, accountID: principal.accountID, sessionID: principal.sessionID, platform: principal.platform, at: now)
        }
    }
}
