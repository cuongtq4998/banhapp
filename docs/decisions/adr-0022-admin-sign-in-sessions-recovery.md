# ADR-0022: Admin sign-in by e-mail code, sessions with rotating refresh credentials, owner recovery

| Field    | Value |
| -------- | ----- |
| ADR      | 0022 |
| Version  | 1.0 |
| Status   | Proposed (security and customer data: owner confirms; the functional rules are already decided by the owner as Q-3, Q-4, Q-14 to Q-16) |
| Date     | 2026-10-31 |
| Decider  | atlas-architect proposes; product owner confirms |
| Based on | PRD admin-orders FR-1 to FR-7, FR-36, FR-37, FR-42, FR-43, BR-5 to BR-8, BR-17; TQ-4, TQ-9, TQ-10; standard 07 |

## Context

Staff and owner sign in with an e-mail address and a 6-digit code. A device stays signed in 7 days, renewed on each use (Q-15). A deactivated account or revoked device must lose data access within 5 minutes and must not renew at once. A reused renewal credential signs the device out. The owner recovers with two codes, one per mailbox (Q-16). Responses must not reveal whether an address is registered. The backend is one Swift process with PostgreSQL; request volume is tiny.

## Decision Drivers

- Revocation must be exact and simple to test; no key management if it can be avoided.
- A lost refresh response (flaky mobile network) must not sign a good device out.
- Six-digit codes are guessable if the database leaks, so they need a keyed hash and attempt limits.
- Account existence must not leak through timing, text or state.

## Options Considered

| Option | Pros | Cons |
| ------ | ---- | ---- |
| A. Access token as a signed JWT (5 min), no database check | Stateless | Revocation only at expiry; signing key to manage; a JWT library; we read the database on every request anyway |
| B. Opaque access token (5 min, hash stored, checked against the device session row on every request) plus opaque refresh token (chosen) | Revocation is immediate (0 s, bound 5 min even if a check were cached); no signing key; two small tables | One indexed lookup per request (negligible at 5 requests per second) |
| C. Server session cookie with sliding expiry | One credential | Not renewable as designed (FR-36); weaker reuse detection |

## Decision

Option B. Details (values are configuration, defaults shown):

- Credentials: access token `at_<device_id>_<secret>` and refresh token `rt_<device_id>_<secret>`, secret 256 bits from the system CSPRNG, base64url. Only SHA-256 hashes are stored; the device id in the token locates the row, then the hash is compared in constant time. Access lifetime 300 s. Refresh lifetime 7 days, restarted on every successful refresh (Q-15); no absolute cap (owner decision; risk R-AO-4).
- Rotation with family reuse detection: one `device_session` row is the family. A refresh stores the old hash as `previous_refresh_hash` and the time. Presenting the previous hash after 20 s (`REFRESH_GRACE_SECONDS`), or a hash that matches neither, revokes the whole session (`reuse_detected`) and writes a security event. Presenting the previous hash within 20 s is a lost response: the server rotates again from the current state and returns a new pair, so the legitimate retry works.
- Revocation: sign-out, owner revoke, account deactivation (all sessions of the account in the same transaction) and reuse set `revoked_at` and delete the push token. Every authenticated request joins the session and account rows; revoked or inactive means 401 at once.
- Codes: 6 digits, valid 10 minutes, one use; a new code consumes older ones. Stored as HMAC-SHA256 with the server secret `AUTH_CODE_PEPPER`, bound to address and purpose. Wrong codes counted per address in `auth_email_state` (5 wrong, locked 15 minutes, a locked address refuses even a correct code). Requests: 30 s between codes, 3 per hour per address, a global daily mail cap (default 80, below the provider's free daily cap) and 20 per hour per client address. These limits do not depend on the client address being correct (ADR-0019 stays open): the keys are the address and the global cap.
- No existence leak: for an unregistered address the server writes the same `auth_code` row without an account and sends nothing, so request counts, expiry, lockout and error codes behave the same. The send runs after the response.
- Recovery (owner): `recovery-requests` creates one challenge with two codes (purposes `recovery_owner`, `recovery_backup`) when the address is the owner's and a backup address is confirmed; otherwise it answers the same and sends nothing. `recovery-sessions` needs both codes at once; the attempt counter and lockout are shared with the address; success consumes both, creates a session, and sends a notice to both mailboxes. Backup e-mail: set by `PUT /v1/owner/backup-email` (code to the new address) and confirmed with the code; a change sends a notice to the owner address and the old backup address.
- Device identity (TQ-9): the app generates a random `installation_id` (UUID) once and sends it with a short `device_name` (model, no user name; at most 60 characters). The server creates the session id (the "device" in lists). A new sign-in with the same installation id revokes the earlier session of that installation, so the list does not fill with ghosts. No hardware identifier is read.
- First owner (A-2): a Vapor command `bootstrap-owner` (e-mail, name) run by the operator; it refuses when an owner exists.
- On devices: iOS Keychain (accessible after first unlock, this device only); Android a Keystore-wrapped key encrypting the app-private store (unverified details, forge-dev spike).

## Consequences

- Positive: exact revocation, no signing key, one place to test (`device_session`); behaviour identical for unknown addresses.
- Negative: an address can be locked by someone typing five wrong codes (denial of sign-in, not access); accepted per BR-5. Every request costs one extra lookup.
- Follow-up: forge-dev builds the tables of data-model/04, endpoints api/05, workflow `session-lifecycle.md`. The owner confirms this ADR and the test-code rule of auth/abuse-secrets-threats.md section 5 (no fixed code in production).

## Sources

| Claim | Source (URL) | Read on | Confidence |
| ----- | ------------ | ------- | ---------- |
| Refresh rotation and revoking on replay are current practice (RFC 9700 section 4.14) | https://www.rfc-editor.org/rfc/rfc9700 | 2026-10-31 (PRD S-6) | Medium (normative text not read) |
| A grace window for retried refresh requests is a known practice (Auth0 "reuse interval") | not fetched | 2026-10-31 | Unverified |
| Short codes need attempt limits and keyed hashing | OWASP Authentication Cheat Sheet, not fetched | 2026-10-31 | Unverified |

## Links

Related: ADR-0014, ADR-0019, ADR-0023, ADR-0027. Detail: auth.md, session-lifecycle.md, api/05.
