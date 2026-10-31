# ADR-0022: Admin sign-in by e-mail code, sessions with rotating refresh credentials, owner recovery

| Field    | Value |
| -------- | ----- |
| ADR      | 0022 |
| Version  | 1.2 [v1.2 | 2026-10-31] (aligned with PRD v1.4; simplified) |
| Status   | Accepted (product owner, 2026-10-31, including the 20 s refresh grace, one code for ordinary owner sign-in, no time lock Q-20 and the new-device notice Q-24) [v1.2 | 2026-10-31] |
| Date     | 2026-10-31 |
| Decider  | atlas-architect proposes; product owner accepted on 2026-10-31 [v1.1 | 2026-10-31] |
| Based on | PRD admin-orders FR-1 to FR-7, FR-36, FR-37, FR-42, FR-43, BR-5 to BR-8, BR-17, BR-26, FR-47; Q-20, Q-24; TQ-4, TQ-9, TQ-10, TQ-11, TQ-13; standard 07 |

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
- Codes: 6 digits, valid 10 minutes, one use; a new code consumes older ones. Stored as HMAC-SHA256 with the server secret `AUTH_CODE_PEPPER`, bound to address and purpose. Wrong entries are counted on the code itself (`auth_code.wrong_count`): the 5th wrong entry voids that code, so even its correct digits are refused with `CODE_EXPIRED` ("request a new code"); there is NO time lock on the address and no second table (owner decision Q-20, BR-5) [v1.2 | 2026-10-31]. Requests: 30 s between codes, 3 per hour per address, a global daily mail cap (default 80, below the provider's free daily cap) and 20 code requests per hour per client address, 60 requests an hour per client address on the other `/v1/auth` routes (sessions, refresh, recovery) [v1.1 | 2026-10-31]. Counters are per address AND purpose, so recovery has its own 30 s wait, 3 an hour and 5-wrong void; ordinary sign-in and recovery never block each other (BR-17). Shared counters with a recovery path were considered and rejected: a stranger could block the owner's way back in [v1.2 | 2026-10-31]. Only the provider-protecting daily mail cap is global. These limits do not depend on the client address being correct (ADR-0019 stays open): the keys are the address and the global cap.
- No existence leak: for an unregistered address the server writes the same `auth_code` row without an account and sends nothing, so request counts, expiry, lockout and error codes behave the same. The send runs after the response.
- Ordinary owner sign-in (owner decision 2026-10-31, closes SL-Q1): the owner signs in exactly like staff, with ONE code sent to the owner address, on any device, whether or not a backup address exists. Recovery below is a separate flow and is never required.
- Recovery (owner; kept as a separate flow, see auth.md section 2 for what it does and does not protect): `recovery-requests` creates one challenge with two codes (purposes `recovery_owner`, `recovery_backup`) when the address is the owner's and a backup address is confirmed; otherwise it answers the same and sends nothing. `recovery-sessions` needs both codes at once; a wrong entry adds 1 to `wrong_count` of both rows and the 5th voids the attempt (both codes), without touching ordinary sign-in; success consumes both, creates a session, and sends the recovery notice to both mailboxes (this is the only notice, no second new-device notice). Backup e-mail: set by `PUT /v1/owner/backup-email` (code to the new address) and confirmed with the code; a change sends a notice to the owner address and the old backup address.
- Device identity (TQ-9): the app generates a random `installation_id` (UUID) once and sends it with a short `device_name` (model and operating system, no user name; at most 60 characters; format in api/05 10.2) [v1.1 | 2026-10-31]. The server creates the session id (the "device" in lists). A new sign-in with the same installation id revokes the earlier session of that installation, so the list does not fill with ghosts. No hardware identifier is read.
- New-device notice (FR-47, BR-26, TQ-13) [v1.2 | 2026-10-31]: a device is new when, at a successful code sign-in of the OWNER account, no unrevoked, unexpired `device_session` of that account has the same `installation_id`. The check runs before the older session of the installation is replaced, in the same transaction as the session insert. Staff, renewals, recovery and review sign-ins send nothing. The notice goes to the owner address and the confirmed backup address, after the response, by the same mail task and retry as codes (one retry after 5 s); a failure is logged without addresses and never affects the sign-in. Content: device name, time, "revoke it in the device list if this was not you"; no code, no link. It needs no table and is not counted in the daily cap (a security notice must not be blocked by it; owner sign-ins are rare, at most 2 mails each). Consequence accepted: signing in again after sign-out or after 7 idle days counts as a new device and sends a notice. The `installation_id` is never shown in any list, so a stranger cannot claim a known one.
- First owner (A-2): a Vapor command `bootstrap-owner` (e-mail, name) run by the operator; it refuses when an owner exists.
- Offline sign-out (TQ-D6) [v1.1 | 2026-10-31]: the app clears customer data and shows the sign-in screen at once; if the server call fails it keeps only the refresh token as a pending sign-out (no customer data), unregisters the push token locally, and retries on the next launch or connection (refresh, then `DELETE /v1/admin/session`) until the answer is 204 or 401, at most 7 days. Until then pushes (code, cakes, date only) may still arrive; the owner can revoke the device sooner.
- On devices: iOS Keychain (accessible after first unlock, this device only); Android a Keystore-wrapped key encrypting the app-private store (unverified details, forge-dev spike).

## Consequences

- Positive: exact revocation, no signing key, one place to test (`device_session`); behaviour identical for unknown addresses.
- Negative: a stranger can void codes and use the 3 requests an hour of an address (denial of one sign-in, never of access or recovery; signed-in devices are unaffected); accepted per BR-5 and Q-20. A stranger gets at most 15 guesses an hour per address. Every request costs one extra lookup.
- Follow-up: forge-dev builds the tables of data-model/04, endpoints api/05, workflow `session-lifecycle.md`. The test-code rule of auth/abuse-secrets-threats.md section 5 (no fixed code in production) stands as part of this decision.

## Sources

| Claim | Source (URL) | Read on | Confidence |
| ----- | ------------ | ------- | ---------- |
| Refresh rotation and revoking on replay are current practice (RFC 9700 section 4.14) | https://www.rfc-editor.org/rfc/rfc9700 | 2026-10-31 (PRD S-6) | Medium (normative text not read) |
| A grace window for retried refresh requests is a known practice (Auth0 "reuse interval") | not fetched | 2026-10-31 | Unverified |
| Short codes need attempt limits and keyed hashing | OWASP Authentication Cheat Sheet, not fetched | 2026-10-31 | Unverified |

## Links

Related: ADR-0014, ADR-0019, ADR-0023, ADR-0027. Detail: auth.md, session-lifecycle.md, api/05.
